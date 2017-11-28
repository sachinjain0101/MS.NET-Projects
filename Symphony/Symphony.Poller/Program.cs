using log4net;
using log4net.Config;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

namespace DataHub.Poller {
    static class Program {
        private static readonly ILog LOGGER = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);

        static void Main() {
            XmlConfigurator.Configure();
            //XmlConfigurator.ConfigureAndWatch(new System.IO.FileInfo("log4net.config"));

            ServiceBase[] ServicesToRun;
            ServicesToRun = new ServiceBase[]
            {
                new svcPoller()
            };
            ServiceBase.Run(ServicesToRun);
        }
    }
}
