using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PeoplenetBillingConsole {
    class Constants {
        public const string DIR_TXN = "txn_history";
        public const string SEP_FILE = "\\";
        public const string SEP = " ";
        private const string INDICATOR = "==>";
        private static string DISP_LINE = INDICATOR + SEP + "{0}";
        public static string CONNECT_STR = "Server={0};Database="+DB_NAME+";Trusted_Connection=True;Integrated Security=True;MultipleActiveResultSets=True";
        public static string DB_NAME = "CigOrders";

        public static string DisplayLine(string txt) {
            return String.Format(DISP_LINE, txt);
        }
    }
}
