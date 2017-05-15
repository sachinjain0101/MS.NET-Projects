Create PROCEDURE [dbo].[usp_EmplCalc_OT_Colorado]
	@Client 		  varchar(4), 
	@GroupCode 		int,
	@PeriodDate 	datetime, 
	@SSN 			    int 
AS
--*/

SET NOCOUNT ON

/*
DECLARE @Client			  varchar(4)
DECLARE @GroupCode		int
DECLARE @PeriodDate		datetime
DECLARE @SSN			    int

SELECT @Client = 'LEAR'
SELECT @GroupCode = 277600
SELECT @PeriodDate = '12/04/04'
SELECT @SSN = 522359094
--SELECT @SSN = 517845096
--SELECT @PeriodDate = '11/13/04'

SELECT @Client = 'LEAR'
SELECT @GroupCode = 277600
SELECT @PeriodDate = '3/26/05'
SELECT @SSN = 452539889
*/

/*
  ASSUMPTIONS:
  - There are no auto-generated "breaks"
*/

DECLARE	@MaxBetweenIns			  int			-- Max minutes between In Punches to consider
DECLARE @MaxBetweenPunches		int			-- Max minutes between Out and In Punches to consider

SELECT @MaxBetweenIns = XRefValue * 60 FROM TimeCurrent..tblClientXRef WHERE Client = @Client AND XRefID = 'MAXBETWEENINS'
SELECT @MaxBetweenPunches = XRefValue FROM TimeCurrent..tblClientXRef WHERE Client = @Client AND XRefID = 'MAXBETWEENPUNCHES'

SELECT thd.RecordID, thd.PayrollPeriodEndDate, thd.TransDate, thd.Hours, 
  dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InDateTime,
  dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutDateTime
INTO #tmpHours
FROM tblTimeHistDetail AS thd
LEFT JOIN TimeCurrent..tblAdjCodes AS adjs
ON adjs.Client = thd.Client
  AND adjs.GroupCode = thd.GroupCode
  AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
INNER JOIN tblPeriodEndDates AS ppeds
ON ppeds.Client = thd.Client
  AND ppeds.GroupCode = thd.GroupCode
  AND ppeds.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
WHERE thd.Client = @Client
  AND thd.GroupCode = @GroupCode
  AND thd.PayrollPeriodEndDate IN (@PeriodDate, DATEADD(day, 7, @PeriodDate), DATEADD(day, -7, @PeriodDate))
  AND thd.SSN = @SSN
  AND thd.Hours <> 0
  AND (adjs.Worked = 'Y' OR thd.ClockAdjustmentNo = ' ')
--  AND ppeds.Status <> 'C'

SELECT CAST(0.00 AS numeric(7,2)) AS RegHours, 
  CAST(0.00 AS numeric(7,2)) AS DailyOT, 
  CAST(0.00 AS numeric(7,2)) AS WeeklyOT, 
  hrs2.RecordID AS ParentID, hrs.*,
  hrs2.InDateTime AS ParentInDateTime, hrs2.OutDateTime AS ParentOutDateTime
INTO #tmpData
FROM #tmpHours AS hrs
INNER JOIN #tmpHours AS hrs2
ON (
--  hrs.PayrollPeriodEndDate = DATEADD(day, 7, @PeriodDate) AND 
--  hrs.InDateTime >= hrs2.OutDateTime AND
--  hrs.InDateTime <= DATEADD(minute, @MaxBetweenPunches, hrs2.OutDateTime) AND
--  hrs.InDateTime > hrs2.InDateTime
  hrs.InDateTime = hrs2.OutDateTime
/*
) OR (
--  hrs.PayrollPeriodEndDate = DATEADD(day, -7, @PeriodDate) AND 
  hrs.OutDateTime <= hrs2.InDateTime AND
  hrs.OutDateTime >= DATEADD(minute, (-1) * @MaxBetweenPunches, hrs2.InDateTime) AND
  hrs.OutDateTime > hrs2.OutDateTime
*/
) OR (
--  hrs2.PayrollPeriodEndDate = @PeriodDate AND 
  hrs2.RecordID = hrs.RecordID
)
ORDER BY hrs.InDateTime

