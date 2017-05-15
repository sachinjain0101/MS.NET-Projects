Create PROCEDURE [dbo].[usp_APP_PuertoRicoOTRules]
(
    @EmployeeType   VARCHAR(15)	
  , @Client 				VARCHAR(4)
	, @GroupCode  	  INT
 	, @PPED   				DATETIME
	, @SSN					  INT	
) AS

/*DECLARE @EmployeeType   VARCHAR(15)	
DECLARE @Client 				VARCHAR(4)
DECLARE @GroupCode  	  INT
DECLARE @PPED   				DATETIME
DECLARE @SSN					  INT	
SET @EmployeeType = '379_FLEX'
SET @Client = 'KELL'
SET @GroupCode = 3288
SET @PPED = '3/17/2013'
SET @SSN = 63916*/

SET NOCOUNT ON

DECLARE @THDRecordID                BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >-- 
DECLARE @DailySummaryID             INT 
DECLARE @SiteNo                     INT
DECLARE @DeptNo                     INT
DECLARE @Hours                      NUMERIC(7, 2)
DECLARE @TransDate                  DATETIME
DECLARE @InTime                     DATETIME
DECLARE @OutTime                    DATETIME
DECLARE @ActualInTime               DATETIME
DECLARE @NextPunch                  DATETIME
DECLARE @NextPunchMinutes           NUMERIC(7, 2)
DECLARE @NextPunchHours             NUMERIC(7, 2)
DECLARE @DailyHours                 NUMERIC(5, 2)
DECLARE @AfterLunchPunch            CHAR(1)
DECLARE @Tmp                        VARCHAR(100)
DECLARE @ContiguousPunchGap         INT 
DECLARE @ContigInTime               DATETIME
DECLARE @ContigOutTime              DATETIME
DECLARE @ContigHours                NUMERIC(5, 2)
DECLARE @ContigRecordID             INT 
DECLARE @ContigFound                CHAR(1)
DECLARE @PrevOutDateTime            DATETIME
DECLARE @LunchStart                 DATETIME
DECLARE @LunchEnd                   DATETIME
DECLARE @MaxGapBetweenPunches       INT 
DECLARE @PrevTransDate              DATETIME
DECLARE @PrevDailySummaryID         INT 
DECLARE @TotalWeeklyHours           NUMERIC(7, 2)
DECLARE @WeeklyBalance              NUMERIC(7, 2)
DECLARE @FirstPunchOfTheDay         VARCHAR(1)

DECLARE @csr_RecordID               INT
DECLARE @csr_TransDate              DATETIME
DECLARE @csr_ShiftStartDateTime     DATETIME
DECLARE @csr_ShiftEndDateTime       DATETIME
DECLARE @csr_LunchStartDateTime     DATETIME
DECLARE @csr_LunchEndDateTime       DATETIME
DECLARE @csr_DailyHours             NUMERIC(5, 2)
DECLARE @csr_Calculated_OT          NUMERIC(5, 2)
DECLARE @csr_Calculated_DT          NUMERIC(5, 2)
DECLARE @WeeklySum                  NUMERIC(7, 2)
DECLARE @WeeklyAppliesTo            VARCHAR(2)
DECLARE @DailyAppliesTo             VARCHAR(2)
DECLARE @OT_DT_Amount               NUMERIC(7, 2)

DECLARE @24HrCycle_NoRest           CHAR(1)
DECLARE @24HrCycle_GT3HrsEarly      CHAR(1)
DECLARE @24HrCycleLunch_GT3HrsLate  VARCHAR(1)
DECLARE @24HourCycleAmount          NUMERIC(5, 2)
DECLARE @YesterdayStart             DATETIME 
DECLARE @YesterdayEnd               DATETIME 
DECLARE @YesterdayLunchStart        DATETIME
DECLARE @YesterdayLunchEnd          DATETIME
DECLARE @YesterdayLunchDuration     NUMERIC(5, 2)
DECLARE @YesterdayHours             NUMERIC(7, 2)
DECLARE @YesterdaysOTDT             NUMERIC(5, 2)
DECLARE @LateStartDuration          NUMERIC(5, 2)
DECLARE @WeeklyMode                 VARCHAR(10)
DECLARE @24HourCyclePyramidBalance  NUMERIC(5, 2)
DECLARE @NoOT                       VARCHAR(1)

SET @WeeklySum = 0
SET @WeeklyAppliesTo = 'DT'
SET @DailyAppliesTo = 'OT'
SET @FirstPunchOfTheDay = '1'
SET @WeeklyMode = 'SPREAD'

--SELECT @NoOT = CASE WHEN hen.NoOT IS NOT NULL THEN hen.NoOT ELSE ISNULL(en.NoOT, '0') END /*MB*/
SELECT @NoOT = COALESCE(hen.NoOT ,en.NoOT, '0')
FROM TimeCurrent..tblEmplNames en
INNER JOIN TimeHistory..tblEmplNames hen
ON hen.Client = en.Client
AND hen.GroupCode = en.GroupCode
AND hen.SSN = en.SSN
AND hen.PayrollPeriodEndDate = @PPED
WHERE en.Client = @Client
AND en.GroupCode = @GroupCode
AND en.SSN = @SSN

IF (ISNULL(@NoOT, 0) = 1)
BEGIN
  RETURN
END

IF (@EmployeeType = '379_FLSA')
BEGIN
  SET @WeeklyAppliesTo = 'OT'
END
IF (@EmployeeType = '379_Daily_DT')
BEGIN
  SET @DailyAppliesTo = 'DT'
  SET @EmployeeType = '379'
END
CREATE TABLE #tmpDailySummary
(
  RecordID            INT IDENTITY(1,1),
  TransDate           DATETIME,  
  ShiftStartDateTime  DATETIME,
  LunchStartDateTime  DATETIME,
  LunchEndDateTime    DATETIME,  
  ShiftEndDateTime    DATETIME,
  PreLunchHours       NUMERIC(5, 2),
  PostLunchHours      NUMERIC(5, 2),
  DailyHours          NUMERIC(7, 2),  
  Calculated_OT       NUMERIC(5, 2),
  Calculated_DT       NUMERIC(5, 2)
)

CREATE TABLE #tmpPunches(RecordID INT IDENTITY(1,1), DailySummaryID INT, InDateTime DATETIME, OutDateTime DATETIME, THDRecordID BIGINT)  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
CREATE TABLE #tmpLunches(RecordID INT IDENTITY(1,1), DailySummaryID INT, LunchStartDateTime DATETIME, LunchEndDateTime DATETIME)
--CREATE TABLE #tmpPreLunchPunches(RecordID INT IDENTITY(1,1), DailySummaryID INT, InDateTime DATETIME, OutDateTime DATETIME, THDRecordID INT)
--CREATE TABLE #tmpPostLunchPunches(RecordID INT IDENTITY(1,1), DailySummaryID INT, InDateTime DATETIME, OutDateTime DATETIME, THDRecordID INT)

