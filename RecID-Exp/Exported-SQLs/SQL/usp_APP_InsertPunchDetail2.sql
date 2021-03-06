USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_InsertPunchDetail2]    Script Date: 3/31/2015 11:53:37 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_InsertPunchDetail2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_InsertPunchDetail2] AS' 
END
GO

/*
EXEC TimeHistory..usp_APP_InsertPunchDetail2 'GAMB',104000,14,410210506,35,'11/06/2004',0,'11/04/2004 08:01:00','01/01/1900 00:00:00','11/04/2004',1291,'1',1,'11/04/2004 08:01:26','0','','01/01/1900 00:00:0',NULL,'',14,0
    This stored procedure is used to add a record to the tblTimeHistdetail table.
EXEC sp_changeobjectowner 'usp_APP_InsertPunchDetail', 'dbo'
*/


--/*
ALTER    procedure [dbo].[usp_APP_InsertPunchDetail2]
(
  @Client char(4),
  @GroupCode int ,
  @SiteNo INT ,  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 16Aug2016 >--
  @SSN int ,
  @DeptNo INT ,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 16Aug2016 >--
  @PayrollPeriodEndDate datetime ,
  @JobID BIGINT,  --< @JOBID data type is changed from  INT to BIGINT by Srinsoft on 28Sept2016 >--
  @InTransDateTime datetime ,
  @OutTransDateTime datetime ,
  @PunchLogicalTransDate as datetime,
  @ClkTransNo BIGINT ,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 28Sept2016 >--
  @DaylightSavTime char(1),
  @lShiftClass int,
  @PunchActualInTime datetime,
  @PunchInSrc char(1),
  @PunchInUserCode varchar(5),
  @PunchActualOutTime datetime,
  @PunchOutSrc char(1),
  @PunchOutUserCode varchar(5),
  @InSiteNo int,
  @OutSiteNo int
)
AS
--*/


/*

declare @Client char(4)
declare @GroupCode int
declare @SSN int
declare @PayrollPeriodEndDate datetime
declare @SiteNo smallint
declare @DeptNo smallint
declare @JobID int
--declare @TransDate datetime
declare @InTransDateTime datetime ,
declare @OutTransDateTime datetime ,

declare @ClkTransNo int
declare @lShiftClass int
declare @ActualInTime datetime
declare @ActualOutTime datetime

select @Client = 
select @GroupCode =
select @SSN =
select @PayrollPeriodEndDate =
select @SiteNo =
select @DeptNo =
select @JobID =
--select @TransDate =
select @InTransDateTime =
select @OutTransDateTime =

select @ClkTransNo =
select @lShiftClass =
select @ActualInTime =
select @ActualOutTime =
*/

SET NOCOUNT ON

--Set the default values.
DECLARE @InDay tinyint 
DECLARE @InTime datetime 
DECLARE @OutDay tinyint 
DECLARE @OutTime datetime 
DECLARE @Hours numeric(5,2) 
DECLARE @Dollars numeric(7,2) 
DECLARE @InSrc char(1) 
DECLARE @OutSrc char(1) 
DECLARE @EmpStatus tinyint 
DECLARE @BillRate numeric(7,2) 
DECLARE @PayRate numeric(7,2) 
DECLARE @BillOTRate numeric(7,2) 
DECLARE @BillOTRateOverride numeric(7,2) 
DECLARE @TransType tinyint 
DECLARE @ShiftNo tinyint 
DECLARE @HandledByImporter char(1) 
--DECLARE @DaylightSavTime char(1) 
DECLARE @Holiday char(1) 
DECLARE @AgencyNo smallint 
DECLARE @MasterPayrollDate datetime
DECLARE @ClockAdjustmentNo varchar(3)   --< Srinsoft 08/20/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) for clockadjustment >--
DECLARE @AdjustmentCode varchar(3)   --< Srinsoft 09/22/2015 Changed @AdjustmentCode char(1) to varchar	(3) for AdjustmentCode >--
DECLARE @AdjustmentName char(16)
DECLARE @MPCount int
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 26Oct2016 >--
--DECLARE @EmplClassID varchar(10)
DECLARE @CalcLevel char(1)
DECLARE @ActualInTime datetime
DECLARE @ActualOutTime datetime
DECLARE @DSTAdjustedHours numeric(6,2)
DECLARE @THDRecordID BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--

