Create PROCEDURE [dbo].[usp_TRAVELTIME_UpdateTravelDeptDetail] ( @RecordID BIGINT )  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--
AS

/*
DECLARE @RecordID int
SELECT @RecordID = 64178464
*/

DECLARE @OldOutDay tinyint
DECLARE @OldOutTime datetime
DECLARE @OldOutSrc char(1)
DECLARE @OldHours numeric(5,2) 
DECLARE @InDay tinyint
DECLARE @InTime datetime


--DECLARE curTHDRec CURSOR FOR
select @InDay = InDay, @InTime = InTime, @OldOutDay = OutDay, @OldOutTime = OutTime, @OldHours = Hours, @OldOutSrc = OutSrc from tblTimeHistDetail where RecordID = @RecordID
--OPEN curTHDRec
--Fetch Next From curTHDRec Into @Inday, @InTime, @OldOutDay, @OldOutTime, @OldHours, @OldOutSrc 
--CLOSE curTHDRec
--DEALLOCATE curTHDRec

update tblTimeHistDetail Set OutDay = @InDay,
  OutTime = @InTime,
  Hours = 0.00,
  OutSrc = 3,
  UserCode = 'TvT'
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
@OldOutDay, @OldOutTime, @OldOutSrc, @OldHours, 'TravelTime', 0, getdate(), null, 'traveltime'
from [Timehistory].[dbo].[tblTimehistDetail] where RecordID = @RecordID 






