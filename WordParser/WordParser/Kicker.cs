using CsvHelper;
using log4net;
using log4net.Config;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WordParser {
    class Kicker {
        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));

        static void Main(string[] args) {
            XmlConfigurator.Configure();

            LOGGER.Info("===> START");
            String dbs = ConfigurationManager.AppSettings["DB_NAME"].ToString();
            string rptDb = ConfigurationManager.AppSettings["RPT_DB_NAME"].ToString();
            String server = ConfigurationManager.AppSettings["SRV_NAME"].ToString();
            String connStr = String.Format(ConfigurationManager.ConnectionStrings["CONN_STR"].ToString(), server, rptDb);

            LOGGER.Info("Reporting Database: " + rptDb);
            LOGGER.Info("Connection String: " + connStr);
            LOGGER.Info("SP Scripts to be pulled from : " + dbs);

            DataTable dt = GetProcList(connStr);
            dt.Columns.Add("TablesUsed", typeof(String));

            foreach (DataRow r in dt.Rows) {
                string spName = r["StoredProcName"].ToString();
                if (spName != null && spName.Length != 0) {
                    string script = GetStoreProcScript(server, dbs, spName);
                    string filtered = GetRelevantWords(script);
                    r["TablesUsed"] = filtered;
                }
            }

            string format = "yyyyMMddHHmmss";
            String outFile = server + "_report_matrix_" + DateTime.Now.ToString(format) + ".csv";

            TextWriter tw = File.CreateText(outFile);
            CsvWriter csv = new CsvWriter(tw);

            foreach (DataColumn column in dt.Columns) {
                csv.WriteField(column.ColumnName);
            }
            csv.NextRecord();

            foreach (DataRow row in dt.Rows) {
                for (var i = 0; i < dt.Columns.Count; i++) {
                    csv.WriteField(row[i]);
                }
                csv.NextRecord();
            }

            Console.ReadLine();
        }

        static string GetRelevantWords(String str) {
            SortedSet<string> filtered = new SortedSet<string>();
            foreach (string word in str.Split(' ')) {
                if ((word.ToLower().StartsWith("tbl") 
                    || word.ToLower().StartsWith("timecurrent..tbl") 
                    || word.ToLower().StartsWith("timecurrent.dbo.tbl")
                    || word.ToLower().StartsWith("timehistory..tbl")
                    || word.ToLower().StartsWith("timehistory.dbo.tbl")
                    )
                    && !word.Contains(')')
                    && !word.Contains(',')
                    && word.Count(x => x == '.') < 3
                    )
                    filtered.Add(word);
            }
            string outStr = "";
            foreach (string word in filtered)
                outStr += word + "|";
            return outStr;
        }

        static String GetStoreProcScript(String server, String dbs, String spName) {
            Server srv = new Server(server);
            String script = "";
            foreach (string db in dbs.Split(',')) {
                if (spName.Contains(db))
                    foreach (StoredProcedure sp in srv.Databases[db].StoredProcedures) {
                        if (spName.ToUpper().Contains(sp.Name.ToUpper())) {
                            script = "";
                            StringCollection lines = sp.Script();

                            foreach (String line in lines) {
                                script = script + " " + line.Replace("\r\n", " ");
                            }
                        }
                    }
            }

            LOGGER.Info("Returning SP Script for :" + spName);
            return script;
        }

        static string GetStoreProc(String path, String connStr) {
            return null;
        }

        static DataTable GetProcList(String connStr) {
            LOGGER.Info("Getting SP list");
            try {
                String qry = "";
                qry += " SELECT A.ProgramName , ReportDesc , ExtendedDesc , ReportCode , REPLACE(StoredProcName,'..','.dbo.') as StoredProcName, B.Cnt ";
                qry += " FROM Scheduler..tblReports2 A ";
                qry += " JOIN (SELECT ProgramName , COUNT(1) AS Cnt FROM Scheduler..tblReports2 GROUP BY ProgramName) B ";
                qry += " ON A.ProgramName = B.ProgramName ";
                qry += " ORDER BY B.Cnt DESC, A.ProgramName ";

                DataTable dt = new DataTable();
                using (SqlConnection cn = new SqlConnection(connStr))
                using (SqlCommand cmd = new SqlCommand(qry, cn))
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    da.Fill(dt);

                return dt;

            } catch (Exception e) {
                LOGGER.Error(e.StackTrace);
            }
            return null;
        }
    }
}
