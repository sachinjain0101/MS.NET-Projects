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

            DataTable dt = new DataTable();

            using (SqlConnection conn = new SqlConnection("Server=SJ;Database=TimeHistory;Trusted_Connection=True;"))
            using (SqlCommand cmd = new SqlCommand("select top 10 * from dbo.tbltimehistdetail WHERE AprvlStatus_Mobile IS NULL", conn))
            using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                da.Fill(dt);

            List<TimeHistDetail> thds = new List<TimeHistDetail>();

            foreach (DataRow r in dt.Rows) {

                TimeHistDetail thd = new TimeHistDetail();

                if (r["RecordID"].ToString() != "")
                    thd.RecordID = Int64.Parse(r["RecordID"].ToString());
                else
                    thd.RecordID = null;
                thd.Client = r["Client"].ToString();
                if (r["GroupCode"].ToString() != "")
                    thd.GroupCode = Int32.Parse(r["GroupCode"].ToString());
                else
                    thd.GroupCode = null;
                if (r["SSN"].ToString() != "")
                    thd.SSN = Int32.Parse(r["SSN"].ToString());
                else
                    thd.SSN = null;
                if (r["PayrollPeriodEndDate"].ToString() != "")
                    thd.PayrollPeriodEndDate = DateTime.Parse(r["PayrollPeriodEndDate"].ToString());
                else
                    thd.PayrollPeriodEndDate = null;
                if (r["MasterPayrollDate"].ToString() != "")
                    thd.MasterPayrollDate = DateTime.Parse(r["MasterPayrollDate"].ToString());
                else
                    thd.MasterPayrollDate = null;
                if (r["SiteNo"].ToString() != "")
                    thd.SiteNo = Int32.Parse(r["SiteNo"].ToString());
                else
                    thd.SiteNo = null;
                if (r["DeptNo"].ToString() != "")
                    thd.DeptNo = Int32.Parse(r["DeptNo"].ToString());
                else
                    thd.DeptNo = null;
                if (r["JobID"].ToString() != "")
                    thd.JobID = Int64.Parse(r["JobID"].ToString());
                else
                    thd.JobID = null;
                if (r["TransDate"].ToString() != "")
                    thd.TransDate = DateTime.Parse(r["TransDate"].ToString());
                else
                    thd.TransDate = null;
                if (r["EmpStatus"].ToString() != "")
                    thd.EmpStatus = Int32.Parse(r["EmpStatus"].ToString());
                else
                    thd.EmpStatus = null;
                if (r["BillRate"].ToString() != "")
                    thd.BillRate = Decimal.Parse(r["BillRate"].ToString());
                else
                    thd.BillRate = null;
                if (r["BillOTRate"].ToString() != "")
                    thd.BillOTRate = Decimal.Parse(r["BillOTRate"].ToString());
                else
                    thd.BillOTRate = null;
                if (r["BillOTRateOverride"].ToString() != "")
                    thd.BillOTRateOverride = Decimal.Parse(r["BillOTRateOverride"].ToString());
                else
                    thd.BillOTRateOverride = null;
                if (r["PayRate"].ToString() != "")
                    thd.PayRate = Decimal.Parse(r["PayRate"].ToString());
                else
                    thd.PayRate = null;
                if (r["ShiftNo"].ToString() != "")
                    thd.ShiftNo = Int32.Parse(r["ShiftNo"].ToString());
                else
                    thd.ShiftNo = null;
                if (r["InDay"].ToString() != "")
                    thd.InDay = Int32.Parse(r["InDay"].ToString());
                else
                    thd.InDay = null;
                if (r["InTime"].ToString() != "")
                    thd.InTime = DateTime.Parse(r["InTime"].ToString());
                else
                    thd.InTime = null;
                if (r["OutDay"].ToString() != "")
                    thd.OutDay = Int32.Parse(r["OutDay"].ToString());
                else
                    thd.OutDay = null;
                if (r["OutTime"].ToString() != "")
                    thd.OutTime = DateTime.Parse(r["OutTime"].ToString());
                else
                    thd.OutTime = null;
                if (r["Hours"].ToString() != "")
                    thd.Hours = Decimal.Parse(r["Hours"].ToString());
                else
                    thd.Hours = null;
                if (r["Dollars"].ToString() != "")
                    thd.Dollars = Decimal.Parse(r["Dollars"].ToString());
                else
                    thd.Dollars = null;
                thd.ClockAdjustmentNo = r["ClockAdjustmentNo"].ToString();
                thd.AdjustmentCode = r["AdjustmentCode"].ToString();
                thd.AdjustmentName = r["AdjustmentName"].ToString();
                if (r["TransType"].ToString() != "")
                    thd.TransType = Int32.Parse(r["TransType"].ToString());
                else
                    thd.TransType = null;
                thd.Changed_DeptNo = r["Changed_DeptNo"].ToString();
                thd.Changed_InPunch = r["Changed_InPunch"].ToString();
                thd.Changed_OutPunch = r["Changed_OutPunch"].ToString();
                if (r["AgencyNo"].ToString() != "")
                    thd.AgencyNo = Int32.Parse(r["AgencyNo"].ToString());
                else
                    thd.AgencyNo = null;
                thd.InSrc = r["InSrc"].ToString();
                thd.OutSrc = r["OutSrc"].ToString();
                thd.DaylightSavTime = r["DaylightSavTime"].ToString();
                thd.Holiday = r["Holiday"].ToString();
                if (r["RegHours"].ToString() != "")
                    thd.RegHours = Decimal.Parse(r["RegHours"].ToString());
                else
                    thd.RegHours = null;
                if (r["OT_Hours"].ToString() != "")
                    thd.OT_Hours = Decimal.Parse(r["OT_Hours"].ToString());
                else
                    thd.OT_Hours = null;
                if (r["DT_Hours"].ToString() != "")
                    thd.DT_Hours = Decimal.Parse(r["DT_Hours"].ToString());
                else
                    thd.DT_Hours = null;
                if (r["RegDollars"].ToString() != "")
                    thd.RegDollars = Decimal.Parse(r["RegDollars"].ToString());
                else
                    thd.RegDollars = null;
                if (r["OT_Dollars"].ToString() != "")
                    thd.OT_Dollars = Decimal.Parse(r["OT_Dollars"].ToString());
                else
                    thd.OT_Dollars = null;
                if (r["DT_Dollars"].ToString() != "")
                    thd.DT_Dollars = Decimal.Parse(r["DT_Dollars"].ToString());
                else
                    thd.DT_Dollars = null;
                if (r["RegBillingDollars"].ToString() != "")
                    thd.RegBillingDollars = Decimal.Parse(r["RegBillingDollars"].ToString());
                else
                    thd.RegBillingDollars = null;
                if (r["OTBillingDollars"].ToString() != "")
                    thd.OTBillingDollars = Decimal.Parse(r["OTBillingDollars"].ToString());
                else
                    thd.OTBillingDollars = null;
                if (r["DTBillingDollars"].ToString() != "")
                    thd.DTBillingDollars = Decimal.Parse(r["DTBillingDollars"].ToString());
                else
                    thd.DTBillingDollars = null;
                thd.CountAsOT = r["CountAsOT"].ToString();
                if (r["RegDollars4"].ToString() != "")
                    thd.RegDollars4 = Decimal.Parse(r["RegDollars4"].ToString());
                else
                    thd.RegDollars4 = null;
                if (r["OT_Dollars4"].ToString() != "")
                    thd.OT_Dollars4 = Decimal.Parse(r["OT_Dollars4"].ToString());
                else
                    thd.OT_Dollars4 = null;
                if (r["DT_Dollars4"].ToString() != "")
                    thd.DT_Dollars4 = Decimal.Parse(r["DT_Dollars4"].ToString());
                else
                    thd.DT_Dollars4 = null;
                if (r["RegBillingDollars4"].ToString() != "")
                    thd.RegBillingDollars4 = Decimal.Parse(r["RegBillingDollars4"].ToString());
                else
                    thd.RegBillingDollars4 = null;
                if (r["OTBillingDollars4"].ToString() != "")
                    thd.OTBillingDollars4 = Decimal.Parse(r["OTBillingDollars4"].ToString());
                else
                    thd.OTBillingDollars4 = null;
                if (r["DTBillingDollars4"].ToString() != "")
                    thd.DTBillingDollars4 = Decimal.Parse(r["DTBillingDollars4"].ToString());
                else
                    thd.DTBillingDollars4 = null;
                if (r["xAdjHours"].ToString() != "")
                    thd.xAdjHours = Decimal.Parse(r["xAdjHours"].ToString());
                else
                    thd.xAdjHours = null;
                thd.AprvlStatus = r["AprvlStatus"].ToString();
                if (r["AprvlStatus_UserID"].ToString() != "")
                    thd.AprvlStatus_UserID = Int32.Parse(r["AprvlStatus_UserID"].ToString());
                else
                    thd.AprvlStatus_UserID = null;
                if (r["AprvlStatus_Date"].ToString() != "")
                    thd.AprvlStatus_Date = DateTime.Parse(r["AprvlStatus_Date"].ToString());
                else
                    thd.AprvlStatus_Date = null;
                if (r["AprvlAdjOrigRecID"].ToString() != "")
                    thd.AprvlAdjOrigRecID = Int64.Parse(r["AprvlAdjOrigRecID"].ToString());
                else
                    thd.AprvlAdjOrigRecID = null;
                thd.HandledByImporter = r["HandledByImporter"].ToString();
                thd.AprvlAdjOrigClkAdjNo = r["AprvlAdjOrigClkAdjNo"].ToString();
                if (r["ClkTransNo"].ToString() != "")
                    thd.ClkTransNo = Int64.Parse(r["ClkTransNo"].ToString());
                else
                    thd.ClkTransNo = null;
                thd.ShiftDiffClass = r["ShiftDiffClass"].ToString();
                if (r["AllocatedRegHours"].ToString() != "")
                    thd.AllocatedRegHours = Decimal.Parse(r["AllocatedRegHours"].ToString());
                else
                    thd.AllocatedRegHours = null;
                if (r["AllocatedOT_Hours"].ToString() != "")
                    thd.AllocatedOT_Hours = Decimal.Parse(r["AllocatedOT_Hours"].ToString());
                else
                    thd.AllocatedOT_Hours = null;
                if (r["AllocatedDT_Hours"].ToString() != "")
                    thd.AllocatedDT_Hours = Decimal.Parse(r["AllocatedDT_Hours"].ToString());
                else
                    thd.AllocatedDT_Hours = null;
                thd.Borrowed = r["Borrowed"].ToString();
                thd.UserCode = r["UserCode"].ToString();
                if (r["DivisionID"].ToString() != "")
                    thd.DivisionID = Int64.Parse(r["DivisionID"].ToString());
                else
                    thd.DivisionID = null;
                thd.CostID = r["CostID"].ToString();
                if (r["ShiftDiffAmt"].ToString() != "")
                    thd.ShiftDiffAmt = Decimal.Parse(r["ShiftDiffAmt"].ToString());
                else
                    thd.ShiftDiffAmt = null;
                thd.OutUserCode = r["OutUserCode"].ToString();
                if (r["ActualInTime"].ToString() != "")
                    thd.ActualInTime = DateTime.Parse(r["ActualInTime"].ToString());
                else
                    thd.ActualInTime = null;
                if (r["ActualOutTime"].ToString() != "")
                    thd.ActualOutTime = DateTime.Parse(r["ActualOutTime"].ToString());
                else
                    thd.ActualOutTime = null;
                if (r["InSiteNo"].ToString() != "")
                    thd.InSiteNo = Int32.Parse(r["InSiteNo"].ToString());
                else
                    thd.InSiteNo = null;
                if (r["OutSiteNo"].ToString() != "")
                    thd.OutSiteNo = Int32.Parse(r["OutSiteNo"].ToString());
                else
                    thd.OutSiteNo = null;
                thd.InVerified = r["InVerified"].ToString();
                thd.OutVerified = r["OutVerified"].ToString();
                thd.InClass = r["InClass"].ToString();
                thd.OutClass = r["OutClass"].ToString();
                if (r["InTimestamp"].ToString() != "")
                    thd.InTimestamp = Int64.Parse(r["InTimestamp"].ToString());
                else
                    thd.InTimestamp = null;
                if (r["outTimestamp"].ToString() != "")
                    thd.outTimestamp = Int64.Parse(r["outTimestamp"].ToString());
                else
                    thd.outTimestamp = null;
                thd.CrossoverStatus = r["CrossoverStatus"].ToString();
                if (r["CrossoverOtherGroup"].ToString() != "")
                    thd.CrossoverOtherGroup = Int32.Parse(r["CrossoverOtherGroup"].ToString());
                else
                    thd.CrossoverOtherGroup = null;
                thd.InRoundOFF = r["InRoundOFF"].ToString();
                thd.OutRoundOFF = r["OutRoundOFF"].ToString();
                if (r["AprvlStatus_Mobile"].ToString() != "")
                    thd.AprvlStatus_Mobile = Boolean.Parse(r["AprvlStatus_Mobile"].ToString());
                else
                    thd.AprvlStatus_Mobile = null;

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

