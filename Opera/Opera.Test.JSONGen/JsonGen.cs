using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.ServiceBus;
using Microsoft.Azure.ServiceBus.Core;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Opera.Test.JSONGen {
    class JsonGen {

        static string initialJson = @"[{""MessageID"":""172f8f22-a7c5-4d45-a1cf-30bb471dded0"",""IntegrationKey"":"""",""TransferCode"":""TYMPNTC"",""BranchName"":""Covina, CA"",""BranchNumber"":""80030"",""AccountName"":""HANSON DISTRIBUTING"",""AccountNumber"":""504449"",""EmployeeFirstName"":""David"",""EmployeeLastName"":""Artishon"",""EmployeeEmailAddress"":""artishondavid87 @gmail.com"",""EmployeeNumber"":""5513497"",""EmployeePIN"":""2266"",""EmployeeBadge"":"""",""AssignmentNumber"":""5108168"",""JobDescription"":""General Warehouse"",""ClockGroup"":"""",""AssignmentStartDate"":""2017-08-02T00:00:00Z"",""AssignmentEndDate"":"""",""AssignmentEndReason"":"""",""DepartmentName"":""1ST SHIFT SHIPPING DEPARTMENT"",""DepartmentAbbr"":"""",""ClientDepartmentCode"":"""",""ClockMapping"":"""",""Shift"":"""",""OTBillingFactor"":""1.50000"",""DTBillingFactor"":""2.00000"",""OTPayFactor"":"""",""DTPayFactor"":"""",""WeekEndingDay"":""SUN"",""WorkSiteNumber"":""1142116"",""WorkSiteName"":""Azusa location"",""WorkSiteState"":""CA"",""ApproverFirstName"":""Juan"",""ApproverLastName"":""Chavez"",""ApproverEmail"":""juan.chavez @hansondistributing.com"",""ReportsToFirstName"":""Juan"",""ReportsToLastName"":""Chavez"",""ReportsToEmail"":""juan.chavez @hansondistributing.com"",""AgencyCode"":""Select Staffing"",""AgencyName"":""Select Staffing"",""VMSEmployeeID"":"""",""VMSAssignmentNumber"":"""",""VMSCostCenter"":"""",""VMSBuyerID"":"""",""VMSRequisitionID"":"""",""EmployeeOTType"":""0"",""ExpenseApproverFName"":""Juan"",""ExpenseApproverLName"":""Chavez"",""ExpenseApproverEmail"":""juan.chavez @hansondistributing.com"",""ExpenseApprover2FName"":""Juan"",""ExpenseApprover2LName"":""Chavez"",""ExpenseApprover2Email"":""juan.chavez @hansondistributing.com"",""InOutIndicator"":"""",""AlternateWorkSchedule"":"""",""RoundingPrecisionType"":"""",""Brand"":""Select Staffing"",""PayRules"":"""",""ApprovalMethod"":"""",""EntryFrequency"":"""",""HolidayCode"":"""",""ConsultantType"":"""",""ProjectTrackingIndicator"":"""",""ExpenseIndicator"":"""",""BranchLocalPhone"":"""",""EmployeeMobilePhone"":"""",""TimeCodes"":"""",""ExpenseCodes"":"""",""NoBill_ExpAprvr_FirstName"":"""",""NoBill_ExpAprvr_LastName"":"""",""NoBill_ExpAprvr_Email"":"""",""NoBill_ExpAprvr_FirstName2"":"""",""NoBill_ExpAprvr_LastName2"":"""",""NoBill_ExpAprvr_Email2"":"""",""SalaryIndicator"":"""",""EmployeeCPAFlag"":"""",""ProxyCPAFlag"":"""",""WaiveBreak1"":"""",""WaiveBreak2"":"""",""WaiveBreak3"":"""",""PuertoRicoEmployeeType"":"""",""PuertoRicoBreakLength"":"""",""BillRate"":""16.0380"",""PayRate"":""11.0000"",""Division"":""Juan Chavez"",""PONumber"":"""",""ShiftName"":"""",""SundayShiftStart"":"""",""SundayShiftStop"":"""",""MondayShiftStart"":"""",""MondayShiftStop"":"""",""TuesdayShiftStart"":"""",""TuesdayShiftStop"":"""",""WednesdayShiftStart"":"""",""WednesdayShiftStop"":"""",""ThursdayShiftStart"":"""",""ThursdayShiftStop"":"""",""FridayShiftStart"":"""",""FridayShiftStop"":"""",""SaturdayShiftStart"":"""",""SaturdayShiftStop"":"""",""PeopleNetAssignmentPayRates"":[{""Row"":""1"",""Name"":""BillRate"",""Value"":""16.0380""},{""Row"":""1"",""Name"":""PayRate"",""Value"":""11.0000""},{""Row"":""1"",""Name"":""EffectiveDate"",""Value"":""""},{""Row"":""1"",""Name"":""CurrentEffectiveRateFlag"",""Value"":""true""}]}]";
        private static string connectionString = "Endpoint=sb://peoplenetqa.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=GpBG4e9yHWnHa9zv/Yks5tbU55Y8QdOEtpvC8E/EGUI=";
        private static string PartitionedQueueName = "assignment";

        


        static void Main(string[] args) {
            Console.WriteLine("Parsing Initial JSON");
            

            string tempStr = initialJson;

            List<string> JsonStrings = new List<string>();

            for (int i = 0; i <= 3; i++) {
                Dictionary<string, string> dict = GetJsonDict(tempStr);
                string val = "";
                dict.TryGetValue("PayRate", out val);
                dict["PayRate"] = (Decimal.Parse(val) + 1).ToString();
                Console.WriteLine(val);
                tempStr = GetJsonStr(dict);
                JsonStrings.Add(tempStr);
            }

            int counter = 0;
            foreach (string json in JsonStrings) {
                var message = new Message(Encoding.UTF8.GetBytes(json)) {
                    ContentType = "application/json",
                    Label = "Test"+(counter++).ToString(),
                    MessageId = DateTime.Now.Ticks.ToString(),
                    //TimeToLive = TimeSpan.FromMinutes(2),
                    PartitionKey = "Test" + (counter++).ToString()
                };
                SendMessageAsync(message);
            }

            Console.ReadLine();

        }

        static async void SendMessageAsync(Message message) {
            var sender = new MessageSender(connectionString, PartitionedQueueName);
            await sender.SendAsync(message);
        }

        static Dictionary<string, string> GetJsonDict(string str) {
            Dictionary<string, string> dict = new Dictionary<string, string>();
            string TEMPLATE = "[{0}]";
            JArray jsonArray = null;
            try {
            jsonArray = JArray.Parse(str);
            }catch(JsonReaderException e) {
                str = String.Format(TEMPLATE, str);
                jsonArray = JArray.Parse(str);
            }

            foreach (JObject job in jsonArray) {
                List<string> keys = job.Properties().Select(p => p.Name).ToList();
                foreach (JProperty p in job.Properties())
                    dict.Add(p.Name, p.Value.ToString());
            }

            return dict;
        }

        static string GetJsonStr(Dictionary<string, string> dict) {
            return JsonConvert.SerializeObject(dict);
        }
    }
}
