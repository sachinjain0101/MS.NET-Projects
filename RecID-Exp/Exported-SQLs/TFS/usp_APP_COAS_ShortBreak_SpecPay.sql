Create PROCEDURE [dbo].[usp_APP_COAS_ShortBreak_SpecPay]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)

AS
SET NOCOUNT ON

DECLARE @RecordCount int
DECLARE @adjcode varchar(3)   --< Srinsoft 08/07/2015 Changed @adjcode char(1) to varchar(3) since it references Clockadjustmentno Column >--
DECLARE @TransDate datetime
DECLARE @TotWorked numeric(9,2)
DECLARE @MPD datetime
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @Waived2nd int
DECLARE @BreakHrs numeric(9,2)
DECLARE @TotBreakHrs numeric(9,2)
DECLARE @InClass char(1)
DECLARE @OutClass char(1)
DECLARE @savClockOutTime datetime
DECLARE @savClockInTime datetime
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @savRecordID BIGINT  --< @savRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @DiffMins int
DECLARE @FirstPunch datetime
DECLARE @LastPunch datetime
DECLARE @Hours numeric(9,2)
DECLARE @ShiftSegment int
DECLARE @LunchBreakCount int
DECLARE @BreakMins INT
DECLARE @AdjNo varchar(3)  --< Srinsoft 08/07/2015 Changed @AdjNo char(1) to varchar(3) since it references Clockadjustmentno Column >--
DECLARE @Type varchar(3)
DECLARE @AdjName varchar(10)
DECLARE @savBreakMins int

Set @AdjCode = 'Z'

Delete from TimeHistory..tblTimeHistDetail where client = @Client and Groupcode = @Groupcode and SSN = @SSN and PayrollPeriodenddate = @PPED
and ClockAdjustmentNo = @AdjCode and InSrc = '3' and UserCode = 'SYS' and AdjustmentName in('NOBREAK','SHORT_BRK')
and TransType <> 7 

-- First Set IN and OUT Classes to indicate Lunch Punches for this time card. We have to do this every time because the old trans clocks do not set this
-- value.
-- 
Set @RecordCount = 0
DECLARE cTHD1 CURSOR
READ_ONLY
FOR 
select t.RecordID, 
ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
t.InClass, t.OutClass, t.ClockADjustmentNo
from Timehistory..tblTimeHistDetail as t
Inner Join TimeCurrent.dbo.tblSiteNames as sn
on sn.Client = @Client
and sn.Groupcode = @Groupcode
and sn.SiteNo = t.SiteNo
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and (t.ClockAdjustmentNo in('',' ','8')  or (t.ClockAdjustmentNo = '1' and t.Hours < 0.00))  -- Count Breaks and Hours Adjs.
and t.Hours <> 0.00
and t.InDay < 8 and t.OutDay < 8
and sn.SiteState = 'CA'
order by TransDate, ClockAdjustmentNo, ClockInTime

SET @savClockOutTime = NULL
SET @ShiftSegment = 1

OPEN cTHD1

FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @AdjNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @RecordCount = @RecordCount + 1
		IF @AdjNo <> '' 
		BEGIN
      Update TimeHistory..tblTimeHistDetail Set InClass = 'A',CountAsOT = @ShiftSegment where recordid = @recordID --and isnull(InClass,'') <> 'A'
			GOTO NextDetail
		END

    IF @savClockOutTime is NULL
    BEGIN
      Set @savClockOutTime = @ClockOutTime
      Set @savRecordID = @RecordID
      Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegment where recordid = @recordID 
      Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', BillOTRateOverride = 0.00 where recordid = isnull(@savRecordID,0) 
    END
    ELSE
    BEGIN
      Set @DiffMins = datediff(minute, @savClockOutTime, @ClockInTime )
      IF @DiffMins >= 27 and @DiffMins <= 90 
      BEGIN
        -- Set InClass to "L" ( Lunch punch )
        Update TimeHistory..tblTimeHistDetail Set InClass = 'L',CountAsOT = @ShiftSegment where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'L', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegment where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins >= 0 and @DiffMins < 27
      BEGIN
        -- Set InClass to "|" ( Split punch or Non-Lunch break)
        Update TimeHistory..tblTimeHistDetail Set InClass = '|',CountAsOT = @ShiftSegment where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = '|', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegment where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins > 90
      BEGIN
        -- Set InClass to "S" ( Shift Start / Shift End punch )
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegment where recordid = isnull(@savRecordID,0) 
				SET @ShiftSegment = @ShiftSegment + 1
				IF @ShiftSegment > 9
					Set @ShiftSegment = 0
        Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegment where recordid = @recordID 
      END
      Set @savRecordID = @RecordID
      Set @savClockOutTime = @ClockOutTime
    END
	NextDetail:
	END
	FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @AdjNo
