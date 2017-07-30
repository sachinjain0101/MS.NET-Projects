using log4net;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SqlServerScripter {
    class ScriptOps {
        private static ILog LOGGER = LogManager.GetLogger(typeof(ScriptOps));
        const string DOT = ".";
        const string SEMI_COLON = " ; ";
        const string COMMA = " , ";

        public static LinkedList<String> SwapObjects(string schemaName, string tableName, OrderedDictionary chkDict, LinkedList<String> lines) {
            LOGGER.Info("Generating Script to swap Original to Old and then New to Original");
            string sql = "EXEC dbo.sp_rename '{0}{1}' , '{2}' {3}";

            string line = "";
            foreach (DictionaryEntry de in chkDict) {
                line = "";
                string obj = de.Key.ToString();
                string fromObj = obj;
                string toObj = obj + Kicker.SUFFIX_STR_OLD;

                string ownerObj = schemaName + DOT + tableName + DOT;

                if (de.Value.ToString() == "INDEX")
                    line = String.Format(sql, ownerObj, fromObj, toObj, ", N'INDEX'");
                else if (de.Value.ToString() == "PKUQ")
                    line = String.Format(sql, ownerObj, fromObj, toObj, "");
                else if (de.Value.ToString() == "TABLE")
                    line = String.Format(sql, "", fromObj, toObj, "");
                else
                    line = String.Format(sql, "", fromObj, toObj, "");
                lines.AddLast(line + SEMI_COLON);
            }

            foreach (DictionaryEntry de in chkDict) {
                line = "";
                string obj = de.Key.ToString();
                string fromObj = obj + Kicker.SUFFIX_STR_NEW;
                string toObj = obj;

                string ownerObj = schemaName + DOT + tableName + Kicker.SUFFIX_STR_NEW + DOT;

                if (de.Value.ToString() == "INDEX")
                    line = String.Format(sql, ownerObj, fromObj, toObj, ", N'INDEX'");
                else if (de.Value.ToString() == "PKUQ")
                    line = String.Format(sql, ownerObj, fromObj, toObj, "");
                else if (de.Value.ToString() == "TABLE")
                    line = String.Format(sql, "", fromObj, toObj, "");
                else
                    line = String.Format(sql, "", fromObj, toObj, "");
                lines.AddLast(line + SEMI_COLON);
            }

            return lines;
        }

        public static LinkedList<String> GenerateScriptUseStmt(string database, LinkedList<String> lines) {
            LOGGER.Info("Generating Use Statement");
            string use = "USE [{0}] ;";
            lines.AddLast(String.Format(use, database));
            lines.AddLast("");
            return lines;
        }

        public static LinkedList<String> GenerateScriptGoStmt(LinkedList<String> lines) {
            LOGGER.Info("Generating Go Statement");
            lines.AddLast("GO");
            lines.AddLast("");
            return lines;
        }

        public static LinkedList<String> GenerateScriptInsert(String server, String database, string schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Insert INTO Script");

            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            int cnt = 0;
            string colString = "";
            foreach (Column col in tbl.Columns) {
                if (cnt == 0)
                    colString = col.Name;
                else
                    colString += COMMA + col.Name;
                cnt++;
            }

            string insertStmt = "INSERT INTO {0} ({1}) SELECT {1} FROM {2} ;";
            string printStartStmt = "PRINT N'START - Inserting into {0}.{1}.{2}'";
            string printFinishStmt = "PRINT N'FINISH Inserting into {0}.{1}.{2}'";
            string newTable = table + Kicker.SUFFIX_STR_NEW;
            string oldTable = table;
            lines.AddLast("SET QUOTED_IDENTIFIER ON;");
            lines.AddLast("SET IDENTITY_INSERT " + newTable + " ON;");
            lines.AddLast("SET NOCOUNT ON;");
            lines.AddLast(String.Format(printStartStmt, database,schema, table) + SEMI_COLON);
            lines.AddLast(String.Format(insertStmt, newTable, colString, oldTable));
            lines.AddLast(String.Format(printFinishStmt, database, schema, table) + SEMI_COLON);
            return lines;
        }

        public static LinkedList<string> GenerateScriptAlterTable(string server, string database, string schema, string table, LinkedList<string> lines, List<CustomTable> data) {

            LOGGER.Info("Generating Alter Column Scripts");
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            string alterStmt = "ALTER TABLE {0}.{1} ALTER COLUMN {2} {3} {4}";
            string printStmt = "PRINT N'Altering {0}.{1}.{2}.{3}'";
            foreach (CustomTable ct in data) {
                foreach(Column col in tbl.Columns) {
                    if (col.Name.ToLower() == ct.ColumnName.ToLower()) {
                        string x = "";
                        if (!col.Nullable)
                            x = "NOT NULL";
                        else
                            x = "NULL";
                        lines.AddLast(String.Format(printStmt, database, schema, table, ct.ColumnName) + SEMI_COLON);
                        lines.AddLast(String.Format(alterStmt, schema, table, ct.ColumnName, ct.NewDataType, x)+SEMI_COLON);
                    }
                }
            }

            return lines;
        }

        public static LinkedList<String> GenerateScriptConstraints(String server, String database, string schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Constraint Scripts");
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            foreach (Check chk in tbl.Checks) {
                ScriptingOptions options = new ScriptingOptions();
                options.ScriptSchema = true;
                foreach (string line in chk.Script(options))
                    lines.AddLast(line + SEMI_COLON);
            }

            foreach (Column col in tbl.Columns) {
                if (col.DefaultConstraint != null)
                    foreach (string line in col.DefaultConstraint.Script())
                        lines.AddLast(line + SEMI_COLON);
            }

            return lines;
        }

        public static LinkedList<String> GenerateScriptIndexes(String server, String database, String schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Index Scripts");
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            foreach (Index idx in tbl.Indexes) {
                ScriptingOptions options = new ScriptingOptions();
                options.ScriptSchema = true;
                options.NoCommandTerminator = false;
                foreach (string line in idx.Script(options))
                    lines.AddLast(line + SEMI_COLON);
            }

            return lines;
        }

        public static LinkedList<String> GenerateScriptTable(String server, String database, String schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Table Script");
            try {

                Server srv = new Server(server);
                Database db = srv.Databases[database];
                db.DefaultSchema = schema;
                StringBuilder sb = new StringBuilder();
                Table tbl = db.Tables[table];


                LinkedList<String> ll = new LinkedList<String>();
                foreach (Index idx in tbl.Indexes) {
                    ScriptingOptions options = new ScriptingOptions();
                    options.ScriptDrops = true;
                    options.NoCommandTerminator = false;
                    foreach (string line in idx.Script(options))
                        ll.AddLast(line);
                }


                foreach (Check chk in tbl.Checks) {
                    ScriptingOptions options = new ScriptingOptions();
                    options.ScriptDrops = true;
                    foreach (string line in chk.Script(options))
                        ll.AddLast(line);
                }


                if (!tbl.IsSystemObject) {
                    ScriptingOptions options = new ScriptingOptions();
                    options.ScriptSchema = true;
                    options.AnsiPadding = true;
                    options.Default = true;
                    options.NoCommandTerminator = false;
                    options.ScriptBatchTerminator = true;
                    //options.SchemaQualify = true;
                    //options.ExtendedProperties = true;
                    //options.ScriptDrops = true;
                    //options.ToFileOnly = true;


                    StringCollection coll = tbl.Script(options);
                    foreach (string str in coll) {
                        lines.AddLast(str + SEMI_COLON);
                    }
                }
                return lines;
            } catch (Exception err) {
                LOGGER.Error(err.Message);
            }
            return null;
        }

        public static LinkedList<String> GenerateScriptDropConstraints(String server, String database, string schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Drop Constraints Script");
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            foreach (Check chk in tbl.Checks) {
                ScriptingOptions options = new ScriptingOptions();
                options.ScriptDrops = true;
                options.NoCommandTerminator = false;
                foreach (string line in chk.Script(options))
                    lines.AddLast(line + SEMI_COLON);
            }

            foreach (Column col in tbl.Columns) {
                if (col.DefaultConstraint != null) {
                    ScriptingOptions options = new ScriptingOptions();
                    options.ScriptDrops = true;
                    options.NoCommandTerminator = false;
                    foreach (string line in col.DefaultConstraint.Script(options))
                        lines.AddLast(line + SEMI_COLON);
                }
            }

            return lines;
        }

        public static LinkedList<String> GenerateScriptDropIndexes(String server, String database, string schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Drop Indexes Script");
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            foreach (Index idx in tbl.Indexes) {
                ScriptingOptions options = new ScriptingOptions();
                options.ScriptDrops = true;
                options.NoCommandTerminator = false;
                foreach (string line in idx.Script(options))
                    lines.AddLast(line + SEMI_COLON);
            }

            return lines;
        }

        public static LinkedList<String> GenerateScriptDropStatistics(String server, String database, string schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Drop Statistics Script");
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            foreach (Statistic stats in tbl.Statistics) {
                ScriptingOptions options = new ScriptingOptions();
                options.ScriptDrops = true;
                options.NoCommandTerminator = false;
                foreach (string line in stats.Script(options))
                    lines.AddLast(line + SEMI_COLON);
            }

            return lines;
        }
    }
}
