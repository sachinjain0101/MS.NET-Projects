CREATE             Procedure [dbo].[usp_APP_ADVO_UnionRules_SpecPay]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)

AS

SET NOCOUNT ON


/*
-- DEBUG SECTION
Declare @Client char(4)
Declare @GroupCode int
Declare @PPED datetime
DECLARE @SSN int

Set @Client = 'ADVO'
Set @GroupCode = 730028
Set @PPED = '1/30/2008'
Set @SSN = 591180633

DROP TABLE #tmpTrans
*/

DECLARE @adjcode varchar(3) --< Srinsoft 08/06/2015 Changed @adjcode char(1) to varchar(3) >--
DECLARE @TransDate datetime
DECLARE @savTransDate datetime
DECLARE @TotWorked numeric(9,2)
DECLARE @totOT_Hours numeric(9,2)
DECLARE @InTime datetime
DECLARE @OutTime datetime
DECLARE @MaxSpan int
DECLARE @tmpMaxSpan int
DECLARE @savOutTime datetime
DECLARE @MPD datetime
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @RecCount int
DECLARE @HalfTimeAdjCount int
DECLARE @Hours numeric(7,2)
DECLARE @OT_Hours numeric(7,2)
DECLARE @RegHours numeric(7,2)
DECLARE @Payrate numeric(9,4)
DECLARE @RecordCount int
DECLARE @InClass char(1)
DECLARE @OutClass char(1)
DECLARE @savClockOutTime datetime
DECLARE @savClockInTime datetime
DECLARE @ClockInTime datetime
DECLARE @ClockOutTime datetime
DECLARE @savRecordID BIGINT  --< @savRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @DiffMins int
DECLARE @ShiftSegment int
DECLARE @AdjNo varchar(3)  --< Srinsoft 08/06/2015 Changed  @AdjNo char(1) to varchar(3) >--
DECLARE @savBreakMins int

Set @AdjCode = 'B'

EXEC TimeHistory..usp_Advocate_EmplCalc_BeforeSP2 18,90, @Client, @GroupCode, @PPED, @SSN

Create Table #tmpTrans
(
  TransDate Datetime,
  ShiftSegment tinyint,
  MasterPayrolldate datetime,
  PrimarySite int,
  PrimaryDept int,
  MaxSpan int,
  TotWorked numeric(9,2)
)
  
IF @GroupCode = 730029
BEGIN
  -- For BOONE only include RN and LPN departments.
  --
  Insert into #tmpTrans(TransDate, ShiftSegment, masterpayrolldate, PrimarySite, PRimaryDept, MaxSpan, TotWorked)
  select t.TransDate, 0, t.masterpayrolldate, e.PrimarySite, e.PrimaryDept,
  MaxSpan = cast(0 as int), TotWorked = Sum(t.regHours)
  from [TimeHistory].[dbo].[tblTimeHistDetail] as t
  Inner join TimeCurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  where t.client = @Client 
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate = @PPED
  and t.ssn = @SSN
  and t.ClockadjustmentNo in('',' ','1','8')
--  and t.DeptNo in(11,12,13,21,22,23,41,42,51,54,57,63,37)
  group by t.transdate, t.masterpayrolldate,e.PrimarySite, e.PrimaryDept
  having sum(t.regHours) >= 15.50
  order by t.Transdate
END
ELSE
BEGIN
  Insert into #tmpTrans(TransDate, ShiftSegment, masterpayrolldate, PrimarySite, PRimaryDept, MaxSpan, TotWorked)
  select t.TransDate, 0, t.masterpayrolldate, e.PrimarySite, e.PrimaryDept,
  MaxSpan = cast(0 as int), TotWorked = Sum(t.regHours)
  from [TimeHistory].[dbo].[tblTimeHistDetail] as t
  Inner join TimeCurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  where t.client = @Client 
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate = @PPED
  and t.ssn = @SSN
  and t.ClockadjustmentNo in('',' ','1','8')
  group by t.transdate, t.masterpayrolldate,e.PrimarySite, e.PrimaryDept
  having sum(t.regHours) >= 15.00
  order by t.Transdate
END

