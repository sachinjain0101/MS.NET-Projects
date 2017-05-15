Create PROCEDURE [dbo].[usp_APP_DAVT_WA_BreakPenalty_SpecPay]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)

AS
SET NOCOUNT ON

DECLARE @RecordCount int
DECLARE @adjcode varchar(3)   --< Srinsoft 08/11/2015 Changed @adjcode char(1) to varchar(3) for [tblTimeHistDetail] >--
DECLARE @TransDate datetime
DECLARE @TotWorked numeric(9,2)
DECLARE @tmpWorked numeric(9,2)
DECLARE @MPD datetime
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
DECLARE @Waived2nd varchar(10)
DECLARE @BreakHrs numeric(9,2)
DECLARE @TotBreakHrs numeric(9,2)
DECLARE @InClass char(1)
DECLARE @OutClass char(1)
DECLARE @savClockOutTime datetime
DECLARE @savClockInTime datetime
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @savRecordID BIGINT  --< @savRecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
DECLARE @DiffMins int
DECLARE @FirstPunch datetime
DECLARE @LastPunch datetime
DECLARE @Hours numeric(9,2)
DECLARE @ShiftSegment int
DECLARE @ShiftSegmentID char(1)
DECLARE @LunchBreakCount int
DECLARE @BreakMins INT
DECLARE @AdjNo varchar(3) --< Srinsoft 08/11/2015 Changed @AdjNo char(1) to varchar(3) for [tblTimeHistDetail] >--
DECLARE @Type varchar(10)
DECLARE @AdjName varchar(10)
DECLARE @savBreakMins int
DECLARE @savShortBreakMins int
DECLARE @BreakCodeID int
DECLARE @BreakExceptionID int
DECLARE @oldAdjName varchar(10)
DECLARE @ShortLunchFlag char(1)

IF @PPED < '3/8/14'
  return

DECLARE @tmpTransDateMP Table
(
  Transdate datetime
)

--Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg) Values('DAVT WA SpecPay', getdate(), 'Start : ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + convert(varchar(12),@PPED,101) + ',' + ltrim(str(@SSN)) )

Set @AdjCode = '6'

/*
Delete from TimeHistory.dbo.tblTimeHistDetail where client = @Client and Groupcode = @Groupcode and SSN = @SSN and PayrollPeriodenddate = @PPED
and ClockAdjustmentNo = @AdjCode and InSrc = '3' 
and ClkTransNo = 9800
--and UserCode = 'SYS' 
--and (AdjustmentName like 'INTRNL%' or AdjustmentName like 'NMR%')
and TransType <> 7 
*/

insert into @tmpTransDateMP (TransDate)
Select Distinct TransDate 
from Timehistory.dbo.tblTimeHistDetail as t with (nolock)
where t.client = @Client
and t.groupcode = @GroupCode
and t.SSN = @SSN
and t.Payrollperiodenddate = @PPED
and t.ClockAdjustmentNo in('',' ') 
and t.Hours = 0.00
and (t.InDay > 7 or t.OutDay > 7)   -- Missing Punch

-- First Set IN and OUT Classes to indicate Lunch Punches for this time card. 
-- 
Set @RecordCount = 0
DECLARE cTHD1 CURSOR
READ_ONLY
FOR 
select t.RecordID, 
ClockInTime = isnull(t.ActualInTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.inDay, t.Intime)),
ClockOutTime = isnull(t.ActualOutTime, TimeHistory.dbo.PunchDateTime2(t.TransDate, t.outDay, t.OutTime)),
t.InClass, 
t.OutClass, 
t.ClockADjustmentNo,
t.Hours
from Timehistory.dbo.tblTimeHistDetail as t with (nolock)
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
  and t.InDay < 8 
  and t.OutDay < 8
  and t.TransDate not in(select TransDate from @tmpTransDateMP)
  and sn.SiteState = 'WA'
