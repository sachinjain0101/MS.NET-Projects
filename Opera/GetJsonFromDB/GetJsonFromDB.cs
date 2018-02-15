using System;
using System.Data.SqlClient;
using System.IO;

namespace Opera.Test.GetJsonFromDB {
    class GetJsonFromDB {
        static void Main(string[] args) {

            string connStr = "Data Source=qa2;Initial Catalog=TimeHistory;Integrated Security=true;";
            string sql = "SELECT TOP 1 Request FROM TimeHistory..tblWebServicesAudit_InBound WHERE 1=1 AND Client = 'nxeo' AND Request like '%2862527%' ORDER BY RecordID DESC";

            string opFile = "Sachin.json";

            using (SqlConnection conn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, conn)) {
                conn.Open();
                SqlDataReader dr = cmd.ExecuteReader();
                while (dr.Read()) {
                    string req = dr["Request"].ToString();
                    File.WriteAllText(opFile, req);
                }
            }

            //Console.ReadLine();
        }
    }
}
