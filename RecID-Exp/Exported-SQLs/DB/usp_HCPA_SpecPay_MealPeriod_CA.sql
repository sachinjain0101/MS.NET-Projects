CREATE Procedure [dbo].[usp_HCPA_SpecPay_MealPeriod_CA]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)

AS

SET NOCOUNT ON

DECLARE @RecordCount int
DECLARE @adjcode char(1)
DECLARE @TransDate datetime
DECLARE @TotWorked numeric(9,2)
DECLARE @tmpWorked numeric(9,2)
DECLARE @MPD datetime
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
DECLARE @Waived2nd varchar(10)
DECLARE @BreakHrs numeric(9,2)
DECLARE @TotBreakHrs numeric(9,2)
DECLARE @InClass char(1)
DECLARE @OutClass char(1)
DECLARE @savClockOutTime datetime
DECLARE @savClockInTime datetime
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @savRecordID BIGINT  --< @savRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
DECLARE @DiffMins int
DECLARE @FirstPunch datetime
DECLARE @LastPunch datetime
DECLARE @Hours numeric(9,2)
DECLARE @ShiftSegment int
DECLARE @ShiftSegmentID char(1)
DECLARE @LunchBreakCount int
DECLARE @BreakMins INT
DECLARE @AdjNo Varchar(3) --< Srinsoft has converted @AdjNo from Char(1) to Varchar(3) on 12May2016 >--
DECLARE @Type varchar(10)
DECLARE @AdjName varchar(10)
DECLARE @savBreakMins int
DECLARE @BreakCodeID int
DECLARE @BreakExceptionID int
DECLARE @oldAdjName varchar(10)
DECLARE @ShortLunchFlag char(1)

DECLARE @tmpTransDateMP Table
(
  Transdate datetime
)

--Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Start : ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + convert(varchar(12),@PPED,101) + ',' + ltrim(str(@SSN)) )

if exists(Select 1 from TImeCurrent..tblEmplNames 
								where client = @Client
								and groupcode = @Groupcode
								and SSN = @SSN
								and isnull(WTE_Spreadsheet_Breaks,0) <= 0
								)
BEGIN
	-- Breaks are no longer valid for this employee so remove them
	-- and return
	delete from TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks] 
		where client = @Client
		and groupcode = @Groupcode
		and PayrollPeriodEndDate = @PPED 
		and SSN = @SSN

	Return
END

Set @AdjCode = 'N'

Delete from TimeHistory..tblTimeHistDetail 
where client = @Client and Groupcode = @Groupcode and SSN = @SSN and PayrollPeriodenddate = @PPED
and ClockAdjustmentNo = @AdjCode and InSrc = '3' 
and ClkTransNo = 9800
--and UserCode = 'SYS' 
--and (AdjustmentName like 'INTRNL%' or AdjustmentName like 'NMR%')
and TransType <> 7 


insert into @tmpTransDateMP (TransDate)
Select Distinct TransDate 
from Timehistory..tblTimeHistDetail as t with (nolock)
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and t.ClockAdjustmentNo in('',' ') 
and t.Hours = 0.00
and (t.InDay > 7 or t.OutDay > 7)   -- Missing Punch


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
t.InClass, t.OutClass, t.ClockADjustmentNo, t.Hours
from Timehistory..tblTimeHistDetail as t with (nolock)
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
and t.TransDate not in(select TransDate from @tmpTransDateMP)
order by TransDate, ClockAdjustmentNo, ClockInTime

SET @savClockOutTime = NULL
SET @ShiftSegment = 1
SET @ShiftSegmentID = @ShiftSegment
Set @TotWorked = 0

OPEN cTHD1

FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @AdjNo, @tmpWorked
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @RecordCount = @RecordCount + 1
    Set @TotWorked = @TotWorked + @tmpWorked 
		IF @AdjNo <> '' 
		BEGIN
      Update TimeHistory..tblTimeHistDetail Set InClass = 'A',CountAsOT = @ShiftSegmentID where recordid = @recordID --and isnull(InClass,'') <> 'A'
			GOTO NextDetail
		END

    IF @savClockOutTime is NULL
    BEGIN
      Set @savClockOutTime = @ClockOutTime
      Set @savRecordID = @RecordID
      Update TimeHistory..tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegmentID where recordid = @recordID 
      Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', BillOTRateOverride = 0.00 
              ,BillOTRate = Case when @totWorked between 3.50 and 6.00 then '1'
                                    when @totWorked between 6.01 and 10.00 then '2'
                                    when @totWorked between 10.01 and 14.00 then '3'
                                    when @totWorked between 14.01 and 18.00 then '4'
                                    when @totWorked between 18.01 and 22.00 then '5'
                                    when @totWorked between 22.01 and 24.00 then '6' else '0' end
      where recordid = isnull(@savRecordID,0) 
    END
    ELSE
    BEGIN
      Set @DiffMins = datediff(minute, @savClockOutTime, @ClockInTime )
      IF @DiffMins >= 30 and @DiffMins <= 90 
      BEGIN
        -- Set InClass to "L" ( Lunch punch )
        Update TimeHistory..tblTimeHistDetail Set InClass = 'L',CountAsOT = @ShiftSegmentID where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'L', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins >= 0 and @DiffMins < 30
      BEGIN
        -- Set InClass to "|" ( Split punch or Non-Lunch break)
        Update TimeHistory..tblTimeHistDetail Set InClass = '|',CountAsOT = @ShiftSegmentID where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = '|', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins > 90
      BEGIN
        -- Set InClass to "S" ( Shift Start / Shift End punch )
        Set @TotWorked = @TotWorked - @tmpWorked -- Back out current hours.
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'S', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegmentID 
              ,BillOTRate = Case when @totWorked between 3.50 and 6.00 then '1'
                                    when @totWorked between 6.01 and 10.00 then '2'
                                    when @totWorked between 10.01 and 14.00 then '3'
                                    when @totWorked between 14.01 and 18.00 then '4'
                                    when @totWorked between 18.01 and 22.00 then '5'
                                    when @totWorked between 22.01 and 24.00 then '6' else '0' end
            where recordid = isnull(@savRecordID,0) 

        Set @TotWorked = @tmpWorked  -- reset total worked.
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

CLOSE cTHD1
DEALLOCATE cTHD1

IF @RecordCount = 0
BEGIN
	Return
END

Update TimeHistory..tblTimeHistDetail Set OutClass = 'S',CountAsOT = @ShiftSegmentID 
              ,BillOTRate = Case when @totWorked between 3.50 and 6.00 then '1'
                                    when @totWorked between 6.01 and 10.00 then '2'
                                    when @totWorked between 10.01 and 14.00 then '3'
                                    when @totWorked between 14.01 and 18.00 then '4'
                                    when @totWorked between 18.01 and 22.00 then '5'
                                    when @totWorked between 22.01 and 24.00 then '6' else '0' end
where recordid = isnull(@savRecordID,0) 

Declare @tmpPenalty TABLE
(
	SSN int,
	TransDate datetime,
  FirstPunch datetime,
  LastPunch datetime,
	Type varchar(10)
)

Declare @tmpDetail TABLE
(
	RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
	ClockInTime datetime,
	ClockOutTime datetime,
	InClass char(1),
	OutClass char(1),
	BreakHrs int,		-- IN MINUTES
	Hours numeric(9,2),
	TransDate datetime,
	ShiftSegment char(1)
)

Insert into @tmpDetail(recordid, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours, TransDate, ShiftSegment)
select t.RecordID, 
ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
t.InClass, t.OutClass, t.BillOTRateOverride, t.Hours, t.TransDate, t.CountAsOT
from Timehistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeCurrent.dbo.tblSiteNames as sn
on sn.Client = @Client
and sn.Groupcode = @Groupcode
and sn.SiteNo = t.SiteNo
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and t.Clockadjustmentno = ''
and t.Hours <> 0.00
and t.InDay < 8 and t.OutDay < 8
and sn.SiteState = 'CA'
and t.TransDate not in(select TransDate from @tmpTransDateMP)
order by ClockInTime 
--OPTION (MAXDOP 1)


