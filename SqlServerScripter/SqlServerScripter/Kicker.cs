using log4net;
using log4net.Config;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace SqlServerScripter {
    class Kicker {

        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));
        public const string SUFFIX_STR_NEW = "_NEW";
        public const string SUFFIX_STR_OLD = "_OLD";
        public const string TIME_FORMAT = "yyyyMMddHHmmss";

        private static String CHECK_STR = @"\b\[{0}\]\b|\b{1}\b";
        const string INSERT_PAT = @"insert[\s]+into\b";
        
        private static String SMALL_FL_TMPL = "{0}_small_tables_{1}.sql";
        private static String BIG_FL_TMPL = "{0}_{1}_{2}_{3}_{4}.sql";
        private static string STAR_STR = "PRINT '****************************************************************************************';" + Environment.NewLine;

        static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info("===> START");

            String server = ConfigurationManager.AppSettings["SRV_NAME"].ToString();
            String tblLstXls = ConfigurationManager.AppSettings["TBL_LIST"].ToString();
            Dictionary<string, List<CustomTable>> data = ExcelOps.getExcelSheetData(tblLstXls);

            LOGGER.Info("Server: " + server);
            LOGGER.Info("Table List: " + tblLstXls);

            string outFileSmall = String.Format(SMALL_FL_TMPL, server,DateTime.Now.ToString(TIME_FORMAT));
            bool smallOp = true;
            foreach (KeyValuePair<string, List<CustomTable>> kv in data) {

                string k = kv.Key.ToString();
                string k0 = k.Split(ExcelOps.HYPHEN)[0];
                string k1 = k.Split(ExcelOps.HYPHEN)[1];

                TblSize size = (TblSize)Enum.Parse(typeof(TblSize), k0);

                String database = k1.Split(ExcelOps.DOT)[0];
                String schema = k1.Split(ExcelOps.DOT)[1];
                String table = k1.Split(ExcelOps.DOT)[2];

                String connStr = String.Format(ConfigurationManager.ConnectionStrings["CONN_STR"].ToString(), server, database);

                LOGGER.Info("Table Operation Size: " + size.ToString());
                LOGGER.Info("Database: " + database);
                LOGGER.Info("Schema Name: " + schema);
                LOGGER.Info("Table Name: " + table);

                LinkedList<String> outLines = new LinkedList<string>();

                switch (size) {
                    case TblSize.BIG:
                        smallOp = false;
                        outLines = BigOp(connStr, server, database, schema, table, kv.Value);
                        if (outLines.Count > 0) {
                            String outFileBig = String.Format(BIG_FL_TMPL,server,database,schema,table,DateTime.Now.ToString(TIME_FORMAT));
                            LOGGER.Info("Writing file: " + outFileBig);
                            File.WriteAllLines(outFileBig, outLines);
                            MoveToOutputDir(server, outFileBig);
                        }
                        break;
                    case TblSize.SMALL:
                        outLines = SmallOp(connStr, server, database, schema, table, kv.Value);
                        if (outLines.Count > 0) {
                            LOGGER.Info("Writing file: " + outFileSmall);
                            File.AppendAllLines(outFileSmall, outLines);
                        }
                        break;
                    case TblSize.ERR:
                        break;
                }

                if(!smallOp)
                    MoveToOutputDir(server, outFileSmall);

                LOGGER.Info("======");
            }

            MoveToOutputDir(server, outFileSmall);


            LOGGER.Info("===> DONE");
            //Console.ReadLine();
        }

        public static void MoveToOutputDir(string server, string file) {

            if(!Directory.Exists(server))
                Directory.CreateDirectory(server);

            string destFile = Path.Combine(server, file);
            if(File.Exists(file))
                File.Move(file, destFile); 

        }

        public static LinkedList<String> SmallOp(string connStr, string server, string database, string schema, string table, List<CustomTable> data) {
            try {
                LinkedList<String> lines = new LinkedList<String>();
                HashSet<string> relevantObjs = ScriptOps.GetRelevantObjects(server, database, schema, table, data);

                lines.AddLast(STAR_STR);
                lines = ScriptOps.GenerateScriptUseStmt(database, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_NON_CLUST, OpType.DROP, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_CLUST, OpType.DROP, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.CKDF, OpType.DROP, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.STAT, OpType.DROP, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptAlterTable(server, database, schema, table, lines, data);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.CKDF, OpType.CREATE, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_CLUST, OpType.CREATE, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_NON_CLUST, OpType.CREATE, TblSize.SMALL, relevantObjs);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines.AddLast(STAR_STR);

                return lines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        public static LinkedList<String> BigOp(string connStr, string server, string database, string schema, string table, List<CustomTable> data) {
            try {
                OrderedDictionary chkDict = GetTableObjects(table, connStr);
                LinkedList<String> lines = new LinkedList<String>();

                lines = ScriptOps.GenerateScriptUseStmt(database, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptTable(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.CKDF, OpType.CREATE, TblSize.BIG, null);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                //INSERT
                lines = ScriptOps.GenerateScriptInsert(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                //INDEX CLUSTERED
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_CLUST, OpType.CREATE, TblSize.BIG, null);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                //INDEX NON CLUSTERED
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_NON_CLUST, OpType.CREATE, TblSize.BIG, null);
                //lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ReplaceObjectNames(chkDict, lines);
                lines = ReplaceDataTypes(chkDict, data, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.SwapObjects(schema, table, chkDict, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.TRG, OpType.DROP, TblSize.BIG, null);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.TRG, OpType.CREATE, TblSize.BIG, null);
                lines = ScriptOps.GenerateScriptGoStmt(lines);

                return lines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        static void WriteFile(String outFile, LinkedList<String> output) {
            LOGGER.Info("Writing output script file");
            System.IO.File.WriteAllLines(outFile, output);
        }

        static OrderedDictionary GetTableObjects(String tableName, String connStr) {
            LOGGER.Info("Getting all objects related to the desired table");
            try {
                OrderedDictionary chkDict = new OrderedDictionary();

                String sql = @" SELECT name, '" + ObjType.INDEX.ToString() + @"' AS ObjectType FROM sys.indexes 
                                WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) ) 
                                      AND is_unique = 0 AND type in (1,2)
                                UNION ALL  
                                SELECT name, '" + ObjType.PKUQ.ToString() + @"' AS ObjectType  FROM sys.all_objects 
                                WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                                      AND type IN ('PK','UQ')
                                UNION ALL
                                SELECT name, '" + ObjType.TRG.ToString() + @"' AS ObjectType FROM sys.all_objects
                                WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                                      AND type IN('TR')
                                UNION ALL  
                                SELECT name, '" + ObjType.CKDF.ToString() + @"' AS ObjectType FROM sys.all_objects 
                                WHERE parent_object_id IN (SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                                      AND type IN ('C','D')
                                UNION ALL  
                                SELECT name, '" + ObjType.TABLE.ToString() + @"' AS ObjectType FROM sys.all_objects 
                                WHERE name IN( '{0}' )
                                ";
                sql = String.Format(sql, tableName);

                DataTable dt = new DataTable();
                using (SqlConnection cn = new SqlConnection(connStr))
                using (SqlCommand cmd = new SqlCommand(sql, cn))
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    da.Fill(dt);

                foreach (DataRow r in dt.Rows) {
                    if (!String.IsNullOrEmpty(r["name"].ToString())) {
                        chkDict.Add(r["name"].ToString(), r["ObjectType"].ToString());
                    }
                }

                return chkDict;

            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        static LinkedList<String> ReplaceDataTypes(OrderedDictionary chkDict, List<CustomTable> data, LinkedList<String> lines) {
            LOGGER.Info("Replacing data types");
            string pattern = @"{0}\b[\s]+{1}\b|\[{0}\b\][\s]+\[{1}\b\]";
            foreach (string line in lines) {
                if (line.StartsWith("CREATE TABLE")) {
                    string val = line;
                    foreach (CustomTable ct in data) {
                        string strPat = String.Format(pattern, ct.ColumnName, ct.OldDataType);
                        string strRpl = "[" + ct.ColumnName + "] [" + ct.NewDataType + "]";
                        val = Regex.Replace(val, strPat, strRpl, RegexOptions.IgnoreCase);
                    }
                    lines.Find(line).Value = val;
                }
            }

            return lines;
        }


        static LinkedList<String> ReplaceObjectNames(OrderedDictionary chkDict, LinkedList<String> lines) {
            LOGGER.Info("Replacing object names with the suffix " + SUFFIX_STR_NEW);
            try {
                LinkedList<String> outLines = new LinkedList<String>(lines);

                foreach (DictionaryEntry de in chkDict) {
                    if (!String.IsNullOrEmpty(de.Key.ToString())) {
                        foreach (String line in outLines) {
                            if (!Regex.IsMatch(line, INSERT_PAT, RegexOptions.IgnoreCase)) {
                                String x = Regex.Replace(line, String.Format(CHECK_STR, de.Key.ToString(), de.Key.ToString()), de.Key.ToString() + SUFFIX_STR_NEW);
                                if (x != line)
                                    outLines.Find(line).Value = x;
                            }
                        }
                    }
                }
                return outLines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

    }
}