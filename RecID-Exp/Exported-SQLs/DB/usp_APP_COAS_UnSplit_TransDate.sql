CREATE Procedure [dbo].[usp_APP_COAS_UnSplit_TransDate]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS

SET NOCOUNT ON


DECLARE @SplitRecordId BIGINT  --< @SplitRecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @OldTransDate DATETIME
DECLARE @NewTransDate DATETIME
DECLARE @LastWeek DATE = DATEADD(dd,-7,@PPED)
DECLARE @ThisWeek DATE = @PPED
DECLARE @NextWeek DATE = DATEADD(dd,7,@PPED)
DECLARE @OutDay INT
DECLARE @OutTime DATETIME
DECLARE @RecordId BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @CloseHour DATETIME
DECLARE @CloseHourStr VARCHAR(4)

EXEC TimeHistory..usp_EmplCalc_OT_AutoClockOut_AT_Midnight @Client,@GroupCode,@PPED,@SSN

-- Assumption:  All clocks have the same close hour
SELECT @CloseHourStr = RIGHT('0000' + CAST(CloseHour AS VARCHAR),4)
FROM TimeCurrent..tblSiteNames sn
WHERE Client = @Client
AND GroupCode = @GroupCode

SET @CloseHour = '1899-12-30 ' + LEFT(@CloseHourStr,2) + ':' + RIGHT(@CloseHourStr,2) + ':00'

-- In case the employee opted to not have the punch rounded, move it to the next day if it's within the shift in window
UPDATE TimeHistory..tblTimeHistDetail
SET TransDate = DATEADD(dd,1,TransDate)
WHERE RecordID IN (
	SELECT thd.RecordID
	FROM TimeHistory..tblTimeHistDetail thd
	INNER JOIN TimeCurrent..tblSiteNames sn
	ON thd.Client = sn.Client
	AND thd.GroupCode = sn.GroupCode
	AND thd.SiteNo = sn.SiteNo
	WHERE thd.Client = @Client
	AND thd.GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED
	AND thd.SSN = @SSN
	AND DATEDIFF(MINUTE,InTime,@CloseHour) BETWEEN 1 AND EODWindow
	AND DATEPART(dw,thd.TransDate) = thd.InDay 
)

-- Update the pay period if it was moved into the next week
UPDATE TimeHistory..tblTimeHistDetail
SET PayrollPeriodEndDate = DATEADD(dd,7,PayrollPeriodEndDate), MasterPayrollDate = DATEADD(dd,7,MasterPayrollDate)
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SSN = @SSN
AND TransDate > PayrollPeriodEndDate


-- Loop through all the split punches
DECLARE csrSplits CURSOR READ_ONLY STATIC
FOR SELECT splitOut.TransDate,splitIn.TransDate,splitIn.RecordID,splitIn.OutDay,splitIn.OutTime
	FROM TimeHistory..tblTimeHistDetail splitOut
	INNER JOIN TimeHistory..tblTimeHistDetail splitIn
	ON splitOut.Client = splitIn.Client
	AND splitOut.GroupCode = splitIn.GroupCode
	AND splitOut.SSN = splitIn.SSN
	AND splitOut.PayrollPeriodEndDate IN (@LastWeek,@ThisWeek,@NextWeek)
	AND splitOut.OutClass = splitIn.InClass
	AND datediff(dd,splitOut.TransDate,splitIn.TransDate) = 1
	WHERE splitOut.Client = @Client
	AND splitOut.GroupCode = @GroupCode
	AND splitOut.SSN = @SSN
	AND splitOut.PayrollPeriodEndDate IN (@LastWeek,@ThisWeek,@NextWeek)
	AND splitOut.OutClass = 'T'
	AND splitOut.ActualOutTime = splitIn.ActualInTime	
	ORDER BY splitOut.TransDate
