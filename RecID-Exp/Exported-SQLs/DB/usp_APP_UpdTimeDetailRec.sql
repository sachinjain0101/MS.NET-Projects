CREATE             procedure [dbo].[usp_APP_UpdTimeDetailRec](
      	 @Client char(4),
      	 @GroupCode int,
      	 @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
         @SiteNo INT ,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 22Aug2016 >--
         @DeptNo INT ,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 22Aug2016 >--
         @InTime Char(5), 
         @OutTime Char(5),
         @Hours numeric(5,2),
      	 @ClockAdjCode char(3),
         @UserID int,
         @UserName varchar(20),
		 @CostID varchar(30)
)
AS

--*/

/*
DECLARE @CLient char(4)
DECLARE @GroupCode int
DECLARE @RecordID int
DECLARE @SiteNo smallint 
DECLARE @DeptNo tinyint 
DECLARE @InTime datetime 
DECLARE @OutTime datetime 
DECLARE @Hours numeric(5,2)
DECLARE @ClockAdjCode char(3)
DECLARE @UserID int
DECLARE @UserName varchar(20)

SELECT @CLient = 'SAMP'
SELECT @GroupCode = 999901
SELECT @RecordID = 72381193
SELECT @SiteNo = 1
SELECT @DeptNo = 2
SELECT @InTime = '00:00'
SELECT @OutTime = '00:00'
SELECT @ClockAdjCode = '8'
SELECT @UserID = 0
SELECT @UserName = ''
SELECT @Hours = -0.25

--/*
usp_APP_UpdTimeDetailRec 'SAMP',999901,72381193,1,2,'00:00','00:00','8',0,'' 

Select recordID, Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, --WeekEndDate,
SiteNo, DeptNo, JobID, 
TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
DaylightSavTime, Holiday, HandledByImporter, ClkTransNo 
From tblTimeHistDetail where
Client = 'SAMP'
and groupCode = 999901
and Payrollperiodenddate = '6/10/2001'
and SSN = 
Order By Payrollperiodenddate, Inday, Intime 

--*/

*/


--Set the default values.
DECLARE @dtInTime DateTime
DECLARE @dtOutTime DateTime
DECLARE @UserCode varchar(5)
--DECLARE @AdjustmentNo char(3)
DECLARE @AdjName varchar(20)
DECLARE @PrevAdjNo char(1)

SELECT @dtInTime = '12/30/1899 ' + @InTime
SELECT @dtOutTime = '12/30/1899 ' + @OutTime

if @Userid = 0
begin
	SELECT @UserCode = ''
end
else
begin
	SELECT @UserCode = (Select UserCode from timeCurrent..tblUser where UserID = @UserID)
end

if @ClockAdjCode <> ''
begin
--  Select @AdjustmentNo = (Select AdjustmentCode from TimeCurrent..tblAdjCodes where Client = @Client and GroupCode = @GroupCode and ClockAdjustmentNo = @ClockAdjCode)
  Select @AdjName = (Select AdjustmentName from TimeCurrent..tblAdjCodes where Client = @Client and GroupCode = @GroupCode and ClockAdjustmentNo = @ClockAdjCode)
end
else
Begin
--  Select @AdjustmentNo = ''
  Select @AdjName = ''
end


if @Client = 'HILT'
begin
	select @prevAdjNo = (SELECT clockAdjustmentNo FROM tblTimeHistDetail WHERE recordID = @RecordID)
	if @PrevAdjNo = '5' and @ClockAdjCode <> '5'
	-- changing from floating holiday to different adj
		UPDATE timeCurrent..tblEmplNames
		SET floatHolidayDate = NULL
		WHERE client = @Client
		AND groupCode = @GroupCode
		AND ssn IN (SELECT ssn FROM tblTimeHistDetail WHERE recordID = @RecordID)

	if @PrevAdjNo <> '5' and @ClockAdjCode = '5'
	-- changing from floating holiday to different adj
		UPDATE timeCurrent..tblEmplNames
		SET floatHolidayDate = (SELECT transDate FROM tblTimeHistDetail WHERE recordID = @RecordID)
		WHERE client = @Client
		AND groupCode = @GroupCode
		AND ssn IN (SELECT ssn FROM tblTimeHistDetail WHERE recordID = @RecordID)
end

update tblTimeHistDetail
Set SiteNo = @SiteNo,
    DeptNo = @DeptNo,
    InTime = @dtInTime,
    OutTime = @dtOutTime,
		OutDay = case when (@dtOutTime < @dtInTime) then case when (InDay = 7) then 1 else InDay + 1 end ELSE InDay END ,
    Hours = @Hours,
    ClockAdjustmentNo = @ClockAdjCode, 
--    AdjustmentCode = @AdjustmentNo,
    AdjustmentName = @AdjName,
    UserCode = @UserCode,
	CostID = @CostID
where RecordID = @RecordID













