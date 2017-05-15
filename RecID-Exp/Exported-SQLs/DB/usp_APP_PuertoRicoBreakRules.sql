CREATE PROCEDURE [dbo].[usp_APP_PuertoRicoBreakRules]
(
  	@Client 				VARCHAR(4)
	, @GroupCode  	  INT
 	, @PPED   				DATETIME
	, @SSN					  INT	
) AS


SET NOCOUNT ON

DECLARE @MinTHDRecordID         BIGINT  --< @MinTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >-- 
DECLARE @TmpRecordID            INT 
DECLARE @SiteNo                 INT
DECLARE @DeptNo                 INT
DECLARE @MealPeriod             NUMERIC(7, 2)
DECLARE @Hours                  NUMERIC(7, 2)
DECLARE @TransDate              DATETIME
DECLARE @InTime                 DATETIME
DECLARE @OutTime                DATETIME
DECLARE @ActualInTime           DATETIME
DECLARE @BreakClockAdjustmentNo VARCHAR(3)  --< Srinsoft 08/24/2015 Changed @BreakClockAdjustmentNo VARCHAR(1) to VRACHAR(3) for Clockadjustemntno >--
DECLARE @NextPunch              DATETIME
DECLARE @NextPunchMinutes       NUMERIC(7, 2)
DECLARE @NextPunchHours         NUMERIC(7, 2)
DECLARE @Penalty                NUMERIC(5, 2) 
DECLARE @TmpPenalty             NUMERIC(5, 2) 
DECLARE @LateLunchID            INT
DECLARE @NoLunchID              INT
DECLARE @ShortLunchID           INT
DECLARE @PenaltyID              INT
DECLARE @BreakType              VARCHAR(100)
DECLARE @DailyHours             NUMERIC(5, 2)
DECLARE @AfterLunchPunch        CHAR(1)
DECLARE @Tmp                    VARCHAR(100)
DECLARE @ContiguousPunchGap     INT 
DECLARE @ContigInTime           DATETIME
DECLARE @ContigOutTime          DATETIME
DECLARE @ContigHours            NUMERIC(5, 2)
DECLARE @ContigRecordID         INT 
DECLARE @ContigFound            CHAR(1)
DECLARE @BreakRuleID            INT 
DECLARE @DisableBreakExceptions VARCHAR(1)

SELECT  @BreakRuleID = WTE_Spreadsheet_Breaks,
        @DisableBreakExceptions = DisableBreakExceptions
FROM TimeCurrent.dbo.tblEmplNames
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN

SELECT @LateLunchID = RecordID
FROM TimeHistory.dbo.tblWTE_BreakCodes
WHERE Client = @Client
AND BreakErrorFieldName = 'LLUN'

SELECT @NoLunchID = RecordID
FROM TimeHistory.dbo.tblWTE_BreakCodes
WHERE Client = @Client
AND BreakErrorFieldName = 'NBUN'

SELECT @ShortLunchID = RecordID
FROM TimeHistory.dbo.tblWTE_BreakCodes
WHERE Client = @Client
AND BreakErrorFieldName = 'SBUN'

SET @BreakType = 'Lunch'
SET @ContiguousPunchGap = 5 -- Minutes
SELECT @BreakClockAdjustmentNo = ClockAdjustmentNo FROM TimeCurrent.dbo.tblAdjCodes
WHERE Client = @Client AND GroupCode = @GroupCode AND AdjustmentName = 'PR Brk';

CREATE TABLE #tmpPunch
(
  RecordID        INT IDENTITY(1,1),
  MinTHDRecordID  BIGINT,  --< @MinTHDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
  SiteNo          INT,
  DeptNo          INT,
  MealPermit      NUMERIC(7, 2),
  [Hours]         NUMERIC(7, 2),
  TransDate       DATETIME,  
  ActualInTime    DATETIME,
  InTime          DATETIME,
  OutTime         DATETIME
)

CREATE TABLE #tmpBreakAlerts
(
  SiteNo          INT,
  DeptNo          INT,					 				
  TransDate       DATETIME,			
  [In]            DATETIME,							
  [Out]           DATETIME,
  Position        INT,	
  [Hours]         NUMERIC(5, 2),	
  BreakCode       INT
)