OPEN csrSplits
FETCH NEXT FROM csrSplits INTO @NewTransDate,@OldTransDate,@SplitRecordId,@OutDay,@OutTime
WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN

    -- Look for contiguous punches the next day and move them to the previous day.
    SET @RecordId = @SplitRecordId

	WHILE @RecordId IS NOT NULL
	BEGIN

		UPDATE TimeHistory..tblTimeHistDetail
		SET TransDate = @NewTransDate, CostID = @OldTransDate
	  	WHERE RecordID = @RecordId

		SET @RecordId = NULL

		SELECT @RecordId = RecordID,@OutDay = OutDay, @OutTime = OutTime
		FROM TimeHistory..tblTimeHistDetail thd
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SSN = @SSN
		AND TransDate = @OldTransDate
		AND PayrollPeriodEndDate IN (@LastWeek,@ThisWeek,@NextWeek)
		AND DATEDIFF(mi,TimeHistory.dbo.PunchDateTime2(@OldTransDate,@OutDay,@OutTime),TimeHistory.dbo.PunchDateTime2(TransDate,InDay,InTime)) BETWEEN 0 AND 90
		ORDER BY TimeHistory.dbo.PunchDateTime2(TransDate,InDay,InTime)

	END

	-- If the majority of the time was moved to the previous day, move the break too.
	IF EXISTS (
		SELECT TransDate
		FROM TimeHistory..tblTimeHistDetail
		WHERE Client = @Client
		AND GroupCode= @GroupCode
		AND SSN = @SSN
		AND PayrollPeriodEndDate IN (@LastWeek,@ThisWeek,@NextWeek)
		AND TransDate = @OldTransDate
		GROUP BY TransDate HAVING SUM(Hours) <= 0
	)
	BEGIN
		UPDATE TimeHistory..tblTimeHistDetail
		SET TransDate = @NewTransDate, CostID = @OldTransDate
		WHERE Client = @Client
		AND GroupCode= @GroupCode
		AND SSN = @SSN
		AND PayrollPeriodEndDate IN (@LastWeek,@ThisWeek,@NextWeek)
		AND TransDate = @OldTransDate
		AND ClockAdjustmentNo = '8'
	END


	-- Pulled a punch into the previous week
	UPDATE TimeHistory..tblTimeHistDetail
	SET TimeHistory..tblTimeHistDetail.PayrollPeriodEndDate = ped.PayrollPeriodEndDate,
		TimeHistory..tblTimeHistDetail.MasterPayrollDate = ped.MasterPayrollDate
	FROM TimeHistory..tblTimeHistDetail
	INNER Join TimeHistory..tblPeriodEndDates ped
	ON TimeHistory..tblTimeHistDetail.Client = ped.Client
	AND TimeHistory..tblTimeHistDetail.GroupCode = ped.GroupCode
	AND DATEADD(dd,-7,TimeHistory..tblTimeHistDetail.PayrollPeriodEndDate) = ped.PayrollPeriodEndDate
	WHERE TimeHistory..tblTimeHistDetail.Client = @Client
	AND TimeHistory..tblTimeHistDetail.GroupCode = @GroupCode
	AND TimeHistory..tblTimeHistDetail.SSN = @SSN
	AND TimeHistory..tblTimeHistDetail.PayrollPeriodEndDate IN (@LastWeek,@ThisWeek,@NextWeek)
	AND datediff(dd,TimeHistory..tblTimeHistDetail.TransDate,TimeHistory..tblTimeHistDetail.PayrollPeriodEndDate) = 7

  END
  FETCH NEXT FROM csrSplits INTO @NewTransDate,@OldTransDate,@SplitRecordId,@OutDay,@OutTime
END
CLOSE csrSplits
DEALLOCATE csrSplits

-- If a new punch was moved into the previous week, it won't be picked up by EmplCalc when this week is processed.   Need to schedule a job for the previous week.
IF EXISTS (
	SELECT 1
	FROM TimeHistory..tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = @LastWeek
	AND Hours <> (RegHours + OT_Hours + DT_Hours)
)
BEGIN
	DECLARE @JobID    int

	INSERT INTO Scheduler..tblJobs (ProgramName, Client, GroupCode, RequestedBy) 
	VALUES ('EmplCalc', @Client, @GroupCode, 'Special Pay')
	SET @JobID = SCOPE_IDENTITY()
  
	INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'CLIENT', @Client)
	INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'GROUP', ltrim(str(@GroupCode)))
	INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'DATE', CONVERT(varchar(12), @LastWeek, 101))
	INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'SSN', ltrim(Str(@SSN)))
END 
