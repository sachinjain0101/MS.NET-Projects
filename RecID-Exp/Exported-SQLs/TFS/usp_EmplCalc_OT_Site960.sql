Create PROCEDURE [dbo].[usp_EmplCalc_OT_Site960]
	@Client 		  varchar(4), 
	@GroupCode 		int,
	@PeriodDate 	datetime, 
	@SSN 			    int 
AS

SET NOCOUNT ON
--*/

-- OT up to 10, DT after 10 on Sundays

/*
DECLARE @Client			  varchar(4)
DECLARE @GroupCode		int
DECLARE @PeriodDate		datetime
DECLARE @SSN			    int

SELECT @Client = 'DAVI'
SELECT @GroupCode = 301100
SELECT @PeriodDate = '11/05/05'
SELECT @SSN = 492561868
*/

BEGIN TRAN

DECLARE @SundayHours  numeric(7,2)

SET @SundayHours = (
  SELECT SUM(thd.Hours)
  FROM tblTimeHistDetail thd
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.PayrollPeriodEndDate = @PeriodDate
    AND thd.SSN = @SSN
    AND DATEPART(weekday, thd.TransDate) = 1
)

DECLARE csrHours CURSOR READ_ONLY
FOR 
  SELECT thd.RecordID, thd.Hours
  FROM tblTimeHistDetail thd
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.PayrollPeriodEndDate = @PeriodDate
    AND thd.SSN = @SSN
    AND DATEPART(weekday, thd.TransDate) = 1
  ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) ASC

DECLARE @tmpRecordID    BIGINT  --< @tmpRecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
DECLARE @tmpHours       numeric(7,2)

DECLARE @AllocHours     numeric(7,2)

SET @AllocHours = 0

OPEN csrHours

FETCH NEXT FROM csrHours INTO @tmpRecordID, @tmpHours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    IF @AllocHours + @tmpHours <= 10
    BEGIN
      UPDATE tblTimeHistDetail
      SET RegHours = 0, OT_Hours = Hours, DT_Hours = 0
      WHERE RecordID = @tmpRecordID
    END
    ELSE
    BEGIN
      IF @AllocHours > 10
      BEGIN
        UPDATE tblTimeHistDetail
        SET RegHours = 0, OT_Hours = 0, DT_Hours = Hours
        WHERE RecordID = @tmpRecordID
      END
      ELSE
      BEGIN
        UPDATE tblTimeHistDetail
        SET RegHours = 0, OT_Hours = 10 - @AllocHours, DT_Hours = @AllocHours + Hours - 10
        WHERE RecordID = @tmpRecordID
      END
    END

    SET @AllocHours = @AllocHours + @tmpHours
	END
	FETCH NEXT FROM csrHours INTO @tmpRecordID, @tmpHours
END

CLOSE csrHours
DEALLOCATE csrHours

/*
SELECT hours, reghours, ot_hours, dt_hours, *
FROM tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PeriodDate
and datepart(weekday, transdate) = 1
*/

COMMIT TRAN

EXEC usp_DAVT_AcuteSpecPay_ShiftDiff 0, @Client, @GroupCode, @PeriodDate, @SSN




