Create PROCEDURE [dbo].[usp_DAVT_SpecPay_ShiftDiff_At_ShiftStart]
(
  @ApplyToSiteNo int,
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
as 

SET NOCOUNT ON

/*
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @SSN int
DECLARE @PPED datetime

SET @Client = 'DVT2'
Set @GroupCode = 501202
SET @PPED = '11/11/2006'
SET @SSN = 612865245
*/

DECLARE @PrevShiftNo int
DECLARE @PrevShiftDiffAmt numeric(6,2)
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
DECLARE @ShiftNo int
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @inClass char(1)
DECLARE @outClass char(1)
DECLARE @DeptNo int
DECLARE @SiteNo int
DECLARE @NewShiftNo int
DECLARE @ShiftDiffAmt numeric(6,2)
DECLARE @inTime varchar(5)
DECLARE @outTime varchar(5)
DECLARE @DOW int
DECLARE @ShiftStart datetime
DECLARE @ShiftEnd datetime
DECLARE @MPD datetime
DECLARE @Changed_DeptNo char(1)
DECLARE @savClockOutTime datetime
DECLARE @savRecordID BIGINT  --< @savRecordId data type is changed from  INT to BIGINT by Srinsoft on 23Aug2016 >--
DECLARE @DiffMins int

DECLARE @ActDate varchar(20)
DECLARE @ActIn datetime
DECLARE @ActOut datetime
DECLARE @BaseDays int

/*
IF @PRSiteNo in(963,3053)
BEGIN
  EXEC [TimeHistory].[dbo].[usp_EmplCalc_OT_AutoClockOut_DEH] @Client, @GroupCode, @PPED, @SSN
END
*/

-- =============================================
-- IF the pay Rule Siteno is a trans clock then we need to 
-- manually set the lunch punches
-- =============================================
--IF @PRSiteNo in(431,3444,3053)
--BEGIN
  DECLARE cTHD1 CURSOR
  READ_ONLY
  FOR 
  select RecordID, ShiftNo, 
  ClockInTime = isnull(ActualInTime, TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime)),
  ClockOutTime = isnull(ActualOutTime, TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime)),
  InClass, OutClass 
  from Timehistory..tblTimeHistDetail with (nolock)
  where client = @Client
  and groupcode = @GroupCode
  and SSN = @SSN
  and Payrollperiodenddate = @PPED
  and Clockadjustmentno = ''
  and TransType <> '7'
  order by ClockInTime
  
  SET @savClockOutTime = NULL
  
  OPEN cTHD1
  
  FETCH NEXT FROM cTHD1 INTO @RecordID, @ShiftNo, @ClockInTime, @ClockOutTime, @InClass, @OutClass
  WHILE (@@fetch_status <> -1)
  BEGIN
  	IF (@@fetch_status <> -2)
  	BEGIN
      IF @savClockOutTime is NULL
      BEGIN
        Set @savClockOutTime = @ClockOutTime
        Set @savRecordID = @RecordID
      END
      ELSE
      BEGIN
        Set @DiffMins = datediff(minute, @savClockOutTime, @ClockInTime )
        --Print @savClockOutTime
        --Print @ClockInTime
        --Print @DiffMins
        IF @DiffMins >= 0 and @DiffMins <= 90 
        BEGIN
          -- Set InClass to "L" ( Lunch punch )
          Update TimeHistory..tblTimeHistDetail Set InClass = 'L' where recordid = @recordID and isnull(InClass,'') NOT IN('L','|','T')
          Update TimeHistory..tblTimeHistDetail Set OUTClass = 'L' where recordid = isnull(@savRecordID,0) and isnull(OutClass,'') NOT IN('L','|','T')
        END
        Set @savRecordID = @RecordID
        Set @savClockOutTime = @ClockOutTime
      END
  	END
  	FETCH NEXT FROM cTHD1 INTO @RecordID, @ShiftNo, @ClockInTime, @ClockOutTime, @InClass, @OutClass
  END
  
  CLOSE cTHD1
  DEALLOCATE cTHD1
--END  

-- =============================================
-- 
-- =============================================
DECLARE cTHD SCROLL CURSOR FOR
select Distinct t.RecordID, t.ShiftNo, 
ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
isnull(t.InClass,'S'), isnull(t.OutClass,'S'), t.DeptNo, t.SiteNo, t.masterpayrolldate, isnull(t.Changed_DeptNo,'')
from Timehistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeCurrent..tblDeptShiftDiffs as d
on d.Client = t.Client 
and d.GroupCode = t.GroupCode 
and d.SiteNo = t.SiteNo 
and d.DeptNo = t.DeptNo 
and d.RecordStatus = '1'
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and t.clockadjustmentno = ''
and t.TransType <> '7'
order by ClockInTime

Set @PrevShiftNo = 0
Set @PrevShiftDiffAmt = 0.00

OPEN cTHD

