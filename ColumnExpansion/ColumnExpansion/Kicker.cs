using log4net;
using log4net.Config;
using System;
using System.Configuration;

namespace ColumnExpansion {
    class Kicker {
        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));
        static string connectionString = "";

        static void Main(string[] args) {
            XmlConfigurator.Configure();

            LOGGER.Info("************************");
            if (args.Length > 0) {
                connectionString = String.Format(ConfigurationManager.ConnectionStrings["DBConnectStrTempl"].ConnectionString, args[0], args[1]);
            } else {
                connectionString = ConfigurationManager.ConnectionStrings["DBConnectStrSimple"].ConnectionString;
            }

            LOGGER.Info("Connection String: " + connectionString);

            //ScriptDropScript()

            Console.ReadLine();
        }
    }
}
