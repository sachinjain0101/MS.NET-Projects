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

        private static String CHECK_STR = "\\b\\[{0}\\]\\b|\\b{1}\\b";
        private static String SMALL_TABLE = "small_tables_{0}.sql";
        private static String BIG_TABLE = "big_tables_{0}.sql";

        static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info("===> START");

            String server = ConfigurationManager.AppSettings["SRV_NAME"].ToString();
            String tblLstXls = ConfigurationManager.AppSettings["TBL_LIST"].ToString();
            Dictionary<string, List<CustomTable>> data = ExcelOps.getExcelSheetData(tblLstXls);

            LOGGER.Info("Server: " + server);
            LOGGER.Info("Table List: " + tblLstXls);

            string smallTablesFile = String.Format(SMALL_TABLE, DateTime.Now.ToString(TIME_FORMAT));
            string bigTablesFile = String.Format(BIG_TABLE, DateTime.Now.ToString(TIME_FORMAT));

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
                        outLines = BigOp(connStr, server, database, schema, table, kv.Value);
                        if (outLines.Count > 0) {
                            LOGGER.Info("Writing file: " + bigTablesFile);
                            File.AppendAllLines(bigTablesFile, outLines);
                        }
                        if (outLines.Count > 0) {
                            String outFile = server + "_" + database + "_" + schema + "_" + table + "_" + DateTime.Now.ToString(TIME_FORMAT) + ".sql";
                            LOGGER.Info("Writing file: " + outFile);
                            File.WriteAllLines(outFile, outLines);
                        }
                        break;
                    case TblSize.SMALL:
                        outLines = SmallOp(connStr, server, database, schema, table, kv.Value);
                        if (outLines.Count > 0) {
                            LOGGER.Info("Writing file: " + smallTablesFile);
                            File.AppendAllLines(smallTablesFile, outLines);
                        }
                        break;
                    case TblSize.ERR:
                        break;
                }

                LOGGER.Info("======");
            }

            LOGGER.Info("===> DONE");
            Console.ReadLine();
        }

        public static LinkedList<String> SmallOp(string connStr, string server, string database, string schema, string table, List<CustomTable> data) {
            try {
                LinkedList<String> lines = new LinkedList<String>();

                lines = ScriptOps.GenerateScriptUseStmt(database, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptDropIndexes(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptDropConstraints(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptDropStatistics(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptAlterTable(server, database, schema, table, lines, data);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptConstraints(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptIndexes(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);

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
                lines = ScriptOps.GenerateScriptConstraints(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptInsert(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptIndexes(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ReplaceObjectNames(chkDict, lines);
                lines = ReplaceDataTypes(chkDict, data, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.SwapObjects(schema, table, chkDict, lines);
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

                String sql = @" SELECT name, 'INDEX' AS ObjectType FROM sys.indexes 
                                WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) ) 
                                      AND is_unique = 0
                                UNION ALL  
                                SELECT name, 'PKUQ' AS ObjectType  FROM sys.all_objects 
                                WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                                      AND type IN ('PK','UQ')
                                UNION ALL  
                                SELECT name, 'CKDF' AS ObjectType FROM sys.all_objects 
                                WHERE parent_object_id IN (SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                                      AND type NOT IN ('PK','UQ')
                                UNION ALL  
                                SELECT name, 'TABLE' AS ObjectType FROM sys.all_objects 
                                WHERE name IN( '{0}' )
                                ";
                sql = String.Format(sql, tableName);
                //String qry = "";
                //qry += " SELECT name FROM sys.all_objects WHERE name IN( '{0}' ) ";
                //qry += " UNION ALL ";
                //qry += " SELECT name FROM sys.all_objects WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{1}' ) ) ";
                //qry += " UNION ALL ";
                //qry += " SELECT name FROM sys.indexes WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{2}' ) ) ";
                //qry = String.Format(qry, tableName, tableName, tableName);

                DataTable dt = new DataTable();
                using (SqlConnection cn = new SqlConnection(connStr))
                using (SqlCommand cmd = new SqlCommand(sql, cn))
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    da.Fill(dt);

                foreach (DataRow r in dt.Rows) {
                    chkDict.Add(r["name"].ToString(), r["ObjectType"].ToString());
                }

                return chkDict;

            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        static LinkedList<String> ReplaceDataTypes(OrderedDictionary chkDict, List<CustomTable> data, LinkedList<String> lines) {

            foreach (string line in lines) {
                if (line.StartsWith("CREATE TABLE")) {
                    string val = line;
                    foreach (CustomTable ct in data) {
                        string str = "[" + ct.ColumnName + "] [" + ct.OldDataType + "]";
                        string strRpl = "[" + ct.ColumnName + "] [" + ct.NewDataType + "]";
                        val = val.Replace(str, strRpl);
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
                    foreach (String line in outLines) {
                        if (!line.StartsWith("INSERT INTO")) {
                            String x = Regex.Replace(line, String.Format(CHECK_STR, de.Key.ToString(), de.Key.ToString()), de.Key.ToString() + SUFFIX_STR_NEW);
                            if (x != line)
                                outLines.Find(line).Value = x;
                        }
                    }
                }
                return outLines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }


        static LinkedList<String> SwapOriginalToOld(string table, LinkedList<String> lines) {
            LOGGER.Info("Generating Script to swap Original with Old");
            string sql = @"SELECT 'EXEC dbo.sp_rename '''+name+''' , '''+ name+'Old' + ''';' AS Stmt
                             FROM sys.all_objects WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                             UNION ALL 
                             SELECT 'EXEC dbo.sp_rename '''+'{0}.'+name+''' , '''+ name+'Old' + '''' + CASE WHEN is_unique=1 THEN ' ;' ELSE ' , ''INDEX'';' END AS Stmt
                             FROM sys.indexes WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) ) 
                             UNION ALL
                             SELECT 'EXEC dbo.sp_rename '''+name+''' , '''+ name+'Old' + ''';' AS Stmt
                             FROM sys.all_objects WHERE name IN( '{0}' )";
            sql = String.Format(sql, table);
            return lines;
        }

        static LinkedList<String> SwapNewToOriginal(string table, LinkedList<String> lines) {
            LOGGER.Info("Generating Script to swap New to Original");
            string sql = @"";
            return lines;
        }

    }
}

/* 

 SELECT 'EXEC dbo.sp_rename '''+name+''' , '''+ name+'Old' + ''';' AS Stmt
 FROM sys.all_objects WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( 'tblTimeHistDetail' ) )  
 UNION ALL 
 SELECT 'EXEC dbo.sp_rename '''+'tblTimeHistDetail.'+name+''' , '''+ name+'Old' + '''' + CASE WHEN is_unique=1 THEN ' ;' ELSE ' , ''INDEX'';' END AS Stmt
 FROM sys.indexes WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( 'tblTimeHistDetail' ) ) 
 UNION ALL
 SELECT 'EXEC dbo.sp_rename '''+name+''' , '''+ name+'Old' + ''';' AS Stmt
 FROM sys.all_objects WHERE name IN( 'tblTimeHistDetail' )  

 SELECT 'EXEC dbo.sp_rename '''+name+''' , '''+ REPLACE(name,'New','') + ''';' AS Stmt
 FROM sys.all_objects WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( 'tblTimeHistDetailNew' ) )  
 UNION ALL 
 SELECT 'EXEC dbo.sp_rename '''+'tblTimeHistDetailNew.'+name+''' , '''+ REPLACE(name,'New','') + '''' + CASE WHEN is_unique=1 THEN ';' ELSE ' , ''INDEX'';' END AS Stmt
 FROM sys.indexes WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( 'tblTimeHistDetailNew' ) ) 
 UNION ALL 
 SELECT 'EXEC dbo.sp_rename '''+name+''' , '''+ REPLACE(name,'New','') + ''';' AS Stmt
 FROM sys.all_objects WHERE name IN( 'tblTimeHistDetailNew' )  

*/
