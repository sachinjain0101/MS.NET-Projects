using Microsoft.SqlServer.Management.Common;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.IO;
using log4net;

namespace RecordIDExpansion {
    public class SvcDB {
        private static ILog LOGGER = LogManager.GetLogger(typeof(SvcDB));

        public string serverName { get; set; }
        public string databaseName { get; set; }

        public void ExecuteScripts(string f) {
            string connStr = string.Format(Constants.CONNECT_STR, serverName, databaseName);
            var serverConnection = new ServerConnection(new SqlConnection(connStr));
            var server = new Server(serverConnection);
            FileInfo file = new FileInfo(f);
            string script = file.OpenText().ReadToEnd();
            server.ConnectionContext.ExecuteNonQuery(script, ExecutionTypes.Default);
        }

        public void OutputProcFiles(List<string> lstVals) {
            string connStr = string.Format(Constants.CONNECT_STR, serverName, databaseName);
            var serverConnection = new ServerConnection(new SqlConnection(connStr));
            var server = new Server(serverConnection);
            List<string> lstDBNames = new List<string>();
            LOGGER.Info(Constants.SEP + "Total Procs: " + lstVals.Count);
            int count = 0;
            foreach (StoredProcedure sp in server.Databases["TimeHistory"].StoredProcedures) {
                string nm = "";
                if (sp.Schema != "dbo")
                    nm = sp.Schema + "." + sp.Name;
                else
                    nm = sp.Name;

                if (lstVals.Contains(nm)) {
                    count++;
                    try {
                        string txtBody = (sp.TextBody != null && sp.TextBody.Length > 0) ? sp.TextBody : "";
                        File.WriteAllText(Constants.EXP_PATH_DB + nm + Constants.EXT, sp.TextHeader + Environment.NewLine + txtBody);
                    } catch (Exception e) {
                        LOGGER.Info(e.Message);
                    }
                }
                lstDBNames.Add(sp.Name);
            }
            LOGGER.Info(Constants.SEP + "Exported Procs: " + count);
            LOGGER.Info(Constants.SEP + "Missing Procs: ");
            var lstMissing = lstVals.Except(lstDBNames);
            foreach (string missed in lstMissing)
                LOGGER.Info(Constants.WHITE_SEP + missed);
        }
    }

}
