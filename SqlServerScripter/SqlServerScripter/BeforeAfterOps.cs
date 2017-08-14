using log4net;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Text;
using System.Text.RegularExpressions;

namespace SqlServerScripter {
    class BeforeAfterOps {
        private static ILog LOGGER = LogManager.GetLogger(typeof(BeforeAfterOps));


        private static String CHECK_STR = @"\b\[{0}\]\b|\b{1}\b";
        const string INSERT_PAT = @"insert[\s]+into\b";


        public static LinkedList<String> ReplaceObjectNames(OrderedDictionary chkDict, LinkedList<String> lines) {
            LOGGER.Info("Replacing object names with the suffix " + Global.SUFFIX_STR_NEW);
            try {
                LinkedList<String> outLines = new LinkedList<String>(lines);

                foreach (DictionaryEntry de in chkDict) {
                    if (!String.IsNullOrEmpty(de.Key.ToString())) {
                        foreach (String line in outLines) {
                            if (!Regex.IsMatch(line, INSERT_PAT, RegexOptions.IgnoreCase)) {
                                String x = Regex.Replace(line, String.Format(CHECK_STR, de.Key.ToString(), de.Key.ToString()), de.Key.ToString() + Global.SUFFIX_STR_NEW);
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

        public static void WriteFile(String outFile, LinkedList<String> output) {
            LOGGER.Info("Writing output script file");
            System.IO.File.WriteAllLines(outFile, output);
        }

        public static OrderedDictionary AddToDict(OrderedDictionary chkDict, string key, ObjType val) {
            if (!chkDict.Contains(key))
                chkDict.Add(key, val);
            return chkDict;
        }

        public static OrderedDictionary GetTableObjects(String server, String database, string schema, String table, String connStr) {
            LOGGER.Info("Getting all objects related to the desired table");
            try {
                OrderedDictionary chkDict = new OrderedDictionary();


                Server srv = new Server(server);
                Database db = srv.Databases[database];
                db.DefaultSchema = schema;
                StringBuilder sb = new StringBuilder();
                Table tbl = db.Tables[table];

                foreach (Index idx in tbl.Indexes) {
                    if (idx.IsClustered)
                        chkDict = AddToDict(chkDict, idx.Name, ObjType.INDEX_CLUST);
                    else
                        chkDict = AddToDict(chkDict, idx.Name, ObjType.INDEX_NON_CLUST);
                }

                foreach (Check chk in tbl.Checks)
                    chkDict = AddToDict(chkDict, chk.Name, ObjType.CKDF);

                foreach (Column col in tbl.Columns)
                    if (col.DefaultConstraint != null)
                        chkDict = AddToDict(chkDict, col.DefaultConstraint.Name, ObjType.CKDF);

                foreach (Trigger trg in tbl.Triggers)
                    chkDict = AddToDict(chkDict, trg.Name, ObjType.TRG);

                foreach (Statistic stat in tbl.Statistics)
                    chkDict = AddToDict(chkDict, stat.Name, ObjType.STAT);

                chkDict = AddToDict(chkDict, table, ObjType.TABLE);


                //String sql = @" SELECT name, '" + ObjType.INDEX.ToString() + @"' AS ObjectType FROM sys.indexes 
                //                WHERE object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) ) 
                //                      AND is_unique = 0 AND type in (1,2)
                //                UNION ALL  
                //                SELECT name, '" + ObjType.PKUQ.ToString() + @"' AS ObjectType  FROM sys.all_objects 
                //                WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                //                      AND type IN ('PK','UQ')
                //                UNION ALL
                //                SELECT name, '" + ObjType.TRG.ToString() + @"' AS ObjectType FROM sys.all_objects
                //                WHERE parent_object_id IN(SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                //                      AND type IN('TR')
                //                UNION ALL  
                //                SELECT name, '" + ObjType.CKDF.ToString() + @"' AS ObjectType FROM sys.all_objects 
                //                WHERE parent_object_id IN (SELECT object_id FROM sys.all_objects WHERE name IN ( '{0}' ) )  
                //                      AND type IN ('C','D')
                //                UNION ALL  
                //                SELECT name, '" + ObjType.TABLE.ToString() + @"' AS ObjectType FROM sys.all_objects 
                //                WHERE name IN( '{0}' )
                //                ";
                //sql = String.Format(sql, tableName);

                //DataTable dt = new DataTable();
                //using (SqlConnection cn = new SqlConnection(connStr))
                //using (SqlCommand cmd = new SqlCommand(sql, cn))
                //using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                //    da.Fill(dt);

                //foreach (DataRow r in dt.Rows) {
                //    if (!String.IsNullOrEmpty(r["name"].ToString())) {
                //        chkDict.Add(r["name"].ToString(), r["ObjectType"].ToString());
                //    }
                //}

                return chkDict;

            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }

        public static LinkedList<String> ReplaceDataTypes(OrderedDictionary chkDict, List<CustomTable> data, LinkedList<String> lines) {
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
            lines.AddLast(Global.END_STR);
            return lines;
        }

    }
}
