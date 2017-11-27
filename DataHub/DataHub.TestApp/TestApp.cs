using DataHub.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Data;
using System.Data.SqlClient;

namespace DataHub.TestApp {
    public class Student {
        public string First { get; set; }
        public string Last { get; set; }
        public int ID { get; set; }
        public List<int> Scores;
    }

    public class TestApp {

        // Create a data source by using a collection initializer.
        public static List<Student> students = new List<Student>
        {
               new Student {First="Svetlana", Last="Omelchenko", ID=111, Scores= new List<int> {97, 92, 81, 60}},
               new Student {First="Claire", Last="O'Donnell", ID=111, Scores= new List<int> {75, 84, 91, 39}},
               new Student {First="Sven", Last="Mortensen", ID=111, Scores= new List<int> {88, 94, 65, 91}},
               new Student {First="Cesar", Last="Garcia", ID=111, Scores= new List<int> {97, 89, 85, 82}},
               new Student {First="Debra", Last="Garcia", ID=111, Scores= new List<int> {35, 72, 91, 70}},
               new Student {First="Fadi", Last="Fakhouri", ID=111, Scores= new List<int> {99, 86, 90, 94}},
               new Student {First="Hanying", Last="Feng", ID=111, Scores= new List<int> {93, 92, 80, 87}},
               new Student {First="Hugo", Last="Garcia", ID=111, Scores= new List<int> {92, 90, 83, 78}},
               new Student {First="Lance", Last="Tucker", ID=119, Scores= new List<int> {68, 79, 88, 92}},
               new Student {First="Terry", Last="Adams", ID=120, Scores= new List<int> {99, 82, 81, 79}},
               new Student {First="Eugene", Last="Zabokritski", ID=121, Scores= new List<int> {96, 85, 91, 60}},
               new Student {First="Michael", Last="Tucker", ID=122, Scores= new List<int> {94, 92, 91, 91} }
            };