CREATE TABLE #tmpBreakExceptionSummary_Old
(
  TransDate       DATETIME,			
  BreakCode       VARCHAR(100)
)

CREATE TABLE #tmpBreakExceptionSummary_New
(
  TransDate       DATETIME,			
  BreakCode       VARCHAR(100)  
)

CREATE TABLE #tmpBreakExceptionSummary_Diffs
(
  TransDate       DATETIME,			
  BreakCode       VARCHAR(100)
)

DELETE FROM TimeHistory..tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND ClockAdjustmentNo = @BreakClockAdjustmentNo

-- Intentionally waiting until after the existing break penalties have been deleted
IF ((ISNULL(@BreakRuleID, 0) = 0 OR @DisableBreakExceptions = '1') AND @Client <> 'OLST') -- Adecco don't have a default break rule therefore this is necessary
BEGIN
	RETURN
END

INSERT INTO #tmpPunch(MinTHDRecordID, SiteNo, DeptNo, MealPermit, [Hours], TransDate, InTime, ActualInTime, OutTime)
SELECT MIN(thd.RecordID), thd.SiteNo, thd.DeptNo, 0, SUM(thd.[Hours]), thd.TransDate, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), thd.ActualInTime, dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)
FROM TimeHistory.dbo.tblTimeHistDetail thd
WHERE thd.Client = @Client
AND thd.GroupCode = @GroupCode
AND thd.PayrollPeriodEndDate = @PPED
AND thd.SSN = @SSN
AND thd.InTime <> thd.OutTime -- Ignore hourly adjustments
AND thd.InDay <> '10'
AND thd.OutDay <> '10'
AND thd.Hours <> 0
GROUP BY thd.SiteNo, thd.DeptNo, thd.TransDate, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), thd.ActualInTime, dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)
ORDER BY thd.TransDate, thd.ActualInTime, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime)

----------------------------
-- Handle contiguous punches
----------------------------
--SELECT * FROM #tmpPunch
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, MinTHDRecordID, SiteNo, DeptNo, MealPermit, [Hours], TransDate, InTime, ActualInTime, OutTime
FROM #tmpPunch
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @TmpRecordID, @MinTHDRecordID, @SiteNo, @DeptNo, @MealPeriod, @Hours, @TransDate, @InTime, @ActualInTime, @OutTime

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT CAST(@InTime AS VARCHAR) + ' - ' + CAST(@OutTime AS VARCHAR)
  SET @ContigInTime = NULL
  SET @ContigOutTime = NULL
  SET @ContigHours = NULL
  SET @ContigRecordID = NULL
  SET @ContigFound = '0'

	/* Added to remove duplicates from the tblemplassignments join to retrieve the mealbreak MB 2015-10-12*/
	SELECT TOP 1 @MealPeriod = ea.MealDuration 
	FROM TimeCurrent.dbo.tblEmplAssignments ea 
	WHERE ea.Client =@Client
		AND ea.GroupCode = @GroupCode
		AND ea.SSN = @SSN
		AND ea.DeptNo = @DeptNo
		AND ea.WorkState = 'PR'
	ORDER BY ea.EndDate DESC   
  
  SELECT  @ContigInTime = InTime,
          @ContigOutTime = OutTime,
          @ContigHours = Hours,
          @ContigRecordID = RecordID
  FROM #tmpPunch
  WHERE DATEDIFF(mi, @OutTime, InTime) < @ContiguousPunchGap
  AND RecordID <> @TmpRecordID
  AND InTime >= @OutTime
  
  WHILE (@ContigInTime IS NOT NULL)
  BEGIN
    PRINT 'Contig found: ' + CAST(@ContigInTime AS VARCHAR)
    UPDATE #tmpPunch
    SET OutTime = @ContigOutTime,
        [Hours] = [Hours] + @ContigHours
    WHERE RecordID = @TmpRecordID
    
    SET @OutTime = @ContigOutTime
    SET @Hours = @Hours + @ContigHours

    DELETE FROM #tmpPunch WHERE RecordID = @ContigRecordID
    
    SET @ContigInTime = NULL
    SET @ContigOutTime = NULL
    SET @ContigHours = NULL
    SET @ContigRecordID = NULL
    SET @ContigFound = '0'
    
    SELECT  @ContigInTime = InTime,
            @ContigOutTime = OutTime,
            @ContigHours = Hours,
            @ContigRecordID = RecordID
    FROM #tmpPunch
    WHERE DATEDIFF(mi, @OutTime, InTime) < @ContiguousPunchGap
    AND RecordID <> @TmpRecordID
    AND InTime >= @OutTime        
  END

	FETCH NEXT FROM punchCursor
	INTO @TmpRecordID, @MinTHDRecordID, @SiteNo, @DeptNo, @MealPeriod, @Hours, @TransDate, @InTime, @ActualInTime, @OutTime
