USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_SpecPay_SoftScheduling]    Script Date: 5/20/2015 3:29:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_SpecPay_SoftScheduling]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_SpecPay_SoftScheduling] AS' 
END
GO

-- exec usp_APP_SpecPay_SoftScheduling 10, 20, 'CSSF',687000,'2/22/2015',470139572
-- exec usp_APP_SpecPay_SoftScheduling 0,15,0, 'KELL',221284,'1/16/2016',000079421


ALTER Procedure [dbo].[usp_APP_SpecPay_SoftScheduling]
(
  @ShiftIn int,
  @ShiftOut int,
  @UseClockSettings CHAR(1),
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON

DECLARE @InRecordId BIGINT  --< @InRecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @InTime DATETIME
DECLARE @OutRecordId BIGINT  --< @OutRecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @OutTime DATETIME
DECLARE @ShifNo INT
DECLARE @SiteNo INT
DECLARE @DeptNo INT
DECLARE @ShiftInWindow INT
DECLARE @ShiftOutWindow INT
DECLARE @RoundedInTime DATETIME
DECLARE @RoundedOutTime DATETIME

CREATE TABLE #tmpPunchTime (PunchTime DATETIME,DiffMinutes INT)

DECLARE cPunch CURSOR
READ_ONLY
FOR 
-- If we're not rounding the in time, get the rounded in time so that we find the correct shift.  Same with out time.
select i.RecordID,CASE WHEN @ShiftIn = 0 THEN TimeHistory.dbo.PunchDateTime2(i.TransDate,i.InDay,i.InTime) ELSE i.ActualInTime END,o.RecordID,CASE WHEN @ShiftOut = 0 THEN TimeHistory.dbo.PunchDateTime2(o.TransDate,o.OutDay,o.OutTime) ELSE o.ActualOutTime END,o.ShiftNo,o.SiteNo,o.DeptNo, 
    CASE WHEN @UseClockSettings = '1' THEN sn.ShiftInWindow ELSE @ShiftIn END,
	CASE WHEN @UseClockSettings = '1' THEN sn.ShiftOutWindow ELSE @ShiftOut END
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
AND i.TransDate = o.TransDate
and i.SSN = o.SSN
and i.InClass = o.OutClass
AND o.ActualOutTime > i.ActualInTime
INNER JOIN TimeCurrent..tblSiteNames sn
ON o.Client = sn.Client
AND o.GroupCode = sn.GroupCode
AND o.SiteNo = sn.SiteNo
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn
and o.Outclass NOT IN ('L','2','3') -- exclude lunch punches

OPEN cPunch

FETCH NEXT FROM cPunch INTO @InRecordId,@InTime,@OutRecordId,@OutTime,@ShifNo,@SiteNo,@DeptNo,@ShiftInWindow,@ShiftOutWindow
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		SET @RoundedInTime = '1/1/1900'
        SET @RoundedOutTime = '1/1/1900'

		SET @InTime = '1/1/1900 ' + CONVERT(VARCHAR(5),@InTime,114)
		SET @OutTime = '1/1/1900 ' + CONVERT(VARCHAR(5),@OutTime,114)

		IF NOT EXISTS (SELECT 1 FROM TimeCurrent..tblDeptShifts WHERE Client = @Client AND GroupCode = @GroupCode AND SiteNo = @SiteNo AND DeptNo = @DeptNo AND ShiftNo = @ShifNo AND RecordStatus = '1')
		BEGIN
			SET @DeptNo = 99
		END

		TRUNCATE TABLE #tmpPunchTime

		-- Insert all shift start times that are within the window of the in punch
		INSERT INTO #tmpPunchTime
		SELECT ShiftStart,ABS(DATEDIFF(mi,ShiftStart,@InTime))
		FROM TimeCurrent..tblDeptShifts
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SiteNo = @SiteNo
		AND DeptNo = @DeptNo
		AND ShiftNo = @ShifNo
		AND @InTime BETWEEN DATEADD(mi,-1 * @ShiftInWindow,ShiftStart) AND DATEADD(mi,@ShiftInWindow,ShiftStart)

		-- Select the one that's closest to the actual in time
		SELECT TOP 1 @RoundedInTime = PunchTime
		FROM #tmpPunchTime
		ORDER BY DiffMinutes ASC


		-- Select the shift end time that matches the shift start time and is within the out shift window
		SELECT @RoundedOutTime = ShiftEnd
		FROM TimeCurrent..tblDeptShifts
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SiteNo = @SiteNo
		AND DeptNo = @DeptNo
		AND ShiftNo = @ShifNo
		AND ShiftStart = CASE WHEN @RoundedInTime = '1/1/1900' THEN ShiftStart ELSE @RoundedInTime END
		AND @OutTime BETWEEN DATEADD(mi,-1 * @ShiftOutWindow,ShiftEnd) AND DATEADD(mi,@ShiftOutWindow,ShiftEnd)

		IF @RoundedInTime <> '1/1/1900' AND @ShiftInWindow <> 0
		BEGIN
		    SET @RoundedInTime = '1899-12-30 ' + CONVERT(VARCHAR(5),@RoundedInTime,114)

			UPDATE TimeHistory..tblTimeHistDetail
            SET InTime = @RoundedInTime,Hours = datediff(mi,@RoundedInTime, CASE WHEN @RoundedInTime > OutTime THEN DATEADD(dd,1,OutTime) ELSE OutTime END)/60.0
			WHERE RecordID = @InRecordId
			AND InTime <> @RoundedInTime
          
		END

		IF @RoundedOutTime <> '1/1/1900' AND @ShiftOutWindow <> 0
		BEGIN
		    SET @RoundedOutTime = '1899-12-30 ' + CONVERT(VARCHAR(5),@RoundedOutTime,114)
			
			IF EXISTS (
				SELECT 1
				FROM TimeHistory..tblTimeHistDetail
				WHERE RecordID = @OutRecordId
				AND InTime > @RoundedOutTime
			)
			BEGIN
				SET @RoundedOutTime = DATEADD(dd,1,@RoundedOutTime)
			END
			
			UPDATE TimeHistory..tblTimeHistDetail
			SET OutTime = @RoundedOutTime,Hours = datediff(mi,InTime, CASE WHEN InTime > @RoundedOutTime THEN DATEADD(dd,1,@RoundedOutTime) ELSE @RoundedOutTime END)/60.0
			WHERE RecordID = @OutRecordId
			AND OutTime <> @RoundedOutTime
            
		END

		
	END


	FETCH NEXT FROM cPunch INTO @InRecordId,@InTime,@OutRecordId,@OutTime,@ShifNo,@SiteNo,@DeptNo,@ShiftInWindow,@ShiftOutWindow
END

CLOSE cPunch
DEALLOCATE cPunch

IF @Client = 'CSSF'
BEGIN

-- This section checks if the employee's lunch break was below the required minimum number of minutes.  If it was within 15 minutes of the min, the intime will be extended such that it is exactly the min number of minutes.
DECLARE @MinBreakLength NUMERIC(7,2)
DECLARE @MinBreakMinutes INT
DECLARE @BreakInTime DATETIME
DECLARE @BreakMinutes INT
DECLARE @BreakInRecordId BIGINT  --< @BreakInRecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
DECLARE @MinutesDiff INT

DECLARE cLunchPunch CURSOR
READ_ONLY
FOR 
SELECT MIN(BreakLength1),i.InTime,DATEDIFF(mi,o.ActualOutTime,i.ActualInTime), i.RecordID
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
AND i.TransDate = o.TransDate
and i.SSN = o.SSN
and i.InClass = o.OutClass
AND i.ActualOutTime > o.ActualInTime
INNER JOIN TimeCurrent..tblDeptShifts ds
ON o.Client = ds.Client
AND o.GroupCode = ds.GroupCode
AND o.SiteNo = ds.SiteNo
AND (o.DeptNo = ds.DeptNo OR ds.DeptNo = 99)
AND o.ShiftNo = ds.ShiftNo
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
AND o.SSN = @SSN
and o.Outclass IN ('L','2','3')
AND ds.ApplyBreak = 'M'
AND datediff(mi,o.OutTime,i.InTime) >= (BreakLength1 * 60) - 15  -- must be within 15 minutes of minimum break length 
AND datediff(mi,o.OutTime,i.InTime) < BreakLength1 * 60
GROUP BY i.InTime, o.RecordID,o.ActualOutTime,i.RecordID,i.ActualInTime,o.ShiftNo,o.SiteNo,o.DeptNo

OPEN cLunchPunch

FETCH NEXT FROM cLunchPunch INTO @MinBreakLength,@BreakInTime,@BreakMinutes,@BreakInRecordId
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
	    SET @MinBreakMinutes = @MinBreakLength * 60
		SET @MinutesDiff = @MinBreakMinutes - @BreakMinutes

		UPDATE TimeHistory..tblTimeHistDetail
		SET InTime = DATEADD(mi,(@MinutesDiff),InTime)
		WHERE RecordID = @BreakInRecordId		

		UPDATE TimeHistory..tblTimeHistDetail
		SET Hours = DATEDIFF(mi,InTime,CASE WHEN ActualInTime > ActualOutTime THEN DATEADD(dd,1,OutTime) ELSE OutTime END)/60.0
		WHERE RecordID = @BreakInRecordId		


	END

	FETCH NEXT FROM cLunchPunch INTO @MinBreakLength,@BreakInTime,@BreakMinutes,@BreakInRecordId
END

CLOSE cLunchPunch
DEALLOCATE cLunchPunch

END


