using DynamicExpresso;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using Z.Expressions;
using System.Data.SqlClient;

namespace Opera.Test.DynamicEval {
    class DynamicEval {
        static void Main(string[] args) {
            Console.WriteLine("Hello World!");

            string connStr = "Data Source=qa2-sql1,15150;Initial Catalog=TimeCurrent;Integrated Security=true;Application Name=DynamicEval;";
            string map = "Avionte";
            string sql = "select * from [TimeCurrent].[dbo].[tblIntegration_Mappings]";


            Dictionary<string, string> mapping = new Dictionary<string, string>();
            using (SqlConnection connection = new SqlConnection(connStr)) {
                SqlCommand cmd = new SqlCommand(sql, connection);
                connection.Open();
                using (SqlDataReader rdr = cmd.ExecuteReader()) {
                    if (rdr.HasRows.Equals(true)) {
                        while (rdr.Read()) {
                            mapping.Add(rdr["Attribute"].ToString(), rdr["Expression"].ToString());
                        }
                    }
                }
            }


            string request = @"[{""AgencyCode"":"""",""AgencyName"":"""",""AlternateWorkSchedule"":"""",""ApprovalMethod"":"""",""Approver1Email"":"""",""Approver1FirstName"":"""",""Approver1LastName"":"""",""Approver2Email"":"""",""Approver2FirstName"":"""",""Approver2LastName"":"""",""AssignmentEndDate"":"""",""AssignmentEndReason"":"""",""AssignmentNumber"":""177778"",""AssignmentPropertyExtra"":"""",""AssignmentStartDate"":""2016-09-26T00:00:00Z"",""BillRate"":""37.50"",""BranchID"":""18"",""BranchContactPhone"":"""",""BranchName"":""Madison"",""BranchPropertyExtra"":"""",""Branding"":"""",""ClientDepartmentCode"":"""",""ClientID"":""1143"",""ClientName"":""Jen Test"",""ClockGroup"":"""",""ClockMapping"":"""",""ConsultantType"":"""",""CustomerID"":""1143"",""CustomerName"":""Jen Test"",""CustomerPropertyExtra"":"""",""DTBillingFactor"":"""",""DTPayFactor"":"""",""DepartmentAbbr"":"""",""DepartmentMapping"":""1143"",""DepartmentName"":""Corporate"",""EmployeeBadge"":"""",""EmployeeEmailAddress"":""eddien@example.com"",""EmployeeFirstName"":""Eddie"",""EmployeeID"":""20632"",""EmployeeCellPhone"":"""",""EmployeeLastName"":""Nguyen"",""EmployeeOTType"":"""",""EmployeePIN"":""6686"",""EmployeePropertyExtra"":"""",""EmployeeSSN"":"""",""EmployeeSSNLast4"":"""",""EmployeeSSNLast6"":"""",""EntryFrequency"":"""",""ExpenseApprover2Email"":"""",""ExpenseApprover2FName"":"""",""ExpenseApprover2LName"":"""",""ExpenseApproverEmail"":"""",""ExpenseApproverFName"":"""",""ExpenseApproverLName"":"""",""ExpenseIndicator"":"""",""HolidayPay"":"""",""InOutIndicator"":"""",""JobDescription"":""1-10 Incoming Lines"",""LastDayOfWeek"":""1"",""OTBillingFactor"":"""",""OTPayFactor"":"""",""OrderID"":""3299"",""OrderPayPeriod"":""Weekly"",""OrderPropertyExtra"":"""",""PONumber"":"""",""PayRate"":""25.00"",""PayRules"":"""",""ProjectTrackingIndicator"":"""",""Rounding"":"""",""ShiftCode"":"""",""ShiftName"":"""",""SkillCode"":""1-10 Incoming Lines"",""SkillCodeID"":""78"",""Source"":""C"",""SupervisorFirstName"":"""",""SupervisorLastName"":"""",""VMSAssignmentNumber"":"""",""VMSBuyerID"":"""",""VMSCostCenter"":"""",""VMSEmployeeID"":"""",""VMSRequisitionID"":"""",""WorkSiteID"":""20746"",""WorkSiteName"":""1 main Saint Paul MN 55121"",""WorkSiteState"":""MN""}]";

            Dictionary<string, string> dictRequest = new Dictionary<string, string>();

            JArray jsonArray = JArray.Parse(request);

            foreach (JObject job in jsonArray) {
                List<string> keys = job.Properties().Select(p => p.Name).ToList();
                foreach (JProperty p in job.Properties())
                    dictRequest.Add(p.Name, p.Value.ToString());
            }

            Interpreter interpreter = new Interpreter();
            Parameter[] parameters = new[] { new Parameter("dict", dictRequest.GetType(), dictRequest) };


            Dictionary<string, string> dictResponse = new Dictionary<string, string>();

            foreach (KeyValuePair<string, string> kv in mapping) {

                string result = "";
                string expression = kv.Value;
                if (!String.IsNullOrEmpty(expression)) {
                    result = interpreter.Eval(expression, parameters).ToString();
                }

                dictResponse.Add(kv.Key, result);
            }

            //name = interpreter.Eval(expr1, parameters).ToString();

            //var y = interpreter.Eval(expr2, parameters);

            string response = JsonConvert.SerializeObject(dictResponse);

            Console.ReadLine();

        }
    }
}
