Create PROCEDURE [dbo].[usp_EmplCalc_SetShiftNoWIP]
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


DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
DECLARE @ShiftNo int
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @DeptNo int
DECLARE @SiteNo int
DECLARE @NewShiftNo int
DECLARE @inTime varchar(5)
DECLARE @outTime varchar(5)
DECLARE @DOW int
DECLARE @ActDate varchar(20)
DECLARE @ActIn datetime
DECLARE @ActOut datetime
DECLARE @BaseDays int
DECLARE @DropTable char(1)

Set @DropTable = '0'
DECLARE cTHD SCROLL CURSOR FOR
select 	RecordID, 
				ClockInTime = TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime),
				ClockOutTime = TimeHistory.dbo.PunchDateTime2(TransDate, outDay, OutTime),
				DeptNo, SiteNo
from Timehistory..tblTimeHistDetail 
where client = @Client
and groupcode = @GroupCode
and SSn = @SSN
and Payrollperiodenddate = @PPED
and clockadjustmentno = ''
-- Only interested in people who have currently punched in on the clock
and OutDay = 10
and ShiftNo = 0

OPEN cTHD

FETCH NEXT FROM cTHD INTO @RecordID, @ClockInTime, @ClockOutTime, @DeptNo, @SiteNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
--		print @ClockInTime
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

    IF NOT exists(Select deptno 
									from TimeCurrent..tblDeptShifts 
									where client = @Client 
									and groupcode = @Groupcode 
									and Siteno = @SiteNo 
									and DeptNo = @deptNo 
									and recordstatus = '1')
    BEGIN
      Set @DeptNo = 99
    END

