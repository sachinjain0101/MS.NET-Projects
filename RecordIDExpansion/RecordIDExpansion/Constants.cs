using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RecordIDExpansion
{
    public class Constants {
        public const string SRC_EXCEL = "C:\\Projects\\RecID-Exp\\SP_List_TH_TC.xlsx";
        public const string TFS_TH_TRUNK_DIR = "C:\\TFS\\Peoplenet Projects\\Database\\TimeHistory\\Trunk\\StoredProcedure\\";
        public const string TFS_TC_TRUNK_DIR = "C:\\TFS\\Peoplenet Projects\\Database\\TimeCurrent\\Trunk\\StoredProcedure\\";
        public const string EXP_PATH_DB = "C:\\Projects\\RecID-Exp\\Exported-SQLs\\DB\\";
        public const string EXP_PATH_TFS = "C:\\Projects\\RecID-Exp\\Exported-SQLs\\TFS\\";
        public const string EXP_PATH_DIFF = "C:\\Projects\\RecID-Exp\\Exported-SQLs\\DIFF\\";
        public const string EXP_PATH_SQL = "C:\\Projects\\RecID-Exp\\Exported-SQLs\\SQL\\";
        public const string EXT = ".sql";
        public const string SEP = "===> ";
        public const string LONG_SEP = "==================================================================================================\n"
                    + "==================================================================================================\n";
        public const string WHITE_SEP = "     ";
        public const string CONNECT_STR = "Server={0};Database={1};Trusted_Connection=True;Integrated Security=True;MultipleActiveResultSets=True";
        public const string DIFF_STR = "/C /W /N \"{0}\" \"{1}\"";
        //public const string DIFF_STR = "\"{0}\" \"{1}\" /i /w /b /i /l /e /o:{2}";
    }

    public enum Sheet {
        TIMECURRENT
     , TIMEHISTORY
    }

    public enum StmtType {
        ALTER
     , CREATE
     , GO
    }
}