FETCH NEXT FROM cTHD INTO @RecordID, @ShiftNo, @ClockInTime, @ClockOutTime, @inClass, @OutClass, @DeptNo, @SiteNo, @MPD, @Changed_DeptNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- IF the Shift has been previously manually set then skip the record.
    IF @Changed_DeptNo = '2'
    BEGIN
      -- Need to Reset or clear the shiftdiffamount
      -- Get the shift diff amount from the diff table
      Select @ShiftDiffAmt = DiffRate
      from TimeCurrent.dbo.tblDeptShiftDiffs 
      where client = @Client
      and GroupCode = @Groupcode
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
      and ApplyDiff = '1' and DiffType <> 'D' 
      and RecordStatus = '1'
      and ShiftNo = @ShiftNo

      -- Update the detail rec.
      Update TimeHistory..tblTimeHistDetail Set ShiftDiffAmt = isnull(@ShiftDiffAmt,0)
      where recordid = @RecordID
      GOTO NextRecord
    END

    -- IF the InClass is a 'T' or '|' (Split) or a Lunch Punch 'L'
    IF @inClass in('T', '|', 'L' ) and @PrevShiftNo <> 0
    BEGIN
      -- Then set this punch the same as the previous punch.
      Update TimeHistory..tblTimeHistDetail Set ShiftNo = @PrevShiftNo, ShiftDiffAmt = @PrevShiftDiffAmt where RecordID = @RecordID
      Goto NextRecord
    END

    -- Determine what shift this punch is in.
    -- the first punch should be start of a shift InClass = 'S'
    SET @DOW = datepart(weekday, @ClockInTime)
    Set @BaseDays = 38716  -- Number of days from 1/1/1900 to 1/1/2006
    Set @ActDate = convert(varchar(10),dateadd(day, @DOW - 1, '1/1/2006'),101)  -- Sunday
    Set @InTime = convert(varchar(5), @ClockInTime, 108)
    Set @OutTime = convert(varchar(5), @ClockOutTime, 108)

    Set @ActIn = @ActDate + ' ' + @InTime
    Set @ActOut = @ActDate + ' ' + @OutTime
    If @ActOut <= @ActIn
      Set @ActOut = Dateadd(day,1,@ActOut)
    
    Set @NewShiftNo = NULL
    Select @NewShiftNo = ShiftNo, 
           @ShiftDiffAmt = DiffRate, 
           @ShiftStart = ShiftStart,
           @ShiftEnd = ShiftEnd
      from TimeCurrent.dbo.tblDeptShiftDiffs 
      where client = @Client
      and GroupCode = @Groupcode
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
      and ApplyDiff = '1' and DiffType <> 'D' 
      and RecordStatus = '1'
      and 
      (
      (@ActIn between case when ApplyDay1 in('1','2') then dateadd(day,@Basedays,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay1 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+1,Shiftend) else dateadd(day,@Basedays,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay2 in('1','2') then dateadd(day,@Basedays+1,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay2 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+2,Shiftend) else dateadd(day,@Basedays+1,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay3 in('1','2') then dateadd(day,@Basedays+2,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay3 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+3,Shiftend) else dateadd(day,@Basedays+2,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay4 in('1','2') then dateadd(day,@Basedays+3,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay4 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+4,Shiftend) else dateadd(day,@Basedays+3,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay5 in('1','2') then dateadd(day,@Basedays+4,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay5 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+5,Shiftend) else dateadd(day,@Basedays+4,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay6 in('1','2') then dateadd(day,@Basedays+5,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay6 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+6,Shiftend) else dateadd(day,@Basedays+5,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay7 in('1','2') then dateadd(day,@Basedays+6,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay7 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+7,Shiftend) else dateadd(day,@Basedays+6,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay7 in('1','2') then dateadd(day,@Basedays-1,ShiftStart) else '1/1/2026' END
      AND case when ApplyDay7 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays,Shiftend) else dateadd(day,@Basedays-1,Shiftend) end else '1/2/2026' END)
      )

      Update TimeHistory..tblTimeHistDetail Set ShiftNo = @NewShiftNo,ShiftDiffAmt = @ShiftDiffAmt where RecordID = @RecordID

      -- If the out class is a Split or Lunch Then save it.
      IF isnull(@OutClass,'S') in('|','L', 'T') 
      BEGIN
        Set @PrevShiftno = @NewShiftNo
        Set @PrevShiftDiffAmt = @ShiftDiffAmt
      END
      ELSE
      BEGIN
        Set @PrevShiftno = 0
        Set @PrevShiftDiffAmt = 0.00
      END

      --Print 'Shift ' + ltrim(str(@NewShiftNo)) + ' Applied to Punch ' + convert(varchar(20), @ClockInTime, 100 )
      --Print @NewShiftNo
      --Print @ShiftDiffAmt
      
	END
NextRecord:  
	FETCH NEXT FROM cTHD INTO @RecordID, @ShiftNo, @ClockInTime, @ClockOutTime, @inClass, @OutClass, @DeptNo, @SiteNo, @MPD, @Changed_DeptNo
END

CLOSE cTHD
DEALLOCATE cTHD










