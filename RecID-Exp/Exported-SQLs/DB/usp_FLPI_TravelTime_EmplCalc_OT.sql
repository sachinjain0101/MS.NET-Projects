CREATE PROCEDURE [dbo].[usp_FLPI_TravelTime_EmplCalc_OT] (
	@Client 		  varchar(4), 
	@GroupCode 		int,
	@PeriodDate 	datetime, 
	@SSN 			    int 
) AS


SET NOCOUNT ON
--*/
	
/*
DECLARE	@Client 		  varchar(4)
DECLARE	@GroupCode 		int
DECLARE	@PeriodDate 	datetime
DECLARE	@SSN 			    int

SET @Client 		  = 'FLPI'
SET @GroupCode 		= 281100
SET @PeriodDate   = '12/12/04'
SET @SSN 			    = 260378870

SET NOCOUNT ON
*/

/*
If the empl has Travel Time in Department 11 for non-Primary Site(s) AND he has OT at his Primary Site,
then allocate as much OT as possible to the non-Primary Site(s)
*/

-- Used for validation after calculations
DECLARE @Hours           numeric(5,2)
DECLARE @RegHours        numeric(5,2)
DECLARE @OT_Hours        numeric(5,2)

SELECT @Hours = ISNULL(SUM(Hours), 0), @RegHours = ISNULL(SUM(RegHours), 0), @OT_Hours = ISNULL(SUM(OT_Hours), 0)
FROM tblTimeHistDetail
WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PeriodDate AND SSN = @SSN


DECLARE @PrimarySite     int
DECLARE @PrimaryOT       numeric(5,2)
DECLARE @NonPrimaryHours numeric(5,2)

SET @PrimarySite = (SELECT ISNULL(PrimarySite, 0) FROM TimeCurrent..tblEmplNames WHERE Client = @Client AND GroupCode = @GroupCode AND SSN = @SSN)
--PRINT @PrimarySite

SET @PrimaryOT = (
  SELECT ISNULL(SUM(OT_Hours), 0) FROM tblTimeHistDetail
  WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PeriodDate AND SSN = @SSN
    AND SiteNo = @PrimarySite
)

SET @NonPrimaryHours = (
  SELECT ISNULL(SUM(Hours), 0) FROM tblTimeHistDetail
  WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PeriodDate AND SSN = @SSN
    AND SiteNo <> @PrimarySite
)