UPDATE TimeHistory.dbo.tblTimeHistDetail
SET RegHours = Hours,
    OT_Hours = 0,
    DT_Hours = 0
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SSN = @SSN

PRINT '======================'
PRINT 'Summarize THD'
PRINT '======================'
DECLARE punchCursor CURSOR FOR


SELECT thd.RecordID, thd.TransDate, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime), thd.Hours
FROM TimeHistory.dbo.tblTimeHistDetail thd
WHERE thd.Client = @Client
AND thd.GroupCode = @GroupCode
AND thd.PayrollPeriodEndDate = @PPED
AND thd.SSN = @SSN
AND thd.InTime <> thd.OutTime -- Ignore hourly adjustments
AND thd.InDay <> '10'
AND thd.OutDay <> '10'
AND thd.Hours <> 0
AND EXISTS (	SELECT 1
		FROM TimeCurrent.dbo.tblEmplAssignments ea
		WHERE ea.Client = thd.Client
		AND ea.GroupCode = thd.GroupCode
		AND ea.SSN = thd.SSN
		AND ea.DeptNo = thd.DeptNo
		AND ea.WorkState = 'PR')
ORDER BY thd.TransDate, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime), dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime)
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @THDRecordID, @TransDate, @InTime, @OutTime, @Hours

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT 'THDRecordID: ' + CAST(@THDRecordID AS VARCHAR) + '; ' + CAST(@InTime AS VARCHAR) + ' - ' + CAST(@OutTime AS VARCHAR) + ' = ' + CAST(@Hours AS varchar)
  
  SET @DailySummaryID = NULL
  
  SELECT @DailySummaryID = RecordID
  FROM #tmpDailySummary
  WHERE TransDate = @TransDate
  
  IF (@DailySummaryID IS NULL)
  BEGIN
    -- New Trans Date
    IF (@PrevDailySummaryID IS NOT NULL)
    BEGIN      
      INSERT INTO #tmpLunches(DailySummaryID, LunchStartDateTime, LunchEndDateTime)
      VALUES (@PrevDailySummaryID, @LunchStart, @LunchEnd)
      PRINT 'Lunch inserted: ' + CAST(@PrevDailySummaryID AS VARCHAR) + '; ' + CAST(@LunchStart AS VARCHAR) + ' - ' + CAST(@LunchEnd AS VARCHAR)
    END
    
    INSERT INTO #tmpDailySummary(TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, PreLunchHours, PostLunchHours, DailyHours, Calculated_OT, Calculated_DT)
    VALUES(@TransDate, @InTime, NULL, NULL, @OutTime, NULL, NULL, @Hours, NULL, NULL)
    SET @DailySummaryID = SCOPE_IDENTITY()    
    PRINT 'Daily Summary Created: ' + CAST(@DailySummaryID AS VARCHAR)
            
    SET @MaxGapBetweenPunches = 0
    SET @LunchStart = NULL
    SET @LunchEnd = NULL
    SET @FirstPunchOfTheDay = '1'
  END
  ELSE
  BEGIN
    UPDATE #tmpDailySummary
    SET ShiftEndDateTime = @OutTime,
        DailyHours = DailyHours + @Hours
    WHERE RecordID = @DailySummaryID    
    
    SET @FirstPunchOfTheDay = '0'
  END
  
  INSERT INTO #tmpPunches(DailySummaryID, THDRecordID, InDateTime, OutDateTime)
  VALUES (@DailySummaryID, @THDRecordID, @InTime, @OutTime)  
  
  -- Figure out what time the lunch was
  IF (@FirstPunchOfTheDay = '0')
  BEGIN
    PRINT 'Evaluate Break in time: ' + ISNULL(CAST(@PrevOutDateTime AS VARCHAR), '') + ' - ' + ISNULL(CAST(@InTime AS VARCHAR), '') + '; MaxGap = ' + ISNULL(CAST(@MaxGapBetweenPunches AS VARCHAR), '')
    IF (DATEDIFF(mi, @PrevOutDateTime, @InTime) > @MaxGapBetweenPunches)
    BEGIN
      SET @LunchStart = @PrevOutDateTime
      SET @LunchEnd = @InTime    
    END
    SET @MaxGapBetweenPunches = DATEDIFF(mi, @PrevOutDateTime, @InTime)
  END
      
  SET @PrevOutDateTime = @OutTime
  SET @PrevTransDate = @TransDate
  SET @PrevDailySummaryID = @DailySummaryID
  PRINT ''
    
	FETCH NEXT FROM punchCursor
	INTO @THDRecordID, @TransDate, @InTime, @OutTime, @Hours
END
CLOSE punchCursor
DEALLOCATE punchCursor	

-- Handle the lunch from the last day in the cursor above
INSERT INTO #tmpLunches(DailySummaryID , LunchStartDateTime, LunchEndDateTime)
VALUES (@DailySummaryID, @LunchStart, @LunchEnd)
PRINT 'Evaluate Break in time: ' + ISNULL(CAST(@PrevOutDateTime AS VARCHAR), '') + ' - ' + ISNULL(CAST(@InTime AS VARCHAR), '') + '; MaxGap = ' + ISNULL(CAST(@MaxGapBetweenPunches AS VARCHAR), '')

UPDATE ds
SET LunchStartDateTime = l.LunchStartDateTime,
    LunchEndDateTime = l.LunchEndDateTime
FROM #tmpDailySummary ds
LEFT JOIN #tmpLunches l
ON l.DailySummaryID = ds.RecordID

SELECT 'After Summarize' AS WhereAreWe, * FROM #tmpDailySummary
SELECT 'After Summarize' AS WhereAreWe, * FROM #tmpPunches
--SELECT 'After Summarize' AS WhereAreWe, * FROM #tmpPunches
--SELECT 'After Summarize' AS WhereAreWe, * FROM #tmpLunches

SELECT @TotalWeeklyHours = SUM(DailyHours)
FROM #tmpDailySummary

SET @24HourCyclePyramidBalance = @TotalWeeklyHours - 40

--SELECT * FROM #tmpPunch

