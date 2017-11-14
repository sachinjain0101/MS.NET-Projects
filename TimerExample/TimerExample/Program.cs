using log4net;
using log4net.Config;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Timers;

namespace TimerExample {
    class Program {
        private static readonly ILog LOGGER = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        static Timer timer;

        static void MainX(string[] args) {
            FileInfo f = new FileInfo("log4net.config");
            XmlConfigurator.ConfigureAndWatch(new System.IO.FileInfo("log4net.config"));
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;
            LOGGER.Info("******* Service Started");

            LOGGER.Info("hi");
            Console.ReadLine();
        }

        static void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e) {
            LOGGER.Fatal("Unhandled exception caught by AppDomain handler.  Application Terminating=" + e.IsTerminating, e.ExceptionObject as Exception);
        }



        static void Main(string[] args) {
            //XmlConfigurator.Configure();
            XmlConfigurator.ConfigureAndWatch(new System.IO.FileInfo("log4net.config"));
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