IF (@PrimaryOT  > 0) AND (@NonPrimaryHours > 0) AND ((
  SELECT ISNULL(SUM(Hours), 0) FROM tblTimeHistDetail
  WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PeriodDate AND SSN = @SSN
    AND SiteNo <> @PrimarySite AND ClockAdjustmentNo = 'T'
) > 0)
BEGIN
  /*
  Iterate backward through the Time Card placing as much Primary OT in non-Primary Sites as possible
  */

  /*
  SELECT thd.Hours, thd.RegHours, thd.OT_Hours, * 
  FROM tblTimeHistDetail AS thd
  WHERE thd.Client = @Client AND thd.GroupCode = @GroupCode AND thd.PayrollPeriodEndDate = @PeriodDate AND thd.SSN = @SSN
  ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) DESC
  */

  DECLARE @tmpPrimaryOT AS numeric(5,2)
  SET @tmpPrimaryOT = @PrimaryOT

  DECLARE @tmpRecordID  AS BIGINT  --< @tmpRecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
  DECLARE @tmpRegHours  AS numeric(5,2)
  DECLARE @tmpOT_Hours  AS numeric(5,2)

  BEGIN TRAN

  /*
  Place possible Primary Site OT into non-Primary Site records
  */

  DECLARE csrTimeCard CURSOR FOR
    SELECT thd.RecordID, thd.RegHours, thd.OT_Hours
    FROM tblTimeHistDetail AS thd
    WHERE thd.Client = @Client AND thd.GroupCode = @GroupCode AND thd.PayrollPeriodEndDate = @PeriodDate AND thd.SSN = @SSN
      AND thd.SiteNo <> @PrimarySite AND thd.RegHours > 0
    ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) DESC
  
  OPEN csrTimeCard
  
    FETCH NEXT FROM csrTimeCard INTO @tmpRecordID, @tmpRegHours, @tmpOT_Hours
    WHILE @@FETCH_STATUS = 0
    BEGIN
      IF @tmpPrimaryOT > @tmpRegHours
      BEGIN
        UPDATE tblTimeHistDetail SET RegHours = 0, OT_Hours = OT_Hours + @tmpRegHours WHERE RecordID = @tmpRecordID
        SET @tmpPrimaryOT = @tmpPrimaryOT - @tmpRegHours
      END
      ELSE
      BEGIN
        UPDATE tblTimeHistDetail SET RegHours = RegHours - @tmpPrimaryOT, OT_Hours = OT_Hours + @tmpPrimaryOT WHERE RecordID = @tmpRecordID
        SET @tmpPrimaryOT = 0
      END
      
      FETCH NEXT FROM csrTimeCard INTO @tmpRecordID, @tmpRegHours, @tmpOT_Hours
    END
  
  CLOSE csrTimeCard
  DEALLOCATE csrTimeCard

  /*
  Balance Primary Site records after changes
  */

  DECLARE @BalanceHours    numeric(5,2)
  SET @BalanceHours = @PrimaryOT - @tmpPrimaryOT --Hours that were moved

  IF @BalanceHours > 0
  BEGIN
    DECLARE csrTimeCard CURSOR FOR
      SELECT thd.RecordID, thd.RegHours, thd.OT_Hours
      FROM tblTimeHistDetail AS thd
      WHERE thd.Client = @Client AND thd.GroupCode = @GroupCode AND thd.PayrollPeriodEndDate = @PeriodDate AND thd.SSN = @SSN
        AND thd.SiteNo = @PrimarySite AND thd.OT_Hours > 0
      ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) DESC
    
    OPEN csrTimeCard
    
      FETCH NEXT FROM csrTimeCard INTO @tmpRecordID, @tmpRegHours, @tmpOT_Hours
      WHILE @@FETCH_STATUS = 0
      BEGIN
        IF @tmpOT_Hours > @BalanceHours
        BEGIN
          UPDATE tblTimeHistDetail SET RegHours = RegHours + @BalanceHours, OT_Hours = OT_Hours - @BalanceHours WHERE RecordID = @tmpRecordID
          SET @BalanceHours = 0
        END
        ELSE
        BEGIN
          UPDATE tblTimeHistDetail SET RegHours = RegHours + @tmpOT_Hours, OT_Hours = 0 WHERE RecordID = @tmpRecordID
          SET @BalanceHours = @BalanceHours - @tmpOT_Hours
        END
        
        FETCH NEXT FROM csrTimeCard INTO @tmpRecordID, @tmpRegHours, @tmpOT_Hours
      END
    
    CLOSE csrTimeCard
    DEALLOCATE csrTimeCard
  END

  /*
  SELECT thd.Hours, thd.RegHours, thd.OT_Hours, * 
  FROM tblTimeHistDetail AS thd
  WHERE thd.Client = @Client AND thd.GroupCode = @GroupCode AND thd.PayrollPeriodEndDate = @PeriodDate AND thd.SSN = @SSN
  ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) DESC
  */

  DECLARE @Hours2           numeric(5,2)
  DECLARE @RegHours2        numeric(5,2)
  DECLARE @OT_Hours2        numeric(5,2)
  
  SELECT @Hours2 = ISNULL(SUM(Hours), 0), @RegHours2 = ISNULL(SUM(RegHours), 0), @OT_Hours2 = ISNULL(SUM(OT_Hours), 0)
  FROM tblTimeHistDetail
  WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PeriodDate AND SSN = @SSN

  IF @Hours = @Hours2 AND @RegHours = @RegHours2 AND @OT_Hours = @OT_Hours2
    COMMIT TRAN
  ELSE
    ROLLBACK TRAN
END



