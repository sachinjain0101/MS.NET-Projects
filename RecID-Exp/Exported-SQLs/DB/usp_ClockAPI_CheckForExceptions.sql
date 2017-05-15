CREATE Procedure [dbo].[usp_ClockAPI_CheckForExceptions]
(
  @Client varchar(4),
  @Groupcode int,
  @SSN int,
  @ThisPunch varchar(20),
  @PunchType varchar(20),
  @Errorcode varchar(80),
  @ActualOutPunch DateTime = '1/1/1970',
  @SiteNo int = 0,
  @SiteState varchar(2) = '',
  @MaxExceptionID int = 0,
  @thdRecordID BIGINT = 0,  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
  @ShiftID int = 0
)
AS


SET NOCOUNT ON

Declare @AuditMessage varchar(400)

set @AuditMessage = '''' + @Client + ''',' + ltrim(str(@GroupCode)) + ',' + ltrim(str(@SSN)) + ',''' + @ThisPunch + ''',''' + @PunchType + ''',''' + @ErrorCode + ''',''' + 
					convert(varchar(40),@ActualOutPunch,120) + ''',' + ltrim(str(@siteNo)) + ',''' + @SiteSTate + ''',' + ltrim(str(@MaxExceptionID)) + ',' + ltrim(str(@thdRecordID))
					+ ',' + ltrim(str(@ShiftID)) 

INSERT INTO Audit.[dbo].[tblSimpleAuditLog]
           ([DateTimeAdded]
           ,[LogSource]
           ,[LogID1]
           ,[LogID2]
           ,[LogID3]
           ,[LogID4]
           ,[LogID5]
           ,[LogMessage])
     VALUES
           (getdate()
           ,'[usp_ClockAPI_CheckForExceptions]'
		   ,  Ltrim(str(@thdRecordID))
		   , @ThisPunch
		   , convert(varchar(32), @ActualOutPunch, 120)
		   , Ltrim(str(@shiftID))
		   , ''
		   ,@AuditMessage )


IF @PunchType = 'I'
BEGIN
  Select 1 where 1 = 0
  Return
END

-- Need to determine based on the shift information and the transactions for the day if the employee should be prompted to enter a break
-- for the amount of time entered

--  If any segment of time > workspan1 and break amount < break length 1
-- 


if @Errorcode not in('0','')
BEGIN
  INSERT INTO Audit.[dbo].[tblSimpleAuditLog]([DateTimeAdded],[LogSource],[LogID1],[LogID2],[LogID3],[LogID4],[LogID5],[LogMessage])
  select getdate(),'usp_ClockAPI_CheckForExceptions', 
    @Client + ',' + ltrim(str(@groupcode)) + ',' + ltrim(str(@SiteNo)),
    ltrim(str(@SSN)),
    @thisPunch,
    @Errorcode,
    ltrim(str(@thdRecordID)),
    'Punch did not process - cigtrans returned code = ' + @errorcode 

END

DECLARE @PPED datetime
DECLARE @Transdate datetime

Select 
    @PPED = Payrollperiodenddate,
    @Transdate = TransDate  
from Timehistory..tblTimeHistDetail as t with (nolock)
where RecordID = @thdRecordID 
and CLient = @Client
and groupCode = @Groupcode
and SSN = @SSN
and ActualOutTime = @ActualOutPunch 

IF isnull(@PPED,'1/1/1970') = '1/1/1970'
BEGIN
	Select 
			@PPED = Payrollperiodenddate,
			@Transdate = TransDate  
	from Timehistory..tblTimeHistDetail as t with (nolock)
	where RecordID >= @thdRecordID 
	and CLient = @Client
	and groupCode = @Groupcode
	and SSN = @SSN
	and ActualOutTime = @ActualOutPunch 
	order by RecordID desc
END
--Print @PPED
--Print @TransDate