/*
 2 - Weekly OT/DT   
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT 'Weekly Cursor: ' + CAST(@csr_TransDate AS VARCHAR)
  PRINT 'Weekly Sum: ' + CAST(@WeeklySum AS VARCHAR)
  PRINT 'csr_DailyHours: ' + CAST(@csr_DailyHours AS VARCHAR)
  
  IF (@WeeklySum > 40)
  BEGIN
    IF (@WeeklyAppliesTo = 'OT')
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_OT = DailyHours - ISNULL(Calculated_DT, 0)
      WHERE RecordID = @csr_RecordID
    END
    ELSE
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_DT = ISNULL(Calculated_DT, 0) + (DailyHours - ISNULL(Calculated_DT, 0))
      WHERE RecordID = @csr_RecordID    
    END
  END
  ELSE IF (@WeeklySum + @csr_DailyHours) > 40
  BEGIN
    IF (@WeeklyAppliesTo = 'OT')
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_OT = (@csr_DailyHours - (40 - @WeeklySum)) - ISNULL(Calculated_DT, 0)
      WHERE RecordID = @csr_RecordID
    END
    ELSE
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_DT = (@csr_DailyHours - (40 - @WeeklySum)) - ISNULL(Calculated_DT, 0)
      WHERE RecordID = @csr_RecordID    
    END
  END
  SET @WeeklySum = @WeeklySum + @csr_DailyHours
  
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
*/

/*
 2 - Weekly OT/DT   
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT 'Weekly Cursor: ' + CAST(@csr_TransDate AS VARCHAR)

  SET @WeeklySum = @WeeklySum + (ISNULL(@csr_DailyHours, 0) - ISNULL(@csr_Calculated_OT, 0) - ISNULL(@csr_Calculated_DT, 0))  
  
  PRINT 'Weekly Sum: ' + CAST(@WeeklySum AS VARCHAR)
  PRINT 'csr_DailyHours: ' + CAST(@csr_DailyHours AS VARCHAR)
  PRINT '@csr_Calculated_OT: ' + CAST(@csr_Calculated_OT AS VARCHAR)
  PRINT '@csr_Calculated_DT: ' + ISNULL(CAST(@csr_Calculated_DT AS VARCHAR), '')
    
  IF (@WeeklySum > 40)
  BEGIN
    PRINT 'Scenario 1'
    IF (@WeeklyAppliesTo = 'OT')
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_OT = DailyHours - ISNULL(Calculated_DT, 0)
      WHERE RecordID = @csr_RecordID
    END
    ELSE
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_DT = ISNULL(Calculated_DT, 0) + (DailyHours - ISNULL(Calculated_DT, 0))
      WHERE RecordID = @csr_RecordID    
    END
  END
  ELSE IF (@WeeklySum + @csr_DailyHours) > 40
  BEGIN
    PRINT 'Scenario 2'
    IF (@WeeklyAppliesTo = 'OT')
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_OT = (@csr_DailyHours - (40 - @WeeklySum)) - ISNULL(Calculated_DT, 0)
      WHERE RecordID = @csr_RecordID
    END
    ELSE
    BEGIN
      UPDATE #tmpDailySummary
      SET Calculated_DT = (@csr_DailyHours - (40 - @WeeklySum)) - ISNULL(Calculated_DT, 0)
      WHERE RecordID = @csr_RecordID    
    END
  END
  
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	*/
DECLARE @DailyOverage NUMERIC(7, 2)

PRINT ''
PRINT ''
PRINT '======================'
PRINT 'Weekly Cursor'
PRINT '======================'
PRINT '@TotalWeeklyHours: ' + CAST(@TotalWeeklyHours AS VARCHAR)
IF (@TotalWeeklyHours > 40)
BEGIN
  SET @WeeklyBalance = @TotalWeeklyHours - 40
  
  /* First time around, i.e. SPREAD mode, try to go back through each day and spready any hours over 8 in the day to weekly OT/DT.
     Second time around, just apply it all to the end of the week
  */
  WHILE @WeeklyBalance > 0
  BEGIN
    PRINT ''
    PRINT '@WeeklyBalance: ' + CAST(@WeeklyBalance AS VARCHAR)   
    PRINT 'Mode: ' + @WeeklyMode
    DECLARE weeklyCursor CURSOR DYNAMIC FOR
    SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
    FROM #tmpDailySummary
    ORDER BY TransDate DESC
    OPEN weeklyCursor

    FETCH NEXT FROM weeklyCursor
    INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

    WHILE @@FETCH_STATUS = 0
    BEGIN

      IF (@WeeklyBalance > 0)
      BEGIN
        	
        PRINT 'Weekly Cursor: ' + CAST(@csr_TransDate AS VARCHAR)       
        PRINT 'csr_DailyHours: ' + CAST(@csr_DailyHours AS VARCHAR)
        PRINT '@csr_Calculated_OT: ' + ISNULL(CAST(@csr_Calculated_OT AS VARCHAR), '')
        PRINT '@csr_Calculated_DT: ' + ISNULL(CAST(@csr_Calculated_DT AS VARCHAR), '')
        
        SET @DailyOverage = @csr_DailyHours - 8
        PRINT '@DailyOverage: ' + CAST(@DailyOverage AS VARCHAR) 
        
        IF (@DailyOverage <= 0 AND @WeeklyMode = 'ENDOFWEEK')
        BEGIN
          SET @DailyOverage = @csr_DailyHours
          IF (@DailyOverage > @WeeklyBalance)
          BEGIN
            SET @DailyOverage = @WeeklyBalance
          END
          
          PRINT 'Adjusted @DailyOverage: ' + CAST(@DailyOverage AS VARCHAR) 
          
          PRINT 'Moving to: ' + @WeeklyAppliesTo
          UPDATE #tmpDailySummary
          SET Calculated_OT = ISNULL(Calculated_OT, 0) + CASE WHEN @WeeklyAppliesTo = 'OT' THEN @DailyOverage ELSE Calculated_OT END,
              Calculated_DT = ISNULL(Calculated_DT, 0) + CASE WHEN @WeeklyAppliesTo = 'DT' THEN @DailyOverage ELSE Calculated_DT END,
              DailyHours = DailyHours - @DailyOverage
          WHERE RecordID = @csr_RecordID          
          SET @WeeklyBalance = @WeeklyBalance - @DailyOverage          
        END        
        ELSE IF (@DailyOverage > 0)
        BEGIN
          IF (@DailyOverage >= @WeeklyBalance)
          BEGIN
            PRINT '@DailyOverage >= @WeeklyBalance'
            PRINT 'Moving to:' + @WeeklyAppliesTo
            UPDATE #tmpDailySummary
            SET Calculated_OT = ISNULL(Calculated_OT, 0) + (CASE WHEN @WeeklyAppliesTo = 'OT' THEN ISNULL(Calculated_OT, 0) + @WeeklyBalance ELSE Calculated_OT END),
                Calculated_DT = ISNULL(Calculated_DT, 0) + (CASE WHEN @WeeklyAppliesTo = 'DT' THEN ISNULL(Calculated_DT, 0) + @WeeklyBalance ELSE Calculated_DT END),
                DailyHours = DailyHours - @WeeklyBalance
            WHERE RecordID = @csr_RecordID          
            SET @WeeklyBalance = 0       
          END -- IF (@DailyOverage >= @WeeklyBalance)
          ELSE IF (@DailyOverage < @WeeklyBalance)
          BEGIN
            PRINT '@DailyOverage < @WeeklyBalance'
            PRINT 'Moving to: ' + @WeeklyAppliesTo
            UPDATE #tmpDailySummary
            SET Calculated_OT =  CASE WHEN @WeeklyAppliesTo = 'OT' THEN @DailyOverage ELSE Calculated_OT END,
                Calculated_DT =  CASE WHEN @WeeklyAppliesTo = 'DT' THEN @DailyOverage ELSE Calculated_DT END,
                DailyHours = DailyHours - @DailyOverage
            WHERE RecordID = @csr_RecordID          
            SET @WeeklyBalance = @WeeklyBalance - @DailyOverage
          END -- ELSE IF (@DailyOverage < @WeeklyBalance)
        END
      END
      
	    FETCH NEXT FROM weeklyCursor
	    INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
    END
    CLOSE weeklyCursor
    DEALLOCATE weeklyCursor  
    
    IF (@WeeklyBalance > 0)
    BEGIN
      SELECT 'After Weekly OT/DT: 1st Pass' AS WhereAreWe, * FROM #tmpDailySummary
      SET @WeeklyMode = 'ENDOFWEEK'
    END
  END -- WHILE @WeeklyBalance > 0
