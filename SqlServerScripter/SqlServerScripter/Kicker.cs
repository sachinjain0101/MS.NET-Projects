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

        private static String CHECK_STR = "\\b\\[{0}\\]\\b|\\b{1}\\b";

        static void Main(string[] args) {
            XmlConfigurator.Configure();

            String database = ConfigurationManager.AppSettings["DB_NAME"].ToString();
            String table = ConfigurationManager.AppSettings["TBL_NAME"].ToString();
            String server = ConfigurationManager.AppSettings["SRV_NAME"].ToString();
            String connStr = String.Format(ConfigurationManager.ConnectionStrings["CONN_STR"].ToString(), server, database);
            LOGGER.Info("===> START");
            LOGGER.Info(database);
            LOGGER.Info(table);
            LOGGER.Info(server);

            try {
                LinkedList<String> chkLst = GetChkList(table, connStr);
                LinkedList<String> lines = SpecificTableScript(server, database, table);
                LinkedList<String> outLines = ReplaceObjectNames(chkLst, lines);

                string format = "yyyyMMddHHmmss";
                String outFile = server + "_" + database + "_" + table + "_" + DateTime.Now.ToString(format) + ".sql";

                WriteFile(outFile, outLines);

            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }

            LOGGER.Info("===> DONE");
            Console.ReadLine();
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
            LOGGER.Info("Replacing object names with the suffix 'New'");
            try {
                LinkedList<String> outLines = new LinkedList<String>(lines);

                foreach (String chk in chkLst) {
                    foreach (String line in outLines) {
                        String x = Regex.Replace(line, String.Format(CHECK_STR, chk, chk), chk + "New");
                        if (x != line)
                            outLines.Find(line).Value = x;
                    }
                }
                return outLines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }


        static LinkedList<String> SpecificTableScript(String server, String database, String table) {
            LOGGER.Info("Generating actual table script");
            try {
                LinkedList<String> lines = new LinkedList<String>();

                ScriptingOptions scriptOptions = new ScriptingOptions();
                Server srv = new Server(server);
                Database db = srv.Databases[database];
                db.DefaultSchema = "dbo";
                StringBuilder sb = new StringBuilder();
                Table tbl = db.Tables[table];
                if (!tbl.IsSystemObject) {
                    ScriptingOptions options = new ScriptingOptions();
                    options.IncludeIfNotExists = true;
                    options.NoCommandTerminator = false;
                    options.ToFileOnly = true;
                    options.AllowSystemObjects = false;
                    options.Permissions = true;
                    options.DriAllConstraints = true;
                    options.SchemaQualify = true;
                    options.AnsiFile = true;
                    options.SchemaQualifyForeignKeysReferences = true;
                    options.Indexes = true;
                    options.DriIndexes = true;
                    options.DriClustered = true;
                    options.DriNonClustered = true;
                    options.NonClusteredIndexes = true;
                    options.ClusteredIndexes = true;
                    options.FullTextIndexes = true;
                    options.EnforceScriptingOptions = true;
                    options.IncludeHeaders = true;
                    options.SchemaQualify = true;
                    options.NoCollation = true;
                    options.DriAll = true;
                    options.DriAllKeys = true;
                    options.ToFileOnly = true;
                    options.NoExecuteAs = true;
                    options.AppendToFile = false;
                    options.ToFileOnly = false;
                    options.Triggers = true;
                    options.IncludeDatabaseContext = false;
                    options.AnsiPadding = true;
                    options.FullTextStopLists = true;
                    options.ScriptBatchTerminator = true;
                    options.ExtendedProperties = true;
                    options.FullTextCatalogs = true;
                    options.XmlIndexes = true;
                    options.ClusteredIndexes = true;
                    options.Default = true;
                    options.DriAll = true;
                    options.Indexes = true;
                    options.IncludeHeaders = true;
                    options.ExtendedProperties = true;
                    options.WithDependencies = true;

                    StringCollection coll = tbl.Script(options);
                    foreach (string str in coll) {
                        lines.AddLast(str);
                    }
                }
                return lines;
            } catch (Exception err) {
                LOGGER.Error(err.Message);
            }
            return null;
        }
    }
}