END

CLOSE punchCursor
DEALLOCATE punchCursor	
--SELECT * FROM #tmpPunch
------------------------------------------------------
-- Process and create adjustments and break exceptions
------------------------------------------------------
DECLARE punchCursor CURSOR FOR
SELECT RecordID, MinTHDRecordID, SiteNo, DeptNo, MealPermit, [Hours], TransDate, InTime, ActualInTime, OutTime
FROM #tmpPunch
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @TmpRecordID, @MinTHDRecordID, @SiteNo, @DeptNo, @MealPeriod, @Hours, @TransDate, @InTime, @ActualInTime, @OutTime

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT 'InTime: ' + CAST(@InTime AS VARCHAR)
  PRINT 'Hours: ' + CAST(@Hours AS VARCHAR)

	/* Added to remove duplicates from the tblemplassignments join to retrieve the mealbreak MB 2015-10-12*/
	SELECT TOP 1 @MealPeriod = ea.MealDuration 
	FROM TimeCurrent.dbo.tblEmplAssignments ea 
	WHERE ea.Client =@Client
		AND ea.GroupCode = @GroupCode
		AND ea.SSN = @SSN
		AND ea.DeptNo = @DeptNo
		AND ea.WorkState = 'PR'
	ORDER BY ea.EndDate DESC
	  
  SET @Penalty = 0
  SET @TmpPenalty = 0
  SET @DailyHours = 0

  SELECT TOP 1 @NextPunch = InTime
  FROM #tmpPunch
  WHERE TransDate = @TransDate
  AND InTime > @OutTime
  ORDER BY InTime
  
  PRINT @OutTime
  PRINT @NextPunch
  SET @NextPunchMinutes = DATEDIFF(mi, @OutTime, @NextPunch)
  SET @NextPunchHours = @NextPunchMinutes / 60

  -- BEGIN Short Section
  PRINT '@NextPunchHours: ' + CAST(@NextPunchHours AS VARCHAR)
  PRINT '@MealPeriod: ' + CAST(@MealPeriod AS VARCHAR)    
  IF (@MealPeriod > @NextPunchHours AND @NextPunchHours > 0)
  BEGIN
    PRINT 'PUNCH OK, SHORT LUNCH'
    PRINT '@NextPunchHours: ' + CAST(@NextPunchHours AS VARCHAR)
    PRINT '@MealPeriod: ' + CAST(@MealPeriod AS VARCHAR)
    SET @Penalty = @MealPeriod - @NextPunchHours
    PRINT 'Penalty1: ' + CAST(@Penalty AS VARCHAR)
    
    INSERT INTO #tmpBreakAlerts (SiteNo, DeptNo, TransDate,	[In],	[Out], Position, [Hours],	BreakCode)
    VALUES(@SiteNo, @DeptNo, @TransDate, @InTime, @OutTime, 0, @Hours, @ShortLunchID)
  END  
  -- END Short Section
  
  -- Punch is less than 5 hours and we have minimum gap until next punch - NO ACTION
  IF (@Hours <= 5)
  BEGIN
    PRINT '(@Hours <= 5)'

--    ELSE
--    BEGIN
      PRINT 'DO NOTHING'
