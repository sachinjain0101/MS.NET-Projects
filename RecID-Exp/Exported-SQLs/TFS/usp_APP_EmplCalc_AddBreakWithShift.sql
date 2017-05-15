Create PROCEDURE [dbo].[usp_APP_EmplCalc_AddBreakWithShift]
(
  @Client varchar(4), 
  @GroupCode int,
  @SSN int,
  @PPED datetime, 
  @MasterPayrolldate datetime,
  @BreakHours numeric(5,2),
  @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
  @ShiftNo int
)
AS

SET NOCOUNT ON

DECLARE @dupBreakID BIGINT  --< @dupRecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
DECLARE @Scheduled int
DECLARE @InDay2 int
DECLARE @ClockAdjustmentNo varchar(3)  --< Srinsoft 08/11/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
DECLARE @InSrc char(1)
DECLARE @SiteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
DECLARE @DeptNo INT  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
DECLARE @TransDate datetime
DECLARE @InDay tinyint
--DECLARE @ShiftNo tinyint
DECLARE @EmpStatus tinyint
DECLARE @AgencyNo smallint
DECLARE @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 26Sept2016 >--

SET @ClockAdjustmentNo = '8'
SET @InSrc = '3'

-- Get the scheduled flag and ShiftCode from Timecurrent..tblEmplnames.
--
SELECT @Scheduled = isnull(Scheduled,99) from TimeCurrent.dbo.tblEmplNames where client = @Client and Groupcode = @GroupCode and SSN = @SSN

-- If unscheduled then don't make a break.
-- This is a quick fix to prevent unscheduled employees from getting breaks via
-- PNE.
-- 
if @Scheduled = 0 and NOT(@Client = 'DAVI' and @GroupCode = 910000)
BEGIN
  Set @dupBreakID = 100
END
ELSE
BEGIN

  -- Get the data we will need later to check for duplicates and insert a break.
  --
  --- NOTE: The reason we are re-reading the tblTimeHistDetail with a record ID is because
  ---       this may not be the actual record that caused the break. It is the record with 
  ---       most hours for the contigious span of hours. 
  select 
    @SiteNo = SiteNo, 
    @DeptNo = DeptNo, 
    @TransDate = TransDate,
    @InDay = InDay, 
--    @ShiftNo = ShiftNo, 
    @EmpStatus = EmpStatus, 
    @AgencyNo = AgencyNo, 
    @ClkTransNo = isnull(ClkTransNo,0) + 5
  from TimeHistory.dbo.tblTimeHistDetail where RecordID = @RecordID 

  If @Inday = 1
    Set @Inday2 = 7
  else
    Set @Inday2 = @Inday - 1

  -- Check for Duplicate Breaks. If we find one then don't add another one.
  --
  if (@Client = 'DAVI' and @GroupCode = 300200 and @SiteNo = 1533) OR (@Client = 'DAVT' and @GroupCode = 500500 and @SiteNo = 1533) 
  BEGIN
    -- Site 1533 has a special pay routine that forces the end of week to be SAT at 10:00am. This
    -- causes breaks to get split proportionally as well. So the standard check for a break will not 
    -- work for 1533. So we need a different check that does not include break hours.
    --
    -- See if there is an existing break.
    Set @dupBreakID = (SELECT Top 1 RecordID FROM TimeHistory.dbo.tblTimeHistDetail 
    WHERE Client = @Client 
     and GroupCode = @GroupCode
     and SSN = @SSN
     and PayrollPeriodEndDate = @PPED
     and TransDate = @TransDate
     and (InDay = @InDay OR InDay = @Inday2)
     and ClockAdjustmentNo = @ClockAdjustmentNo)

    IF @dupBreakID is NULL
      Set @dupBreakID = 0
  END
  ELSE
  BEGIN
    -- See if there is an existing break.
    SET @dupBreakID = (SELECT Top 1 RecordID FROM TimeHistory.dbo.tblTimeHistDetail 
    WHERE Client = @Client 
     and GroupCode = @GroupCode
     and SSN = @SSN
     and PayrollPeriodEndDate = @PPED
    -- and SiteNo = @SiteNo Eliminated SiteNo from match due to VTC can have multiple sites on one day. 6/25/02 - DEH
    -- and DeptNo = @DeptNo Eliminated DeptNo from match due to change department on the web. 8/24/01 - DEH
     and TransDate = @TransDate
     and (InDay = @InDay OR InDay = @Inday2)
     and Hours = CONVERT(NUMERIC(8,5), @BreakHours)                      --attempt to fix ticket 10901, formerly @Hours
     and ClockAdjustmentNo = @ClockAdjustmentNo
     --and InSrc = @InSrc  Eliminated source from the match 7/9/01 - RRB
    )
    IF @dupBreakID is NULL
      Set @dupBreakID = 0
  END
END  

-- If we found a duplicate break then return and don't insert a break for this
-- employee
IF @dupBreakID > 0
  RETURN

-- ELSE Insert a new break record for this employee.
-- based on the data in the recordID passed in.
--
INSERT INTO tblTimeHistDetail(Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, ShiftNo, JobID, TransDate, InDay, OutDay, Hours, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, InSrc, OutSrc, EmpStatus, AgencyNo, ClkTransNo, Holiday )
VALUES (@Client, @GroupCode, @SSN, @PPED, @MasterPayrollDate, @SiteNo, @DeptNo, @ShiftNo, 0, @TransDate, @InDay, 0, @BreakHours, '8', 'B', 'BREAK', '3', '', @EmpStatus, @AgencyNo, @ClkTransNo, '0' )






