USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_HCPA_SpecPay_ShiftDiff_BasedOnStartTime]    Script Date: 11/3/2015 9:16:49 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_HCPA_SpecPay_ShiftDiff_BasedOnStartTime]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_HCPA_SpecPay_ShiftDiff_BasedOnStartTime] AS' 
END
GO

ALTER procedure [dbo].[usp_HCPA_SpecPay_ShiftDiff_BasedOnStartTime]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
as 

SET NOCOUNT ON

DECLARE @PrevShiftNo int
DECLARE @PrevShiftDiffAmt numeric(6,2)
DECLARE @PrevShiftDiffClass char(1)
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
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
DECLARE @savRecordID BIGINT  --< @savRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
DECLARE @DiffMins int
DECLARE @TransDate datetime

DECLARE @ActDate varchar(20)
DECLARE @ActIn datetime
DECLARE @ActOut datetime
DECLARE @BaseDays int


DECLARE cTHD1 CURSOR
READ_ONLY
FOR 
select RecordID, ShiftNo, 
ClockInTime = TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime),
ClockOutTime = TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime),
InClass, OutClass 
from Timehistory..tblTimeHistDetail with(nolock)
where client = @Client
and groupcode = @GroupCode
and SSN = @SSN
and Payrollperiodenddate = @PPED
and Clockadjustmentno = ''
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

-- =============================================
-- 
-- =============================================
DECLARE cTHD SCROLL CURSOR FOR
select 
RecordID, 
ShiftNo, 
ClockInTime = TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime),
ClockOutTime = TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime),
isnull(InClass,'S'), 
isnull(OutClass,'S'), 
DeptNo, 
SiteNo, 
masterpayrolldate, 
isnull(Changed_DeptNo,'')
from Timehistory..tblTimeHistDetail with(nolock)
where client = @Client
and groupcode = @GroupCode
and SSn = @SSN
and Payrollperiodenddate = @PPED
and clockadjustmentno = ''
and DeptNo in(select DeptNo from TimeCurrent..tblDeptShiftDiffs with(nolock) where Client = @Client and GroupCode = @GroupCode and SiteNo = tblTimeHistDetail.SiteNo )
--and isnull(shiftno,0) <> 4
order by ClockInTime

Set @PrevShiftNo = 0
Set @PrevShiftDiffAmt = 0.00
Set @PrevShiftDiffClass = '0'

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
      Select 
				@ShiftDiffAmt = DiffRate
      from TimeCurrent.dbo.tblDeptShiftDiffs 
      where client = @Client
      and GroupCode = @Groupcode
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
      and ApplyDiff = '1' 
			and DiffType <> 'D' 
      and RecordStatus = '1'
      and ShiftNo = @ShiftNo

      -- Update the detail rec.
      Update TimeHistory..tblTimeHistDetail 
				Set ShiftDiffAmt = isnull(@ShiftDiffAmt,0)
      where recordid = @RecordID
      --Print 'Record was manually changed. Skipped RecordID '+ ltrim(str(@RecordID))
      GOTO NextRecord
    END

    -- IF the InClass is a 'T' or '|' (Split) or a Lunch Punch 'L'
    IF @inClass in('T', '|', 'L' ) and @PrevShiftNo <> 0
    BEGIN
      -- Then set this punch the same as the previous punch.
      Update TimeHistory..tblTimeHistDetail 
        Set ShiftNo = isnull(@PrevShiftNo,1),
            ShiftDiffAmt = isnull(@PrevShiftDiffAmt,0),
						ShiftDiffClass = '' 
        where RecordID = @RecordID
        --and NOT( InTime = '12/30/1899 00:00' and InDay in(7,2) )  -- Not split at midnight on Saturday Morning or Monday Morning.
      if @@RowCount > 0   
      BEGIN
        --Print 'Record was part of a split and was updated to prior record. RecordID '+ ltrim(str(@RecordID))  
        Goto NextRecord
      END
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
    
    --Print 'ActDate: ' + convert(varchar(32),@ActDate,120)
    --Print 'ActIn: ' + convert(varchar(32),@ActIN,120)
    --Print 'ActOut: ' + convert(varchar(32),@ActOut,120)

    Set @NewShiftNo = NULL
    Select @NewShiftNo = ShiftNo, 
           @ShiftDiffAmt = DiffRate, 
           @ShiftStart = ShiftStart,
           @ShiftEnd = ShiftEnd
      from TimeCurrent.dbo.tblDeptShiftDiffs with(nolock)
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

      --Print 'NewShiftNo: ' + ltrim(str(@NewShiftNo))
      --Print 'ShiftStart: ' + convert(varchar(32),@ShiftStart,120)
      --Print 'ShiftEnd: ' + convert(varchar(32),@ShiftEnd,120)

      Set @TransDate = (select Transdate From TimeHistory..tblTimeHistDetail where recordid = @RecordID )
      Update TimeHistory..tblTimeHistDetail 
				Set ShiftNo = isnull(@NewShiftNo,1),
						ShiftDiffAmt = isnull(@ShiftDiffAmt,0),
						ShiftDiffClass = ''
			where RecordID = @RecordID

      Update TimeHistory..tblTimeHistDetail
        Set ShiftNo = isnull(@NewShiftNo,1),
            ShiftDiffAmt = isnull(@ShiftDiffAmt,0),
						ShiftDiffClass = ''
      where client = @Client 
				and groupcode = @groupcode 
				and ssn = @SSN 
				and TransDate = @TransDate 
				and ClockADjustmentno = '8'
        and ShiftNo <> @NewShiftNo
      
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








