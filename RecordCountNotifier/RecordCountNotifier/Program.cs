using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RecordCountNotifier {
    class Program {
        static void Main(string[] args) {




        }


    }

    class DBOps {
        private string connStr;
        public string ConnStr { get => connStr; set => connStr = value; }

        public int GetRecordCount(string tableName) {
            int count = 0;

            string sql = @"
                            
                            ";

            DataTable dt = new DataTable();
            using (SqlConnection cn = new SqlConnection(connStr))
            using (SqlCommand cmd = new SqlCommand(sql, cn))
            using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                da.Fill(dt);

            //foreach (DataRow r in dt.Rows) {
            //    if (!String.IsNullOrEmpty(r["name"].ToString())) {
            //        chkDict.Add(r["name"].ToString(), r["ObjectType"].ToString());
            //    }
            //}

            return count;
        }

    }
}
