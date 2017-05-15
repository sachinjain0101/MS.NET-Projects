CREATE                   procedure [dbo].[usp_CigTrans_UpdatePunchDetail3](
     @Client char(4)
   , @GroupCode int
   , @SiteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 23Aug2016 >--
   , @SSN int
   , @DeptNo INT  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 23Aug2016 >--
   , @PayrollPeriodEndDate datetime
   , @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 04Oct2016 >--
   , @InTransDateTime datetime
   , @OutTransDateTime datetime
   , @PunchLogicalTransDate as datetime
   , @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 04Oct2016 >--
   , @DaylightSavTime char(1)
   , @lShiftClass int
   , @PunchActualInTime datetime
   , @PunchInSrc char(1)
   , @PunchActualOutTime datetime
   , @PunchOutSrc char(1)
   , @THDRecordId BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
   , @PunchInUserCode varchar(5)
   , @PunchOutUserCode varchar(5)
   , @InSiteNo int = 0
   , @OutSiteNo int = 0 
   , @PunchInVerified char(1)
   , @PunchOutVerified char(1)
   , @FixPunchStatus char(1)
   , @ShiftNo int
   , @TransType tinyint
   , @InClass char(1)
   , @OutClass char(1)
  , @InTimeStamp varchar(20)
  , @OutTimeStamp varchar(20)

)
AS

--*/

/*
declare @Client char(4)
declare @GroupCode int 
declare @SiteNo smallint 
declare @SSN int 
declare @DeptNo smallint 
declare @PayrollPeriodEndDate datetime 
declare @JobID int 
declare @InTransDateTime datetime 
declare @OutTransDateTime datetime 
declare @PunchLogicalTransDate as datetime
declare @ClkTransNo int 
declare @DaylightSavTime char(1)
declare @lShiftClass int
declare @PunchActualInTime datetime
declare @PunchInSrc char(1)
declare @PunchActualOutTime datetime
declare @PunchOutSrc char(1)
declare @THDRecordId int
declare @PunchInUserCode varchar(5)
declare @PunchOutUserCode varchar(5)
declare @InSiteNo int 
declare @OutSiteNo int 

select @Client 			= 'GAMB'
select @GroupCode 		= 720200
select @SiteNo 			= 103
select @SSN  			= 540829437
select @DeptNo 			= 57
select @PayrollPeriodEndDate	= '01/15/2005'
select @JobID 			= 0
select @InTransDateTime		= '1/11/2005 7:00:00 AM'
select @OutTransDateTime 	= '1/11/2005 12:00:00 PM'
select @PunchLogicalTransDate	= '01/11/2005'
select @ClkTransNo		= 77733
select @DaylightSavTime		= '1'
select @lShiftClass		= 1
select @PunchActualInTime	= '1/11/2005 7:01:00 AM'
select @PunchInSrc		= '0'
select @PunchActualOutTime	= '1/11/2005 11:56:00 AM'
select @PunchOutSrc		= '3'
select @THDRecordId		= 92542731
select @PunchInUserCode		= ''
select @PunchOutUserCode	= ''
select @InSiteNo		= 57
select @OutSiteNo		= 57
*/

SET NOCOUNT ON

DECLARE @InDay tinyint 
DECLARE @InTime datetime 
DECLARE @tmpOutTime datetime 
DECLARE @InSrc char(1) 
DECLARE @tmpHours numeric(6,2)
DECLARE @tmpMinutes int
DECLARE @ActualInTime datetime
DECLARE @DSTAdjustedHours numeric(6,2)
DECLARE @OutDay tinyint 
DECLARE @OutTime datetime 
DECLARE @tmpInTime datetime 
DECLARE @OutSrc char(1) 
DECLARE @ActualOutTime datetime
DECLARE @InUserCode varchar(5)
DECLARE @OutUserCode varchar(5)
DECLARE @PayType int

SET @PayType = (select isnull(paytype,0) as paytype from timecurrent..tblemplnames WITH(NOLOCK) where client = @client and groupcode = @groupcode and ssn = @ssn and recordstatus = '1')

if @InTransDateTime = '1/1/1900'
begin
  if @PayType = 1 --salaried
  begin
  	SET @InDay = 11
  end
  else
  begin
    SET @InDay = 10
  end
	SELECT @InTime = '12/30/1899 00:00:00'
  SELECT @InSrc = '9' 
  SELECT @ActualInTime = NULL  
  select @InUserCode = ''
end
else
begin
  SELECT @InDay = datepart(weekday, @InTransDateTime) 
  SELECT @InTime = '12/30/1899 ' + cast(datepart(hh,@InTransDateTime) as char(2)) + ':' + cast(datepart(mi, @InTransDateTime) as char(2))
  
  if @PunchInSrc is null
    SELECT @InSrc = '0' --'V'
  else
    SELECT @InSrc = @PunchInSrc
  
  if @InSrc = '3' -- web
  begin
    select @ActualInTime = @PunchActualInTime --select @ActualInTime = null -- simulate the way web does it
    select @InUserCode = @PunchInUserCode
  end
  else 
  begin
    select @ActualInTime = @PunchActualInTime
    select @InUserCode = ''
  end
