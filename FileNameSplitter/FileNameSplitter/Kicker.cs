using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FileNameSplitter {
    class Kicker {

        public class ReportMetaData {
            string _reportName = "";
            string _reportCode = "";
            string _reportOrder = "";
            string _dbName = "";
            string _spName = "";
            string _xlsFileName = "";
            const string COMMA = ",";

            public string ReportName { get => _reportName; set => _reportName = value; }
            public string ReportCode { get => _reportCode; set => _reportCode = value; }
            public string ReportOrder { get => _reportOrder; set => _reportOrder = value; }
            public string DbName { get => _dbName; set => _dbName = value; }
            public string SpName { get => _spName; set => _spName = value; }
            public string XlsFileName { get => _xlsFileName; set => _xlsFileName = value; }


            public override string ToString() {
                string outstring = this.ReportCode + COMMA + this.ReportName + COMMA + this.ReportOrder + COMMA + this.DbName + COMMA + this.SpName + COMMA + this.XlsFileName;
                return outstring;
            }
        }

        static void Main(string[] args) {

            string dir = @"C:\Users\sachin.jain\Google Drive\#PeopleNet-Work\Reporting Project\Report Templates_";
            foreach (string file in System.IO.Directory.GetFiles(dir)) {
                string fileName = System.IO.Path.GetFileNameWithoutExtension(file);
                ReportMetaData rmd = new ReportMetaData();
                rmd.XlsFileName = System.IO.Path.GetFileName(file);

                string[] split1 = fileName.Split('_');
                string[] split2 = { };

                if (split1.Length > 1) {
                    split2 = split1[1].Split(new string[] { "By" }, StringSplitOptions.None);
                    if(split2.Length > 1) {
                        rmd.ReportOrder = split2[1];
                    }
                    rmd.ReportCode = split2[0];
                }
                rmd.ReportName = split1[0];

                Console.WriteLine(rmd.ToString());
            }

            Console.WriteLine("");
        }
    }
}
