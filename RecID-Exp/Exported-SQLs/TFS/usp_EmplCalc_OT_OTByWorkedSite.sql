Create PROCEDURE [dbo].[usp_EmplCalc_OT_OTByWorkedSite]
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

SET @Client = 'PLAT'
SET @GroupCode = 271501
SET @PeriodDate = '5/27/05'
SET @SSN = 461390004
*/

DECLARE @WklyHrsBefore_OT   AS numeric(5,2)

SET @WklyHrsBefore_OT = 40.00

BEGIN TRAN EmplCalc_OT_OTByWorkedSite

UPDATE tblTimeHistDetail
SET RegHours = Hours, OT_Hours = 0, DT_Hours = 0
WHERE Client = @Client
  AND GroupCode = @GroupCode
  AND SSN = @SSN
  AND PayrollPeriodEndDate = @PeriodDate

DECLARE @tmpSiteNo          AS int

DECLARE csrSites CURSOR READ_ONLY FOR 
  SELECT thd.SiteNo AS HoursSum
  FROM TimeHistory..tblTimeHistDetail thd
  LEFT JOIN TimeCurrent..tblAdjCodes AS adjs
  ON adjs.Client = thd.Client
    AND adjs.GroupCode = thd.GroupCode
    AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.SSN = @SSN
    AND thd.PayrollPeriodEndDate = @PeriodDate
    AND (adjs.Worked = 'Y' OR thd.ClockAdjustmentNo = ' ')
  GROUP BY thd.SiteNo
  HAVING SUM(thd.Hours) > @WklyHrsBefore_OT
  ORDER BY thd.SiteNo

OPEN csrSites
FETCH NEXT FROM csrSites INTO @tmpSiteNo
WHILE (@@fetch_status = 0)
BEGIN
  
  DECLARE @tmpRecordID      AS BIGINT  --< @tmpRecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
  DECLARE @tmpHours         AS numeric(5,2)
  DECLARE @HoursSum         AS numeric(5,2)

  SET @HoursSum = 0

  DECLARE csrSiteHours CURSOR READ_ONLY FOR 
    SELECT thd.RecordID, thd.Hours
    FROM TimeHistory..tblTimeHistDetail thd
    LEFT JOIN TimeCurrent..tblAdjCodes AS adjs
    ON adjs.Client = thd.Client
      AND adjs.GroupCode = thd.GroupCode
      AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
    WHERE thd.Client = @Client
      AND thd.GroupCode = @GroupCode
      AND thd.SSN = @SSN
      AND thd.PayrollPeriodEndDate = @PeriodDate
      AND thd.SiteNo = @tmpSiteNo
      AND (adjs.Worked = 'Y' OR thd.ClockAdjustmentNo = ' ')
    ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) ASC

  OPEN csrSiteHours
  FETCH NEXT FROM csrSiteHours INTO @tmpRecordID, @tmpHours
  WHILE (@@fetch_status = 0)
  BEGIN

    IF @HoursSum >= @WklyHrsBefore_OT
    BEGIN
      IF @HoursSum + @tmpHours >= @WklyHrsBefore_OT
        UPDATE tblTimeHistDetail 
        SET RegHours = 0, OT_Hours = @tmpHours, DT_Hours = 0 
        WHERE RecordID = @tmpRecordID
      ELSE
        UPDATE tblTimeHistDetail 
        SET RegHours = @tmpHours - (@WklyHrsBefore_OT - @HoursSum), OT_Hours = @WklyHrsBefore_OT - @HoursSum, DT_Hours = 0 
        WHERE RecordID = @tmpRecordID
    END
    ELSE IF @HoursSum + @tmpHours > @WklyHrsBefore_OT
      UPDATE tblTimeHistDetail 
      SET RegHours = @WklyHrsBefore_OT - @HoursSum, OT_Hours = @HoursSum + @tmpHours - @WklyHrsBefore_OT, DT_Hours = 0 
      WHERE RecordID = @tmpRecordID

    SET @HoursSum = @HoursSum + @tmpHours

  	FETCH NEXT FROM csrSiteHours INTO @tmpRecordID, @tmpHours
  END
  CLOSE csrSiteHours
  DEALLOCATE csrSiteHours  


	FETCH NEXT FROM csrSites INTO @tmpSiteNo
END
CLOSE csrSites
DEALLOCATE csrSites

COMMIT TRAN EmplCalc_OT_OTByWorkedSite


