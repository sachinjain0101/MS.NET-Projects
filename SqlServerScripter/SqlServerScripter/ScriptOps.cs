using log4net;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace SqlServerScripter {
    class ScriptOps {
        private static ILog LOGGER = LogManager.GetLogger(typeof(ScriptOps));
        const string DOT = ".";
        const string SEMI_COLON = " ; ";
        const string COMMA = " , ";
        const string START = "START";
        const string END = "END";
        private static string SEP_STR = "PRINT '--------------------------------------';" + Environment.NewLine;

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

                line = GetSwapLine(line, de.Value.ToString(), sql, ownerObj, fromObj, toObj);
                if (!String.IsNullOrEmpty(line)) {
                    lines.AddLast("PRINT N'Renaming " + fromObj + " to " + toObj + "';");
                    lines.AddLast(line + SEMI_COLON);
                }
            }

            foreach (DictionaryEntry de in chkDict) {
                line = "";
                string obj = de.Key.ToString();

                string fromObj = obj + Kicker.SUFFIX_STR_NEW;
                string toObj = obj;
                string ownerObj = schemaName + DOT + tableName + Kicker.SUFFIX_STR_NEW + DOT;

                line = GetSwapLine(line, de.Value.ToString(), sql, ownerObj, fromObj, toObj);
                if (!String.IsNullOrEmpty(line)) {
                    lines.AddLast("PRINT N'Renaming " + fromObj + " to " + toObj + "';");
                    lines.AddLast(line + SEMI_COLON);
                }
            }

            return lines;
        }

        private static string GetSwapLine(string line, string chk, string sql, string ownerObj, string fromObj, string toObj) {
            if (chk == ObjType.INDEX_CLUST.ToString() || chk == ObjType.INDEX_NON_CLUST.ToString())
                line = String.Format(sql, ownerObj, fromObj, toObj, ", N'INDEX'");
            else if (chk == ObjType.PKUQ.ToString())
                line = String.Format(sql, ownerObj, fromObj, toObj, "");
            else if (chk == ObjType.TABLE.ToString())
                line = String.Format(sql, "", fromObj, toObj, "");
            else if (chk == ObjType.CKDF.ToString())
                line = String.Format(sql, "", fromObj, toObj, "");

            return line;
        }

        public static LinkedList<String> GenerateScriptUseStmt(string database, LinkedList<String> lines) {
            LOGGER.Info("Generating Use Statement");
            string use = "USE [{0}] ;";
            lines.AddLast(String.Format(use, database));
            lines.AddLast("PRINT N'Using Database : " + database + "';");
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
            string printStartStmt = "PRINT FORMAT(CURRENT_TIMESTAMP, 'MM-dd-yyyy HH:mm:ss') + N' START : Inserting into {0}.{1}.{2}'";
            string printFinishStmt = "PRINT FORMAT(CURRENT_TIMESTAMP, 'MM-dd-yyyy HH:mm:ss') + N' END : Inserting into {0}.{1}.{2}'";
            string newTable = table + Kicker.SUFFIX_STR_NEW;
            string oldTable = table;
            lines.AddLast("SET QUOTED_IDENTIFIER ON;");
            lines.AddLast("SET IDENTITY_INSERT " + newTable + " ON;");
            lines.AddLast("SET NOCOUNT ON;");
            lines.AddLast(String.Format(printStartStmt, database, schema, table) + SEMI_COLON);
            lines.AddLast(String.Format(insertStmt, newTable, colString, oldTable));
            lines.AddLast(String.Format(printFinishStmt, database, schema, table) + SEMI_COLON);
            lines.AddLast(SEP_STR);
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
                foreach (Column col in tbl.Columns) {
                    if (col.Name.ToLower() == ct.ColumnName.ToLower()) {
                        string x = "";
                        if (!col.Nullable)
                            x = "NOT NULL";
                        else
                            x = "NULL";
                        lines.AddLast(String.Format(printStmt, database, schema, table, ct.ColumnName) + SEMI_COLON);
                        lines.AddLast(String.Format(alterStmt, schema, table, ct.ColumnName, ct.NewDataType, x) + SEMI_COLON);
                    }
                }
            }

            return lines;
        }

        public static HashSet<string> GetRelevantObjects(String server, String database, string schema, String table, List<CustomTable> data) {
            LOGGER.Info(String.Format("Getting relevant objects for {0}", database + DOT + schema + DOT + table));
            HashSet<string> objects = new HashSet<string>();

            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];
            ScriptingOptions options = new ScriptingOptions();
            options.ScriptSchema = true;
            options.NoCommandTerminator = false;

            foreach (CustomTable ct in data) {
                string x = "";
                foreach (Index idx in tbl.Indexes) {
                    if (DoQuickCheck(idx.Script(options), ct.ColumnName)) {
                        objects.Add(idx.Name);
                        break;
                    }
                }
                foreach (Check chk in tbl.Checks) {
                    if (DoQuickCheck(chk.Script(options), ct.ColumnName)) {
                        objects.Add(chk.Name);
                        break;
                    }
                }
                foreach (Column col in tbl.Columns) {
                    if (col.DefaultConstraint != null) {
                        if (DoQuickCheck(col.DefaultConstraint.Script(options), ct.ColumnName)) {
                            objects.Add(col.DefaultConstraint.Name);
                            break;
                        }
                    }
                }
            }
            return objects;
        }

        public static bool DoQuickCheck(StringCollection collection, string col) {
            string[] arr = new string[collection.Count];
            if (collection.Count > 0) {
                collection.CopyTo(arr, 0);
                string str = String.Join(" ", arr);
                string pattern = @"\b{0}\b";
                if (Regex.IsMatch(str, String.Format(pattern, col), RegexOptions.IgnoreCase))
                    return true;
            }
            return false;
        }

        public static LinkedList<String> GenerateScript(String server, String database, string schema, String table, LinkedList<String> lines
                                                            , ObjType dot, OpType ot, TblSize ts, HashSet<string> relObjs) {

            LOGGER.Info("Generating " + ot.ToString() + " Script for " + dot.ToString());
            Server srv = new Server(server);
            Database db = srv.Databases[database];
            db.DefaultSchema = schema;
            StringBuilder sb = new StringBuilder();
            Table tbl = db.Tables[table];

            string printStr = "PRINT FORMAT(CURRENT_TIMESTAMP, 'MM-dd-yyyy HH:mm:ss') + N' {0} {1} : {2} : {3}';";
            ScriptingOptions options = null;

            switch (ot) {
                case OpType.CREATE:
                    options = new ScriptingOptions();
                    options.ScriptSchema = true;
                    options.NoCommandTerminator = false;
                    break;
                case OpType.DROP:
                    options = new ScriptingOptions();
                    options.ScriptDrops = true;
                    options.NoCommandTerminator = false;
                    break;
                default:
                    break;
            }

            switch (dot) {
                case ObjType.CKDF:
                    foreach (Check chk in tbl.Checks) {

                        if (ts != TblSize.SMALL) {
                            lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), chk.Name));
                            foreach (string line in chk.Script(options))
                                lines.AddLast(line + SEMI_COLON);
                            lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), chk.Name));
                            lines.AddLast(SEP_STR);
                            lines = ScriptOps.GenerateScriptGoStmt(lines);
                        } else {
                            if (relObjs.Contains(chk.Name)) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), chk.Name));
                                foreach (string line in chk.Script(options))
                                    lines.AddLast(line + SEMI_COLON);
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), chk.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            }
                        }

                    }
                    foreach (Column col in tbl.Columns) {
                        if (col.DefaultConstraint != null) {

                            if (ts != TblSize.SMALL) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), col.DefaultConstraint.Name));
                                foreach (string line in col.DefaultConstraint.Script(options))
                                    lines.AddLast(line + SEMI_COLON);
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), col.DefaultConstraint.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            } else {
                                if (relObjs.Contains(col.DefaultConstraint.Name)) {
                                    lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), col.DefaultConstraint.Name));
                                    foreach (string line in col.DefaultConstraint.Script(options))
                                        lines.AddLast(line + SEMI_COLON);
                                    lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), col.DefaultConstraint.Name));
                                    lines.AddLast(SEP_STR);
                                    lines = ScriptOps.GenerateScriptGoStmt(lines);
                                }
                            }

                        }
                    }
                    break;

                case ObjType.INDEX_CLUST:
                    foreach (Index idx in tbl.Indexes) {
                        if (idx.IsClustered) {

                            if (ts != TblSize.SMALL) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), idx.Name));
                                foreach (string line in idx.Script(options))
                                    lines.AddLast(line + SEMI_COLON);
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), idx.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            } else {
                                if (relObjs.Contains(idx.Name)) {
                                    lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), idx.Name));
                                    foreach (string line in idx.Script(options))
                                        lines.AddLast(line + SEMI_COLON);
                                    lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), idx.Name));
                                    lines.AddLast(SEP_STR);
                                    lines = ScriptOps.GenerateScriptGoStmt(lines);
                                }
                            }

                        }
                    }
                    break;

                case ObjType.INDEX_NON_CLUST:
                    foreach (Index idx in tbl.Indexes) {
                        if (!idx.IsClustered) {

                            if (ts != TblSize.SMALL) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), idx.Name));
                                foreach (string line in idx.Script(options))
                                    lines.AddLast(line + SEMI_COLON);
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), idx.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            } else {
                                if (relObjs.Contains(idx.Name)) {
                                    lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), idx.Name));
                                    foreach (string line in idx.Script(options))
                                        lines.AddLast(line + SEMI_COLON);
                                    lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), idx.Name));
                                    lines.AddLast(SEP_STR);
                                    lines = ScriptOps.GenerateScriptGoStmt(lines);
                                }
                            }

                        }
                    }
                    break;

                case ObjType.TRG:
                    string dropTrg = "DROP TRIGGER [{0}].[{1}]";
                    switch (ot) {
                        case OpType.CREATE:
                            string pattern = @"create[\s]+trigger\b";
                            foreach (Trigger trg in tbl.Triggers) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), trg.Name));
                                foreach (string line in trg.Script(options)) {
                                    if (Regex.IsMatch(line, pattern, RegexOptions.IgnoreCase))
                                        lines = ScriptOps.GenerateScriptGoStmt(lines);
                                    lines.AddLast(line + SEMI_COLON);
                                }
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), trg.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            }
                            break;
                        case OpType.DROP:
                            foreach (Trigger trg in tbl.Triggers) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), trg.Name));
                                lines.AddLast(String.Format(dropTrg, schema, trg.Name) + SEMI_COLON);
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), trg.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            }
                            break;
                    }
                    break;
                case ObjType.STAT:
                    foreach (Statistic stats in tbl.Statistics) {
                        foreach (string line in stats.Script(options)) {
                            if (!String.IsNullOrEmpty(line)) {
                                lines.AddLast(String.Format(printStr, START, ot.ToString(), dot.ToString(), stats.Name));
                                lines.AddLast(line + SEMI_COLON);
                                lines.AddLast(String.Format(printStr, END, ot.ToString(), dot.ToString(), stats.Name));
                                lines.AddLast(SEP_STR);
                                lines = ScriptOps.GenerateScriptGoStmt(lines);
                            }
                        }
                    }
                    break;
                case ObjType.PKUQ:
                    break;
                case ObjType.TABLE:
                    break;
                default:
                    break;
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

    }
}