--    END
  END
  
  WHILE (@Hours > 5)
  BEGIN
    SET @AfterLunchPunch = '0'
    -- Segment more than 5 hours
    IF (@Hours > 5)
    BEGIN
      PRINT 'Segment > 5'
      PRINT '@MealPeriodMinutes = ' + CAST(@MealPeriod AS VARCHAR)
      SET @TmpPenalty = @Hours - 5
      IF (@TmpPenalty > @MealPeriod)
      BEGIN
        SET @TmpPenalty = @MealPeriod
      END
      
      IF (@TmpPenalty = @MealPeriod) --(@NextPunchHours IS NULL)
      BEGIN
        SET @PenaltyID = @NoLunchID
        PRINT 'No Lunch'
      END
      ELSE
      BEGIN
        SET @PenaltyID = @LateLunchID
        PRINT 'Late Lunch'
      END
      
      -- Missing Lunch
      IF (@MealPeriod = 0.5)
      BEGIN        
        -- If the employee worked less than 10 hours in the day the penalty associated to the second segment (after lunch) is waived.
        SELECT @DailyHours = SUM([Hours])
        FROM #tmpPunch
        WHERE TransDate = @TransDate
        
        IF EXISTS(SELECT 1
                  FROM #tmpPunch
                  WHERE TransDate = @TransDate
                  AND InTime < @InTime)
        BEGIN
        
          SELECT @Tmp = InTime
          FROM #tmpPunch
                  WHERE TransDate = @TransDate
                  AND InTime < @InTime
          PRINT '@Tmp: ' + @Tmp
          SET @AfterLunchPunch = '1'
        END
        
        IF (@DailyHours <= 10 AND @AfterLunchPunch = '1')
        BEGIN
          PRINT '1/2 meal permit waived'
        END
        ELSE
        BEGIN
          PRINT '1/2 meal permit NOT waived'
          INSERT INTO #tmpBreakAlerts (SiteNo, DeptNo, TransDate,	[In],	[Out], Position, [Hours],	BreakCode)
          VALUES(@SiteNo, @DeptNo, @TransDate, @InTime, @OutTime, 0, @Hours, @PenaltyID)            
          
          SET @Penalty = @Penalty + @TmpPenalty
          PRINT 'Penalty2: ' + CAST(@Penalty AS VARCHAR)            
        END          
      END
      ELSE
      BEGIN
        INSERT INTO #tmpBreakAlerts (SiteNo, DeptNo, TransDate,	[In],	[Out], Position, [Hours],	BreakCode)
        VALUES(@SiteNo, @DeptNo, @TransDate, @InTime, @OutTime, 0, @Hours, @PenaltyID)
        
        SET @Penalty = @Penalty + @TmpPenalty
        PRINT 'Penalty2: ' + CAST(@Penalty AS VARCHAR)          
      END
    END
     
    SET @Hours = @Hours - (5 + @MealPeriod)
    
  END
  --INSERT INTO TimeHistory.dbo.tblTimeHistDetail
  IF (@Penalty <> 0)
  BEGIN
    --EXEC TimeHistory.dbo.usp_APP_XLSImport_Adjustment_Insert_THD @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @BreakClockAdjustmentNo, 'BRK PEN', @Penalty, 0.00, @TransDate, @PPED, 'SYS','Y','N','Y'
    INSERT INTO TimeHistory..tblTimeHistDetail
            ( Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, 
              BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, Hours, Dollars, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
              TransType, Changed_DeptNo, Changed_InPunch, Changed_OutPunch, AgencyNo, InSrc, OutSrc, DaylightSavTime, Holiday, 
              RegHours, OT_Hours, DT_Hours, RegDollars, OT_Dollars, DT_Dollars, RegBillingDollars, OTBillingDollars, DTBillingDollars, CountAsOT, RegDollars4, OT_Dollars4, DT_Dollars4, 
              RegBillingDollars4, OTBillingDollars4, DTBillingDollars4, xAdjHours, AprvlStatus, AprvlStatus_UserID, AprvlStatus_Date, AprvlAdjOrigRecID, 
              HandledByImporter, AprvlAdjOrigClkAdjNo, ClkTransNo, ShiftDiffClass, AllocatedRegHours, AllocatedOT_Hours, AllocatedDT_Hours, Borrowed, UserCode, 
              DivisionID, CostID, ShiftDiffAmt, OutUserCode, ActualInTime, ActualOutTime, InSiteNo, OutSiteNo, InVerified, OutVerified, InClass, OutClass, InTimestamp, 
              outTimestamp, CrossoverStatus, CrossoverOtherGroup, InRoundOFF, OutRoundOFF, AprvlStatus_Mobile)
    SELECT    Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, 
              BillOTRateOverride, PayRate, ShiftNo, InDay, InTime = '1899-12-30 00:00:00.000', InDay /*OutDay*/, OutTime = '1899-12-30 00:00:00.000', @Penalty, Dollars, ClockAdjustmentNo = @BreakClockAdjustmentNo, AdjustmentCode, AdjustmentName = 'BRK PEN', 
              TransType = '0', Changed_DeptNo, Changed_InPunch, Changed_OutPunch, AgencyNo, InSrc, OutSrc, DaylightSavTime, Holiday, 
              RegHours = 0, OT_Hours = 0, DT_Hours = 0, RegDollars = 0, OT_Dollars = 0, DT_Dollars = 0, RegBillingDollars = 0, OTBillingDollars = 0, DTBillingDollars = 0, CountAsOT, RegDollars4 = 0, OT_Dollars4 = 0, DT_Dollars4 = 0, 
              RegBillingDollars4, OTBillingDollars4, DTBillingDollars4, xAdjHours, AprvlStatus, AprvlStatus_UserID, AprvlStatus_Date, AprvlAdjOrigRecID, 
              HandledByImporter, AprvlAdjOrigClkAdjNo, ClkTransNo, ShiftDiffClass = NULL, AllocatedRegHours = 0, AllocatedOT_Hours = 0, AllocatedDT_Hours = 0, Borrowed, UserCode = 'SYS', 
              DivisionID, CostID, ShiftDiffAmt, OutUserCode, ActualInTime = NULL, ActualOutTime = NULL, InSiteNo, OutSiteNo, InVerified, OutVerified, InClass, OutClass, InTimestamp, 
              outTimestamp, CrossoverStatus, CrossoverOtherGroup, InRoundOFF, OutRoundOFF, AprvlStatus_Mobile
    FROM TimeHistory.dbo.tblTimeHistDetail
    WHERE RecordID = @MinTHDRecordID
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @TmpRecordID, @MinTHDRecordID, @SiteNo, @DeptNo, @MealPeriod, @Hours, @TransDate, @InTime, @ActualInTime, @OutTime
END

