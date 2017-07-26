using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExcelParser {
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
}
