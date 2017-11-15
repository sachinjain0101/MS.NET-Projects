
using log4net;
using System;
using System.Reflection;
using System.Timers;

namespace DataHub.Poller {
    class Work {
        private static readonly ILog LOGGER = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        static Timer timer;

        static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e) {
            LOGGER.Fatal("Unhandled exception caught by AppDomain handler.  Application Terminating=" + e.IsTerminating, e.ExceptionObject as Exception);
        }

        public static void doWork() {
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
            LOGGER.Info("******* Service Started");
            startTimer();
            Console.ReadLine();
        }

        static void startTimer() {
            LOGGER.Info("Timer started...");
            double tickTime = 1000;
            timer = new Timer(tickTime);
            timer.Elapsed += new ElapsedEventHandler(timeElapsed);
            timer.Start();
        }

        static void timeElapsed(object sender, ElapsedEventArgs e) {
            LOGGER.Info("Hello World!!! - Performing scheduled task...");
        }


    }
}