--		print '@ActIn: ' + cast(@ActIn as varchar)
--		print '@ActOut: ' + cast(@ActOut as varchar)
/*    Select 	shiftno, 
						@ActIn as ActIn,
						ABS(DateDiff(mi, @ActIn, ShiftStart)) as ShiftStartDiff,
						case when ApplyDay1 in('1','2') then dateadd(day,@Basedays,ShiftStart) else '1/1/2026' END as SunStart,
					 	case when ApplyDay1 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+1,Shiftend) else dateadd(day,@Basedays,Shiftend) end else '1/2/2026' END as SunEnd,
			      case when ApplyDay2 in('1','2') then dateadd(day,@Basedays+1,ShiftStart) else '1/1/2026' END as MonStart,
			      case when ApplyDay2 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+2,Shiftend) else dateadd(day,@Basedays+1,Shiftend) end else '1/2/2026' END as MonEnd,
      			case when ApplyDay3 in('1','2') then dateadd(day,@Basedays+2,ShiftStart) else '1/1/2026' END as TueStart,
      			case when ApplyDay3 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+3,Shiftend) else dateadd(day,@Basedays+2,Shiftend) end else '1/2/2026' END as TueEnd,
      			case when ApplyDay4 in('1','2') then dateadd(day,@Basedays+3,ShiftStart) else '1/1/2026' END as WedStart,
      			case when ApplyDay4 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+4,Shiftend) else dateadd(day,@Basedays+3,Shiftend) end else '1/2/2026' END as WedEnd,
			      case when ApplyDay5 in('1','2') then dateadd(day,@Basedays+4,ShiftStart) else '1/1/2026' END as ThuStart,
			      case when ApplyDay5 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+5,Shiftend) else dateadd(day,@Basedays+4,Shiftend) end else '1/2/2026' END as ThuEnd,
			      case when ApplyDay6 in('1','2') then dateadd(day,@Basedays+5,ShiftStart) else '1/1/2026' END as FriStart,
			      case when ApplyDay6 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+6,Shiftend) else dateadd(day,@Basedays+5,Shiftend) end else '1/2/2026' END as FriEnd,
      			case when ApplyDay7 in('1','2') then dateadd(day,@Basedays+6,ShiftStart) else '1/1/2026' END as SatStart,
      			case when ApplyDay7 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+7,Shiftend) else dateadd(day,@Basedays+6,Shiftend) end else '1/2/2026' END as SatEnd,
					  *
      from TimeCurrent.dbo.tblDeptShifts 
      where client = @Client
      and GroupCode = @Groupcode
      and SiteNo = @SiteNo
      and DeptNo = @DeptNo
      and RecordStatus = '1'
      and 
      (
      (@ActIn between case when ApplyDay1 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay1 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+1,Shiftend)) else dateadd(day,@Basedays,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay2 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays+1,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay2 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+2,Shiftend)) else dateadd(day,@Basedays+1,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay3 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays+2,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay3 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+3,Shiftend)) else dateadd(day,@Basedays+2,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay4 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays+3,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay4 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+4,Shiftend)) else dateadd(day,@Basedays+3,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay5 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays+4,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay5 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+5,Shiftend)) else dateadd(day,@Basedays+4,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay6 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays+5,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay6 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+6,Shiftend)) else dateadd(day,@Basedays+5,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay7 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays+6,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay7 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays+7,Shiftend)) else dateadd(day,@Basedays+6,Shiftend) end else '1/2/2026' END)
      OR
      (@ActIn between case when ApplyDay7 in('1','2') then dateadd(mi, -60, dateadd(day,@Basedays-1,ShiftStart)) else '1/1/2026' END
      AND case when ApplyDay7 in('1','2') then case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays,Shiftend)) else dateadd(day,@Basedays-1,Shiftend) end else '1/2/2026' END)
      )
      order by ShiftNo desc

*/
			-- Expand out the shift table so we can compare the punch to each shift, this is the only way that I can think of that
			-- we can accurately determine the closest shift
			create table #tmpShift(ShiftNo int, ShiftStart datetime, ShiftEnd datetime, ShiftStartDiff int)

			INSERT INTO #tmpShift(ShiftNo, ShiftStart, ShiftEnd)
			Select 	shiftno, 
							dateadd(day,@Basedays,ShiftStart) as ShiftStart, --SunStart,
						 	case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+1,Shiftend) else dateadd(day,@Basedays,Shiftend) end as ShiftEnd --as SunEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay1 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
				      dateadd(day,@Basedays+1,ShiftStart) as ShiftStart, --as MonStart,
				      case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+2,Shiftend) else dateadd(day,@Basedays+1,Shiftend) end as ShiftEnd -- as MonEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay2 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
			  			dateadd(day,@Basedays+2,ShiftStart) as ShiftStart, --as TueStart,
			  			case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+3,Shiftend) else dateadd(day,@Basedays+2,Shiftend) end as ShiftEnd -- as TueEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay3 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
			  			dateadd(day,@Basedays+3,ShiftStart) as ShiftStart, --as WedStart,
			  			case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+4,Shiftend) else dateadd(day,@Basedays+3,Shiftend) end as ShiftEnd -- as WedEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay4 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
				      dateadd(day,@Basedays+4,ShiftStart) as ShiftStart, --as ThuStart,
				      case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+5,Shiftend) else dateadd(day,@Basedays+4,Shiftend) end as ShiftEnd -- as ThuEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay5 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
				      dateadd(day,@Basedays+5,ShiftStart) as ShiftStart, --as FriStart,
				      case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+6,Shiftend) else dateadd(day,@Basedays+5,Shiftend) end as ShiftEnd -- as FriEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay6 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
			  			dateadd(day,@Basedays+6,ShiftStart) as ShiftStart, --as SatStart,
			  			case when ShiftEnd <= ShiftStart then dateadd(day,@Basedays+7,Shiftend) else dateadd(day,@Basedays+6,Shiftend) end as ShiftEnd -- as SatEnd,
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay7 in('1','2') 
			and RecordStatus = '1'
			UNION
			Select 	shiftno, 
				      dateadd(mi, -60, dateadd(day,@Basedays-1,ShiftStart)) as ShiftStart, --as SunStart2
				      case when ShiftEnd <= ShiftStart then dateadd(mi, 60, dateadd(day,@Basedays,Shiftend)) else dateadd(day,@Basedays-1,Shiftend) end as ShiftEnd --SunEnd2
			from TimeCurrent.dbo.tblDeptShifts 
			where client = @Client
			and GroupCode = @Groupcode
			and SiteNo = @SiteNo
			and DeptNo = @DeptNo
			and ApplyDay7 in('1','2') 
			and RecordStatus = '1'

			UPDATE #tmpShift
			SET ShiftStartDiff = ABS(DateDiff(mi, @ActIn, ShiftStart))

--			SELECT @ActIn as ActualIn, * FROM #tmpShift		

    Set @NewShiftNo = NULL
		Set @NewShiftNo = (SELECT TOP 1 ShiftNo
											 FROM #tmpShift
											 ORDER BY ShiftStartDiff ASC, ShiftNo DESC)
/*    set @NewShiftNo = (Select TOP 1 ShiftNo
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
      order by ShiftNo desc)*/

			IF (@NewShiftNo IS NOT NULL)
			BEGIN
	      Update TimeHistory..tblTimeHistDetail 
				Set ShiftNo = @NewShiftNo 
				where RecordID = @RecordID
				and (inday = 10 or OutDay = 10 )
			END

    	DROP TABLE #tmpShift
			--print @NewShiftNo
      --Print 'Shift ' + ltrim(str(@NewShiftNo)) + ' Applied to Punch ' + convert(varchar(20), @ClockInTime, 100 )
      
	END
	FETCH NEXT FROM cTHD INTO @RecordID, @ClockInTime, @ClockOutTime, @DeptNo, @SiteNo
END

CLOSE cTHD
DEALLOCATE cTHD