order by TransDate, ClockAdjustmentNo, ClockInTime
OPTION (MAXDOP 1)

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
      Update TimeHistory.dbo.tblTimeHistDetail Set InClass = 'A',CountAsOT = @ShiftSegmentID where recordid = @recordID --and isnull(InClass,'') <> 'A'
			GOTO NextDetail
		END

    IF @savClockOutTime is NULL
    BEGIN
      Set @savClockOutTime = @ClockOutTime
      Set @savRecordID = @RecordID
      Update TimeHistory.dbo.tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegmentID where recordid = @recordID 
      Update TimeHistory.dbo.tblTimeHistDetail 
          Set OutClass = 'S', 
              BillOTRateOverride = 0.00,
              BillOTRate = Case when @totWorked between 3.00 and 6.00 then '1'
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
        Update TimeHistory.dbo.tblTimeHistDetail Set InClass = 'L',CountAsOT = @ShiftSegmentID where recordid = @recordID 
        Update TimeHistory.dbo.tblTimeHistDetail Set OutClass = 'L',BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegmentID 
        where recordid = isnull(@savRecordID,0) 

      END
      IF @DiffMins >= 0 and @DiffMins < 30
      BEGIN
        -- Set InClass to "|" ( Split punch or Non-Lunch break)
        Update TimeHistory.dbo.tblTimeHistDetail Set InClass = '|',CountAsOT = @ShiftSegmentID where recordid = @recordID 
        Update TimeHistory.dbo.tblTimeHistDetail Set OutClass = '|', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegmentID where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins > 90
      BEGIN
        -- Set InClass to "S" ( Shift Start / Shift End punch )
        Set @TotWorked = @TotWorked - @tmpWorked -- Back out current hours.
        Update TimeHistory.dbo.tblTimeHistDetail 
                  Set OutClass = 'S', 
                      BillOTRateOverride = @DiffMins,
                      CountAsOT = @ShiftSegmentID, 
                      BillOTRate = Case when @totWorked between 3.00 and 6.00 then '1'
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

        Update TimeHistory.dbo.tblTimeHistDetail Set InClass = 'S',CountAsOT = @ShiftSegmentID where recordid = @recordID 
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

Update TimeHistory.dbo.tblTimeHistDetail 
  Set OutClass = 'S',
      CountAsOT = @ShiftSegmentID, 
      BillOTRate = Case when @totWorked between 3.00 and 6.00 then '1'
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
  Shiftsegment char(1),
  FirstPunch datetime,
  LastPunch datetime,
	Type varchar(10)
)

Declare @tmpDetail TABLE
(
	RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
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
from Timehistory.dbo.tblTimeHistDetail as t with (nolock)
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
and sn.SiteState = 'WA'
and t.TransDate not in(select TransDate from @tmpTransDateMP)
order by ClockInTime 
OPTION (MAXDOP 1)

/*
select t.MasterPayrolldate, 
maxTransDate = Max(t.TransDate), 
ShiftSegment = t.CountasOT,
TotWorked = Sum( case when t.ClockADjustmentNo = '' then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end), 
BreakHours = sum( case when t.ClockADjustmentNo in('8','1') Then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end),
Waived2nd = left(isnull(e.SubStatus8,'N'),1),
FirstPunch = Min( case when t.ClockADjustmentNo = '' and InClass in('S','|') and OutClass in('L','|') then isnull(t.actualInTime,TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime)) else '1/1/2030 00:00' end),
LastPunch = Max( case when t.ClockADjustmentNo = '' and InClass in('L','|') and OutClass = 'S' then isnull(ActualOutTime,TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime)) else '1/1/1970 00:00' end)
from [TimeHistory].[dbo].[tblTimeHistDetail] as t with (nolock)
Inner join TimeCurrent.dbo.tblEmplNames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
Inner Join TimeCurrent.dbo.tblSIteNames as sn
on sn.Client = t.Client
and sn.Groupcode = t.GroupCode
and sn.SiteNo = t.SiteNo
and sn.SiteState = 'WA'
where t.client = @Client 
and t.groupcode = @GroupCode
and t.payrollperiodenddate = @PPED
and t.ssn = @SSN
and (t.ClockAdjustmentNo in('',' ','8')  or (t.ClockAdjustmentNo = '1' and t.Hours < 0.00 and t.AdjustmentName <> 'Moved'))  -- Count Breaks and Hours Adjs.
and t.Hours <> 0.00
and t.InDay < 8 
and t.OutDay < 8
and t.TransDate not in(select TransDate from @tmpTransDateMP)
and isnull(e.SubStatus9,'') <> 'Y'       -- Don't process CA Rules for RN's that are required to work through lunches (RN On-Duty Meal Exception)
--and t.ClockAdjustmentNo in('',' ', 'N') -- Don't count breaks and hours adjustments.
group by t.MasterPayrolldate, t.CountasOT, left(isnull(e.SubStatus8,'N'),1)
having sum(t.regHours + t.OT_Hours + t.DT_Hours) > 5.00
order by ShiftSegment, maxTransdate
OPTION (MAXDOP 1)
*/

-- =============================================
-- Get the days that are greater than 5 hours as candidate days.
-- =============================================
DECLARE cDays CURSOR
READ_ONLY
FOR 
select t.MasterPayrolldate, 
maxTransDate = Max(t.TransDate), 
ShiftSegment = t.CountasOT,
TotWorked = Sum( case when t.ClockADjustmentNo = '' then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end), 
BreakHours = sum( case when t.ClockADjustmentNo in('8','1') Then t.regHours + t.OT_Hours + t.DT_Hours else 0.00 end),
Waived2nd = left(isnull(e.SubStatus8,'N'),1),
FirstPunch = Min( case when t.ClockADjustmentNo = '' and InClass in('S','|') and OutClass in('L','|') then isnull(t.actualInTime,TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime)) else '1/1/2030 00:00' end),
LastPunch = Max( case when t.ClockADjustmentNo = '' and InClass in('L','|') and OutClass = 'S' then isnull(ActualOutTime,TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime)) else '1/1/1970 00:00' end)
from [TimeHistory].[dbo].[tblTimeHistDetail] as t with (nolock)
Inner join TimeCurrent.dbo.tblEmplNames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
Inner Join TimeCurrent.dbo.tblSIteNames as sn
on sn.Client = t.Client
and sn.Groupcode = t.GroupCode
and sn.SiteNo = t.SiteNo
and sn.SiteState = 'WA'
where t.client = @Client 
and t.groupcode = @GroupCode
and t.payrollperiodenddate = @PPED
and t.ssn = @SSN
and (t.ClockAdjustmentNo in('',' ','8')  or (t.ClockAdjustmentNo = '1' and t.Hours < 0.00 and t.AdjustmentName <> 'Moved'))  -- Count Breaks and Hours Adjs.
and t.Hours <> 0.00
and t.InDay < 8 
and t.OutDay < 8
and t.TransDate not in(select TransDate from @tmpTransDateMP)
and isnull(e.SubStatus9,'') <> 'Y'       -- Don't process CA Rules for RN's that are required to work through lunches (RN On-Duty Meal Exception)
--and t.ClockAdjustmentNo in('',' ', 'N') -- Don't count breaks and hours adjustments.
group by t.MasterPayrolldate, t.CountasOT, left(isnull(e.SubStatus8,'N'),1)
having sum(t.regHours + t.OT_Hours + t.DT_Hours) > 5.00
order by ShiftSegment, maxTransdate
OPTION (MAXDOP 1)


