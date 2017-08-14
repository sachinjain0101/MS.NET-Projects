using System;

namespace SqlServerScripter {
    class Global {
        public static string STAR_STR = "PRINT '****************************************************************************************';" + Environment.NewLine;
        public const string SUFFIX_STR_NEW = "_NEW";
        public const string SUFFIX_STR_OLD = "_OLD";
        public const string TIME_FORMAT = "yyyyMMddHHmmss";
        public static string END_STR = "PRINT '--------------------------------------';" + Environment.NewLine + "GO";

    }
}