-- Try to figure out what days have differences and only regenerate the codes for those days
INSERT INTO #tmpBreakExceptionSummary_Old(TransDate, BreakCode)
SELECT TransDate, bc.BreakType
FROM TimeHistory..tblWTE_Spreadsheet_Breaks sb
LEFT JOIN TimeHistory..tblWTE_BreakCodes bc
ON bc.RecordId = sb.BreakCode
WHERE sb.Client = @Client
AND sb.GroupCode = @GroupCode
AND sb.SSN = @SSN
AND sb.PayrollPeriodEndDate = @PPED
AND sb.Position = 0

INSERT INTO #tmpBreakExceptionSummary_New(TransDate, BreakCode)
SELECT TransDate, bc.BreakType
FROM #tmpBreakAlerts ba
LEFT JOIN TimeHistory..tblWTE_BreakCodes bc
ON bc.RecordId = ba.BreakCode

INSERT INTO #tmpBreakExceptionSummary_Diffs(TransDate, BreakCode)
SELECT * FROM #tmpBreakExceptionSummary_Old
EXCEPT
SELECT * FROM #tmpBreakExceptionSummary_New

INSERT INTO #tmpBreakExceptionSummary_Diffs(TransDate, BreakCode)
SELECT * FROM #tmpBreakExceptionSummary_New
EXCEPT
SELECT * FROM #tmpBreakExceptionSummary_OLD

DELETE FROM TimeHistory..tblWTE_Spreadsheet_Breaks
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND Position = 0
AND TransDate IN (SELECT DISTINCT TransDate FROM #tmpBreakExceptionSummary_Diffs)

INSERT INTO tblWTE_SpreadSheet_Breaks(Client, GroupCode, PayrollPeriodEndDate, SiteNo, DeptNo, SSN,						
                                      BreakType, TransDate, [In], [Out], Position, Hours, BreakCode)
SELECT  @Client, @GroupCode, @PPED, SiteNo, DeptNo, @SSN,
        @BreakType, TransDate, [In], [Out], 0, [Hours], BreakCode
FROM #tmpBreakAlerts
WHERE TransDate IN (SELECT DISTINCT TransDate FROM #tmpBreakExceptionSummary_Diffs)
AND BreakCode IS NOT NULL
	
CLOSE punchCursor
DEALLOCATE punchCursor	
	
DROP TABLE #tmpPunch

RETURN