END

/*
 4 - Now we have daily hours correct for each day, let's assign Daily OT/DT
*/
SELECT 'After Weekly OT/DT' AS WhereAreWe, * FROM #tmpDailySummary

PRINT '======================'
PRINT 'Daily OT/DT'
PRINT '======================'
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT 'Daily OT/DT: ' + CAST(@csr_TransDate AS VARCHAR)
  PRINT '@csr_DailyHours: ' + ISNULL(CAST(@csr_DailyHours as varchar), '')
  PRINT '@csr_Calculated_OT: ' + ISNULL(CAST(@csr_Calculated_OT as varchar), '')
  PRINT '@csr_Calculated_DT: ' + ISNULL(CAST(@csr_Calculated_DT as varchar), '')
  
  SET @OT_DT_Amount = @csr_DailyHours - 8
  PRINT '@OT_DT_Amount: ' + CAST(@OT_DT_Amount AS VARCHAR)
  
  IF (@OT_DT_Amount > 0)
  BEGIN
    PRINT 'Applied to: ' + @DailyAppliesTo
    UPDATE #tmpDailySummary
    SET Calculated_OT = CASE WHEN @DailyAppliesTo = 'OT' THEN ISNULL(Calculated_OT, 0) + @OT_DT_Amount ELSE Calculated_OT END,
        Calculated_DT = CASE WHEN @DailyAppliesTo = 'DT' THEN ISNULL(Calculated_DT, 0) + @OT_DT_Amount ELSE Calculated_DT END,
        DailyHours = DailyHours - @OT_DT_Amount
    WHERE RecordID = @csr_RecordID
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
SELECT 'After Daily OT/DT' AS WhereAreWe, * FROM #tmpDailySummary
PRINT ''
PRINT ''

/* THIS IS THE VERSION FROM BEFORE I UNDERSTOOD EXACTLY WHAT THEY MEANT BY 24 HOUR CYCLE LUNCH
 3 - Move hours to previous day for 24 hour cycle lunch rule if necessary
PRINT '======================'
PRINT '24 Hour Cycle Lunch'
PRINT '======================'
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT '24Hr Cycle Lunch Cursor: ' + CAST(@csr_TransDate AS VARCHAR)
  
  SET @24HrCycleLunch_GT3HrsLate = '0'  
  SET @YesterdayLunchStart = NULL
  SET @YesterdayLunchEnd = NULL
  SET @YesterdayLunchDuration = NULL
  SET @YesterdayHours = NULL
  
  SELECT  @YesterdayStart = ShiftStartDateTime,
          @YesterdayLunchStart = LunchStartDateTime,
          @YesterdayLunchEnd = LunchEndDateTime,
          @YesterdayLunchDuration = DATEDIFF(mi, LunchStartDateTime, LunchEndDateTime) / 60.00,
          @YesterdayHours = DailyHours
  FROM #tmpDailySummary
  WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
  PRINT '@YesterdayLunchStart: ' + ISNULL(CAST(@YesterdayLunchStart AS VARCHAR), '')
    
  IF (@EmployeeType = '379')
  BEGIN
    SET @24HrCycleLunch_GT3HrsLate = '1'
  END
  ELSE
  BEGIN      
    -- Started lunch more than 3 hours later than yesterday    
    IF (@csr_LunchStartDateTime > DATEADD(hh, 3, DATEADD(dd, 1, @YesterdayLunchStart)))
    BEGIN
      SET @24HrCycleLunch_GT3HrsLate = '1'
    END    
  END 
  
  PRINT '@24HrCycleLunch_GT3HrsLate: ' + @24HrCycleLunch_GT3HrsLate
  IF (@24HrCycleLunch_GT3HrsLate = '1')
  BEGIN        
    IF (@YesterdayLunchStart IS NOT NULL)
    BEGIN
      PRINT '24 Hour Lunch Cycle Applies'
      
      SET @24HourCycleAmount = DATEDIFF(mi, @YesterdayLunchStart, DATEADD(dd, -1, @csr_LunchStartDateTime)) / 60.00
      PRINT '@24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
      
      IF (@24HourCycleAmount > 0)
      BEGIN
        -- Subtract out the length of the lunch from yesterday
        -- Subtract off Yesterdays End from Todays start
        PRINT 'Subtract from 24 Hour Lunch Penalty: ' + CAST(DATEDIFF(mi, DATEADD(dd, 1, @YesterdayLunchEnd), @csr_LunchStartDateTime) / 60.00 AS VARCHAR)
        PRINT '@csr_LunchStartDateTime: ' + CAST(@csr_LunchStartDateTime AS VARCHAR)
        PRINT '@YesterdayLunchEnd: ' + CAST(@YesterdayLunchEnd AS VARCHAR)
        
        -- ToDo: Not sure I really need this IF statement around the calculation, need to revisit this.  If we take it out, then Scenario 15 will be wrong.
        IF (DATEDIFF(mi, DATEADD(dd, 1, @YesterdayLunchEnd), @csr_LunchStartDateTime) / 60.00) > 0
        BEGIN
          SET @24HourCycleAmount = @24HourCycleAmount - (DATEDIFF(mi, DATEADD(dd, 1, @YesterdayLunchEnd), @csr_LunchStartDateTime) / 60.00)
          PRINT 'NEW @24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
        END
        
        -- If he started his shift later today than yesterday then we need to subtract that off also
        PRINT 'Late Start Duration: ' + CAST(DATEADD(dd, 1, @YesterdayStart) AS varchar) + ' - ' + cast(@csr_ShiftStartDateTime AS varchar)
        SET @LateStartDuration = DATEDIFF(mi, DATEADD(dd, 1, @YesterdayStart), @csr_ShiftStartDateTime) / 60.00
        IF (@LateStartDuration < 0)
        BEGIN
          SET @LateStartDuration = 0
        END
        PRINT '@LateStartDuration: ' + CAST(@LateStartDuration AS VARCHAR)
        SET @24HourCycleAmount = @24HourCycleAmount - @LateStartDuration
                
        SET @24HourCycleAmount = (@YesterdayHours + @24HourCycleAmount) - 8.00
        PRINT 'ACTUAL @24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
        IF (@24HourCycleAmount > 0)
        BEGIN
          PRINT 'Appled to: ' + @DailyAppliesTo
          UPDATE #tmpDailySummary
          SET Calculated_OT = CASE WHEN @DailyAppliesTo = 'OT' THEN ISNULL(Calculated_OT, 0) + @24HourCycleAmount ELSE Calculated_OT END,
              Calculated_DT = CASE WHEN @DailyAppliesTo = 'DT' THEN ISNULL(Calculated_DT, 0) + @24HourCycleAmount ELSE Calculated_DT END
          WHERE RecordID = @csr_RecordID
        END
      END
    END
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
SELECT 'After 24 Hour Cycle Lunch' AS WhereAreWe, * FROM #tmpDailySummary
PRINT ''
PRINT ''
*/