END

CLOSE cTHD1
DEALLOCATE cTHD1

IF @RecordCount = 0
BEGIN
	Return
END

Update TimeHistory..tblTimeHistDetail Set OutClass = 'S' where recordid = isnull(@savRecordID,0) 

Create Table #tmpPenalty
(
	SSN int,
	TransDate datetime,
	Type varchar(3)
)

Create Table #tmpDetail
(
	RecordID BIGINT,  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
	ClockInTime datetime,
	ClockOutTime datetime,
	InClass char(1),
	OutClass char(1),
	BreakHrs int,		-- IN MINUTES
	Hours numeric(9,2),
	TransDate datetime,
	ShiftSegment char(1)
)

Insert into #tmpDetail(recordid, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours, TransDate, ShiftSegment)
select t.RecordID, 
ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
t.InClass, t.OutClass, t.BillOTRateOverride, t.Hours, t.TransDate, t.CountAsOT
from Timehistory..tblTimeHistDetail as t
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and t.Clockadjustmentno = ''
and t.Hours <> 0.00
and t.InDay < 8 and t.OutDay < 8
order by ClockInTime 

-- =============================================
-- Get the days that are greater than six hours as candidate days.
-- =============================================
DECLARE cDays CURSOR
READ_ONLY
FOR 
select t.MasterPayrolldate, t.TransDate, ShiftSegment = t.CountasOT,
TotWorked = Sum( case when t.ClockADjustmentNo = '' then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end), 
BreakHours = sum( case when t.ClockADjustmentNo in('8','1') Then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end),
Waived2nd = '1', -- sn.ClientDefined2,
FirstPunch = Min( case when t.ClockADjustmentNo = '' and InClass in('S','|') and OutClass in('L','|') then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime) else '1/1/2030 00:00' end),
LastPunch = Max( case when t.ClockADjustmentNo = '' and InClass in('L','|') and OutClass = 'S' then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) else '1/1/1970 00:00' end)
from [TimeHistory].[dbo].[tblTimeHistDetail] as t
Inner join TimeCurrent..tblEmplNames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
Inner Join TimeCurrent..tblSIteNames as sn
on sn.Client = t.Client
and sn.Groupcode = t.GroupCode
and sn.SiteNo = t.SiteNo
where t.client = @Client 
and t.groupcode = @GroupCode
and t.payrollperiodenddate = @PPED
and t.ssn = @SSN
and (t.ClockAdjustmentNo in('',' ','8')  or (t.ClockAdjustmentNo = '1' and t.Hours < 0.00))  -- Count Breaks and Hours Adjs.
and t.Hours <> 0.00
and t.InDay < 8 
and t.OutDay < 8
--and t.ClockAdjustmentNo in('',' ', 'N') -- Don't count breaks and hours adjustments.
group by t.MasterPayrolldate, t.transdate, t.CountasOT, sn.ClientDefined2
having sum(t.regHours + t.OT_Hours + t.DT_Hours) > 6.00
order by t.Transdate

OPEN cDays

