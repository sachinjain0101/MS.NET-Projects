CREATE          Procedure [dbo].[usp_FountainView_EmplCalc_OT_Helper]
	@Client 		varchar(4), 
	@GroupCode 		int,
	@PeriodDate 	datetime, 
	@SSN 			int 
AS


SET NOCOUNT ON


/*
DECLARE @Client			varchar(4)
DECLARE @GroupCode		int
DECLARE @PeriodDate		datetime
DECLARE @SSN			int

SELECT @Client = 'HORI'
SELECT @GroupCode = 589009
SELECT @PeriodDate = '7/19/07'
SELECT @SSN = 592212057
*/

DECLARE @PPED2 datetime
DECLARE @JobID int
DECLARE	@MaxBetweenIns			int			-- Max minutes between In Punches to consider
DECLARE @MaxBetweenPunches		int			-- Max minutes between Out and In Punches to consider
DECLARE @RecID BIGINT  --< @RecId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--

Set @PPED2 = dateadd(day,-7,@PeriodDate)

SELECT @MaxBetweenIns = XRefValue * 60 FROM TimeCurrent..tblClientXRef WHERE Client = @Client AND XRefID = 'MAXBETWEENINS'
SELECT @MaxBetweenPunches = XRefValue FROM TimeCurrent..tblClientXRef WHERE Client = @Client AND XRefID = 'MAXBETWEENPUNCHES'


IF @MaxBetweenIns is NULL
BEGIN
  Set @MaxBetweenIns = 720
END

IF @MaxBetweenPunches is NULL
BEGIN
  Set @MaxBetweenPunches = 90
END

SELECT thd.RecordID, thd.ShiftNo, thd.Payrollperiodenddate, thd.TransDate, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime
INTO #tmpPunches
FROM tblTimeHistDetail AS thd
WHERE thd.Client = @Client
	AND thd.GroupCode = @GroupCode
	AND thd.PayrollPeriodEndDate IN(@PeriodDate,@PPED2)
	AND thd.SSN = @SSN
	AND thd.InDay <> 10 AND thd.InTime IS NOT NULL
	AND thd.OutDay <> 10 AND thd.OutTime IS NOT NULL
  AND thd.TransType <> '7'
	AND LTrim(thd.ClockAdjustmentNo) = ''
ORDER BY thd.ShiftNo ASC, thd.TransDate ASC, thd.InDay ASC, thd.InTime ASC

SELECT NextPunches.RecordID, Punches.TransDate, Punches.Payrollperiodenddate, oPPED = @PeriodDate
INTO #tmpRecords
FROM #tmpPunches AS Punches
INNER JOIN #tmpPunches AS NextPunches
ON NextPunches.TransDate > Punches.TransDate
	AND NextPunches.RecordID <> Punches.RecordID
	AND DateDiff(minute, dbo.PunchDateTime2(Punches.TransDate, Punches.InDay, Punches.InTime),
		dbo.PunchDateTime2(NextPunches.TransDate, NextPunches.InDay, NextPunches.InTime)) < @MaxBetweenIns
	AND DateDiff(minute, dbo.PunchDateTime2(Punches.TransDate, Punches.OutDay, Punches.OutTime),
		dbo.PunchDateTime2(NextPunches.TransDate, NextPunches.InDay, NextPunches.InTime)) < @MaxBetweenPunches
	AND dbo.PunchDateTime2(Punches.TransDate, Punches.OutDay, Punches.OutTime) <=
		dbo.PunchDateTime2(NextPunches.TransDate, NextPunches.InDay, NextPunches.InTime)
--	AND DatePart(weekday, Punches.TransDate) = Punches.InDay
	AND Punches.ShiftNo = NextPunches.ShiftNo

--SELECT * FROM #tmpRecords
--SELECT * FROM #tmpPunches
--/*

DECLARE cThd CURSOR
READ_ONLY
FOR 
Select RecordID, TransDate, Payrollperiodenddate, oPPED from #tmpRecords

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
DECLARE @TransDate datetime
DECLARE @PPED datetime
DECLARE @oPPED datetime

OPEN cTHD

FETCH NEXT FROM cTHD INTO @RecordID, @TransDate, @PPED, @oPPED
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    IF @PPED <> @oPPED
    BEGIN
      --PRINT 'PPED change for RecordID : ' + str(@RecordID)
      -- Move the transaction only if it does not already exist in the prior week.
      
      -- Check to see if it exist in the prior week
      Set @RecID = NULL
      Set @RecID = (Select t1.RecordID from TimeHistory..tblTimeHistDetail as t1
                    Inner Join TimeHistory..tblTimeHistDetail As t2
                    on t2.Client = t1.Client
                    and t2.groupcode = t1.groupcode
                    and t2.payrollperiodenddate = @PPED
                    and t2.InDay = t1.InDay
                    and t2.InTime = t1.Intime
                    and t2.outday = t1.outday
                    and t2.OutTime = t1.OutTime
                    and t2.hours = t1.hours
                    where t1.recordID = @RecordID ) 

      IF isnull(@RecID,0) = 0
      BEGIN
        --Print 'Transaction Moved to Prior Week'
        -- It does not exist so move it and recalc the prior week time card.
        UPDATE tblTimeHistDetail SET TransDate = @TransDate, PayrollPeriodEndDate = @PPED WHERE RecordID = @RecordID
        -- Need to recalc Prior week.
        INSERT INTO Scheduler..tblJobs (ProgramName, Client, GroupCode, RequestedBy) VALUES ('EmplCalc', @Client, @GroupCode, 'SpecialPay')
        SET @JobID = SCOPE_IDENTITY()
      
        INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'CLIENT', @Client)
        INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'GROUP', @GroupCode)
        INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'DATE', CONVERT(varchar(12), @PPED2, 101))
        INSERT INTO Scheduler..tblJobs_Parms (JobID, ParmKey, Parm) VALUES (@JobID, 'SSN', @SSN)
        --Print @JObID
      END
      ELSE
      BEGIN
        --Print 'Transaction already in prior week, deleted from current week.'
        -- It already exist in the prior week and is in the current week.
        -- this is because the punch is in the wrong week on the trans clock and it will continue to get added back to the current
        -- week on the web because it's on the clock. Not sure how to delete a punch from a time card on the trans clock so it will
        -- be delete on the web when it is re-added by the clock and it has already been moved to the prior week.
        -- 
        Delete from TimeHistory..tblTimeHistDetail where recordid = @RecordID
      END
    END
    ELSE
    BEGIN
      UPDATE tblTimeHistDetail SET TransDate = @TransDate WHERE RecordID = @RecordID
    END
	END
	FETCH NEXT FROM cTHD INTO @RecordID, @TransDate, @PPED, @oPPED
END

CLOSE cTHD
DEALLOCATE cTHD


IF (SELECT COUNT(RecordID) FROM #tmpRecords) > 0
BEGIN
  DROP TABLE #tmpPunches
  DROP TABLE #tmpRecords
	RETURN 1
END
ELSE
BEGIN
  DROP TABLE #tmpPunches
  DROP TABLE #tmpRecords
	RETURN 0
END