Set @RecordCount = (Select count(*) from #tmpTrans)

--IF @RecordCount = 0
--  Return

-- First Set IN and OUT Classes to indicate Lunch Punches for this time card. 
-- We have to do this every time because the old trans clocks do not set this
-- value.
-- 

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
and t.TransDate in(Select TransDate from #tmpTrans)
order by TransDate, ClockAdjustmentNo, ClockInTime

SET @savClockOutTime = NULL
SET @ShiftSegment = 1
Set @RecordCount = 0

OPEN cTHD1

FETCH NEXT FROM cTHD1 INTO @RecordID, @ClockInTime, @ClockOutTime, @InClass, @OutClass, @AdjNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Set @RecordCount = @RecordCount + 1
		IF @AdjNo <> '' 
		BEGIN
      Update TimeHistory..tblTimeHistDetail Set InClass = 'A',CountAsOT = @ShiftSegment where recordid = @recordID and isnull(InClass,'') <> 'A'
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
      IF @DiffMins >= 15 and @DiffMins <= 90 
      BEGIN
        -- Set InClass to "L" ( Lunch punch )
        Update TimeHistory..tblTimeHistDetail Set InClass = 'L',CountAsOT = @ShiftSegment where recordid = @recordID 
        Update TimeHistory..tblTimeHistDetail Set OutClass = 'L', BillOTRateOverride = @DiffMins,CountAsOT = @ShiftSegment where recordid = isnull(@savRecordID,0) 
      END
      IF @DiffMins >= 0 and @DiffMins < 15
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

Update TimeHistory..tblTimeHistDetail Set OutClass = 'S' where recordid = isnull(@savRecordID,0) 

-- Remove the days that are over 15 hours and reset to days and shift segments within the day that are over 15 hours.
--
Delete from #tmpTrans

IF @GroupCode = 730029
BEGIN
  -- For BOONE only include RN and LPN departments.
  --
  Insert into #tmpTrans(TransDate, Shiftsegment, masterpayrolldate, PrimarySite, PRimaryDept, MaxSpan, TotWorked)
  select t.TransDate, isnull(t.CountAsOT,0), t.masterpayrolldate, e.PrimarySite, e.PrimaryDept,
  MaxSpan = cast(0 as int), TotWorked = Sum(t.regHours)
  from [TimeHistory].[dbo].[tblTimeHistDetail] as t
  Inner join TimeCurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  where t.client = @Client 
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate = @PPED
  and t.ssn = @SSN
  and t.ClockadjustmentNo in('',' ','1','8')
--  and t.DeptNo in(11,12,13,21,22,23,41,42,51,54,57,63,37)
  group by t.transdate, isnull(CountAsOT,0), t.masterpayrolldate,e.PrimarySite, e.PrimaryDept
  having sum(t.regHours) >= 15.50
  order by t.Transdate
END
ELSE
BEGIN
  Insert into #tmpTrans(TransDate, ShiftSegment, masterpayrolldate, PrimarySite, PRimaryDept, MaxSpan, TotWorked)
  select t.TransDate, isnull(t.CountAsOT,0), t.masterpayrolldate, e.PrimarySite, e.PrimaryDept,
  MaxSpan = cast(0 as int), TotWorked = Sum(t.regHours)
  from [TimeHistory].[dbo].[tblTimeHistDetail] as t
  Inner join TimeCurrent..tblEmplNames as e
  on e.client = t.client
  and e.groupcode = t.groupcode
  and e.ssn = t.ssn
  where t.client = @Client 
  and t.groupcode = @GroupCode
  and t.payrollperiodenddate = @PPED
  and t.ssn = @SSN
  and t.ClockadjustmentNo in('',' ','1','8')
  group by t.transdate, isnull(t.CountAsOT,0), t.masterpayrolldate,e.PrimarySite, e.PrimaryDept
  having sum(t.regHours) >= 15.00
  order by t.Transdate
END

Set @RecCount = 0
Set @HalfTimeAdjCount = 0
-- =============================================
-- Determine the dates that get a half time adjustment.
--
-- =============================================
DECLARE cHalftime CURSOR
READ_ONLY
FOR select TransDate, MasterPayrollDate, PrimarySite, PrimaryDept from #tmpTrans

OPEN cHalftime

FETCH NEXT FROM cHalftime into @TransDate, @MPD, @SiteNo, @deptNo
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    Set @RecordID = NULL
    SELECT @RecordId = recordID from TimeHistory..tblTimeHistdetail
      where client = @Client
        and groupcode = @GroupCode
        and Payrollperiodenddate = @PPED
	      and TransDate = @TransDate
        and ssn = @SSN
        and ClockADjustmentNo = @AdjCode
        --and UserCode = 'SYS' 
        and Hours = 8.00


    IF isnull(@RecordID,0) = 0 
    BEGIN
      Set @RecCount = @RecCount + 1
      EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @Adjcode, 'HALFTIM', 8.00, 0.00, @TransDate, @MPD, 'SYS', 'N'
      --Print 'Added half time for: ' + convert(varchar(12), @TransDate, 101)
    END
    Set @HalfTimeAdjCount = @HalfTimeAdjCount + 1
	END
	FETCH NEXT FROM cHalftime into @TransDate, @MPD, @SiteNo, @deptNo
END

CLOSE cHalftime
DEALLOCATE cHalftime

DROP TABLE #tmpTrans

IF @RecCount = 0 and @HalfTimeAdjCount > 0 
BEGIN
  -- No NEW Half time adjustments were added. 
  -- And there is at least one HalfTime adj on the card. 
  -- So back out any OT based on the amount
  -- of Half time adjustments added.
  --
  -- @TotWorked = OT Hours to back out. @totOT_Hours = TOTAL OT for the week
  
  Select @TotWorked = sum(case when ClockAdjustmentNo = @AdjCode then Hours else 0.00 end), 
         @totOT_Hours = Sum(OT_Hours) 
  from Timehistory..tblTimeHistdetail where client = @CLient and groupcode = @groupcode and payrollperiodenddate = @PPED and ssn = @SSN

  IF @totOT_Hours > 0 and @totWorked > 0
  BEGIN
    -- Need to back out OT because we have some on the card and we have half time ( daily OT )
    -- 
    -- Build a cusor and back out the hours.
    --
    DECLARE cthd CURSOR
    READ_ONLY
    FOR 
    Select RecordID, Hours, RegHours, OT_Hours, PayRate from TimeHistory..tblTimeHistdetail
      where client = @CLient and groupcode = @groupcode and payrollperiodenddate = @PPED and ssn = @SSN
        and OT_Hours <> 0.00
        and isnull(Holiday,'0') <> '1'
    order by TransDate, ClockAdjustmentNo, InDay, InTime

    OPEN cthd
    
    FETCH NEXT FROM cthd INTO @RecordID, @Hours, @RegHours, @OT_Hours, @PayRate
    WHILE (@@fetch_status <> -1)
    BEGIN
    	IF (@@fetch_status <> -2)
    	BEGIN
        
        IF @OT_Hours > @TotWorked and @TotWorked > 0
        BEGIN
          SET @OT_Hours = @OT_Hours - @TotWorked
          SET @RegHours = @RegHours + @TotWorked
          SET @TotWorked = 0
          Update TimeHistory..tblTimeHistDetail
            Set OT_Hours = @OT_Hours,
                RegHours = @RegHours,
                RegDollars  = round(@RegHours * @PayRate,2),
                OT_Dollars  = round(@OT_Hours * @PayRate,2),
                RegDollars4 = round(@RegHours * @PayRate,4),
                OT_Dollars4 = round(@OT_Hours * @PayRate,4)
          Where RecordID = @RecordID
        END
        ELSE
        BEGIN
          IF @OT_Hours <> 0 and @TotWorked > @OT_Hours and @TotWorked > 0
          BEGIN
            SET @TotWorked = @TotWorked - @OT_Hours
            SET @RegHours = @RegHours + @OT_Hours
            SET @OT_Hours = 0.00
            Update TimeHistory..tblTimeHistDetail
              Set OT_Hours = @OT_Hours,
                  RegHours = @RegHours,
                  RegDollars  = round(@RegHours * @PayRate,2),
                  OT_Dollars  = round(@OT_Hours * @PayRate,2),
                  RegDollars4 = round(@RegHours * @PayRate,4),
                  OT_Dollars4 = round(@OT_Hours * @PayRate,4)
            Where RecordID = @RecordID
          END
        END
    	END
    	FETCH NEXT FROM cthd INTO @RecordID, @Hours, @RegHours, @OT_Hours, @PayRate
    END
    
    CLOSE cthd
    DEALLOCATE cthd
  END
END

Select RecCount = @RecCount 