FETCH NEXT FROM cDays INTO @MPD, @TransDate, @ShiftSegment, @TotWorked, @TotBreakHrs, @Waived2nd, @FirstPunch, @LastPunch
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		-- At this point we have a valid day. Apply the Penalty break rules 
		-- 
		-- * If a teammate works more than a 6-hour shift, but less than a 10-hour shift, teammate must take a 30 minute
		--   uninterrupted(e.g., "off duty") meal break
		--    NOTE: Meal break MUST begin within the first 5 hours of the shift(299 Minutes), but does not need to end before then
		-- * If teammate works more than a 10 hour shift, teammate must take an additional uninterrupted 
	  --   (e.g., "off duty") 30 minute meal break
		--    NOTE: Additional meal break must begin within second 5 hours of shift, but does not need to end before then
		--          Cannot Combine meal breaks
		--
		Set @TotBreakHrs = (-1 * @TotBreakHrs)

		IF @Waived2nd = 1 and @TotBreakHrs >= .50 	-- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		IF @Waived2nd = 0 and @TotBreakHrs >= .50 and (@TotWorked - @TotBreakHrs) < 10.00 	-- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		IF @Waived2nd = 0 and @TotBreakHrs >= 1.00 and (@TotWorked - @TotBreakHrs) >= 10.00 -- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		-- This means that there is not a lunch punch for this day and the hours are greater than 6.00 
		-- and if there was a manual break it was not long enough
		-- Save this day as a penalty day.
		--
		IF @FirstPunch = '1/1/2030 00:00' 
		BEGIN
			Insert into #tmpPenalty (SSN, TransDate, Type) values (@SSN, @TransDate, '_NB')
			GOTO NextRecord
		END
		--Print @TransDate
		--Print @TotBreakHrs

		/*
		Select RecordID, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours
		from #tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegment
		Order by ClockInTime
		*/
		-- =============================================
		-- Traverse the punch detail record for this trans date and shift Segment. 
		-- =============================================
		DECLARE cDetail CURSOR
		READ_ONLY
		FOR
		Select RecordID, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours
		from #tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegment
		Order by ClockInTime

		OPEN cDetail
		
		Set @SavClockInTime = NULL
		Set @LunchBreakCount = 0
    Set @savBreakMins = 0

		FETCH NEXT FROM cDetail INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @BreakMins, @Hours
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN
				--Print @ClockInTime
				IF @SavClockInTime IS NULL 
				BEGIN
					Set @SavClockInTime = @ClockInTime
				END

				-- Split Transaction so move to next transaction.
				IF @OutClass = '|'
				BEGIN	
					GOTO NextTrans
				END

				-- This is a Lunch Out. Break Len has been checked early by cursor above. 
				-- At this point we know the break len is between 27 and 90 minutes.
				-- Just need to make sure the start of the break is within a 5 hour segment of time from the start of the shift.
        -- 
				IF @OutClass = 'L'
				BEGIN
 					Set @DiffMins = datediff(minute, @SavClockInTime, @ClockOutTime)
          -- What this next statement is doing is:
          -- * the rule is translated as -- A break needs to be taken within a 5 hour segment of time from the start of the shifr.
          -- * the @SavClockInTime represents the start of this shift 
          -- * Multiply the lunch/break count by 300 (5 hours) and then add in any break length that was
          --   previously taken.
          --
          -- 2/21/07 -- Davita has added a 15 minute grace period to the 5 hour rule. So time has been changed from 300 minutes
          --            to 315 minutes.
          --
 
          --Set @DiffMins = @DiffMins - ((@LunchBreakCount * 300) + @savBreakMins )
          Set @DiffMins = @DiffMins - ((@LunchBreakCount * 315) + @savBreakMins )

					Set @LunchBreakCount = @LunchBreakCount + 1
					--Print @DiffMins
					--IF @DiffMins > 299
          IF @DiffMins > 2400
					BEGIN
							-- Break was taken but the break must be taken before the start of the 5th hour
							-- Mark date as Penalty date and Exit Cursor
							Insert into #tmpPenalty (SSN, TransDate, Type) values (@SSN, @TransDate, '_SL')
							GOTO ExitCursor
					END
					ELSE
					BEGIN
							-- Break was taken before the 5th hour
							IF @LunchBreakCount = 1 
							BEGIN
								-- This transaction has past 1st lunch rule
								-- If this location has waived the 2nd lunch rule or the total hours < 10.00 
								-- then skip the rest of the transactions for the day.
								IF @Waived2nd = 1 OR (@TotWorked - @TotBreakHrs) < 10.00
									GOTO ExitCursor
							END
					END
					--Set @SavClockInTime = NULL		-- reset for next in time.
				END

			NextTrans:
        Set @savBreakMins = case when @BreakMins <= 90 then @BreakMins else 0 end  + @savBreakMins
			END
			FETCH NEXT FROM cDetail INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @BreakMins, @Hours
		END
		
		ExitCursor:
		CLOSE cDetail
		DEALLOCATE cDetail

		-- If this location did not waive 2nd break and two lunch breaks were not taken and the hours > 10.00 
		-- and the manual break amount < .50 then Penalty should apply
		IF @Waived2nd = 0 and @LunchBreakCount < 2 and (@TotWorked - @TotBreakHrs) >= 10.00 and @TotBreakHrs < .50
		BEGIN
			Insert into #tmpPenalty (SSN, TransDate, Type) values (@SSN, @TransDate, '_2B')
		END		
		-- If no lunch breaks were not taken and the hours > 6.00 
		-- and the manual break amount < .50 then Penalty should apply
		IF @LunchBreakCount < 1 and (@TotWorked - @TotBreakHrs) > 6.00 and @TotBreakHrs < .50
		BEGIN
			Insert into #tmpPenalty (SSN, TransDate, Type) values (@SSN, @TransDate, '_NB')
		END		

	END
	NextRecord:
	FETCH NEXT FROM cDays INTO @MPD, @TransDate, @ShiftSegment, @TotWorked, @TotBreakHrs, @Waived2nd, @FirstPunch, @LastPunch