-- =============================================
-- Get the days that are greater than six hours as candidate days.
-- =============================================
DECLARE cDays CURSOR
READ_ONLY
FOR 
select t.MasterPayrolldate, 
maxTransDate = Max(t.TransDate), 
ShiftSegment = t.CountasOT,
TotWorked = Sum( case when t.ClockADjustmentNo = '' then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end), 
BreakHours = sum( case when t.ClockADjustmentNo in('8','1') Then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end),
Waived2nd = left(isnull(e.SubStatus2,'N'),1),
FirstPunch = Min( case when t.ClockADjustmentNo = '' and InClass in('S','|') and OutClass in('L','|') then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime) else '1/1/2030 00:00' end),
LastPunch = Max( case when t.ClockADjustmentNo = '' and InClass in('L','|') and OutClass = 'S' then TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) else '1/1/1970 00:00' end)
from [TimeHistory].[dbo].[tblTimeHistDetail] as t with (nolock)
Inner join TimeCurrent..tblEmplNames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
Inner Join TimeCurrent..tblSIteNames as sn
on sn.Client = t.Client
and sn.Groupcode = t.GroupCode
and sn.SiteNo = t.SiteNo
and sn.SiteState = 'CA'
where t.client = @Client 
and t.groupcode = @GroupCode
and t.payrollperiodenddate = @PPED
and t.ssn = @SSN
and (t.ClockAdjustmentNo in('',' ','8')  or (t.ClockAdjustmentNo = '1' and t.Hours < 0.00))  -- Count Breaks and Hours Adjs.
and t.Hours <> 0.00
and t.InDay < 8 
and t.OutDay < 8
and t.TransDate not in(select TransDate from @tmpTransDateMP)
and isnull(e.SubStatus5,'') <> 'Y'       -- Don't process CA Rules for RN's that are required to work through lunches (RN On-Duty Meal Exception)
--and t.ClockAdjustmentNo in('',' ', 'N') -- Don't count breaks and hours adjustments.
group by t.MasterPayrolldate, t.CountasOT, left(isnull(e.SubStatus2,'N'),1)
having sum(t.regHours + t.OT_Hours + t.DT_Hours) > 5.00
order by ShiftSegment, maxTransdate
--OPTION (MAXDOP 1)


--having sum(t.regHours + t.OT_Hours + t.DT_Hours) > 6.00   ( removed the 6 hour limit 12/13/12 - per Davita request )

OPEN cDays

