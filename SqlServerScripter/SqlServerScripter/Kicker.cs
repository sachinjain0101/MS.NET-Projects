using log4net;
using log4net.Config;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Text.RegularExpressions;

namespace SqlServerScripter {
    class Kicker {

        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));
        public const string SUFFIX_STR = "_NEW";

        private static String CHECK_STR = "\\b\\[{0}\\]\\b|\\b{1}\\b";

        static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info("===> START");

            String server = ConfigurationManager.AppSettings["SRV_NAME"].ToString();
            String tblLstXls = ConfigurationManager.AppSettings["TBL_LIST"].ToString();
            Dictionary<string, List<CustomTable>> data = ExcelOps.getExcelSheetData(tblLstXls);

            LOGGER.Info("Server: " + server);
            LOGGER.Info("Table List: " + tblLstXls);

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
                        break;
                    case TblSize.SMALL:
                        break;
                    case TblSize.ERR:
                        break;
                }

                if (outLines.Count > 0) {
                    string format = "yyyyMMddHHmmss";
                    String outFile = server + "_" + database + "_" +schema+"_"+ table + "_" + DateTime.Now.ToString(format) + ".sql";
                    WriteFile(outFile, outLines);
                }
                LOGGER.Info("======");
            }

            LOGGER.Info("===> DONE");
            //Console.ReadLine();
        }


        public static LinkedList<String> BigOp(string connStr, string server, string database, string schema, string table, List<CustomTable> data) {
            try {
                LinkedList<String> chkLst = GetChkList(table, connStr);
                LinkedList<String> lines = new LinkedList<String>();

                lines = ScriptOps.GenerateScriptUseStmt(database, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptTable(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptConstraints(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptInsert(table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);
                lines = ScriptOps.GenerateScriptIndexes(server, database, schema, table, lines);
                lines = ScriptOps.GenerateScriptGoStmt(lines);

                LinkedList<String> outLines = ReplaceObjectNames(chkLst, lines);

                return outLines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        static void WriteFile(String outFile, LinkedList<String> output) {
            LOGGER.Info("Writing output script file");
            System.IO.File.WriteAllLines(outFile, output);
        }

        static LinkedList<String> GetChkList(String tableName, String connStr) {
            LOGGER.Info("Getting all objects related to the desired table");
            try {
                LinkedList<String> chkLst = new LinkedList<String>();
                String qry = "";
                qry += " SELECT name FROM sys.all_objects WHERE name IN( '{0}' ) ";
                qry += " UNION ALL ";
                qry += " SELECT name FROM sys.all_objects WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{1}' ) ) ";
                qry += " UNION ALL ";
                qry += " SELECT name FROM sys.indexes WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{2}' ) ) ";

                qry = String.Format(qry, tableName, tableName, tableName);

                DataTable dt = new DataTable();
                using (SqlConnection cn = new SqlConnection(connStr))
                using (SqlCommand cmd = new SqlCommand(qry, cn))
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    da.Fill(dt);

                foreach (DataRow r in dt.Rows)
                    chkLst.AddLast(r["name"].ToString());

                return chkLst;

            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        static LinkedList<String> ReplaceObjectNames(LinkedList<String> chkLst, LinkedList<String> lines) {
            LOGGER.Info("Replacing object names with the suffix " + SUFFIX_STR);
            try {
                LinkedList<String> outLines = new LinkedList<String>(lines);

                foreach (String chk in chkLst) {
                    foreach (String line in outLines) {
                        if (!line.StartsWith("INSERT INTO")) {
                            String x = Regex.Replace(line, String.Format(CHECK_STR, chk, chk), chk + SUFFIX_STR);
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