/* THIS IS THE VERSION FROM BEFORE I UNDERSTOOD EXACTLY WHAT THEY MEANT BY 24 HOUR CYCLE LUNCH
 3.1 - Move hours to previous day for 24 hour cycle lunch rule if necessary
*/
PRINT '======================'
PRINT '24 Hour Cycle Lunch'
PRINT '======================'
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, ISNULL(Calculated_OT, 0), ISNULL(Calculated_DT, 0)
FROM #tmpDailySummary
WHERE LunchStartDateTime IS NOT NULL
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT '24Hr Cycle Lunch Cursor: ' + CAST(@csr_TransDate AS VARCHAR)
  
  SET @24HrCycleLunch_GT3HrsLate = '0'  
  SET @YesterdayLunchStart = NULL
  SET @YesterdayLunchEnd = NULL
  SET @YesterdayLunchDuration = NULL
  SET @YesterdayHours = NULL
  
  SELECT  @YesterdayStart = ShiftStartDateTime,
          @YesterdayLunchStart = LunchStartDateTime,
          @YesterdayLunchEnd = LunchEndDateTime,
          @YesterdayLunchDuration = DATEDIFF(mi, LunchStartDateTime, LunchEndDateTime) / 60.00,
          @YesterdayHours = DailyHours,
          @YesterdaysOTDT = ISNULL(Calculated_OT, 0) + ISNULL(Calculated_DT, 0)
  FROM #tmpDailySummary
  WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
  PRINT '@YesterdayLunchStart: ' + ISNULL(CAST(@YesterdayLunchStart AS VARCHAR), '')
    
  IF (@EmployeeType = '379')
  BEGIN
    SET @24HrCycleLunch_GT3HrsLate = '1'
  END
  ELSE
  BEGIN      
    -- Started lunch more than 3 hours later than yesterday    
    IF (@csr_LunchStartDateTime > DATEADD(hh, 3, DATEADD(dd, 1, @YesterdayLunchStart)))
    BEGIN
      SET @24HrCycleLunch_GT3HrsLate = '1'
    END    
  END 
  
  PRINT '@24HrCycleLunch_GT3HrsLate: ' + @24HrCycleLunch_GT3HrsLate
  IF (@24HrCycleLunch_GT3HrsLate = '1')
  BEGIN        
    IF (@YesterdayLunchStart IS NOT NULL)
    BEGIN
      PRINT '24 Hour Lunch Cycle Applies'
      PRINT 'Checking 24 hour cycle: ' + CAST(DATEADD(dd, -1, @csr_LunchStartDateTime) AS VARCHAR) + ' - ' + CAST(@csr_LunchStartDateTime AS VARCHAR)
      SELECT @24HourCycleAmount = TimeHistory.dbo.fn_GetTotalWorkedHoursSinceDateTime(@Client, @GroupCode, @PPED, @SSN, DATEADD(dd, -1, @csr_LunchStartDateTime), @csr_LunchStartDateTime)
      PRINT '@24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
      
      IF (@24HourCycleAmount > 8)
      BEGIN                        
        SET @24HourCycleAmount = @24HourCycleAmount - 8.00 - @YesterdaysOTDT -- - @csr_Calculated_OT
        PRINT 'ACTUAL @24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
        PRINT '@24HourCyclePyramidBalance: ' + CAST(@24HourCyclePyramidBalance AS VARCHAR)        
        
        IF (@24HourCyclePyramidBalance > 0)
        BEGIN
          IF (@24HourCyclePyramidBalance >= @24HourCycleAmount)
          BEGIN
            SET @24HourCyclePyramidBalance = @24HourCyclePyramidBalance - @24HourCycleAmount
            SET @24HourCycleAmount = 0
          END
          ELSE
          BEGIN            
            SET @24HourCyclePyramidBalance = 0
            SET @24HourCycleAmount = @24HourCycleAmount - @24HourCyclePyramidBalance            
          END
          PRINT '@24HourCycleAmount - PyramidBalance: ' + CAST(@24HourCycleAmount AS VARCHAR)
        END
                
        IF (@24HourCycleAmount > 0)
        BEGIN
          PRINT 'Applied to: ' + @DailyAppliesTo
          UPDATE #tmpDailySummary
          SET Calculated_OT = CASE WHEN @DailyAppliesTo = 'OT' THEN ISNULL(Calculated_OT, 0) + @24HourCycleAmount ELSE Calculated_OT END,
              Calculated_DT = CASE WHEN @DailyAppliesTo = 'DT' THEN ISNULL(Calculated_DT, 0) + @24HourCycleAmount ELSE Calculated_DT END
          WHERE TransDate = DATEADD(dd, -1, @csr_TransDate) --RecordID = @csr_RecordID
        END
      END
    END
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
SELECT 'After 24 Hour Cycle Lunch' AS WhereAreWe, * FROM #tmpDailySummary
PRINT ''
PRINT ''