FETCH NEXT FROM cDays INTO @MPD, @TransDate, @ShiftSegmentID, @TotWorked, @TotBreakHrs, @Waived2nd, @FirstPunch, @LastPunch
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
    
    IF (@TotWorked - @TotBreakHrs) > 12.00 
      Set @Waived2nd = 'N'

		IF @Waived2nd = 'Y' and @TotBreakHrs >= .50 	-- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		IF @Waived2nd <> 'Y' and @TotBreakHrs >= .50 and (@TotWorked - @TotBreakHrs) < 10.00 	-- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		IF @Waived2nd <> 'Y' and @TotBreakHrs >= 1.00 and (@TotWorked - @TotBreakHrs) >= 10.00 -- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		-- This means that there is not a lunch punch for this day and the hours are greater than 6.00 
		-- and if there was a manual break it was not long enough
		-- Save this day as a penalty day.
		--
		IF @FirstPunch = '1/1/2030 00:00' 
		BEGIN
			Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) 
      select top 1 @SSN, @TransDate, ClockInTime, ClockOutTIme, 'NO_MLBRK-W'
      from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			GOTO NextRecord
		END
		--Print @TransDate
		--Print @TotBreakHrs

		/*
		Select RecordID, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours
		from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
		Order by ClockInTime
		*/
		-- =============================================
		-- Traverse the punch detail record for this trans date and shift Segment. 
		-- =============================================
		DECLARE cDetail CURSOR
		READ_ONLY
		FOR
		Select RecordID, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours
		from @tmpDetail where ShiftSegment = @ShiftSegmentID
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
          IF @BreakMins > 5
            Set @ShortLunchFlag = '1'
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
 
          Set @DiffMins = @DiffMins - ((@LunchBreakCount * 300) + @savBreakMins )
          --Set @DiffMins = @DiffMins - ((@LunchBreakCount * 315) + @savBreakMins )

					Set @LunchBreakCount = @LunchBreakCount + 1
					--Print @DiffMins
          --IF @DiffMins > 314
					IF @DiffMins > 299
					BEGIN
							-- Break was taken but the break must be taken before the start of the 5th hour
							-- Mark date as Penalty date and Exit Cursor
              if @LunchBreakCount = 1
              BEGIN
        			  Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) values (@SSN, @TransDate, @ClockInTime, @ClockOutTime, 'LT_MLBRK-W')
                GOTO ExitCursor
              END
              if @LunchBreakCount = 2
              BEGIN
        			  Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) values (@SSN, @TransDate, @ClockInTime, @ClockOutTime, 'SH_M2BRK-W')
                GOTO ExitCursor
              END
              if @LunchBreakCount = 3
              BEGIN
        			  Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) values (@SSN, @TransDate, @ClockInTime, @ClockOutTime, 'SH_M3BRK-W')
                GOTO ExitCursor
              END
							
					END
					ELSE
					BEGIN
							-- Break was taken before the 5th hour
							IF @LunchBreakCount = 1 
							BEGIN
								-- This transaction has passed 1st lunch rule
								-- If this location has waived the 2nd lunch rule or the total hours < 10.00 
								-- then skip the rest of the transactions for the day.
								IF (@TotWorked - @TotBreakHrs) < 10.00
									GOTO ExitCursor
								IF @Waived2nd = 'Y' AND (@TotWorked - @TotBreakHrs) < 15.00
									GOTO ExitCursor
							END
							IF @LunchBreakCount = 2 
							BEGIN
								-- This transaction has passed 2nd lunch rule
								-- Make sure total hours < 15.00
								-- then skip the rest of the transactions for the day.
								IF (@TotWorked - @TotBreakHrs) < 15.00
									GOTO ExitCursor
							END
					END
          Set @ShortLunchFlag = '0'
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
		IF @Waived2nd <> 'Y' and @LunchBreakCount < 2 and (@TotWorked - @TotBreakHrs) >= 10.00 and @TotBreakHrs < .50
		BEGIN
			Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) 
			values (@SSN, @TransDate, @FirstPunch, @LastPunch, case when @shortLunchFlag = '1' then 'SH_MLBRK-W' else 'NO_M2BRK-W' end)
		END		
		-- If this location did not waive 2nd break and two lunch breaks were not taken and the hours > 10.00 
		-- and the manual break amount < .50 then Penalty should apply
		IF @LunchBreakCount < 3 and (@TotWorked - @TotBreakHrs) >= 15.00 and @TotBreakHrs < 1.50
		BEGIN
			Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) 
			values (@SSN, @TransDate, @FirstPunch, @LastPunch, case when @shortLunchFlag = '1' then 'SH_M3BRK-W' else 'NO_M3BRK-W' end)
		END		
		-- If no lunch breaks were not taken and the hours > 5.00 
		-- and the manual break amount < .50 then Penalty should apply
		IF @LunchBreakCount < 1 and (@TotWorked - @TotBreakHrs) > 5.00 and @TotBreakHrs < .50
		BEGIN
			-- Check to see if employee answered "I" or "V" to prompt at clock.
      IF Exists( Select InVerified 
            from TimeHistory..tblTimeHistDetail with (nolock)
            where client = @Client
            and groupcode = @GroupCode
            and ssn = @SSN
            and PayrollPeriodEndDate = @PPED 
            and transdate between @TransDate - 1 and @transdate + 1
            and timeHistory.dbo.PunchDateTime2(transdate, inday, intime) between @FirstPunch and @LastPunch
            and isnull(InVerified,'0') = 'V' )
      BEGIN
        --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Employee has recorded - voluntary short break' )
        --
        -- Update this transaction acccordingly.
        Set @BreakCodeID = (select top 1 RecordID from TimeHistory..tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'SLV')

        --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Break Code ID changed to : ' + ltrim(str(@BreakCodeID)) )

        -- Check to make sure an exception is not already there for this in/out pair
        --
        if not (exists(select 1 from TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
          where client = @Client
          and groupcode = @Groupcode
          and ssn = @SSN
          --and Transdate = @TransDate
          and PayrollPeriodEndDate = @PPED 
          and [In] = @FirstPunch
          and [Out] = @LastPunch ) )
        Begin

            Select TOP 1 @SiteNo = SiteNo, 
              @DeptNo = DeptNo, 
              @tmpWorked = sum(Hours)
            from TimeHistory..tblTimeHistDetail with (nolock) 
            where client = @Client 
            and groupcode = @Groupcode 
            and PayrollPeriodenddate = @PPED 
            and SSN = @SSN 
            and TransDate = @TransDate 
            group by SiteNo, deptNo order By sum(Hours) DESC

          INSERT INTO TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
          ([Client],[GroupCode],[PayrollPeriodEndDate],[SiteNo],[DeptNo],[BreakType],[SSN],[TransDate],[In],[Out],[Hours],[Position],[WorkNEat],[LunchBreakNP],[LunchBreakWP],[LunchBreakPM],[LunchBreakVPM],[BreakCode],[InOutId])
          Values(@Client, @GroupCode, @PPED, @SiteNo, @DeptNo, 'Lunch', @SSN, @TransDate, 
            @FirstPunch,@LastPunch,
            @TotWorked,0,0,0,0,0,0,@BreakCodeID,0 )

          Set @BreakExceptionID = SCOPE_IDENTITY()
        
          --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg ) Values('DAVT CA SpecPay', getdate(), 'Break exception added : ' + ltrim(str(@BreakExceptionID)) )

          --Set @oldAdjName = 'SH_MLBRK-V'
      	  --EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '/', @oldAdjName, 0.00, 0.00, @TransDate, @MPD, 'SYS', 'N'

          -- Add Audit Record at this point to lock down exception.
          --
          INSERT INTO [TimeHistory].[dbo].[tblWTE_Spreadsheet_Breaks_Audit]
          ([BreakRecord],[FromCode],[ToCode],[ChangeDescription],[MaintDateTime],[MaintUserId])
           VALUES(@BreakExceptionID,@BreakCodeID,@BreakCodeID,'Employee Voluntarily took short meal period.',getdate(),1)  
        End
      End
      else
      Begin  
        Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) 
				values (@SSN, @TransDate, @FirstPunch, @LastPunch, case when @shortLunchFlag = '1' then 'SH_MLBRK-W' else 'NO_MLBRK-W' end)
      End
		END		
	END
	NextRecord:
	FETCH NEXT FROM cDays INTO @MPD, @TransDate, @ShiftSegmentID, @TotWorked, @TotBreakHrs, @Waived2nd, @FirstPunch, @LastPunch