END

CLOSE cDays
DEALLOCATE cDays


-- At this point process the penalty dates.
--
DECLARE cDates CURSOR
READ_ONLY
FOR
select TransDate, max(Type)  from #tmpPenalty where SSN = @SSN group by TransDate

OPEN cDates

FETCH NEXT FROM cDates into @TransDate, @Type
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Select TOP 1 @SiteNo = SiteNo, @DeptNo = DeptNo, @TotWorked = sum(Hours) from TimeHistory..tblTimeHistDetail where client = @Client and groupcode = @Groupcode and PayrollPeriodenddate = @PPED and SSN = @SSN and TransDate = @TransDate group by SiteNo, deptNo order By sum(Hours) DESC
		Set @AdjName = 'NMR' + @Type
    --Delete from TimeHistory..tblTimeHistDetail where client = @Client and Groupcode = @Groupcode and SSN = @SSN and PayrollPeriodenddate = @PPED
    --and ClockAdjustmentNo = @AdjCode and InSrc = '3' and UserCode = 'SYS' and AdjustmentName like 'NMR%'
    --and TransType <> 7 and TransDate = @TransDate

    -- Only Add the adjustment if there is NOT a reversal for that day.
    -- 
    IF not ( exists(select 1 from TimeHistory..tblTimeHistDetail 
            where client = @Client
            and groupcode = @groupcode
            and SSN = @SSN
            and payrollperiodenddate = @PPED
            and TransDate = @TransDate
            and clockAdjustmentno = '/'
            ) )
    BEGIN
  	  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @Adjcode, @AdjName, 0.00, 0.00, @TransDate, @MPD, 'SYS', 'N'
    END
	END
	FETCH NEXT FROM cDates into @TransDate, @Type
END

CLOSE cDates
DEALLOCATE cDates

-- Delete Penalties for dates that no longer have a penalty
/*
	-- NEED TO SOLVE THIS PROBLEM MOVING FORWARD.
Delete from TimeCurrent..tblAdjustments where client = @Client and Groupcode = @Groupcode and SSN = @SSN and PayrollPeriodenddate = @PPED
and ClockAdjustmentNo = @AdjCode and AdjustmentCode = 'SYS' and AdjustmentName like 'NMR%' and UserName = 'SYS' and UserID = 0
and TransDate not in(Select Distinct TransDate from #tmpPenalty)
*/

Drop table #tmpPenalty
Drop Table #tmpDetail