--having sum(t.regHours + t.OT_Hours + t.DT_Hours) > 6.00   ( removed the 6 hour limit 12/13/12 - per Davita request )

OPEN cDays
-- Out Loop represents the candidate days that may have meal period exceptions.
--
FETCH NEXT FROM cDays INTO @MPD, @TransDate, @ShiftSegmentID, @TotWorked, @TotBreakHrs, @Waived2nd, @FirstPunch, @LastPunch
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		-- At this point we have a valid day. Apply the Penalty break rules 
    -- * The first meal period must be taken 
    --     * after the end of the second hour worked (2.0) and
    --     * before the end of the fifth hour worked (4:59)
    -- * TM may not work more than five (5) consecutive hours without a second meal period unless waived in writing
    -- * Teammates who work three (3) hours longer than their usual work shift are allowed an additional 30-minute 
    --   meal period before or during the overtime portion of the shift
    --
    --   Hours of Work = Meal Period 
    --     0.01  -   4.99 = 0   
    --     5.00  -  10.00 = 1
    --    10.01  -  15.00 = 2
		-- 

		Set @TotBreakHrs = (-1 * @TotBreakHrs)
    
    --IF (@TotWorked - @TotBreakHrs) > 12.00 
    --  Set @Waived2nd = 'N'

		IF @Waived2nd = 'Y' and @TotBreakHrs >= .50 	-- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		IF @TotBreakHrs >= .50 and (@TotWorked - @TotBreakHrs) < 10.00 	-- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		IF @TotBreakHrs >= 1.00 and (@TotWorked - @TotBreakHrs) >= 10.00 -- Skip Dates where manually entered Breaks are used.
		BEGIN
			GOTO NextRecord
		END

		-- This means that there is not a lunch punch for this day and the hours are greater than 5.00 
		-- and if there was a manual break it was not long enough
		-- Save this day as a penalty day.
		--
		IF @FirstPunch = '1/1/2030 00:00' 
		BEGIN
      if @TotWorked >= 5 and @TotWorked < 10 
      BEGIN  
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, ShiftSegment, ClockInTime, ClockOutTIme, 'N1_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
      END
      if @TotWorked >= 10 and @TotWorked < 15 
      BEGIN  
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N1_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N2_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
      END
      if @TotWorked >= 15 and @TotWorked < 20 
      BEGIN  
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N1_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N2_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N3_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
      END
      if @TotWorked >= 20
      BEGIN  
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N1_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N2_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N3_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
        select top 1 @SSN, @TransDate, Shiftsegment, ClockInTime, ClockOutTIme, 'N4_MLBK-WK'
        from @tmpDetail where TransDate = @TransDate and ShiftSegment = @ShiftSegmentID
      END
			GOTO NextRecord
		END
		--Print @TransDate
		--Print @TotBreakHrs

    /*
		Select RecordID, ClockInTime, ClockOutTime, InClass, OutClass, BreakHrs, Hours
		from @tmpDetail where ShiftSegment = @ShiftSegmentID
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
    Set @savShortBreakMins = 0

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

				-- Split Transaction ( Short Meal Period )
				IF @OutClass = '|'
				BEGIN	
          Set @savShortBreakMins = @BreakMins
          IF @InClass <> '|'
            Set @SavClockInTime = NULL    -- reset for next segment
					GOTO NextTrans
				END

				-- Split Transaction ( Short Meal Period )
				IF @InClass = '|'
				BEGIN	
          IF @savShortBreakMins > 2
          BEGIN
            -- Insert a short lunch if the total is over 5 hours.
            -- 
            if (@TotWorked - @TotBreakHrs) > 5
            BEGIN
              Set @LunchBreakCount = @LunchBreakCount + 1
              Set @AdjName = 'S' + ltrim(str(@LunchBreakCount)) + '_MLBK-WK'
      			  Insert into @tmpPenalty (SSN, TransDate, Shiftsegment , FirstPunch, LastPunch, Type) 
              values (@SSN, @TransDate, @ShiftSegmentID, @ClockInTime, @ClockOutTime, @AdjName)
							Set @savBreakMins = 0
            END
          END
				END

				-- This is a Lunch Out. Break Len has been checked early by cursor above. 
				-- At this point we know the break len is between 30 and 90 minutes.
				-- Just need to make sure the start of the break is within a 5 hour segment of time from the start of the shift.
        -- and not before the 2 hour.
				IF @OutClass = 'L'
				BEGIN
          
          -- What this next statement is doing is:
          -- * the rule is translated as  
                -- A break needs to be taken within any continuous 5 hour segment of time from the start of the segment.
          -- * the @SavClockInTime represents the start of the segment of time. 
          -- * Check the segment length to see if it is greater than
                -- 300 (5 hours) and any break length that was previously taken.
          
          --Set @DiffMins = @DiffMins - ((@LunchBreakCount * 300) + @savBreakMins )

 					Set @DiffMins = datediff(minute, @SavClockInTime, @ClockOutTime)
          Set @DiffMins = @DiffMins - @savBreakMins

          --Print @SavClockInTime
          --Print @ClockOutTime
					--Print @DiffMins

          Set @SavClockInTime = NULL    -- reset for next segment
          Set @savBreakMins = 0

					Set @LunchBreakCount = @LunchBreakCount + 1
					IF @DiffMins > 299
					BEGIN
						-- Break was taken but the break must be taken before the start of the 5th hour
						-- Mark date as Penalty date and Exit Cursor
            Set @AdjName = 'N' + ltrim(str(@LunchBreakCount)) + '_MLBK-WK'
      			Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
            values (@SSN, @TransDate, @ShiftSegmentID, @ClockInTime, @ClockOutTime, @AdjName)
            GOTO NextTrans
					END
					ELSE
					BEGIN
              -- Make Sure the lunch was not taken before the 2nd hour of the shift segement.
              --
					    IF @DiffMins < 120 and @LunchBreakCount = 1 and @OutClass = 'L'
					    BEGIN
						    -- Break was taken but the break must be taken after the start of the 2nd hour
                -- and this rule only applies to the first lunch break of the segment
						    -- 
                Set @AdjName = 'E' + ltrim(str(@LunchBreakCount)) + '_MLBK-WK'
      			    Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
                values (@SSN, @TransDate, @ShiftsegmentID, @ClockInTime, @ClockOutTime, @AdjName)
                GOTO NextTrans
					    END
              /*
					    ELSE
              BEGIN
							  -- Break was taken before the 5th hour
							  IF @LunchBreakCount = 1 
							  BEGIN
								  -- This transaction has passed 1st lunch rule
								  -- If the total hours < 10.00 
								  -- then skip the rest of the transactions for the day.
								  IF (@TotWorked - @TotBreakHrs) < 10.00
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
							  IF @LunchBreakCount = 3 
							  BEGIN
								  -- This transaction has passed 2nd lunch rule
								  -- Make sure total hours < 20.00
								  -- then skip the rest of the transactions for the day.
								  IF (@TotWorked - @TotBreakHrs) < 20.00
									  GOTO ExitCursor
							  END
              END
              */
					END
				END

        IF @OutClass = 'S' 
        BEGIN

 					Set @DiffMins = datediff(minute, @SavClockInTime, @ClockOutTime)
          Set @DiffMins = @DiffMins - @savBreakMins

          --Print @SavClockInTime
          --Print @ClockOutTime
					--Print @DiffMins

          Set @SavClockInTime = NULL    -- reset for next segment
          Set @savBreakMins = 0

					Set @LunchBreakCount = @LunchBreakCount + 1
					IF @DiffMins > 299
					BEGIN
						-- Break was taken but the break must be taken before the start of the 5th hour
						-- Mark date as Penalty date and Exit Cursor
            Set @AdjName = 'N' + ltrim(str(@LunchBreakCount)) + '_MLBK-WK'
      			Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
            values (@SSN, @TransDate, @ShiftSegmentID, @ClockInTime, @ClockOutTime, @AdjName)
            GOTO NextTrans
					END
        END

      NextTrans:
        Set @savBreakMins = case when @BreakMins <= 90 then @BreakMins else 0 end  + @savBreakMins
			END
			FETCH NEXT FROM cDetail INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @BreakMins, @Hours
		END
		
		ExitCursor:
		CLOSE cDetail
		DEALLOCATE cDetail

		-- If no lunch breaks were taken and the hours > 5.00 
		-- and the manual break amount < .50 then Penalty should apply
		IF @LunchBreakCount < 1 and (@TotWorked - @TotBreakHrs) > 5.00 and @TotBreakHrs < .50
		BEGIN
			Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
      values (@SSN, @TransDate, @ShiftsegmentID, @FirstPunch, @LastPunch, 'N1_MLBK-WK')
		END		
		-- If two lunch breaks were not taken and the hours > 10.00 
		-- and the manual break amount < .50 then Penalty should apply
		IF @LunchBreakCount < 2 and (@TotWorked - @TotBreakHrs) >= 10.00 and @TotBreakHrs < 1.00
		BEGIN
			Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
      values (@SSN, @TransDate, @ShiftsegmentID, @FirstPunch, @LastPunch, 'N2_MLBK-WK')
		END		
		-- If three lunch breaks were not taken and the hours > 15.00 
		-- and the manual break amount < 1.50 then Penalty should apply
		IF @LunchBreakCount < 3 and (@TotWorked - @TotBreakHrs) >= 15.00 and @TotBreakHrs < 1.50
		BEGIN
			Insert into @tmpPenalty (SSN, TransDate, Shiftsegment, FirstPunch, LastPunch, Type) 
      values (@SSN, @TransDate, @ShiftSegmentID, @FirstPunch, @LastPunch, 'N3_MLBK-WK')
		END		
	END
	NextRecord:

/*  
  if not exists(select 1 from @tmpPenalty where TransDate = @TransDate)
  Begin
    -- Insert a blank penalty for this day - meaning that there may need to be clean up done on this day (i.e. was a penalty at one point, but was
    -- removed due to time card edits, etc.)
    --
    Insert into @tmpPenalty (SSN, TransDate, FirstPunch, LastPunch, Type) values (@SSN, @TransDate, @FirstPunch, @LastPunch, '')

  End
*/  
	FETCH NEXT FROM cDays INTO @MPD, @TransDate, @ShiftSegmentID, @TotWorked, @TotBreakHrs, @Waived2nd, @FirstPunch, @LastPunch
END

CLOSE cDays
DEALLOCATE cDays

/*
select * from @tmpPenalty Order by TransDate, [Type]
select * from @tmpDetail order by ClockInTime 

select p.Transdate, p.ShiftSegment, p.[type],actionid = 'ADD'  --, t.ActualInTime,t.ActualOutTime,t.AdjustmentName 
from @tmpPenalty as p
Left Join TimeHistory.[dbo].[tblTimeHistDetail] as t with(nolock)
on t.client = @Client
and t.groupcode = @Groupcode
and t.PayrollPeriodEndDate = @PPED
and t.SSN = @SSN
and t.TransDate = p.TransDate 
and t.ClockAdjustmentNo = @adjcode 
and substring(t.AdjustmentName,2,1) = substring(p.[Type],2,1)
and t.Hours <> 0
union
select t.TransDate, p.ShiftSegment, [Type] = t.AdjustmentName,ActionID = 'Remove'  --FirstPunch = t.ActualInTime, lAstPunch = t.ActualOutTime, 
from TimeHistory.[dbo].[tblTimeHistDetail] as t with(nolock)
left Join @tmpPenalty as p
on p.TransDate = t.TransDate 
and substring(p.[Type],2,1) = substring(t.AdjustmentName,2,1)
where 
 t.client = @Client
and t.groupcode = @Groupcode
and t.PayrollPeriodEndDate = @PPED
and t.SSN = @SSN
and t.ClockAdjustmentNo = @adjcode 
and t.Hours <> 0
and isnull(p.ssn,0) = 0
Order by TransDate,  ShiftSegment, [Type]
*/

