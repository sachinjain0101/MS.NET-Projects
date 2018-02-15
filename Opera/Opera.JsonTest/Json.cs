using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Opera.Test.Json {
    class Dat {
        bool Valid {
            get; set;
        }
        string Value {
            get; set;
        }
    }

    class Json {

        static Dat FlattenJson(string json) {
            Dat d = new Dat();
            if (IsValidJson(json)) {

            }

            return d;
        }

        static void Main(string[] args) {

            string hdr = "Source,BranchName,BranchID,ClientName,ClientID,EmployeeFirstName,EmployeeLastName,EmployeeEmailAddress,EmployeeID,EmployeeSSN,EmployeePIN,EmployeeBadge,AssignmentNumber,JobDescription,ClockGroup,AssignmentStartDate,AssignmentEndDate,AssignmentEndReason,DepartmentMapping,DepartmentName,DepartmentAbbr,ClientDepartmentCode,ClockMapping,ShiftCode,BillRate,PayRate,OTBillingFactor,DTBillingFactor,OTPayFactor,DTPayFactor,LastDayOfWeek,WorkSiteID,WorkSiteName,WorkSiteState,Approver1FirstName,Approver1LastName,Approver1Email,Approver2FirstName,Approver2LastName,Approver2Email,AgencyCode,AgencyName,VMSEmployeeID,VMSAssignmentNumber,VMSCostCenter,VMSBuyerID,VMSRequisitionID,EmployeeOTType,ExpenseApproverFName,ExpenseApproverLName,ExpenseApproverEmail,ExpenseApprover2FName,ExpenseApprover2LName,ExpenseApprover2Email,InOutIndicator,AlternateWorkSchedule,Rounding,Branding,PayRules,ApprovalMethod,EntryFrequency,HolidayPay,ConsultantType,ProjectTrackingIndicator,ExpenseIndicator,SupervisorFirstName,SupervisorLastName,CustomerName,CustomerID,EmployeeSSNLast4,EmployeeSSNLast6,OrderID,OrderPayPeriod,SkillCodeID,SkillCode,PONumber,ShiftName,BranchPropertyExtra,CustomerPropertyExtra,OrderPropertyExtra,AssignmentPropertyExtra,EmployeePropertyExtra,BranchContactPhone,EmployeeCellPhone";
            string dat = "C,PMG Main Office,61,Bowling Green Metal Forming,179793,Project,Expenses,,1000006,,3333,,505799,Expenses,,2014-04-06T00:00:00Z,,,179793,Corporate,,,,,0.00,0.00,,,,,1,918232,111 Cosma Drive Bowling Green KY 42101,KY,,,,,,,111,PMG Travel,,,,,,,,,,,,,,,,,,,,,,,,,,Bowling Green Metal Forming,179793,,,40098,Weekly,3937,Expenses,,,,,,,,,";


            Console.WriteLine("*******************************************");
            Console.WriteLine("Hello Opera!");
            Console.WriteLine("*******************************************");

            string[] hrdArr = hdr.Split(",");

            Console.WriteLine(hrdArr.Length);

            string[] datArr = dat.Split(",");

            Console.WriteLine(datArr.Length);

            List<Dictionary<string, string>> lstDict = new List<Dictionary<string, string>>();
            int i = 0;
            foreach (string key in hrdArr) {
                Dictionary<string, string> dict = new Dictionary<string, string>();
                dict.Add(key, datArr[i]);
                lstDict.Add(dict);
                i++;
            }

            string json = JsonConvert.SerializeObject(lstDict);

            Console.WriteLine(lstDict.Count);

            Console.WriteLine(json);

            String jsonDat = @"[{""AgencyCode"":""111"",""AgencyName"":""PMG Travel"",""AlternateWorkSchedule"":"""",""ApprovalMethod"":"""",""Approver1Email"":""EMantooth @cameron.slb.com""}]";
            //,{ ""AgencyCode"":""111"",""AgencyName"":""PMG Travel"",""AlternateWorkSchedule"":"""",""ApprovalMethod"":"""",""Approver1Email"":""""}]";



            JArray jsonArray = JArray.Parse(jsonDat);
            foreach (JObject job in jsonArray) {

                foreach (JProperty p in job.Properties()) {
                    Console.WriteLine("==> {0}  ***  {1}", p.Name, p.Value);
                }

                //dynamic data = JObject.Parse(jsonArray[0].ToString());
            }





            string x = Regex.Replace(jsonDat, @"\\[|\\]", "");

            string[] y = Regex.Matches(x, @"{.*?}").Cast<Match>().Select(m => m.Value).ToArray();

            foreach (string z in y) {
                string a = Regex.Replace(z, @"{|}", "");
                string[] b = Regex.Split(a, ",");

            }

            Console.ReadLine();

        }

        private static bool IsValidJson(string strInput) {
            strInput = strInput.Trim();
            if ((strInput.StartsWith("{") && strInput.EndsWith("}")) || //For object
                (strInput.StartsWith("[") && strInput.EndsWith("]"))) //For array
            {
                try {
                    var obj = JToken.Parse(strInput);
                    return true;
                } catch (JsonReaderException jex) {
                    //Exception in parsing json
                    Console.WriteLine(jex.Message);
                    return false;
                } catch (Exception ex) //some other exception
                  {
                    Console.WriteLine(ex.ToString());
                    return false;
                }
            } else {
                return false;
            }
        }
    }
}
