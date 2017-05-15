CREATE  procedure [dbo].[usp_TAND_SpecPay_AssignShift_MP]
(
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

SET @Client = 'TAND'
Set @GroupCode = 310200
SET @PPED = '8/26/2007'
SET @SSN = 9077
*/

DECLARE @PrevShiftNo int
DECLARE @PrevShiftDiffAmt numeric(6,2)
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--
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
DECLARE @savRecordID int
DECLARE @DiffMins int

DECLARE @ActDate varchar(20)
DECLARE @ActIn datetime
DECLARE @ActOut datetime
DECLARE @BaseDays int

DECLARE cTHD SCROLL CURSOR FOR
select RecordID, 
ClockInTime = TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime),
ClockOutTime = TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime),
DeptNo, SiteNo
from Timehistory..tblTimeHistDetail where client = @Client
and groupcode = @GroupCode
and SSn = @SSN
and Payrollperiodenddate = @PPED
and clockadjustmentno = ''
and (inday = 10 or OutDay = 10 )

Set @PrevShiftNo = 0
Set @PrevShiftDiffAmt = 0.00

OPEN cTHD

FETCH NEXT FROM cTHD INTO @RecordID, @ClockInTime, @ClockOutTime, @DeptNo, @SiteNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
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

    IF NOT exists(Select deptno from TimeCurrent..tblDeptShifts where client = @Client and groupcode = @Groupcode and Siteno = @SiteNo and DeptNo = @deptNo and recordstatus = '1')
    BEGIN
      Set @DeptNo = 99
    END


    Select *
      from TimeCurrent.dbo.tblDeptShifts 
      where client = @Client
      and GroupCode = @Groupcode
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
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
      order by ShiftNo desc


    Set @NewShiftNo = NULL
    Select @NewShiftNo = ShiftNo, 
           @ShiftDiffAmt = DiffRate, 
           @ShiftStart = ShiftStart,
           @ShiftEnd = ShiftEnd
      from TimeCurrent.dbo.tblDeptShifts 
      where client = @Client
      and GroupCode = @Groupcode
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
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
      order by ShiftNo desc

      Update TimeHistory..tblTimeHistDetail Set ShiftNo = @NewShiftNo where RecordID = @RecordID

      --Print 'Shift ' + ltrim(str(@NewShiftNo)) + ' Applied to Punch ' + convert(varchar(20), @ClockInTime, 100 )
      
	END
	FETCH NEXT FROM cTHD INTO @RecordID, @ClockInTime, @ClockOutTime, @DeptNo, @SiteNo
END

CLOSE cTHD
DEALLOCATE cTHD