DECLARE @ActionID varchar(20)
DECLARE @InVerified char(1)
DECLARE @BreakErrorFieldName varchar(12)
DECLARE @Answer varchar(100)

-- At this point process the penalty dates.
--
DECLARE cDates CURSOR
READ_ONLY
FOR
select p.Transdate, p.ShiftSegment, p.[type],actionid = 'ADD'  --, t.ActualInTime,t.ActualOutTime,t.AdjustmentName 
from @tmpPenalty as p
Left Join TimeHistory.[dbo].[tblTimeHistDetail] as t with(nolock)
on t.client = @Client
and t.groupcode = @Groupcode
and t.PayrollPeriodEndDate = @PPED
and t.SSN = @SSN
and t.TransDate = p.TransDate 
and t.ClockAdjustmentNo = @adjcode 
and substring(t.AdjustmentName,2,1) = substring(p.[Type],2,1)
and t.Hours <> 0
union
select t.TransDate, p.ShiftSegment, [Type] = t.AdjustmentName,ActionID = 'Remove'  --FirstPunch = t.ActualInTime, lAstPunch = t.ActualOutTime, 
from TimeHistory.[dbo].[tblTimeHistDetail] as t with(nolock)
left Join @tmpPenalty as p
on p.TransDate = t.TransDate 
and substring(p.[Type],2,1) = substring(t.AdjustmentName,2,1)
where 
 t.client = @Client