end


if @OutTransDateTime = '1/1/1900'
begin
  if @PayType = 1 --salaried
  begin
  	SET @OutDay = 11
  end
  else
  begin
    SET @OutDay = 10
  end
	SELECT @OutTime = '12/30/1899 00:00:00'

  SELECT @OutSrc = '9' 
  SELECT @ActualOutTime = NULL  
  select @OutUserCode = ''
end
else
begin
  SELECT @OutDay = datepart(weekday, @OutTransDateTime) 
  SELECT @OutTime = '12/30/1899 ' + cast(datepart(hh,@OutTransDateTime) as char(2)) + ':' + cast(datepart(mi, @OutTransDateTime) as char(2))
  
  if @PunchOutSrc is null
    SELECT @OutSrc = '0' --'V'
  else
    SELECT @OutSrc = @PunchOutSrc
  
  if @OutSrc = '3' -- web
  begin
    select @ActualOutTime = @PunchActualOutTime --select @ActualOutTime = null -- simulate the way web does it
    select @OutUserCode = @PunchOutUserCode
  end
  else 
  begin
    select @ActualOutTime = @PunchActualOutTime
    select @OutUserCode = ''
  end
end

--SELECT @tmpOutTime = ( select dbo.PunchDateTime( TransDate, OutDay, OutTime ) 
--                       from timehistory..tbltimehistdetail 
--                       where recordid = @THDRecordId )

--SELECT @tmpMinutes = datediff(minute, @TransDate, @tmpOutTime)
--SELECT @tmpHours = @tmpMinutes / 60.00
--exec usp_APP_GetDSTAdjustedHours @Client, @GroupCode, @SiteNo, @TransDate, @tmpOutTime, NULL, NULL, @DSTAdjustedHours OUTPUT

if @InTransDateTime <> '1/1/1900' and @OutTransDateTime <> '1/1/1900'
begin
  exec usp_APP_GetDSTAdjustedHours2 @Client, @GroupCode, @SiteNo, @InTransDateTime, @OutTransDateTime, NULL, NULL, @DaylightSavTime, @DSTAdjustedHours OUTPUT
end
else
begin
  select @DSTAdjustedHours = 0.00
end

if @Client = 'SPRI'
BEGIN
  IF @Insrc = '0'
  BEGIN
    Set @InSrc = '3'
    Set @InUserCode = 'Emp'
  END
  If @OutSrc = '0'
  BEGIN
    Set @OutSrc = '3'
    Set @OutUserCode = 'Emp'
  END
END

/*
    FixPunchStatus values:
    eNotAFixedPunch = 0
    eFixedInPunch = 1
    eFixedOutPunch = 2
*/

DECLARE @FixPunchGensBreak char(1)
SELECT @FixPunchGensBreak = (SELECT FixPunchGensBreak 
                            FROM timecurrent..tblclientgroups  WITH(NOLOCK)
                            WHERE client = @Client
                              and groupcode = @GroupCode )

Update tblTimeHistDetail 
Set InDay = @InDay 
  , InTime = @InTime
  , InSrc = @InSrc
  , OutDay = @OutDay
  , OutTime = @OutTime
  , OutSrc = @OutSrc
  , Hours = @DSTAdjustedHours --@tmpHours,
  , ShiftNo = (CASE WHEN @FixPunchStatus IN ('1','2') and @FixPunchGensBreak = '0' THEN @ShiftNo ELSE 0 END)
  , ActualInTime = @ActualInTime
  , ActualOutTime = @ActualOutTime
  , PayrollPeriodEndDate = @PayrollPeriodEndDate
  , TransDate = @PunchLogicalTransDate
  , DaylightSavTime = @DaylightSavTime
  , UserCode = @InUserCode --InUserCode
  , OutUserCode = @OutUserCode
  , InSiteNo = (CASE WHEN @InSiteNo = 0 THEN InSiteNo ELSE @InSiteNo END)
  , OutSiteNo = (CASE WHEN @OutSiteNo = 0 THEN OutSiteNo ELSE @OutSiteNo END)
  , InVerified = @PunchInVerified
  , OutVerified = @PunchOutVerified
  , Changed_InPunch = (CASE WHEN @FixPunchStatus = '1' THEN '1' ELSE NULL END)
  , Changed_OutPunch = (CASE WHEN @FixPunchStatus = '2' THEN '1' ELSE NULL END)
  , TransType = @TransType
  , InClass = @InClass
  , OutClass = @OutClass
  , InTimeStamp = @InTimeStamp
  , OutTimeStamp = @OutTimeStamp
Where RecordID = @THDRecordId


--Commented out by Dale H. This is now handled by EmplCalc
--exec usp_APP_ResetMissingPunchFlag @Client, @GroupCode, @SSN, @PayrollPeriodEndDate













