using log4net;
using log4net.Config;
using System;

namespace DatabaseMonitor {
    class Kicker {
        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));
        public static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info(Constants.DisplayLine("Start: Database Monitor"));
            LOGGER.Info(Constants.DisplayLine("Finish: Database Monitor"));
            Console.ReadLine();
        }
        public static bool ConfigureLogger() {

            return false;
        }
    }
}