and t.groupcode = @Groupcode
and t.PayrollPeriodEndDate = @PPED
and t.SSN = @SSN
and t.ClockAdjustmentNo = @adjcode 
--and t.Hours <> 0
and isnull(p.ssn,0) = 0
and t.TransDate not in(select TransDate from @tmpTransDateMP)
Order by TransDate, ShiftSegment, [Type]

OPEN cDates

FETCH NEXT FROM cDates into @TransDate, @ShiftSegmentID, @Type, @ActionID
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    IF @ActionID = 'Remove'
    BEGIN
      -- Update the adjustment to have zero and reset the break exception record.
      Update TimeHistory.dbo.tblTimeHistDetail 
        Set Hours = 0.00,
            RegHours = 0.00,
            JobID = cast(convert(varchar(8),getdate(),112) as int),
            TransType = 7
      where client = @Client
      and groupcode = @groupcode
      and SSN = @SSN
      and payrollperiodenddate = @PPED
      and TransDate = @TransDate
      and clockAdjustmentno = @AdjCode
      and AdjustmentName = @Type 
      --and hours <> 0.00 
      and UserCode in('SYS','P_N')

        -- Reset the Break Exceptions to all be Voluntary exceptions/cancelled.
        --
      Set @BreakExceptionID = 0

      select @BreakExceptionID =  RecordID, 
          @AdjName = BreakType,
          @RecordID = BreakCode  
      from TimeHistory.dbo.tblWTE_Spreadsheet_Breaks with (nolock)
          where client = @Client
          and groupcode = @groupcode
          and SSN = @SSN
          and payrollperiodenddate = @PPED
          and TransDate = @TransDate
          and BreakCode in(select RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakCodeIndex = 0 ) -- Only want ones that are involuntary - need to flip them
          and BreakType = @Type 

      Set @BreakExceptionID = isnull(@BreakExceptionID,0)
      if @BreakExceptionID <> 0
      BEGIN
        -- Update the code to VOL and set audit record.
        -- Select * from TimeHistory.dbo.tblWTE_BreakCodes where client = 'DAVT'
        IF left(@Type,1) not in('S','N','L','E')
          Set @BreakErrorFieldName = 'NLV'
        else
          Set @BreakErrorFieldName = left(@Type,1) +  'LV'

        Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = @BreakErrorFieldName)

        /*
        IF @Type like 'N%'
          Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'NLV')
        IF @Type like 'L%'
          Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'LLV')
        IF @Type like 'S%'
          Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'SLV')
        IF @Type like 'E%'
          Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'ELV')
        IF left(@Type,1) not in('S','N','L','E')
          Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'NLV')
        */

        Update TimeHistory.dbo.tblWTE_Spreadsheet_Breaks 
            Set BreakCode = @BreakCodeID
        where RecordID = @BreakExceptionID

        INSERT INTO [TimeHistory].[dbo].[tblWTE_Spreadsheet_Breaks_Audit]
                    ([BreakRecord]
                    ,[FromCode]
                    ,[ToCode]
                    ,[ChangeDescription]
                    ,[MaintDateTime]
                    ,[MaintUserId])
              VALUES
                    (@BreakExceptionID
                    ,@RecordID
                    ,@BreakCodeID
                    ,'Systematic change to voluntary/cancelled due to time card edits made.'
                    ,getdate()
                    ,1)
      END
      goto NextPenalty
    END  

    -- ADD
    --Print @Transdate
    --Print @Type
    Select
      @FirstPunch = FirstPunch,
      @LastPunch = LastPunch
    from @tmpPenalty where TransDate = @TransDate and [Type] = @Type --and ShiftSegment = @ShiftSegmentID

    --select * from @tmpPenalty where TransDate = @TransDate and [Type] = @Type and ShiftSegment = @ShiftSegmentID

    Select TOP 1 
      @SiteNo = SiteNo, 
      @DeptNo = DeptNo,
      @InVerified = isnull(InVerified,'X') 
    from TimeHistory.dbo.tblTimeHistDetail with (nolock)
    where client = @Client 
    and groupcode = @Groupcode 
    and PayrollPeriodenddate = @PPED 
    and SSN = @SSN 
    and TransDate = @TransDate 
    and isnull(ActualInTime, TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime)) = @FirstPunch

		Set @AdjName = @Type
    --Print '@SiteNo = ' + case when isnull(@SIteNo,0) = 0 then 'NULL' else ltrim(str(@SIteNo)) end + ', @InVerified = ' + @InVerified

		IF isnull(@SiteNo,0) = 0
		BEGIN
			Select TOP 1 
				@SiteNo = SiteNo, 
				@DeptNo = DeptNo,
				@InVerified = isnull(InVerified,'X') 
			from TimeHistory.dbo.tblTimeHistDetail with (nolock)
			where client = @Client 
			and groupcode = @Groupcode 
			and PayrollPeriodenddate = @PPED 
			and SSN = @SSN 
			and TransDate = @TransDate 
			--and isnull(ActualInTime, TimeHistory.dbo.PunchDateTime2(TransDate, inDay, Intime)) = @FirstPunch
		END

		IF isnull(@SiteNo,0) = 0
		BEGIN
			Select 
				@SiteNo = PrimarySite, 
				@DeptNo = PrimaryDept,
				@InVerified = 'X'
			from TimeCurrent..tblEmplNames  with (nolock)
			where client = @Client 
			and groupcode = @Groupcode 
			and SSN = @SSN 
		END

    Set @RecordID = (select Top 1 RecordID from TimeHistory.dbo.tblTimeHistDetail with (nolock) 
                      where client = @Client
                      and groupcode = @groupcode
                      and SSN = @SSN
                      and payrollperiodenddate = @PPED
                      and TransDate = @TransDate
                      and clockAdjustmentno = @AdjCode
                      and substring(AdjustmentName,2,1) = substring(@AdjName,2,1) ) -- checking the meal period exception number 1,2,3,4

    -- Only Add the adjustment if it's not already there
    -- 
    IF isnull(@RecordID,0) = 0 
    BEGIN
      --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT WA SpecPay', getdate(), 'Added Adjustment')
      
  	  EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @Adjcode, @AdjName, 0.00, 0.00, @TransDate, @MPD, 'SYS', 'Y','Y'

      Set @RecordID = (select Top 1 RecordID from TimeHistory.dbo.tblTimeHistDetail with (nolock)
          where client = @Client
          and groupcode = @groupcode
          and SSN = @SSN
          and payrollperiodenddate = @PPED
          and TransDate = @TransDate
          and clockAdjustmentno = @AdjCode
          and AdjustmentName = @AdjName )

      -- Set the reg hours
      -- Update TimeHistory.dbo.tblTimeHistDetail Set RegHours = 0.50, ActualInTime = @FirstPunch, ActualOutTime = @LastPunch where RecordID = @RecordID 

      --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Adjustment RecordID = ' + ltrim(str(@RecordID)))
    END
    ELSE
    BEGIN
      -- Update the adjustment type if it changed ( Missed lunch to Late lunch, etc.)
      Update TimeHistory.dbo.tblTimeHistDetail 
        Set AdjustmentName = @AdjName,
            ActualInTime = @FirstPunch, 
            ActualOutTime = @LastPunch
      where RecordID = @RecordID
       and left(AdjustmentName,2) <> left(@AdjName,2)
    END

    -- Add the break exception to the break exception table - if it is not already there.
    --  Set it to unknown.
    --
    -- Determine the type of Break Code to set as default.
    -- If it start with a "X" then it's a missed break
    -- else late lunch
    --
    IF left(@Type,1) not in('S','N','L','E')
      Set @BreakErrorFieldName = 'NL' + case when @Inverified <> 'V' then 'I' else @Inverified end
    else
      Set @BreakErrorFieldName = left(@Type,1) +  'L' + case when @Inverified <> 'V' then 'I' else @Inverified end

    --Print @BreakErrorFieldName

    Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = @BreakErrorFieldName)
    /*
    IF @Type like 'N%'
      Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'NLI')
    IF @Type like 'L%'
      Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'LLI')
    IF @Type like 'S%'
      Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'SLI')
    IF @Type like 'E%'
      Set @BreakCodeID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_BreakCodes where client = @Client and BreakErrorFieldName = 'ELI')
    */
    --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'BreakCodeID = ' + ltrim(str(@BreakCodeID)))

    Set @BreakExceptionID = (select top 1 RecordID from TimeHistory.dbo.tblWTE_Spreadsheet_Breaks with (nolock)
            where client = @Client
            and groupcode = @groupcode
            and SSN = @SSN
            and payrollperiodenddate = @PPED
            and TransDate = @TransDate
            and substring(BreakType,2,1) = substring(@AdjName,2,1) -- Check the meal period number, 1,2,3,4 
            )

    --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Break Exception Record ID = ' + ltrim(str(isnull(@BreakExceptionID,0))))

    if isnull(@BreakExceptionID,0) = 0
    BEGIN
      --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg) Values('DAVT CA SpecPay', getdate(), 'No Existing Break Exception - so add it' )

      INSERT INTO TimeHistory.[dbo].[tblWTE_Spreadsheet_Breaks]
      ([Client],[GroupCode],[PayrollPeriodEndDate],[SiteNo],[DeptNo],[BreakType],[SSN],[TransDate],[In],[Out],[Hours],[Position],[WorkNEat],[LunchBreakNP],[LunchBreakWP],[LunchBreakPM],[LunchBreakVPM],[BreakCode],[InOutId])
      Values(@Client, @GroupCode, @PPED, @SiteNo, @DeptNo, @AdjName, @SSN, @TransDate, 
        @FirstPunch,@LastPunch,
        @TotWorked,0,0,0,0,0,0,@BreakCodeID,@RecordID )

      Set @BreakExceptionID = SCOPE_IDENTITY()
        
      -- IF the inverifed was set by the employee. We need to add audit record - to track employee response.
      IF @Inverified in('I','V')
      BEGIN
        --
        -- Void Penalty on the transdate 
        --
        if @Inverified = 'V'
          Update TimeHistory..tblTImeHistDetail
            Set TransType = 7, AdjustmentName = left(AdjustmentName,8) + 'WV'
          where RecordID = @RecordID 
            and Transtype <> 7
  
        Set @Answer = case when @Inverified = 'I' then 'Answered YES to "Short meal prd due to work" Prompt' else 'Answered YES to "Short meal prd waived meal" Prompt' end
        -- Add audit record.
        INSERT INTO TimeHistory..tblWTE_Spreadsheet_Breaks_Audit
                ( BreakRecord ,
                  FromCode ,
                  ToCode ,
                  ChangeDescription ,
                  MaintDateTime ,
                  MaintUserId
                )
        VALUES  ( @BreakExceptionID, 
                  @BreakCodeID,
                  @BreakCodeID,
                  @Answer,
                  GetDate(),
                  1
                )
      END

      --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName,AuditDateTime,AuditMsg) Values('DAVT CA SpecPay', getdate(), 'Break exception added : ' + ltrim(str(@BreakExceptionID)))
               
    END
    ELSE
    BEGIN
      -- There is already a exception on the table for this transdate.
      -- if it's been editted then leave it.
      -- If it has not been editted then update the exception to the new values if different.
      --
      --  --Insert into timeCurrent.dbo.tblWork_SPROC_Audit(SPROCName, AuditDateTime, AuditMsg )
      --  Values('DAVT CA SpecPay', getdate(), ' Break Exception Record already exists ' )
      IF not ( exists(select 1 from TimeHistory.dbo.tblWTE_Spreadsheet_Breaks_Audit where BreakRecord = @BreakExceptionID) )
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

				-- IF the inverifed was set by the employee. We need to add audit record - to track employee response.
				IF @Inverified in('I','V')
				BEGIN
					--
					-- Void Penalty on the transdate 
					--
					if @Inverified = 'V'
						Update TimeHistory..tblTImeHistDetail
							Set TransType = 7, AdjustmentName = left(AdjustmentName,8) + 'WV'
						where RecordID = @RecordID 
							and Transtype <> 7
  
					Set @Answer = case when @Inverified = 'I' then 'Answered YES to "Short meal prd due to work" Prompt' else 'Answered YES to "Short meal prd waived meal" Prompt' end
					-- Add audit record.
					INSERT INTO TimeHistory..tblWTE_Spreadsheet_Breaks_Audit
									( BreakRecord ,
										FromCode ,
										ToCode ,
										ChangeDescription ,
										MaintDateTime ,
										MaintUserId
									)
					VALUES  ( @BreakExceptionID, 
										@BreakCodeID,
										@BreakCodeID,
										@Answer,
										GetDate(),
										1
									)
				END

      END
    END
  NextPenalty:
	END
	FETCH NEXT FROM cDates into @TransDate, @ShiftSegmentID, @Type, @ActionID
END

CLOSE cDates
DEALLOCATE cDates



