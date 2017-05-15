using Microsoft.SqlServer.Management.Common;
using Microsoft.SqlServer.Management.Smo;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.IO;
using System.Text.RegularExpressions;

namespace Finder {
    public class SvcDB {
        public string serverName { get; set; }
        public string databaseName { get; set; }

        public void OutputProcFiles() {
            OutputProcFiles(null);
        }

        public void OutputProcFiles(List<string> lstVals) {
            string connStr = string.Format(Constants.CONNECT_STR, serverName, databaseName);
            var serverConnection = new ServerConnection(new SqlConnection(connStr));
            var server = new Server(serverConnection);
            List<string> lstDBNames = new List<string>();
            int count = 0;
            if (lstVals == null)
                count = 0;
            else
                count = lstVals.Count;
            Console.WriteLine(Constants.SEP + "Total Procs: " + count);

            count = 0;
            foreach (StoredProcedure sp in server.Databases["TimeHistory"].StoredProcedures) {
                count++;
                try {
                    string txtBody = (sp.TextBody != null && sp.TextBody.Length > 0) ? sp.TextBody : "";
                    String pattern = Environment.NewLine;
                    string completeTxt = sp.TextHeader + Environment.NewLine + txtBody;
                    string[] lines = Regex.Split(completeTxt, pattern);
                    Console.WriteLine("Count of split lines: {0}", lines.Length);

                    File.WriteAllText(Constants.EXP_PATH_DB + sp.Name + Constants.EXT, sp.TextHeader + Environment.NewLine + txtBody);
                } catch (Exception e) {
                    Console.WriteLine(e.Message);
                }
                lstDBNames.Add(sp.Name);
            }
            Console.WriteLine(Constants.SEP + "Exported Procs: " + count);
            Console.WriteLine(Constants.SEP + "Missing Procs: ");
            var lstMissing = lstVals.Except(lstDBNames);
            foreach (string missed in lstMissing)
                Console.WriteLine(Constants.WHITE_SEP + missed);
        }
    }

}
