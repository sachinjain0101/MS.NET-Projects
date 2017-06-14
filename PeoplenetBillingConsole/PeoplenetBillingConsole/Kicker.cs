using log4net;
using log4net.Config;
using PeoplenetBillingConsole.Services;
using System;
using System.Data;

namespace PeoplenetBillingConsole {
    class Kicker {
        private static ILog LOGGER = LogManager.GetLogger(typeof(Kicker));

        public static void Main(string[] args) {
            XmlConfigurator.Configure();
            LOGGER.Info(Constants.DisplayLine("Start: PeoplenetBilling Console"));

            string serverName = "BILLINGTESTSQL1";
            string billingDate = "04/30/2017";

            if (args.Length > 0) {
                serverName = args[0];
                billingDate = args[1];
            }

            LOGGER.Info(String.Format("Inputs: DBName # {0} / Billing Date # {1}", serverName, billingDate));

            DBOps dbops = new DBOps(serverName);

            Int32 latestInvoiceNo = dbops.getLatestInvoiceNumber();
            LOGGER.Info(Constants.DisplayLine("Getting billing & customer cross reference info"));
            DataTable dtBillXrefCust = dbops.getBillingXrefCustomers(billingDate, latestInvoiceNo);

            DataTable dtInvoiceSetup = new DataTable();
            LOGGER.Info(Constants.DisplayLine("Getting client definitions"));
            foreach (DataRow r in dtBillXrefCust.Rows) {
                dtInvoiceSetup.Merge(dbops.getItemBillMasterClientDef2(r));
            }

            DataTable dtInvoiceDtls = new DataTable();

            foreach (DataRow r in dtInvoiceSetup.Rows) {
                dbops.loadInvoiceDetails(r, billingDate);
            }

            LOGGER.Info(Constants.DisplayLine("Updating NET billing"));
            dbops.updateNetBilling(billingDate);

            LOGGER.Info(latestInvoiceNo);

            LOGGER.Info(Constants.DisplayLine("Finish: PeoplenetBilling Console"));
            Console.ReadLine();
        }
    }
}
