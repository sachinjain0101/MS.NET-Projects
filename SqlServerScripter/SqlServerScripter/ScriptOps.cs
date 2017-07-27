using log4net;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SqlServerScripter {
    class ScriptOps {
        private static ILog LOGGER = LogManager.GetLogger(typeof(ScriptOps));

        public static LinkedList<String> GenerateScriptUseStmt(string database, LinkedList<String> lines) {
            LOGGER.Info("Generating Use Statement");
            string use = "USE [{0}] ;";
            lines.AddLast(String.Format(use,database));
            lines.AddLast("");
            return lines;
        }

        public static LinkedList<String> GenerateScriptGoStmt(LinkedList<String> lines) {
            LOGGER.Info("Generating Go Statement");
            lines.AddLast("GO");
            lines.AddLast("");
            return lines;
        }

        public static LinkedList<String> GenerateScriptInsert(String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Insert INTO Script");
            string insert = "INSERT INTO {0} SELECT * FROM {1} ;";
            lines.AddLast(String.Format(insert, table + Kicker.SUFFIX_STR, table));
            return lines;
        }

        public static LinkedList<String> GenerateScriptConstraints(String server, String database, string schema, String table, LinkedList<String> lines) {
            LOGGER.Info("Generating Constraint Scripts");
            ScriptingOptions scriptOptions = new ScriptingOptions();
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            foreach (Check chk in tbl.Checks) {
                ScriptingOptions options = new ScriptingOptions();
                options.ScriptSchema = true;
                foreach (string line in chk.Script(options))
                    lines.AddLast(line);
            }

            foreach (Column col in tbl.Columns) {
                if (col.DefaultConstraint != null)
                    foreach (string line in col.DefaultConstraint.Script())
                        lines.AddLast(line);
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
                    lines.AddLast(line);
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
                    options.IncludeDatabaseContext = true;
                    options.ScriptSchema = true;
                    options.EnforceScriptingOptions = true;
                    options.NoCollation = true;
                    options.AnsiPadding = true;
                    options.Default = true;
                    options.NoCommandTerminator = false;
                    options.SchemaQualify = true;
                    options.ExtendedProperties = true;
                    //options.ScriptDrops = true;
                    //options.ToFileOnly = true;
                    //options.AllowSystemObjects = false;
                    //options.Permissions = true;
                    //options.AnsiFile = true;
                    //options.SchemaQualifyForeignKeysReferences = true;
                    //options.DriIndexes = true;
                    //options.DriClustered = true;
                    //options.DriNonClustered = true;
                    //options.NonClusteredIndexes = true;
                    //options.ClusteredIndexes = true;
                    //options.FullTextIndexes = true;
                    //options.SchemaQualify = true;
                    //options.ToFileOnly = true;
                    //options.NoExecuteAs = true;
                    //options.AppendToFile = false;
                    //options.ToFileOnly = false;
                    //options.Triggers = true;
                    //options.FullTextStopLists = true;
                    //options.ScriptBatchTerminator = true;
                    //options.FullTextCatalogs = true;
                    //options.XmlIndexes = true;
                    //options.ClusteredIndexes = true;
                    //options.DriAll = true;
                    //options.DriAllConstraints = true;
                    //options.DriAllKeys = true;
                    //options.Indexes = true;
                    //options.IncludeHeaders = true;
                    //options.WithDependencies = true;

                    StringCollection coll = tbl.Script();
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
