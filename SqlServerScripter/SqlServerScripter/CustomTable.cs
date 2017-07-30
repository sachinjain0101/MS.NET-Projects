using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SqlServerScripter {
    public class CustomTable {

        string tableCatalog;
        string tableSchema;
        string tableName;
        string columnName;
        string oldDataType;
        string newDataType;

        public string TableCatalog { get => tableCatalog; set => tableCatalog = value; }
        public string TableSchema { get => tableSchema; set => tableSchema = value; }
        public string TableName { get => tableName; set => tableName = value; }
        public string ColumnName { get => columnName; set => columnName = value; }
        public string OldDataType { get => oldDataType; set => oldDataType = value; }
        public string NewDataType { get => newDataType; set => newDataType = value; }
    }

    public enum TblSize {
        BIG, SMALL, ERR
    }
}
