using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace DataHub.Models {
    public class TimeHistDetail {
        public Int64? RecordID { get; set; }
        public string Client { get; set; }
        public Int32? GroupCode { get; set; }
        public Int32? SSN { get; set; }
        public DateTime? PayrollPeriodEndDate { get; set; }
        public DateTime? MasterPayrollDate { get; set; }
        public Int32? SiteNo { get; set; }
        public Int32? DeptNo { get; set; }
        public Int64? JobID { get; set; }
        public DateTime? TransDate { get; set; }
        public Int32? EmpStatus { get; set; }
        public Decimal? BillRate { get; set; }
        public Decimal? BillOTRate { get; set; }
        public Decimal? BillOTRateOverride { get; set; }
        public Decimal? PayRate { get; set; }
        public Int32? ShiftNo { get; set; }
        public Int32? InDay { get; set; }
        public DateTime? InTime { get; set; }
        public Int32? OutDay { get; set; }
        public DateTime? OutTime { get; set; }
        public Decimal? Hours { get; set; }
        public Decimal? Dollars { get; set; }
        public string ClockAdjustmentNo { get; set; }
        public string AdjustmentCode { get; set; }
        public string AdjustmentName { get; set; }
        public Int32? TransType { get; set; }
        public string Changed_DeptNo { get; set; }
        public string Changed_InPunch { get; set; }
        public string Changed_OutPunch { get; set; }
        public Int32? AgencyNo { get; set; }
        public string InSrc { get; set; }
        public string OutSrc { get; set; }
        public string DaylightSavTime { get; set; }
        public string Holiday { get; set; }
        public Decimal? RegHours { get; set; }
        public Decimal? OT_Hours { get; set; }
        public Decimal? DT_Hours { get; set; }
        public Decimal? RegDollars { get; set; }
        public Decimal? OT_Dollars { get; set; }
        public Decimal? DT_Dollars { get; set; }
        public Decimal? RegBillingDollars { get; set; }
        public Decimal? OTBillingDollars { get; set; }
        public Decimal? DTBillingDollars { get; set; }
        public string CountAsOT { get; set; }
        public Decimal? RegDollars4 { get; set; }
        public Decimal? OT_Dollars4 { get; set; }
        public Decimal? DT_Dollars4 { get; set; }
        public Decimal? RegBillingDollars4 { get; set; }
        public Decimal? OTBillingDollars4 { get; set; }
        public Decimal? DTBillingDollars4 { get; set; }
        public Decimal? xAdjHours { get; set; }
        public string AprvlStatus { get; set; }
        public Int32? AprvlStatus_UserID { get; set; }
        public DateTime? AprvlStatus_Date { get; set; }
        public Int64? AprvlAdjOrigRecID { get; set; }
        public string HandledByImporter { get; set; }
        public string AprvlAdjOrigClkAdjNo { get; set; }
        public Int64? ClkTransNo { get; set; }
        public string ShiftDiffClass { get; set; }
        public Decimal? AllocatedRegHours { get; set; }
        public Decimal? AllocatedOT_Hours { get; set; }
        public Decimal? AllocatedDT_Hours { get; set; }
        public string Borrowed { get; set; }
        public string UserCode { get; set; }
        public Int64? DivisionID { get; set; }
        public string CostID { get; set; }
        public Decimal? ShiftDiffAmt { get; set; }
        public string OutUserCode { get; set; }
        public DateTime? ActualInTime { get; set; }
        public DateTime? ActualOutTime { get; set; }
        public Int32? InSiteNo { get; set; }
        public Int32? OutSiteNo { get; set; }
        public string InVerified { get; set; }
        public string OutVerified { get; set; }
        public string InClass { get; set; }
        public string OutClass { get; set; }
        public Int64? InTimestamp { get; set; }
        public Int64? outTimestamp { get; set; }
        public string CrossoverStatus { get; set; }
        public Int32? CrossoverOtherGroup { get; set; }
        public string InRoundOFF { get; set; }
        public string OutRoundOFF { get; set; }
        public Boolean? AprvlStatus_Mobile { get; set; }
    }

}
