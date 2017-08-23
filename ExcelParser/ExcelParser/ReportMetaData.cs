using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExcelParser {
    public class ReportMetaData {
        string programName = "";
        string reportCode = "";
        string sortOrder = "";
        string dbName = "";
        string spName = "";
        string xlsFileName = "";
        string columnAlias = "";
        string columnCalc = "";
        const string COMMA = ",";

        public string ProgramName { get => programName; set => programName = value; }
        public string ReportCode { get => reportCode; set => reportCode = value; }
        public string SortOrder { get => sortOrder; set => sortOrder = value; }
        public string DbName { get => dbName; set => dbName = value; }
        public string SpName { get => spName; set => spName = value; }
        public string XlsFileName { get => xlsFileName; set => xlsFileName = value; }
        public string ColumnAlias { get => columnAlias; set => columnAlias = value; }
        public string ColumnCalc { get => columnCalc; set => columnCalc = value; }

        public override string ToString() {
            string outstring = this.ReportCode + COMMA + this.ProgramName + COMMA + this.SortOrder + COMMA + this.XlsFileName; //this.DbName + COMMA + this.SpName + COMMA 
            return outstring;
        }
    }
}
