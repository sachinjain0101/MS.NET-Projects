CREATE Procedure [dbo].[usp_APP_MPOW_231033_SP]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS

SET NOCOUNT ON

DECLARE @RecordId BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--
DECLARE @TransDate datetime
DECLARE @InTime DATETIME
DECLARE @OutTime DATETIME
DECLARE @InDay INT
DECLARE @EmplClassID INT
DECLARE @AdjustmentName VARCHAR(10)
DECLARE @DefaultQue INT
DECLARE @DefaultPriority INT
DECLARE @DefaultClass INT
DECLARE @JobId INT


SELECT TOP 1 @EmplClassID = EmplClassID 
FROM TimeCurrent..tblEmplClass  WITH(NOLOCK)
WHERE Client = @Client 
AND GroupCode = @GroupCode 
AND [Description] = 'Shift 3' 
AND RecordStatus = '1'

IF NOT EXISTS (

	SELECT 1
	FROM TimeHistory..tblEmplSites es
	WHERE es.Client = @Client
	AND es.GroupCode = @GroupCode
	AND es.SSN = @SSN
	AND es.PayrollPeriodEndDate = @PPED
	AND es.EmplClassID = @EmplClassID
)
BEGIN
	RETURN
END

-- Update all break adjustments to clockAdjustmentNo 1.  If it remains 8, the following scenario happens:
-- User adds a punch for Mon 10/26.  
-- This prodedure moves the punch and break to Mon 10/27.
-- Use adds a punch for Tue 10/27.
-- EmplCalc sees there's already a ClockAdjustmentNo = 8 for 10/27 and doesn't add one.
-- This procedure moves the punch to Tue 10/28 and there is no break for 10/28.

UPDATE TimeHistory..tblTimeHistDetail
SET ClockAdjustmentNo = 1
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND ClockAdjustmentNo = 8

DECLARE cPunch CURSOR
READ_ONLY
FOR 

SELECT RecordID,TransDate,InTime,OutTime,InDay,AdjustmentName
FROM TimeHistory..tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND InDay <> 10
AND ISNULL(ClockAdjustmentNo,'') IN ('',' ')

OPEN cPunch

FETCH NEXT FROM cPunch INTO @RecordId,@TransDate,@InTime,@OutTime,@InDay,@AdjustmentName
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN    

		IF ((@InTime BETWEEN '1899-12-30 13:00:00.000' AND '1899-12-30 23:59:00.000') OR @AdjustmentName = 'BREAK') AND DATEPART(dw,@TransDate) = @InDay
		BEGIN
				UPDATE TimeHistory..tblTimeHistDetail
				SET TransDate = DATEADD(dd,1,@TransDate)
				WHERE RecordID = @RecordId
				
				-- Now move the auto-breaks
				IF EXISTS (
				   SELECT 1
				   FROM TimeHistory..tblTimeHistDetail
				   WHERE Client = @Client
				   AND GroupCode = @GroupCode
				   AND SSN = @SSN
				   AND PayrollPeriodEndDate = @PPED
				   AND TransDate = @TransDate
				   AND AdjustmentName = 'Break'
				)
				BEGIN
				   -- If a break doesn't alredy exist in the next day, move it
				   IF NOT EXISTS (
				   SELECT 1
				   FROM TimeHistory..tblTimeHistDetail
				   WHERE Client = @Client
				   AND GroupCode = @GroupCode
				   AND SSN = @SSN
				   AND PayrollPeriodEndDate = @PPED
				   AND TransDate = DATEADD(dd,1,@TransDate)
				   AND AdjustmentName = 'Break'
				   )
				   BEGIN
					 UPDATE TimeHistory..tblTimeHistDetail
					 SET TransDate = DATEADD(dd,1,@TransDate)
					 WHERE Client = @Client
					 AND GroupCode = @GroupCode
					 AND SSN = @SSN
					 AND PayrollPeriodEndDate = @PPED
					 AND TransDate = @TransDate
					 AND AdjustmentName = 'Break'
					 AND InDay = @InDay					
				   END
				END
		END
	FETCH NEXT FROM cPunch INTO @RecordId,@TransDate,@InTime,@OutTime,@InDay,@AdjustmentName
	END
END

CLOSE cPunch
DEALLOCATE cPunch;


WITH CTE AS (
   SELECT RecordID,TransDate,
       RN = ROW_NUMBER()OVER(PARTITION BY TransDate ORDER BY TransDate)
   FROM TimeHistory..tblTimeHistDetail
   WHERE Client = @Client
   AND GroupCode = @GroupCode
   AND SSN = @SSN
   AND PayrollPeriodEndDate = @PPED
   AND AdjustmentName = 'BREAK'
)
DELETE FROM CTE WHERE rn > 1

SELECT  @DefaultQue = DefaultQue, 
		@DefaultPriority = DefaultPriority, 
		@DefaultClass = DefaultClass
FROM Scheduler..tblPrograms
WHERE ProgramName = 'EMPLCALC'

-- If the time moves into the next week, that week needs to be recalced.
IF EXISTS (
SELECT 1
FROM TimeHistory..tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND TransDate > PayrollPeriodEndDate
)
BEGIN

	UPDATE TimeHistory..tblTimeHistDetail
	SET PayrollPeriodEndDate = DATEADD(dd,7,PayrollPeriodEndDate)
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = @PPED
	AND TransDate > PayrollPeriodEndDate

	UPDATE TimeHistory.dbo.tblEmplNames
	SET NeedsRecalc = '1'
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = DATEADD(dd,7,@PPED)

						
	INSERT INTO Scheduler..tbljobs(ProgramName, TimeRequested, TimeQued, Client, GroupCode, PayrollPeriodEndDate)
	VALUES ('EMPLCALC', getDate(), getDate(), @Client, @GroupCode, DATEADD(dd,7,@PPED))
						
	SELECT @JobID = SCOPE_IDENTITY()
		
	INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm) VALUES (@JobID, 'CLIENT', @Client)						
	INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm) VALUES (@JobID, 'GROUP', @GroupCode)						
	INSERT INTO Scheduler..tbljobs_Parms(JobID, ParmKey, Parm) VALUES (@JobID, 'DATE', CONVERT(varchar(10), DATEADD(dd,7,@PPED), 101))						
	INSERT INTO Scheduler..tbljobQue(JobID, Priority, Que, Class) VALUES (@JobID, @DefaultPriority, @DefaultQue, @DefaultClass)


END

IF @Client = 'MPOW' AND @GroupCode = 231033
BEGIN
	EXEC TimeHistory.. usp_APP_NthDayDT_AfterMinHours 1.50,1,40,40,@Client,@GroupCode,@PPED,@SSN
END