/*
 4.1 - Move hours to previous day for 24 hour cycle shift rule if necessary
*/
PRINT '======================'
PRINT '24 Hour Cycle Shift'
PRINT '======================'

DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, ISNULL(Calculated_OT, 0), ISNULL(Calculated_DT, 0)
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT '24Hr Cycle Shift Cursor: ' + CAST(@csr_TransDate AS VARCHAR)
  
  SET @24HrCycle_GT3HrsEarly = '0'  
  SET @YesterdayStart = NULL
  SET @YesterdayEnd = NULL
  SET @YesterdayLunchDuration = NULL
  SET @YesterdayHours = NULL
  
  SELECT  @YesterdayStart = ShiftStartDateTime,
          @YesterdayEnd = ShiftEndDateTime,
          @YesterdayHours = DailyHours,
          @YesterdaysOTDT = ISNULL(Calculated_OT, 0) + ISNULL(Calculated_DT, 0)
  FROM #tmpDailySummary
  WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
  PRINT '@YesterdayShiftStart: ' + ISNULL(CAST(@YesterdayStart AS VARCHAR), '')
    
  IF (@EmployeeType = '379')
  BEGIN
    SET @24HrCycle_GT3HrsEarly = '1'
    SET @24HrCycle_NoRest = '1'
  END
  ELSE
  BEGIN      
    -- Started shift more than 3 hours ealier than yesterday    
    /*IF (@csr_ShiftStartDateTime < DATEADD(hh, -3, DATEADD(dd, 1, @YesterdayStart)) AND @YesterdayStart IS NOT NULL)
    BEGIN
      SET @24HrCycle_GT3HrsEarly = '1'
    END*/
    SET @24HrCycle_GT3HrsEarly = '0'
    -- Did not have at least 12 hour rest
    IF (DATEDIFF(hh, @YesterdayEnd, @csr_ShiftStartDateTime) < 12)
    BEGIN
      SET @24HrCycle_NoRest = '1'
    END
  END 
  
  PRINT '@24HrCycle_GT3HrsEarly: ' + @24HrCycle_GT3HrsEarly
  PRINT '@24HrCycle_NoRest: ' + @24HrCycle_NoRest
  IF (@24HrCycle_GT3HrsEarly = '1' OR @24HrCycle_NoRest = '1')
  BEGIN        
    IF (@YesterdayStart IS NOT NULL)
    BEGIN
      PRINT '24 Hour Shift Cycle Applies'
      
      --SET @24HourCycleAmount = DATEDIFF(mi, @csr_ShiftStartDateTime, DATEADD(dd, 1, @YesterdayStart)) / 60.00
      --SET @24HourCycleAmount = (DATEDIFF(mi, DATEADD(dd, 1, @YesterdayStart), @csr_ShiftStartDateTime) / 60.00) * -1
      PRINT 'Checking 24 hour cycle: ' + CAST(@YesterdayStart AS VARCHAR) + ' - ' + CAST(DATEADD(d, 1, @YesterdayStart) AS VARCHAR)
      SET @24HourCycleAmount = TimeHistory.dbo.fn_GetTotalWorkedHoursSinceDateTime(@Client, @GroupCode, @PPED, @SSN, @YesterdayStart, DATEADD(d, 1, @YesterdayStart))
      PRINT '@24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
      
      IF (@24HourCycleAmount > 8)
      BEGIN                        
        SET @24HourCycleAmount = @24HourCycleAmount - 8.00 - @YesterdaysOTDT -- - @csr_Calculated_OT
        PRINT 'ACTUAL @24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
        PRINT '@24HourCyclePyramidBalance: ' + CAST(@24HourCyclePyramidBalance AS VARCHAR)
                
        IF (@24HourCycleAmount > 0)
        BEGIN
        
          IF (@24HourCyclePyramidBalance > 0)
          BEGIN
            IF (@24HourCyclePyramidBalance >= @24HourCycleAmount)
            BEGIN
              SET @24HourCyclePyramidBalance = @24HourCyclePyramidBalance - @24HourCycleAmount
              SET @24HourCycleAmount = 0
            END
            ELSE
            BEGIN
              PRINT 'ELSE'
              PRINT '@24HourCycleAmount: ' + CAST(@24HourCycleAmount AS varchar)
              PRINT '@24HourCyclePyramidBalance: ' + CAST(@24HourCyclePyramidBalance AS varchar)                            
              SET @24HourCyclePyramidBalance = 0.00
              SET @24HourCycleAmount = CAST(@24HourCycleAmount AS NUMERIC(7, 2)) - CAST(@24HourCyclePyramidBalance AS NUMERIC(7, 2))                            
              PRINT '@24HourCycleAmount1 - PyramidBalance: ' + CAST(@24HourCycleAmount AS VARCHAR)
            END
            PRINT '@24HourCycleAmount2 - PyramidBalance: ' + CAST(@24HourCycleAmount AS VARCHAR)
          END
          
          IF (@24HourCycleAmount > 0)
          BEGIN          
            PRINT 'Applied to: ' + @DailyAppliesTo
            UPDATE #tmpDailySummary
            SET Calculated_OT = CASE WHEN @DailyAppliesTo = 'OT' THEN ISNULL(Calculated_OT, 0) + @24HourCycleAmount ELSE Calculated_OT END,
                Calculated_DT = CASE WHEN @DailyAppliesTo = 'DT' THEN ISNULL(Calculated_DT, 0) + @24HourCycleAmount ELSE Calculated_DT END
            WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
          END
        END
      END
            
    END
    ELSE
    BEGIN
      PRINT 'Did not work yesterday'
    END
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
SELECT 'After 24 Hour Cycle Shift' AS WhereAreWe, * FROM #tmpDailySummary