SET @ClockAdjustmentNo = ''
SET @AdjustmentCode = '' 
SET @AdjustmentName = ''
SET @BillOTRate = 0.00
SET @BillOTRateOverride = 0.00
SET @BillRate = 0.00            -- EmplCalc will Set this correctly on re-calc
SET @PayRate = 0.00             -- EmplCalc will Set this correctly on re-calc

if @InTransDateTime = '1/1/1900'
begin
	SET @InDay = 10 
	SET @InTime = '12/30/1899 00:00:00'
  SET @InSrc = '9' 
  SET @ActualInTime = NULL
end
else
begin
	SET @InDay = datepart(weekday, @InTransDateTime)
	SET @InTime = '12/30/1899 ' + cast(datepart(hh,@InTransDateTime) as char(2)) + ':' + cast(datepart(mi, @InTransDateTime) as char(2))

  if @PunchInSrc is null
    SET @InSrc = '0' --'V'
  else
    SET @InSrc = @PunchInSrc
  
  if @InSrc = '3'
    SET @ActualInTime = @PunchActualInTime --SET @ActualInTime = null -- simulate the way web does it
  else 
    SET @ActualInTime = @PunchActualInTime
end

if @OutTransDateTime = '1/1/1900'
begin
	SET @OutDay = 10
	SET @OutTime = '12/30/1899 00:00:00'
  SET @OutSrc = '9' 
  SET @ActualOutTime = NULL
end
else
begin
	SET @OutDay = datepart(weekday, @OutTransDateTime)
	SET @OutTime = '12/30/1899 ' + cast(datepart(hh,@OutTransDateTime) as char(2)) + ':' + cast(datepart(mi, @OutTransDateTime) as char(2))

  if @PunchOutSrc is null
    SET @OutSrc = '0' --'V'
  else
    SET @OutSrc = @PunchOutSrc
  
  if @OutSrc = '3' -- web
    SET @ActualOutTime = @PunchActualOutTime --SET @ActualOutTime = null -- simulate the way web does it
  else 
    SET @ActualOutTime = @PunchActualOutTime
end

SET @Hours = 0.00
SET @Dollars = 0.00
SET @TransType = 0
SET @ShiftNo = 0
SET @HandledByImporter = 'V'
SET @Holiday = '0'          --EmplCalc will Set this Correctly on re-calc based on tblOvertimeDays
SET @MasterPayrollDate = '1/1/1900' -- emplcalc will set this correctly
SET @MPCount = 0

SELECT @EmpStatus=en.Status, @AgencyNo=en.AgencyNo, @DivisionID=en.DivisionID 
From timeCurrent..tblEmplNames as en
where en.Client = @Client
      and en.GroupCode = @GroupCode
      and en.SSN = @SSN
      and en.RecordStatus = 1

if @InTransDateTime <> '1/1/1900' and @OutTransDateTime <> '1/1/1900'
begin
	EXEC TimeHistory..usp_APP_GetDSTAdjustedHours2 @Client, @GroupCode, @SiteNo, @InTransDateTime, @OutTransDateTime, NULL, NULL, @DaylightSavTime, @DSTAdjustedHours OUTPUT
	SET @Hours = @DSTAdjustedHours
end
else
begin
	SET @Hours = 0.00
end


