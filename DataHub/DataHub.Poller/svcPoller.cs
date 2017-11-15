using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

namespace DataHub.Poller {
    public partial class svcPoller : ServiceBase {

        public svcPoller() {
        }

        protected override void OnStart(string[] args) {
            Work.doWork();
        }

        protected override void OnStop() {
        }

    }
}
