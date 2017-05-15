CREATE procedure [dbo].[usp_Web1_UpdateEmployeeOT] 
(
  @RecordId BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
  @AllocatedOT_Hours numeric(5,2), -- Daily
  @OT_Hours numeric(5,2) -- Weekly + Daily
)
AS



UPDATE TimeHistory..tblTimeHistDetail
SET RegHours = Hours - @AllocatedOT_Hours - @OT_Hours - DT_Hours, 
    OT_Hours = @OT_Hours + @AllocatedOT_Hours,
    AllocatedOT_Hours = @AllocatedOT_Hours
WHERE RecordId = @RecordId

UPDATE TimeHistory..tblTimeHistDetail
SET RegDollars = ROUND(PayRate * RegHours,2),
    RegDollars4 = ROUND(PayRate * RegHours,4),
    OT_Dollars = Round(OT_Hours * (PayRate * 1.5), 2),
    OT_Dollars4 = Round(OT_Hours * (PayRate * 1.5), 4),
    RegBillingDollars = ROUND(BillRate * RegHours,2),
    RegBillingDollars4 = ROUND(BillRate * RegHours,4),
    OTBillingDollars = Round(OT_Hours * TimeHistory.dbo.fn_GetEmplRate(Client,GroupCode,SSN,SiteNo,DeptNo,PayrollPeriodEndDate,'Bill','OT'), 2),
    OTBillingDollars4 = Round(OT_Hours * TimeHistory.dbo.fn_GetEmplRate(Client,GroupCode,SSN,SiteNo,DeptNo,PayrollPeriodEndDate,'Bill','OT'), 4)
WHERE RecordId = @RecordId