DECLARE @RecordCount int
DECLARE @TotWorked numeric(9,2)
DECLARE @tmpWorked numeric(9,2)
DECLARE @RecordID int
DECLARE @BreakHrs numeric(9,2)
DECLARE @TotBreakHrs numeric(9,2)
DECLARE @InClass char(1)
DECLARE @OutClass char(1)
DECLARE @savClockOutTime datetime
DECLARE @savClockInTime datetime
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @savRecordID int
DECLARE @DiffMins int
DECLARE @ShiftSegment int
DECLARE @ShiftSegmentID char(1)
DECLARE @BreakMins INT
DECLARE @AdjNo varchar(3)  --< Srinsoft 08/26/2015 Changed @AdjNo char(1) to varchar(3) for Clockadjustmentno >--
DECLARE @savBreakMins int
DECLARE @MissingBreak int


DECLARE @Workspan1 numeric(7,2)
DECLARE @BreakLen1 numeric(5,2)
DECLARE @Workspan2 numeric(7,2)
DECLARE @BreakLen2 numeric(5,2)
DECLARE @tmpSpan numeric(7,2)
DECLARE @tmpBreak numeric(5,2)

Set @WorkSpan1 = 6.00
Set @BreakLen1 = .50

select @WorkSpan1 = isnull(WorkSpan1,0),
	@BreakLen1 = isnull(BreakLength1,0),
	@WorkSpan2 = isnull(WorkSpan2,0),
	@breakLen2 = isnull(BreakLength2,0)
From TimeCurrent..tblDeptShifts with(nolock) where RecordID = @ShiftID

--select top 10 * from TimeCurrent..tblDeptshifts

IF isNULL(@WorkSPan1,-1) = -1 
BEGIN
  set @WorkSpan1 = 6.00
  Set @Workspan2 = 12.00
  Set @BreakLen1 = .50
  Set @BreakLen2 = 1.00

END

IF @WorkSpan2 = 0
BEGIN
	Set @WorkSpan2 = 99
	Set @BreakLen2 = 00
END

IF @WorkSpan1 = 0
BEGIN
	Set @WorkSpan1 = 99
	Set @BreakLen1 = 00
END

IF @WorkSpan1 > @WorkSpan2 
BEGIN
	-- Flip Spans and Break lens
	-- We always want the workspan1 to be smaller than workspan2 to reduce the complexity of the logic below.
	--
	Set @tmpSpan = @WorkSpan2
	Set @tmpBreak = @BreakLen2 
	Set @Workspan2 = @workspan1
	Set @BreakLen2 = @BreakLen1
	Set @Workspan1 = @tmpSpan 
	Set @BreakLen1 = @tmpBreak 
END

Set @RecordCount = 0
DECLARE cTHD1 CURSOR
READ_ONLY
FOR 
select t.RecordID, 
ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
t.InClass, t.OutClass, t.ClockADjustmentNo, t.Hours
from Timehistory..tblTimeHistDetail as t with (nolock)
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and t.transdate = @TransDate
and (t.ClockAdjustmentNo in('',' ','8')  or (t.ClockAdjustmentNo = '1' and t.Hours < 0.00))  -- Count Breaks and Hours Adjs.
and t.Hours <> 0.00
and t.InDay < 8 and t.OutDay < 8
order by TransDate, ClockAdjustmentNo, ClockInTime

SET @savClockOutTime = NULL
Set @TotWorked = 0
Set @TotBreakHrs = 0
set @MissingBreak = 0

OPEN cTHD1

FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @AdjNo, @tmpWorked
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @RecordCount = @RecordCount + 1
    Set @TotWorked = @TotWorked + @tmpWorked 
    --Print @TotWorked
		IF @AdjNo <> '' 
		BEGIN
      Set @TotBreakHrs = @TotBreakHrs + (@tmpWorked * -1.00 )
      Update TimeHistory..tblTimeHistDetail Set InClass = 'A',CountAsOT = @ShiftSegmentID where recordid = @recordID --and isnull(InClass,'') <> 'A'
			GOTO NextDetail
		END

    IF @savClockOutTime is NULL
    BEGIN
      Set @savClockOutTime = @ClockOutTime
      Set @savRecordID = @RecordID
      Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegmentID where recordid = @recordID 
      Update TimeHistory..tblTimeHistDetail Set OutClass = 'S' where recordid = isnull(@savRecordID,0) 
    END
    ELSE
    BEGIN
      Set @DiffMins = datediff(minute, @savClockOutTime, @ClockInTime )
      IF @DiffMins >= 30 and @DiffMins <= 90 
      BEGIN
        -- Set InClass to "L" ( Lunch punch )
        Set @TotBreakHrs = @TotBreakHrs + (@DiffMins/60.00)
        Update TimeHistory..tblTimeHistDetail Set InClass = 'L',CountAsOT = @ShiftSegmentID where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'L', CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins >= 0 and @DiffMins < 30
      BEGIN
        -- Set InClass to "|" ( Split punch or Non-Lunch break)
        Update TimeHistory..tblTimeHistDetail Set InClass = '|',CountAsOT = @ShiftSegmentID where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = '|', CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins > 90
      BEGIN
        -- New shift segment 
        -- determine if a break should have been taken
        -- 
        -- Set InClass to "S" ( Shift Start / Shift End punch )
        Set @TotWorked = @TotWorked - @tmpWorked -- Back out current hours.

        --Print @TotWorked 
        --Print @TotBreakHrs

        if @TotWorked > @Workspan1 and @TotWorked < @WorkSpan2 and @TotBreakHrs < @BreakLen1
        BEGIN
          -- Need to take a break 
          -- so exit loop
          Set @MissingBreak = 2
          goto ExitCursor
        END
        if @TotWorked >= @Workspan2 and @TotBreakHrs < @BreakLen2
        BEGIN
          -- Need to take a break 
          -- so exit loop
          Set @MissingBreak = 3 
          goto ExitCursor
        END
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 

        Set @TotWorked = @tmpWorked  -- reset total worked.
        Set @TotBreakHrs = 0
				SET @ShiftSegment = @ShiftSegment + 1

        IF @ShiftSegment <= 9
          Set @ShiftSegmentID = @ShiftSegment
				IF @ShiftSegment = 10
					Set @ShiftSegmentID = 'A'
				IF @ShiftSegment = 11
					Set @ShiftSegmentID = 'B'
				IF @ShiftSegment = 12
					Set @ShiftSegmentID = 'C'
				IF @ShiftSegment = 13
					Set @ShiftSegmentID = 'D'
				IF @ShiftSegment = 14
					Set @ShiftSegmentID = 'E'
				IF @ShiftSegment = 15
					Set @ShiftSegmentID = 'F'
				IF @ShiftSegment = 16
					Set @ShiftSegmentID = 'G'

        Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegmentID where recordid = @recordID 
      END
      Set @savRecordID = @RecordID
      Set @savClockOutTime = @ClockOutTime
    END
	NextDetail:
	END
	FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @AdjNo, @tmpWorked
END

ExitCursor:

CLOSE cTHD1
DEALLOCATE cTHD1

if @TotWorked > @Workspan1 and @TotWorked < @Workspan2 and @TotBreakHrs < @BreakLen1
BEGIN
  -- Need to take a break 
  -- so exit loop
  Set @MissingBreak = 2
END


if @TotWorked >= @Workspan2 and @TotBreakHrs < @BreakLen2
BEGIN
  -- Need to take a break 
  -- so exit loop
  Set @MissingBreak = 3
END

IF @MissingBreak <> 0
BEGIN
  select 
  TransID=@thdRecordID, 
  [RecordID],
  [ScreenTitle],
  [ScreenTitle2],
  [ItemType],
  [ItemID],
  [ItemText],
  [ItemValue],
  [ItemVisible],
  [ItemOrder]
  from TimeHistory..tmpClockExceptions 
  where recordid = @MissingBreak
  order by Recordid, ItemOrder 

END  


/*
 1 Get configuration from Clock Setup
    1 -- soft scheduling?
    2 -- break processing?
    3 -- rest break processing?
    4 -- auto break
       0 = Bypass
       1 = Accept or manually enter
       2 = Accept or Dispute
       3 = Accept or manually enter (15 min interval)
       4 = Confirm Break (YES/NO)

*/

