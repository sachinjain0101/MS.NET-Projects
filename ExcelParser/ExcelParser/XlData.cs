using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExcelParser {
    public class XlData {
        string _dbName;
        string _spName;
        List<string> _lines;

        public string DbName { get => _dbName; set => _dbName = value; }
        public string SpName { get => _spName; set => _spName = value; }
        public List<string> Lines { get => _lines; set => _lines = value; }
    }
}