END

CLOSE cDays
DEALLOCATE cDays

--select * from @tmpPenalty where SSN = @SSN 

-- At this point process the penalty dates.
--
DECLARE cDates CURSOR
READ_ONLY
FOR
select TransDate, max(Type) 
from @tmpPenalty where SSN = @SSN 
group by TransDate

OPEN cDates

FETCH NEXT FROM cDates into @TransDate, @Type
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		
    Select TOP 1 @SiteNo = SiteNo, 
      @DeptNo = DeptNo, 
      @TotWorked = sum(Hours)
    from TimeHistory..tblTimeHistDetail with (nolock)
    where client = @Client 
    and groupcode = @Groupcode 
    and PayrollPeriodenddate = @PPED 
    and SSN = @SSN 
    and TransDate = @TransDate 
    group by SiteNo, deptNo order By sum(Hours) DESC


    Set @oldAdjName = @Type
		Set @AdjName = @Type

    select 
      @FirstPunch = FirstPunch, 
      @LastPunch = LastPunch
    from @tmpPenalty 
		where Transdate = @TransDate 
		and Type = @Type

    -- Only Add the adjustment if there is NOT a reversal for that day.
    -- 
/*
    IF not ( exists(select 1 from TimeHistory..tblTimeHistDetail with (nolock) 
            where client = @Client
            and groupcode = @groupcode
            and SSN = @SSN
            and payrollperiodenddate = @PPED
            and TransDate = @TransDate
            and clockAdjustmentno = '/'
            ) )
    BEGIN
      --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Added Adjustment')
      
      if @PPED < '1/12/2013'
        Set @AdjName = @oldAdjName 
        
  	  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @Adjcode, @AdjName, 0.00, 0.00, @TransDate, @MPD, 'SYS', 'N'

      Set @RecordID = (select Top 1 RecordID from TimeHistory..tblTimeHistDetail with (nolock)
          where client = @Client
          and groupcode = @groupcode
          and SSN = @SSN
          and payrollperiodenddate = @PPED
          and TransDate = @TransDate
          and clockAdjustmentno = 'N' )
      --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Adjustment RecordID = ' + ltrim(str(@RecordID)))
      
    END
    ELSE
    BEGIN
      Set @RecordID = (select Top 1 RecordID from TimeHistory..tblTimeHistDetail with (nolock)
            where client = @Client
            and groupcode = @groupcode
            and SSN = @SSN
            and payrollperiodenddate = @PPED
            and TransDate = @TransDate
            and clockAdjustmentno = '/' )
    END
*/
    -- Add the break exception to the break exception table - if it is not already there.
    --  Set it to unknown.
    --
    -- Determine the type of Break Code to set as default.
    --
    IF @Type in('NO_MLBRK-W','NO_M2BRK-W','NO_M3BRK-W')
      Set @BreakCodeID = (select top 1 RecordID from TimeHistory..tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'NLI')
    else
      Set @BreakCodeID = (select top 1 RecordID from TimeHistory..tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'LLI')

     --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'BreakCodeID = ' + ltrim(str(@BreakCodeID)))

    Set @BreakExceptionID = (select top 1 RecordID from TimeHistory..tblWTE_Spreadsheet_Breaks with (nolock)
            where client = @Client
            and groupcode = @groupcode
            and SSN = @SSN
            and payrollperiodenddate = @PPED
            and TransDate = @TransDate )

    --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Break Exception Record ID = ' + ltrim(str(isnull(@BreakExceptionID,0))))

    if isnull(@BreakExceptionID,0) = 0
    BEGIN
      --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg) Values('DAVT CA SpecPay', getdate(), 'No Existing Break Exception - so add it' )

      INSERT INTO TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
      ([Client],[GroupCode],[PayrollPeriodEndDate],[SiteNo],[DeptNo],[BreakType],[SSN],[TransDate],[In],[Out],[Hours],[Position],[WorkNEat],[LunchBreakNP],[LunchBreakWP],[LunchBreakPM],[LunchBreakVPM],[BreakCode],[InOutId])
      Values(@Client, @GroupCode, @PPED, @SiteNo, @DeptNo, 'Lunch', @SSN, @TransDate, 
        @FirstPunch,@LastPunch,
        @TotWorked,0,0,0,0,0,0,@BreakCodeID,@RecordID )

      Set @BreakExceptionID = SCOPE_IDENTITY()
        
      --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Break exception added : ' + ltrim(str(@BreakExceptionID)))
               
    END
    ELSE
    BEGIN
      -- There is already a exception on the table for this transdate.
      -- if it's been editted then leave it.
      -- If it has not been editted then update the exception to the new values if different.
      --
      --  --Insert into timeCurrent..tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg )
      --  Values('DAVT CA SpecPay', getdate(), ' Break Exception Record already exists ' )
      IF not ( exists(select 1 from TimeHistory..tblWTE_Spreadsheet_Breaks_Audit where BreakRecord = @BreakExceptionID) )
      BEGIN
        Update TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
          Set [In] = @FirstPunch
        where RecordID = @BreakExceptionID 
        and [IN] <> @FirstPunch  

        Update TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
          Set [Out] = @LastPunch
        where RecordID = @BreakExceptionID 
        and [Out] <> @LastPunch 

        Update TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
          Set [BreakCode] = @BreakCodeID 
        where RecordID = @BreakExceptionID 
        and [BreakCode] <> @BreakCodeID 

        Update TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
          Set InOutID = @RecordID 
        where RecordID = @BreakExceptionID 
        and InOutID <> @RecordID 
      END

    END

	END
	FETCH NEXT FROM cDates into @TransDate, @Type
END

CLOSE cDates
DEALLOCATE cDates