if @Client = 'SPRI'
BEGIN
  IF @Insrc = '0'
  BEGIN
    Set @InSrc = '3'
    Set @PunchInUserCode = 'Emp'
  END
  If @OutSrc = '0'
  BEGIN
    Set @OutSrc = '3'
    Set @PunchOutUserCode = 'Emp'
  END
END


Insert into TimeHistory..tblTimeHistDetail
(Client, GroupCode, SSN 
, PayrollPeriodEndDate, MasterPayrollDate, SiteNo 
, DeptNo, JobID, TransDate
, EmpStatus, BillRate, BillOTRate
, BillOTRateOverride, PayRate, ShiftNo
, InDay, InTime, OutDay
, OutTime, Hours, Dollars
, TransType, AgencyNo, InSrc
, OutSrc, ClockAdjustmentNo, AdjustmentCode
, AdjustmentName, DaylightSavTime, Holiday
, HandledByImporter, ClkTransNo, DivisionID
, ActualInTime, ActualOutTime
, UserCode, OutUserCode, InSiteNo, OutSiteNo )
Values
(@Client, @GroupCode, @SSN
, convert(char(10), @PayrollPeriodEndDate,101), convert(char(10),@MasterPayrollDate,101), @SiteNo
, @DeptNo, 0, @PunchLogicalTransDate
, @EmpStatus, @BillRate, @BillOTRate
, @BillOTRateOverride, @PayRate, @ShiftNo
, @InDay, @InTime, @OutDay
, @OutTime, @Hours, @Dollars
, @TransType, @AgencyNo, @InSrc
, @OutSrc, @ClockAdjustmentNo, @AdjustmentCode
, @AdjustmentName, @DaylightSavTime, @Holiday
, @HandledByImporter, @ClkTransNo, @DivisionID
, @ActualInTime, @ActualOutTime 
, @PunchInUserCode, @PunchOutUserCode
, (CASE WHEN @InSiteNo > 0 THEN @InSiteNo ELSE NULL END)
, (CASE WHEN @OutSiteNo > 0 THEN @OutSiteNo ELSE NULL END) )

SET @THDRecordID = SCOPE_IDENTITY()

  -- Reset the Missing Punch Flag.      
  -- The employee will always have at least a missing out punch, beacuse we just added
  -- an in punch without an out punch.
  -- so to determine if there is truely a missing punch the missing punch count must be
  -- greater than 1
  --
  -- Set the CalcLevel to Either Client or Group level.
  -- The calc level determines if we should look at all of the punches across groups
  -- or restrict the view to only the group level.
  --

Select @MPCount = (Select Sum(1) from TimeHistory..tblTimeHistDetail 
                      where Client = @Client 
                        and Groupcode = @GroupCode
                        and SSN = @SSN
												and transdate between dateadd(d, -6, @PayrollPeriodEndDate) and @PayrollPeriodEndDate
                        and payrollperiodenddate = @PayrollPeriodEndDate
                        and (Inday = 10 or OutDay = 10) )

if @MPCount is NULL
  Select @MPCount = 0

  if @MPCount > 1
  BEGIN
    update TimeHistory..tblEmplNames 
        Set MissingPunch = '1'
    where Client = @Client 
      and Groupcode = @GroupCode
      and SSN = @SSN 
      and payrollperiodenddate = @PayrollPeriodEndDate
  END
  ELSE
  BEGIN
		if @Client = 'SPRI'
			-- for SPRINT, no ee's should be in in yellow
	    update TimeHistory..tblEmplNames Set MissingPunch = '1'
                      where Client = @Client 
                        and Groupcode = @groupcode
                        and SSN = @SSN 
                        and payrollperiodenddate = @PayrollPeriodEndDate

		else
	    update TimeHistory..tblEmplNames Set MissingPunch = '2'
	                        where Client = @Client 
	                          and Groupcode = @GroupCode
	                          and SSN = @SSN 
	                          and payrollperiodenddate = @PayrollPeriodEndDate
  END

select RecordID = @THDRecordID






GO