        public static void Main(string[] args) {


            DateTime myDateTime = DateTime.Now;
            Console.WriteLine(myDateTime.ToString("yyyy-MM-dd HH:mm:ss"));


            DataTable dt = new DataTable();

            using (SqlConnection conn = new SqlConnection("Server=qa2-sql1,15150;Database=TimeHistory;Trusted_Connection=True;"))
            using (SqlCommand cmd = new SqlCommand("select top 10 * from dbo.tbltimehistdetail WHERE AprvlStatus_Mobile IS NULL", conn))
            using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                da.Fill(dt);

            List<TimeHistDetail> thds = new List<TimeHistDetail>();

            foreach (DataRow r in dt.Rows) {

                TimeHistDetail thd = new TimeHistDetail();

                if (r["RecordID"].ToString() != "")
                    thd.RecordID = r["RecordID"].ToString();
                else
                    thd.RecordID = "0";
                if (r["Client"].ToString() != "")
                    thd.Client = r["Client"].ToString();
                else
                    thd.Client = "";
                if (r["GroupCode"].ToString() != "")
                    thd.GroupCode = r["GroupCode"].ToString();
                else
                    thd.GroupCode = "0";
                if (r["SSN"].ToString() != "")
                    thd.SSN = r["SSN"].ToString();
                else
                    thd.SSN = "0";
                if (r["PayrollPeriodEndDate"].ToString() != "")
                    thd.PayrollPeriodEndDate = DateTime.Parse(r["PayrollPeriodEndDate"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.PayrollPeriodEndDate = "";
                if (r["MasterPayrollDate"].ToString() != "")
                    thd.MasterPayrollDate = DateTime.Parse(r["MasterPayrollDate"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.MasterPayrollDate = "";
                if (r["SiteNo"].ToString() != "")
                    thd.SiteNo = r["SiteNo"].ToString();
                else
                    thd.SiteNo = "0";
                if (r["DeptNo"].ToString() != "")
                    thd.DeptNo = r["DeptNo"].ToString();
                else
                    thd.DeptNo = "0";
                if (r["JobID"].ToString() != "")
                    thd.JobID = r["JobID"].ToString();
                else
                    thd.JobID = "0";
                if (r["TransDate"].ToString() != "")
                    thd.TransDate = DateTime.Parse(r["TransDate"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.TransDate = "";
                if (r["EmpStatus"].ToString() != "")
                    thd.EmpStatus = r["EmpStatus"].ToString();
                else
                    thd.EmpStatus = "0";
                if (r["BillRate"].ToString() != "")
                    thd.BillRate = r["BillRate"].ToString();
                else
                    thd.BillRate = "0.0";
                if (r["BillOTRate"].ToString() != "")
                    thd.BillOTRate = r["BillOTRate"].ToString();
                else
                    thd.BillOTRate = "0.0";
                if (r["BillOTRateOverride"].ToString() != "")
                    thd.BillOTRateOverride = r["BillOTRateOverride"].ToString();
                else
                    thd.BillOTRateOverride = "0.0";
                if (r["PayRate"].ToString() != "")
                    thd.PayRate = r["PayRate"].ToString();
                else
                    thd.PayRate = "0.0";
                if (r["ShiftNo"].ToString() != "")
                    thd.ShiftNo = r["ShiftNo"].ToString();
                else
                    thd.ShiftNo = "0";
                if (r["InDay"].ToString() != "")
                    thd.InDay = r["InDay"].ToString();
                else
                    thd.InDay = "0";
                if (r["InTime"].ToString() != "")
                    thd.InTime = DateTime.Parse(r["InTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.InTime = "";
                if (r["OutDay"].ToString() != "")
                    thd.OutDay = r["OutDay"].ToString();
                else
                    thd.OutDay = "0";
                if (r["OutTime"].ToString() != "")
                    thd.OutTime = DateTime.Parse(r["OutTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.OutTime = "";
                if (r["Hours"].ToString() != "")
                    thd.Hours = r["Hours"].ToString();
                else
                    thd.Hours = "0.0";
                if (r["Dollars"].ToString() != "")
                    thd.Dollars = r["Dollars"].ToString();
                else
                    thd.Dollars = "0.0";
                if (r["ClockAdjustmentNo"].ToString() != "")
                    thd.ClockAdjustmentNo = r["ClockAdjustmentNo"].ToString();
                else
                    thd.ClockAdjustmentNo = "";
                if (r["AdjustmentCode"].ToString() != "")
                    thd.AdjustmentCode = r["AdjustmentCode"].ToString();
                else
                    thd.AdjustmentCode = "";
                if (r["AdjustmentName"].ToString() != "")
                    thd.AdjustmentName = r["AdjustmentName"].ToString();
                else
                    thd.AdjustmentName = "";
                if (r["TransType"].ToString() != "")
                    thd.TransType = r["TransType"].ToString();
                else
                    thd.TransType = "0";
                if (r["Changed_DeptNo"].ToString() != "")
                    thd.Changed_DeptNo = r["Changed_DeptNo"].ToString();
                else
                    thd.Changed_DeptNo = "";
                if (r["Changed_InPunch"].ToString() != "")
                    thd.Changed_InPunch = r["Changed_InPunch"].ToString();
                else
                    thd.Changed_InPunch = "";
                if (r["Changed_OutPunch"].ToString() != "")
                    thd.Changed_OutPunch = r["Changed_OutPunch"].ToString();
                else
                    thd.Changed_OutPunch = "";
                if (r["AgencyNo"].ToString() != "")
                    thd.AgencyNo = r["AgencyNo"].ToString();
                else
                    thd.AgencyNo = "0";
                if (r["InSrc"].ToString() != "")
                    thd.InSrc = r["InSrc"].ToString();
                else
                    thd.InSrc = "";
                if (r["OutSrc"].ToString() != "")
                    thd.OutSrc = r["OutSrc"].ToString();
                else
                    thd.OutSrc = "";
                if (r["DaylightSavTime"].ToString() != "")
                    thd.DaylightSavTime = r["DaylightSavTime"].ToString();
                else
                    thd.DaylightSavTime = "";
                if (r["Holiday"].ToString() != "")
                    thd.Holiday = r["Holiday"].ToString();
                else
                    thd.Holiday = "";
                if (r["RegHours"].ToString() != "")
                    thd.RegHours = r["RegHours"].ToString();
                else
                    thd.RegHours = "0.0";
                if (r["OT_Hours"].ToString() != "")
                    thd.OT_Hours = r["OT_Hours"].ToString();
                else
                    thd.OT_Hours = "0.0";
                if (r["DT_Hours"].ToString() != "")
                    thd.DT_Hours = r["DT_Hours"].ToString();
                else
                    thd.DT_Hours = "0.0";
                if (r["RegDollars"].ToString() != "")
                    thd.RegDollars = r["RegDollars"].ToString();
                else
                    thd.RegDollars = "0.0";
                if (r["OT_Dollars"].ToString() != "")
                    thd.OT_Dollars = r["OT_Dollars"].ToString();
                else
                    thd.OT_Dollars = "0.0";
                if (r["DT_Dollars"].ToString() != "")
                    thd.DT_Dollars = r["DT_Dollars"].ToString();
                else
                    thd.DT_Dollars = "0.0";
                if (r["RegBillingDollars"].ToString() != "")
                    thd.RegBillingDollars = r["RegBillingDollars"].ToString();
                else
                    thd.RegBillingDollars = "0.0";
                if (r["OTBillingDollars"].ToString() != "")
                    thd.OTBillingDollars = r["OTBillingDollars"].ToString();
                else
                    thd.OTBillingDollars = "0.0";
                if (r["DTBillingDollars"].ToString() != "")
                    thd.DTBillingDollars = r["DTBillingDollars"].ToString();
                else
                    thd.DTBillingDollars = "0.0";
                if (r["CountAsOT"].ToString() != "")
                    thd.CountAsOT = r["CountAsOT"].ToString();
                else
                    thd.CountAsOT = "";
                if (r["RegDollars4"].ToString() != "")
                    thd.RegDollars4 = r["RegDollars4"].ToString();
                else
                    thd.RegDollars4 = "0.0";
                if (r["OT_Dollars4"].ToString() != "")
                    thd.OT_Dollars4 = r["OT_Dollars4"].ToString();
                else
                    thd.OT_Dollars4 = "0.0";
                if (r["DT_Dollars4"].ToString() != "")
                    thd.DT_Dollars4 = r["DT_Dollars4"].ToString();
                else
                    thd.DT_Dollars4 = "0.0";
                if (r["RegBillingDollars4"].ToString() != "")
                    thd.RegBillingDollars4 = r["RegBillingDollars4"].ToString();
                else
                    thd.RegBillingDollars4 = "0.0";
                if (r["OTBillingDollars4"].ToString() != "")
                    thd.OTBillingDollars4 = r["OTBillingDollars4"].ToString();
                else
                    thd.OTBillingDollars4 = "0.0";
                if (r["DTBillingDollars4"].ToString() != "")
                    thd.DTBillingDollars4 = r["DTBillingDollars4"].ToString();
                else
                    thd.DTBillingDollars4 = "0.0";
                if (r["xAdjHours"].ToString() != "")
                    thd.xAdjHours = r["xAdjHours"].ToString();
                else
                    thd.xAdjHours = "0.0";
                if (r["AprvlStatus"].ToString() != "")
                    thd.AprvlStatus = r["AprvlStatus"].ToString();
                else
                    thd.AprvlStatus = "";
                if (r["AprvlStatus_UserID"].ToString() != "")
                    thd.AprvlStatus_UserID = r["AprvlStatus_UserID"].ToString();
                else
                    thd.AprvlStatus_UserID = "0";
                if (r["AprvlStatus_Date"].ToString() != "")
                    thd.AprvlStatus_Date = DateTime.Parse(r["AprvlStatus_Date"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.AprvlStatus_Date = "";
                if (r["AprvlAdjOrigRecID"].ToString() != "")
                    thd.AprvlAdjOrigRecID = r["AprvlAdjOrigRecID"].ToString();
                else
                    thd.AprvlAdjOrigRecID = "0";
                if (r["HandledByImporter"].ToString() != "")
                    thd.HandledByImporter = r["HandledByImporter"].ToString();
                else
                    thd.HandledByImporter = "";
                if (r["AprvlAdjOrigClkAdjNo"].ToString() != "")
                    thd.AprvlAdjOrigClkAdjNo = r["AprvlAdjOrigClkAdjNo"].ToString();
                else
                    thd.AprvlAdjOrigClkAdjNo = "";
                if (r["ClkTransNo"].ToString() != "")
                    thd.ClkTransNo = r["ClkTransNo"].ToString();
                else
                    thd.ClkTransNo = "0";
                if (r["ShiftDiffClass"].ToString() != "")
                    thd.ShiftDiffClass = r["ShiftDiffClass"].ToString();
                else
                    thd.ShiftDiffClass = "";
                if (r["AllocatedRegHours"].ToString() != "")
                    thd.AllocatedRegHours = r["AllocatedRegHours"].ToString();
                else
                    thd.AllocatedRegHours = "0.0";
                if (r["AllocatedOT_Hours"].ToString() != "")
                    thd.AllocatedOT_Hours = r["AllocatedOT_Hours"].ToString();
                else
                    thd.AllocatedOT_Hours = "0.0";
                if (r["AllocatedDT_Hours"].ToString() != "")
                    thd.AllocatedDT_Hours = r["AllocatedDT_Hours"].ToString();
                else
                    thd.AllocatedDT_Hours = "0.0";
                if (r["Borrowed"].ToString() != "")
                    thd.Borrowed = r["Borrowed"].ToString();
                else
                    thd.Borrowed = "";
                if (r["UserCode"].ToString() != "")
                    thd.UserCode = r["UserCode"].ToString();
                else
                    thd.UserCode = "";
                if (r["DivisionID"].ToString() != "")
                    thd.DivisionID = r["DivisionID"].ToString();
                else
                    thd.DivisionID = "0";
                if (r["CostID"].ToString() != "")
                    thd.CostID = r["CostID"].ToString();
                else
                    thd.CostID = "";
                if (r["ShiftDiffAmt"].ToString() != "")
                    thd.ShiftDiffAmt = r["ShiftDiffAmt"].ToString();
                else
                    thd.ShiftDiffAmt = "0.0";
                if (r["OutUserCode"].ToString() != "")
                    thd.OutUserCode = r["OutUserCode"].ToString();
                else
                    thd.OutUserCode = "";
                if (r["ActualInTime"].ToString() != "")
                    thd.ActualInTime = DateTime.Parse(r["ActualInTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.ActualInTime = "";
                if (r["ActualOutTime"].ToString() != "")
                    thd.ActualOutTime = DateTime.Parse(r["ActualOutTime"].ToString()).ToString("yyyy-MM-dd HH:mm:ss");
                else
                    thd.ActualOutTime = "";
                if (r["InSiteNo"].ToString() != "")
                    thd.InSiteNo = r["InSiteNo"].ToString();
                else
                    thd.InSiteNo = "0";
                if (r["OutSiteNo"].ToString() != "")
                    thd.OutSiteNo = r["OutSiteNo"].ToString();
                else
                    thd.OutSiteNo = "0";
                if (r["InVerified"].ToString() != "")
                    thd.InVerified = r["InVerified"].ToString();
                else
                    thd.InVerified = "";
                if (r["OutVerified"].ToString() != "")
                    thd.OutVerified = r["OutVerified"].ToString();
                else
                    thd.OutVerified = "";
                if (r["InClass"].ToString() != "")
                    thd.InClass = r["InClass"].ToString();
                else
                    thd.InClass = "";
                if (r["OutClass"].ToString() != "")
                    thd.OutClass = r["OutClass"].ToString();
                else
                    thd.OutClass = "";
                if (r["InTimestamp"].ToString() != "")
                    thd.InTimestamp = r["InTimestamp"].ToString();
                else
                    thd.InTimestamp = "0";
                if (r["outTimestamp"].ToString() != "")
                    thd.outTimestamp = r["outTimestamp"].ToString();
                else
                    thd.outTimestamp = "0";
                if (r["CrossoverStatus"].ToString() != "")
                    thd.CrossoverStatus = r["CrossoverStatus"].ToString();
                else
                    thd.CrossoverStatus = "";
                if (r["CrossoverOtherGroup"].ToString() != "")
                    thd.CrossoverOtherGroup = r["CrossoverOtherGroup"].ToString();
                else
                    thd.CrossoverOtherGroup = "0";
                if (r["InRoundOFF"].ToString() != "")
                    thd.InRoundOFF = r["InRoundOFF"].ToString();
                else
                    thd.InRoundOFF = "";
                if (r["OutRoundOFF"].ToString() != "")
                    thd.OutRoundOFF = r["OutRoundOFF"].ToString();
                else
                    thd.OutRoundOFF = "";
                if (r["AprvlStatus_Mobile"].ToString() != "")
                    thd.AprvlStatus_Mobile = Boolean.Parse(r["AprvlStatus_Mobile"].ToString()).ToString();
                else
                    thd.AprvlStatus_Mobile = "";
                thds.Add(thd);

            }







            IEnumerable<Student> q1 =
                    from s1 in students
                    where s1.First == "Cesar"
                    select s1;


            var q2 =
            from s2 in students
            group s2 by s2.ID;


            Console.ReadLine();
        }

    }

}