/*
 1 - 7th Day DT
   If there are 7 rows in here, then it means he worked 7 consecutive days
*/
IF (SELECT COUNT(*)
    FROM #tmpDailySummary) = 7
BEGIN
  UPDATE #tmpDailySummary
  SET Calculated_DT = (DailyHours + ISNULL(Calculated_OT, 0) + ISNULL(Calculated_DT, 0))
  WHERE TransDate = @PPED
END

SELECT 'After 7th Day DT' AS WhereAreWe, * FROM #tmpDailySummary


/* THIS IS THE VERSION FROM BEFORE I UNDERSTOOD EXACTLY WHAT THEY MEANT BY 24 HOUR CYCLE LUNCH
 4 - Move hours to previous day for 24 hour cycle shift rule if necessary
PRINT '======================'
PRINT '24 Hour Cycle Shift'
PRINT '======================'

DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT '24Hr Cycle Shift Cursor: ' + CAST(@csr_TransDate AS VARCHAR)
  
  SET @24HrCycle_GT3HrsEarly = '0'  
  SET @YesterdayStart = NULL
  SET @YesterdayEnd = NULL
  SET @YesterdayLunchDuration = NULL
  SET @YesterdayHours = NULL
  
  SELECT  @YesterdayStart = ShiftStartDateTime,
          @YesterdayEnd = ShiftEndDateTime,
          @YesterdayHours = DailyHours,
          @YesterdaysOTDT = ISNULL(Calculated_OT, 0) --+ ISNULL(Calculated_DT, 0)
  FROM #tmpDailySummary
  WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
  PRINT '@YesterdayShiftStart: ' + ISNULL(CAST(@YesterdayStart AS VARCHAR), '')
    
  IF (@EmployeeType = '379')
  BEGIN
    SET @24HrCycle_GT3HrsEarly = '1'
    SET @24HrCycle_NoRest = '1'
  END
  ELSE
  BEGIN      
    -- Started shift more than 3 hours ealier than yesterday    
    IF (@csr_ShiftStartDateTime < DATEADD(hh, -3, DATEADD(dd, 1, @YesterdayStart)) AND @YesterdayStart IS NOT NULL)
    BEGIN
      SET @24HrCycle_GT3HrsEarly = '1'
    END    
    -- Did not have at least 12 hour rest
    IF (DATEDIFF(hh, @YesterdayEnd, @csr_ShiftStartDateTime) < 12)
    BEGIN
      SET @24HrCycle_NoRest = '1'
    END
  END 
  
  PRINT '@24HrCycle_GT3HrsEarly: ' + @24HrCycle_GT3HrsEarly
  PRINT '@24HrCycle_NoRest: ' + @24HrCycle_NoRest
  IF (@24HrCycle_GT3HrsEarly = '1' OR @24HrCycle_NoRest = '1')
  BEGIN        
    IF (@YesterdayStart IS NOT NULL)
    BEGIN
      PRINT '24 Hour Shift Cycle Applies'
      
      --SET @24HourCycleAmount = DATEDIFF(mi, @csr_ShiftStartDateTime, DATEADD(dd, 1, @YesterdayStart)) / 60.00
      SET @24HourCycleAmount = (DATEDIFF(mi, DATEADD(dd, 1, @YesterdayStart), @csr_ShiftStartDateTime) / 60.00) * -1
      PRINT '@24HourCycleAmount: ' + CAST(@24HourCycleAmount AS VARCHAR)
      
      IF (@24HourCycleAmount > 0)
      BEGIN
        
        SET @24HourCycleAmount = (@YesterdayHours + @24HourCycleAmount) - 8 - @YesterdaysOTDT
        IF (@24HourCycleAmount > 0)
        BEGIN
          IF (@DailyAppliesTo = 'OT')
          BEGIN
            PRINT 'Appled to OT'
            UPDATE #tmpDailySummary
            SET Calculated_OT = ISNULL(Calculated_OT, 0) + @24HourCycleAmount
            WHERE RecordID = @csr_RecordID
          END
          ELSE IF (@DailyAppliesTo = 'DT')
          BEGIN
            PRINT 'Appled to DT'
            UPDATE #tmpDailySummary
            SET Calculated_DT = ISNULL(Calculated_DT, 0) + @24HourCycleAmount
            WHERE RecordID = @csr_RecordID
          END
        END
      END
    END
    ELSE
    BEGIN
      PRINT 'Did not work yesterday'
    END
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
SELECT 'After 24 Hour Cycle Shift' AS WhereAreWe, * FROM #tmpDailySummary
*/


/*
 3 - Move hours to previous day for 24 hour cycle rule if necessary
SELECT '24 Hour Cycle Shift' AS WhereAreWe, * FROM #tmpDailySummary
PRINT '======================'
PRINT '24 Hour Cycle Shift'
PRINT '======================'
DECLARE @24HrCycleLunch_GT3HrsLate VARCHAR(1)
DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT '24Hr Cycle Lunch Cursor: ' + CAST(@csr_TransDate AS VARCHAR)
  
  SET @24HrCycleLunch_GT3HrsLate = '0'  
  SET @YesterdayStart = NULL
  
  SELECT @YesterdayStart = LunchStartDateTime
  FROM #tmpDailySummary
  WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
  PRINT '@YesterdayLunchStart: ' + ISNULL(CAST(@YesterdayStart AS VARCHAR), '')
    
  IF (@EmployeeType = '379')
  BEGIN
    SET @24HrCycleLunch_GT3HrsLate = '1'
  END
  ELSE
  BEGIN      
    -- Did not have at least 12 hour rest
    IF EXISTS(SELECT 1
              FROM #tmpDailySummary
              WHERE DATEDIFF(hh, ShiftEndDateTime, @csr_ShiftStartDateTime) < 12
              AND ShiftEndDateTime < @csr_ShiftStartDateTime)
    BEGIN
      SET @24HrCycle_NoRest = '1'
    END

    -- Started more than 3 hours earlier than yesterday    
    IF (@csr_ShiftStartDateTime < DATEADD(hh, -3, DATEADD(dd, 1, @YesterdayStart)))
    BEGIN
      SET @24HrCycle_GT3HrsEarly = '1'
    END    
  END 
  
  PRINT '@24HrCycle_NoRest: ' + @24HrCycle_NoRest
  PRINT '@24HrCycle_GT3HrsEarly: ' + @24HrCycle_GT3HrsEarly
  IF (@24HrCycle_NoRest = '1' OR @24HrCycle_GT3HrsEarly = '1')
  BEGIN        
    IF (@YesterdayStart IS NOT NULL)
    BEGIN
      PRINT '24 Hour Cycle Applies'
      
      SELECT @YesterdaysHours = (DATEDIFF(mi, DATEADD(dd, 1, @YesterdayStart), @csr_ShiftStartDateTime) / 60.00) * -1
      PRINT 'Yesterdays Hours: ' + CAST(@YesterdaysHours AS VARCHAR)
      
      -- Subtract from todays hours
      UPDATE #tmpDailySummary
      SET DailyHours = DailyHours - @YesterdaysHours
      WHERE RecordID = @csr_RecordID
      
      -- Add to yesterdays hours
      UPDATE #tmpDailySummary
      SET DailyHours = DailyHours + @YesterdaysHours
      WHERE TransDate = DATEADD(dd, -1, @csr_TransDate)
    END
  END
  PRINT ''
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	
*/

/*
 5 - Update THD
*/
PRINT '======================'
PRINT 'Update THD'
PRINT '======================'
DECLARE @thd_RecordID BIGINT  --< @thd_RecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
DECLARE @thd_InTime   DATETIME
DECLARE @thd_Hours    NUMERIC(5, 2)

DECLARE punchCursor CURSOR DYNAMIC FOR
SELECT RecordID, TransDate, ShiftStartDateTime, LunchStartDateTime, LunchEndDateTime, ShiftEndDateTime, DailyHours, Calculated_OT, Calculated_DT
FROM #tmpDailySummary
WHERE ISNULL(Calculated_OT, 0) <> 0
OR ISNULL(Calculated_DT, 0) <> 0
ORDER BY TransDate
OPEN punchCursor

FETCH NEXT FROM punchCursor
INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT

WHILE @@FETCH_STATUS = 0
BEGIN	
  PRINT '@csr_TransDate: ' + CAST(@csr_TransDate AS VARCHAR)
  PRINT '@csr_Calculated_OT: ' + CAST(@csr_Calculated_OT AS VARCHAR)
  PRINT '@csr_Calculated_DT: ' + CAST(@csr_Calculated_DT AS VARCHAR)
  
  DECLARE thdCursor CURSOR FOR
  SELECT RecordID, dbo.PunchDateTime2(TransDate, InDay, InTime), Hours
  FROM TimeHistory..tblTimeHistDetail
  WHERE Client = @Client
  AND GroupCode = @GroupCode
  AND PayrollPeriodEndDate = @PPED
  AND SSN = @SSN
  AND TransDate = @csr_TransDate
  AND InTime <> OutTime -- Ignore hourly adjustments
  AND InDay <> '10'
  AND OutDay <> '10'
  AND Hours <> 0  
  ORDER BY dbo.PunchDateTime2(TransDate, InDay, InTime) DESC  
  OPEN thdCursor

  FETCH NEXT FROM thdCursor
  INTO @thd_RecordID, @thd_InTime, @thd_Hours

  WHILE @@FETCH_STATUS = 0
  BEGIN	
    PRINT '  @thd_InTime: ' + CAST(@thd_InTime AS VARCHAR)
    PRINT '  @thd_Hours: ' + CAST(@thd_Hours AS VARCHAR)
    IF (@csr_Calculated_DT > 0)
    BEGIN
      IF (@thd_Hours >= @csr_Calculated_DT)
      BEGIN
        PRINT '@thd_Hours >= @csr_Calculated_DT'
        UPDATE TimeHistory..tblTimeHistDetail
        SET DT_Hours = DT_Hours + @csr_Calculated_DT,
                       RegHours = RegHours - @csr_Calculated_DT
        WHERE RecordID = @thd_RecordID  
        SET @thd_Hours = @thd_Hours - @csr_Calculated_DT
        SET @csr_Calculated_DT = 0        
      END
      ELSE IF (@thd_Hours < @csr_Calculated_DT)
      BEGIN
        PRINT '@thd_Hours < @csr_Calculated_DT'
        UPDATE TimeHistory..tblTimeHistDetail
        SET DT_Hours = @thd_Hours,
            RegHours = 0
        WHERE RecordID = @thd_RecordID  
        SET @csr_Calculated_DT = @csr_Calculated_DT - @thd_Hours
        SET @thd_Hours = 0
      END   
      PRINT '@csr_Calculated_DT: ' + CAST(@csr_Calculated_DT AS VARCHAR)
      PRINT '@thd_Hours: ' + CAST(@thd_Hours AS VARCHAR)
    END
    
    IF (@csr_Calculated_OT > 0)
    BEGIN
      IF (@thd_Hours >= @csr_Calculated_OT)
      BEGIN
        PRINT '@thd_Hours >= @csr_Calculated_OT'
        UPDATE TimeHistory..tblTimeHistDetail
        SET OT_Hours = OT_Hours + @csr_Calculated_OT,
                       RegHours = RegHours - @csr_Calculated_OT
        WHERE RecordID = @thd_RecordID  
        SET @thd_Hours = @thd_Hours - @csr_Calculated_OT
        SET @csr_Calculated_OT = 0        
      END
      ELSE IF (@thd_Hours < @csr_Calculated_OT)
      BEGIN
        PRINT '@thd_Hours < @csr_Calculated_OT'
        UPDATE TimeHistory..tblTimeHistDetail
        SET OT_Hours = @thd_Hours,
            RegHours = 0
        WHERE RecordID = @thd_RecordID  
        SET @csr_Calculated_OT = @csr_Calculated_OT - @thd_Hours
        SET @thd_Hours = 0
      END   
      PRINT '@csr_Calculated_OT: ' + CAST(@csr_Calculated_OT AS VARCHAR)
      PRINT '@thd_Hours: ' + CAST(@thd_Hours AS VARCHAR)
      PRINT ''
    END    
    
    FETCH NEXT FROM thdCursor
    INTO @thd_RecordID, @thd_InTime, @thd_Hours
  END
  CLOSE thdCursor
  DEALLOCATE thdCursor	

    
	FETCH NEXT FROM punchCursor
	INTO @csr_RecordID, @csr_TransDate, @csr_ShiftStartDateTime, @csr_LunchStartDateTime, @csr_LunchEndDateTime, @csr_ShiftEndDateTime, @csr_DailyHours, @csr_Calculated_OT, @csr_Calculated_DT
END
CLOSE punchCursor
DEALLOCATE punchCursor	

SELECT 'After Update THD' AS WhereAreWe, *, DailyHours - ISNULL(Calculated_OT, 0) - ISNULL(Calculated_DT, 0) AS REG_HOURS FROM #tmpDailySummary

DROP TABLE #tmpDailySummary
DROP TABLE #tmpPunches
DROP TABLE #tmpLunches
--DROP TABLE #tmpPreLunchPunches
--DROP TABLE #tmpPostLunchPunches

RETURN

GO


