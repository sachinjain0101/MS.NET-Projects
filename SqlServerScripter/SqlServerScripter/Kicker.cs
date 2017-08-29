using log4net;
using log4net.Config;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Configuration;
using System.IO;

namespace SqlServerScripter {
    class Kicker {

        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));
        private static String SMALL_FL_TMPL = "{0}_small_tables_{1}.sql";
        private static String BIG_FL_TMPL = "{0}_{1}_{2}_{3}_{4}.sql";

        static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info("===> START");

            String server = ConfigurationManager.AppSettings["SRV_NAME"].ToString();
            String tblLstXls = ConfigurationManager.AppSettings["TBL_LIST"].ToString();
            Dictionary<string, List<CustomTable>> data = ExcelOps.getExcelSheetData(tblLstXls);

            LOGGER.Info("Server: " + server);
            LOGGER.Info("Table List: " + tblLstXls);

            string outFileSmall = String.Format(SMALL_FL_TMPL, server, DateTime.Now.ToString(Global.TIME_FORMAT));
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
                        if (outLines != null && outLines.Count > 0) {
                            String outFileBig = String.Format(BIG_FL_TMPL, server, database, schema, table, DateTime.Now.ToString(Global.TIME_FORMAT));
                            LOGGER.Info("Writing file: " + outFileBig);
                            File.WriteAllLines(outFileBig, outLines);
                            MoveToOutputDir(server, outFileBig);
                        }
                        break;
                    case TblSize.SMALL:
                        outLines = SmallOp(connStr, server, database, schema, table, kv.Value);
                        if (outLines != null && outLines.Count > 0) {
                            LOGGER.Info("Writing file: " + outFileSmall);
                            File.AppendAllLines(outFileSmall, outLines);
                        }
                        break;
                    case TblSize.ERR:
                        break;
                }

                if (!smallOp)
                    MoveToOutputDir(server, outFileSmall);

                LOGGER.Info("======");
            }

            MoveToOutputDir(server, outFileSmall);


            LOGGER.Info("===> DONE");
            Console.ReadLine();
        }

        public static void MoveToOutputDir(string server, string file) {

            if (!Directory.Exists(server))
                Directory.CreateDirectory(server);

            string destFile = Path.Combine(server, file);
            if (File.Exists(file))
                File.Move(file, destFile);

        }

        public static LinkedList<String> SmallOp(string connStr, string server, string database, string schema, string table, List<CustomTable> data) {
            try {
                LinkedList<String> lines = new LinkedList<String>();
                HashSet<string> relevantObjs = ScriptOps.GetRelevantObjects(server, database, schema, table, data);

                lines.AddLast(Global.STAR_STR);
                lines = ScriptOps.GenerateScriptUseStmt(database, lines);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_NON_CLUST, OpType.DROP, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_CLUST, OpType.DROP, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.CKDF, OpType.DROP, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.STAT, OpType.DROP, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScriptAlterTable(server, database, schema, table, lines, data);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.CKDF, OpType.CREATE, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_CLUST, OpType.CREATE, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_NON_CLUST, OpType.CREATE, TblSize.SMALL, relevantObjs);

                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.STAT, OpType.CREATE, TblSize.SMALL, relevantObjs);

                lines.AddLast(Global.STAR_STR);

                return lines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        public static LinkedList<String> BigOp(string connStr, string server, string database, string schema, string table, List<CustomTable> data) {
            try {
                OrderedDictionary chkDict = BeforeAfterOps.GetTableObjects(server,database,schema,table, connStr);
                LinkedList<String> lines = new LinkedList<String>();

                lines = ScriptOps.GenerateScriptUseStmt(database, lines);

                //CREATE
                lines = ScriptOps.GenerateScriptTable(server, database, schema, table, lines);

                //CONSTRAINTS
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.CKDF, OpType.CREATE, TblSize.BIG, null);

                //INSERT
                lines = ScriptOps.GenerateScriptInsert(server, database, schema, table, lines);

                //INDEX CLUSTERED
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_CLUST, OpType.CREATE, TblSize.BIG, null);

                //INDEX NON CLUSTERED
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.INDEX_NON_CLUST, OpType.CREATE, TblSize.BIG, null);

                lines = BeforeAfterOps.ReplaceObjectNames(chkDict, lines);
                lines = BeforeAfterOps.ReplaceDataTypes(chkDict, data, lines);

                lines = ScriptOps.SwapObjects(schema, table, chkDict, lines);

                //TRIGGERS
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.TRG, OpType.DROP, TblSize.BIG, null);
                lines = ScriptOps.GenerateScript(server, database, schema, table, lines, ObjType.TRG, OpType.CREATE, TblSize.BIG, null);

                return lines;
            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }






    }
}