-- Delete self-reference if parent found
DELETE FROM #tmpData
WHERE RecordID IN (SELECT RecordID FROM #tmpData WHERE ParentID <> RecordID)
  AND RecordID = ParentID

DECLARE @RecordID    AS BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
DECLARE @ParentID    AS BIGINT  --< @ParentId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
DECLARE @TransDate   AS datetime
DECLARE @PPED        as datetime

-- Reduce records with multiple parents to the top-level parent
DECLARE csrMultiples CURSOR FOR
  SELECT RecordID FROM #tmpData GROUP BY RecordID HAVING COUNT(*) > 1

OPEN csrMultiples

  FETCH NEXT FROM csrMultiples INTO @RecordID
  WHILE @@FETCH_STATUS = 0
  BEGIN
    DELETE FROM #tmpData 
    WHERE ParentID <> (SELECT TOP 1 ParentID FROM #tmpData WHERE RecordID = @RecordID ORDER BY ParentInDateTime)
      AND RecordID = @RecordID

    FETCH NEXT FROM csrMultiples INTO @RecordID
  END

CLOSE csrMultiples
DEALLOCATE csrMultiples
  
-- Reduce all records to the top-level parent
DECLARE csrMultiples CURSOR FOR
  SELECT RecordID, ParentID FROM #tmpData WHERE ParentID <> RecordID ORDER BY InDateTime

OPEN csrMultiples

  FETCH NEXT FROM csrMultiples INTO @RecordID, @ParentID
  WHILE @@FETCH_STATUS = 0
  BEGIN
    UPDATE #tmpData SET ParentID = (SELECT ParentID FROM #tmpData WHERE RecordID = @ParentID) WHERE RecordID = @RecordID
    FETCH NEXT FROM csrMultiples INTO @RecordID, @ParentID
  END

CLOSE csrMultiples
DEALLOCATE csrMultiples
  
--SELECT Hours, * FROM #tmpData

-- Delete any record whose self or parent or child isn't in the current week
DELETE FROM #tmpData
WHERE PayrollPeriodEndDate <> @PeriodDate
  AND ParentID NOT IN (SELECT RecordID FROM #tmpData WHERE PayrollPeriodEndDate = @PeriodDate)
  AND RecordID NOT IN (SELECT ParentID FROM #tmpData WHERE PayrollPeriodEndDate = @PeriodDate)

--SELECT Hours, * FROM #tmpData

DECLARE @PPEDHours    AS numeric(7,2)
DECLARE @PunchHours   AS numeric(7,2)
DECLARE @WeeklyOT     AS numeric(7,2)
DECLARE @GroupHours   AS numeric(7,2)

-- Apply WeeklyOT
DECLARE @TotalHours   AS numeric(7,2)
SET @TotalHours = 0.00

UPDATE #tmpData SET RegHours = Hours

DECLARE csrWeeklyOT CURSOR FOR
  SELECT RecordID, Hours FROM #tmpData WHERE PayrollPeriodEndDate = @PeriodDate

OPEN csrWeeklyOT

  FETCH NEXT FROM csrWeeklyOT INTO @RecordID, @PunchHours
  WHILE @@FETCH_STATUS = 0
  BEGIN
--PRINT @TotalHours
--PRINT @PunchHours
    IF @TotalHours >= 40
    BEGIN
      IF @TotalHours + @PunchHours >= 40
        UPDATE #tmpData SET RegHours = 0, WeeklyOT = RegHours WHERE RecordID = @RecordID
      ELSE
        UPDATE #tmpData SET RegHours = @PunchHours - (40 - @TotalHours), WeeklyOT = 40 - @TotalHours WHERE RecordID = @RecordID
    END
    ELSE IF @TotalHours + @PunchHours > 40
    BEGIN
      UPDATE #tmpData SET RegHours = Hours - (@TotalHours + @PunchHours - 40) WHERE RecordID = @RecordID
      UPDATE #tmpData SET WeeklyOT = Hours - RegHours WHERE RecordID = @RecordID
    END
    ELSE
    BEGIN
      UPDATE #tmpData SET RegHours = Hours WHERE RecordID = @RecordID
    END

    SET @TotalHours = @TotalHours + @PunchHours

--SELECT Hours, * FROM #tmpData

    FETCH NEXT FROM csrWeeklyOT INTO @RecordID, @PunchHours
  END

CLOSE csrWeeklyOT
DEALLOCATE csrWeeklyOT

--SELECT Hours, * FROM #tmpData

-- Create tracking tables for whether a consecutive parent or a day has been processed

SELECT DISTINCT ParentID INTO #tmpParents FROM #tmpData
SELECT DISTINCT TransDate INTO #tmpDays FROM #tmpData WHERE PayrollPeriodEndDate = @PeriodDate

--SELECT * FROM #tmpParents
--SELECT * FROM #tmpDays

-- Loop through the records

DECLARE csrRecords CURSOR FOR
  SELECT RecordID, ParentID, TransDate, PayrollPeriodEndDate, Hours FROM #tmpData ORDER BY InDateTime

OPEN csrRecords

  FETCH NEXT FROM csrRecords INTO @RecordID, @ParentID, @TransDate, @PPED, @PunchHours
  WHILE @@FETCH_STATUS = 0
  BEGIN
    DECLARE @SubRecordID    BIGINT  --< @SubRecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
    DECLARE @SubHours       numeric(7,2)
    DECLARE @SubCurrentOT   numeric(7,2)
    DECLARE @SubOT          numeric(7,2)

    -- Process Consecutive Daily OT
    IF (SELECT COUNT(*) FROM #tmpParents WHERE ParentID = @ParentID) = 1
    BEGIN
      DELETE FROM #tmpParents WHERE ParentID = @ParentID

      SET @GroupHours = (SELECT SUM(Hours) FROM #tmpData WHERE ParentID = @ParentID)

--      PRINT CAST(@RecordID AS varchar(20)) + ': Conecutive - ' + CAST(@GroupHours AS varchar(20))

      IF @GroupHours > 12
      BEGIN
        DECLARE csrProcess CURSOR FOR
          SELECT RecordID, Hours, DailyOT + WeeklyOT FROM #tmpData WHERE ParentID = @ParentID ORDER BY InDateTime DESC
        
        OPEN csrProcess
        
          FETCH NEXT FROM csrProcess INTO @SubRecordID, @SubHours, @SubCurrentOT
          WHILE @@FETCH_STATUS = 0
          BEGIN
            IF @GroupHours - @SubHours > 12
            BEGIN
              SET @SubOT = @SubHours
              SET @GroupHours = @GroupHours - @SubHours
            END
            ELSE
            BEGIN
              SET @SubOT = @GroupHours - 12
              SET @GroupHours = 12
            END
            IF @SubOT > @SubCurrentOT
            BEGIN
              UPDATE #tmpData SET DailyOT = DailyOT + (@SubOT - @SubCurrentOT), RegHours = RegHours - (@SubOT - @SubCurrentOT) WHERE RecordID = @SubRecordID
            END

            FETCH NEXT FROM csrProcess INTO @SubRecordID, @SubHours, @SubCurrentOT
          END
        
        CLOSE csrProcess
        DEALLOCATE csrProcess
      END
      
    END

    -- Process TransDate Daily OT
    IF (SELECT COUNT(*) FROM #tmpDays WHERE TransDate = @TransDate) = 1
    BEGIN
      DELETE FROM #tmpDays WHERE TransDate = @TransDate

      SET @GroupHours = (SELECT SUM(Hours) FROM #tmpData WHERE TransDate = @TransDate)

--      PRINT CAST(@RecordID AS varchar(20)) + ': Daily - ' + CAST(@GroupHours AS varchar(20))

      IF @GroupHours > 12
      BEGIN
        DECLARE csrProcess CURSOR FOR
          SELECT RecordID, Hours, DailyOT + WeeklyOT FROM #tmpData WHERE TransDate = @TransDate ORDER BY InDateTime DESC
        
        OPEN csrProcess
        
          FETCH NEXT FROM csrProcess INTO @SubRecordID, @SubHours, @SubCurrentOT
          WHILE @@FETCH_STATUS = 0
          BEGIN
            IF @GroupHours - @SubHours > 12
            BEGIN
              SET @SubOT = @SubHours
              SET @GroupHours = @GroupHours - @SubHours
            END
            ELSE
            BEGIN
              SET @SubOT = @GroupHours - 12
              SET @GroupHours = 12
            END
            IF @SubOT > @SubCurrentOT
            BEGIN
              UPDATE #tmpData SET DailyOT = DailyOT + (@SubOT - @SubCurrentOT), RegHours = RegHours - (@SubOT - @SubCurrentOT) WHERE RecordID = @SubRecordID
            END

            FETCH NEXT FROM csrProcess INTO @SubRecordID, @SubHours, @SubCurrentOT
          END
        
        CLOSE csrProcess
        DEALLOCATE csrProcess
      END
      
    END

    FETCH NEXT FROM csrRecords INTO @RecordID, @ParentID, @TransDate, @PPED, @PunchHours
  END

CLOSE csrRecords
DEALLOCATE csrRecords

--/*
DECLARE @ErrorHeader      varchar(1000)
SET @ErrorHeader = 'Client: ' + @Client + CHAR(13) + CHAR(10)
                 + 'GroupCode: ' + CAST(@GroupCode AS varchar(6)) + CHAR(13) + CHAR(10)
                 + 'PPED: ' + CAST(@PeriodDate AS varchar(20)) + CHAR(13) + CHAR(10)
                 + 'SSN: ' + CAST(@SSN AS varchar(9)) + CHAR(13) + CHAR(10)

IF (
  SELECT COUNT(*) FROM #tmpData 
  WHERE RegHours + DailyOT + WeeklyOT <> Hours
) > 0
BEGIN
  INSERT INTO Scheduler..tblNotifications (SeverityLevel, SeveritySeqNum, JobName, JobID, SetupID, DateAdded, Notification)
  VALUES (1, 1, 'EmplCalc_Colorado', 0, 0, GETDATE(), @ErrorHeader + 'Records exist where Reg + DailyOT + WeeklyOT <> Hours')
END
IF (
  SELECT SUM(RegHours + DailyOT) FROM #tmpData 
  WHERE PayrollPeriodEndDate = @PeriodDate
) > 40
BEGIN
  INSERT INTO Scheduler..tblNotifications (SeverityLevel, SeveritySeqNum, JobName, JobID, SetupID, DateAdded, Notification)
  VALUES (1, 1, 'EmplCalc_Colorado', 0, 0, GETDATE(), @ErrorHeader + 'Sum of Reg + DailyOT > 40')
END
--*/

--SELECT Hours, * FROM #tmpData

--/*
DECLARE @UpdateReg      AS numeric(7,2)
DECLARE @UpdateOT       AS numeric(7,2)

DECLARE csrUpdate CURSOR FOR
  SELECT RecordID, RegHours, DailyOT + WeeklyOT
  FROM #tmpData 
  WHERE PayrollPeriodEndDate >= @PeriodDate

OPEN csrUpdate

  FETCH NEXT FROM csrUpdate INTO @RecordID, @UpdateReg, @UpdateOT
  WHILE @@FETCH_STATUS = 0
  BEGIN
    UPDATE tblTimeHistDetail
    SET RegHours = @UpdateReg, OT_Hours = @UpdateOT
    WHERE RecordID = @RecordID

    FETCH NEXT FROM csrUpdate INTO @RecordID, @UpdateReg, @UpdateOT
  END

CLOSE csrUpdate
DEALLOCATE csrUpdate
--*/

DROP TABLE #tmpParents
DROP TABLE #tmpDays

DROP TABLE #tmpHours
DROP TABLE #tmpData



