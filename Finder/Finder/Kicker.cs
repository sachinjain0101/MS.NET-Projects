using System;

namespace Finder {
    public class Kicker {

        static void Main(string[] args) {

            Console.WriteLine(Constants.SEP + "START");

            SvcFile.CreateDirs(Constants.EXP_PATH_DB);
            SvcDB svcDB = new SvcDB();
            svcDB.serverName = "dev1sql1";
            svcDB.databaseName = "TimeHistory";
            Console.WriteLine(Constants.SEP + "Exporting Procs");
            svcDB.OutputProcFiles();

            Console.WriteLine(Constants.SEP + "END (press any key to exit)");
            Console.ReadLine();
        }
    }

}
