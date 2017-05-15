Create PROCEDURE [dbo].[usp_TravelTime_GetSplitTravelRecs] 
(
  @PPED Datetime,
  @Client varchar(4),
  @GroupCode int,
  @DeptNo int
)
AS

SET NOCOUNT ON

/*
select * from TimeHistory..tblTimeHistDetail where RecordID in(263755330,
264101903,
263927633,
263899892)

Select * from tblPeriodenddates where client = 'DAVI' and groupcode in(300700,910000)
and payrollperiodenddate = '3/4/06'


263755330	8.57
264101903	11.95
263927633	9.52
263899892	9.12

300700 - SSN 210483701,423685767
910000 - SSN 245135123,435678801


DECLARE @PPED Datetime
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @DeptNo int

SET @PPED = '3/04/06'
SET @Client = 'DAVI'
SET @GroupCode = 910000
SET @DeptNo = 88


Select RecordID, Hours from TimeHistory..tblTimeHistDetail
where client = @Client
and groupcode = @GroupCode
--and groupcode in (300100,300200,300300,300400,300500,300600,300700,300800,300900,301000,301100,301200,301300,301400,301600,302600,302900,910000)
and Payrollperiodenddate = @PPED
and deptno = @deptno
and InSrc = '8'
and OutSrc = '8'
and Intime = '1899-12-30 00:01:00.000'

return
*/

Create Table #tmpSSN
(
SSN int
)

DECLARE cTravel CURSOR
READ_ONLY
FOR 
Select RecordID, Hours, SSN from TimeHistory..tblTimeHistDetail
where client = @Client
and groupcode = @GroupCode
--and groupcode in (300100,300200,300300,300400,300500,300600,300700,300800,300900,301000,301100,301200,301300,301400,301600,302600,302900,910000)
and Payrollperiodenddate = @PPED
and deptno = @deptno
and InSrc = '8'
and OutSrc = '8'
and Intime = '1899-12-30 00:01:00.000'
and Hours > 0.00

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--
DECLARE @OldHours numeric(5,2) 
DECLARE @SSN int

OPEN cTravel

FETCH NEXT FROM cTravel INTO @RecordID, @OldHours, @SSN
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
    Select Client, GroupCode, PayrollPeriodendDate, SSN, getdate(), 
    'Transaction voided by Travel Time program. Date: ' + convert(varchar(12), TransDate, 101) + 
    ' InTime: ' + convert(varchar(5), InTime, 108) + 
    ' Orig Hours: ' + ltrim(str(Hours,6,2)),
    1785, 'TravelTime', '0'
    from TimeHistory..tblTimeHistDetail where RecordID = @RecordID
    
    update TimeHistory..tblTimeHistDetail 
      Set Hours = 0.00
    where RecordID = @RecordID
    
    INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch]([OrigRecordID], 
    [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], 
    [OldSiteNo], [OldDeptNo], [OldJobID], [OldTransDate], [OldEmpStatus], 
    [OldBillRate], [OldBillOTRate], [OldBillOTRateOverride], [OldPayRate], 
    [OldShiftNo], [OldInDay], [OldInTime], [OldInSrc],  [OldDollars], 
    [OldClockAdjustmentNo], [OldAdjustmentCode], [OldAdjustmentName], 
    [OldTransType], [OldAgencyNo], [OldDaylightSavTime], [OldHoliday], 
    [NewSiteNo], [NewDeptNo], [NewJobID], [NewTransDate], [NewEmpStatus], 
    [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], [NewPayRate], 
    [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], [NewOutDay], [NewOutTime], 
    [NewOutSrc], [NewHours], [NewDollars], [NewClockAdjustmentNo], 
    [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], [NewAgencyNo], 
    [NewDaylightSavTime], [NewHoliday], 
    [OldOutDay], [OldOutTime], [OldOutSrc], [OldHours],
    [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr])
    Select 
    RecordID, Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, 
    SiteNo, DeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride,
    PayRate, ShiftNo, InDay, InTime, InSrc, Dollars, ClockAdjustmentNo, AdjustmentCode,
    AdjustmentName, TransType, AgencyNo, DaylightSavTime, Holiday, 
    SiteNo, DeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride,
    PayRate, ShiftNo, InDay, InTime, InSrc, OutDay, OutTime, OutSrc, Hours,
    Dollars, ClockAdjustmentNo, AdjustmentCode,
    AdjustmentName, TransType, AgencyNo, DaylightSavTime, Holiday,
    OutDay, OutTime, OutSrc, @OldHours, 'TravelTime', 0, getdate(), null, 'traveltime'
    from [Timehistory].[dbo].[tblTimehistDetail] where RecordID = @RecordID 
 
    Insert into #tmpSSN (SSN) Values (@SSN)
   
	END
	FETCH NEXT FROM cTravel INTO @RecordID, @OldHours, @SSN
END

CLOSE cTravel
DEALLOCATE cTravel

select Distinct SSN from #tmpSSN

drop table #tmpSSN



