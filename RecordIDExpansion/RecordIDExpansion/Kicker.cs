using log4net;
using log4net.Config;
using System;
using System.Collections.Generic;

namespace RecordIDExpansion {
    public class Kicker {
        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));
        static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info(Constants.SEP + "START");
            
            LOGGER.Info(Constants.SEP + "Reading Excel");
            SvcExcel svcExcel = new SvcExcel();
            List<string> lstVals = svcExcel.ReadSheet(Constants.SRC_EXCEL, Sheet.TIMEHISTORY);

            LOGGER.Info(Constants.SEP + "Processing TFS Files");

            SvcFile.CreateDirs(Constants.EXP_PATH_DB);
            SvcFile.CreateDirs(Constants.EXP_PATH_TFS);
            SvcFile.CreateDirs(Constants.EXP_PATH_SQL);
            SvcFile.CreateDirs(Constants.EXP_PATH_DIFF);
            //SvcFile.CreateFiles(lstVals);
            SvcFile.CopyFiles(Constants.TFS_TH_TRUNK_DIR, lstVals);
            SvcFile.ModifyFiles(Constants.EXP_PATH_TFS, lstVals, StmtType.ALTER);
            SvcFile.ReplaceString(Constants.EXP_PATH_TFS, lstVals);
            SvcFile.RemoveLastLine(Constants.EXP_PATH_TFS, lstVals, StmtType.GO);

            SvcDB svcDB = new SvcDB();
            svcDB.serverName = "dev3sql1";
            svcDB.databaseName = "TimeHistory";
            LOGGER.Info(Constants.SEP + "Exporting Procs");
            svcDB.OutputProcFiles(lstVals);
            SvcFile.ModifyFiles(Constants.EXP_PATH_DB, lstVals, StmtType.CREATE);

            LOGGER.Info(Constants.SEP + "Running Diff for Procs");
            SvcFile.DiffFiles(Constants.EXP_PATH_DB, Constants.EXP_PATH_TFS);
            
            LOGGER.Info(Constants.SEP + "Getting Diff size");
            List<string> lstFiles = SvcFile.GetDiffSize(Constants.EXP_PATH_DIFF);
            LOGGER.Info("Files upto 10KB = " + lstFiles.Count.ToString());
            lstFiles = SvcFile.ReplaceString(lstFiles, Constants.EXP_PATH_DIFF, Constants.EXP_PATH_SQL);
            LOGGER.Info("Files upto 10KB = " + lstFiles.Count.ToString());

            foreach (string f in lstFiles) {
                LOGGER.Info(f);
                try {
                    svcDB.ExecuteScripts(f);
                } catch (Exception e) {
                    LOGGER.Error(e.StackTrace);
                }
            }


            LOGGER.Info(Constants.SEP + "END (press any key to exit)");
            Console.ReadLine();
        }
    }

}
