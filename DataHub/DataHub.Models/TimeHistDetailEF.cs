using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.Models {
    public class TimeHistDetailEF {
        public long RecordID { get; set; }
        public string Client { get; set; }
        public int GroupCode { get; set; }
        public int SSN { get; set; }
        public DateTime PayrollPeriodEndDate { get; set; }
        public DateTime MasterPayrollDate { get; set; }
        public int SiteNo { get; set; }
        public int DeptNo { get; set; }
        public long JobID { get; set; }
        public Nullable<System.DateTime> TransDate { get; set; }
        public Nullable<byte> EmpStatus { get; set; }
        public Nullable<decimal> BillRate { get; set; }
        public Nullable<decimal> BillOTRate { get; set; }
        public Nullable<decimal> BillOTRateOverride { get; set; }
        public Nullable<decimal> PayRate { get; set; }
        public Nullable<byte> ShiftNo { get; set; }
        public Nullable<byte> InDay { get; set; }
        public Nullable<System.DateTime> InTime { get; set; }
        public Nullable<byte> OutDay { get; set; }
        public Nullable<System.DateTime> OutTime { get; set; }
        public Nullable<decimal> Hours { get; set; }
        public Nullable<decimal> Dollars { get; set; }
        public string ClockAdjustmentNo { get; set; }
        public string AdjustmentCode { get; set; }
        public string AdjustmentName { get; set; }
        public Nullable<byte> TransType { get; set; }
        public string Changed_DeptNo { get; set; }
        public string Changed_InPunch { get; set; }
        public string Changed_OutPunch { get; set; }
        public Nullable<short> AgencyNo { get; set; }
        public string InSrc { get; set; }
        public string OutSrc { get; set; }
        public string DaylightSavTime { get; set; }
        public string Holiday { get; set; }
        public Nullable<decimal> RegHours { get; set; }
        public Nullable<decimal> OT_Hours { get; set; }
        public Nullable<decimal> DT_Hours { get; set; }
        public Nullable<decimal> RegDollars { get; set; }
        public Nullable<decimal> OT_Dollars { get; set; }
        public Nullable<decimal> DT_Dollars { get; set; }
        public Nullable<decimal> RegBillingDollars { get; set; }
        public Nullable<decimal> OTBillingDollars { get; set; }
        public Nullable<decimal> DTBillingDollars { get; set; }
        public string CountAsOT { get; set; }
        public Nullable<decimal> RegDollars4 { get; set; }
        public Nullable<decimal> OT_Dollars4 { get; set; }
        public Nullable<decimal> DT_Dollars4 { get; set; }
        public Nullable<decimal> RegBillingDollars4 { get; set; }
        public Nullable<decimal> OTBillingDollars4 { get; set; }
        public Nullable<decimal> DTBillingDollars4 { get; set; }
        public Nullable<decimal> xAdjHours { get; set; }
        public string AprvlStatus { get; set; }
        public Nullable<int> AprvlStatus_UserID { get; set; }
        public Nullable<System.DateTime> AprvlStatus_Date { get; set; }
        public Nullable<long> AprvlAdjOrigRecID { get; set; }
        public string HandledByImporter { get; set; }
        public string AprvlAdjOrigClkAdjNo { get; set; }
        public Nullable<long> ClkTransNo { get; set; }
        public string ShiftDiffClass { get; set; }
        public Nullable<decimal> AllocatedRegHours { get; set; }
        public Nullable<decimal> AllocatedOT_Hours { get; set; }
        public Nullable<decimal> AllocatedDT_Hours { get; set; }
        public string Borrowed { get; set; }
        public string UserCode { get; set; }
        public Nullable<long> DivisionID { get; set; }
        public string CostID { get; set; }
        public Nullable<decimal> ShiftDiffAmt { get; set; }
        public string OutUserCode { get; set; }
        public Nullable<System.DateTime> ActualInTime { get; set; }
        public Nullable<System.DateTime> ActualOutTime { get; set; }
        public Nullable<int> InSiteNo { get; set; }
        public Nullable<int> OutSiteNo { get; set; }
        public string InVerified { get; set; }
        public string OutVerified { get; set; }
        public string InClass { get; set; }
        public string OutClass { get; set; }
        public Nullable<long> InTimestamp { get; set; }
        public Nullable<long> outTimestamp { get; set; }
        public string CrossoverStatus { get; set; }
        public Nullable<int> CrossoverOtherGroup { get; set; }
        public string InRoundOFF { get; set; }
        public string OutRoundOFF { get; set; }
        public Nullable<bool> AprvlStatus_Mobile { get; set; }

    }

}
