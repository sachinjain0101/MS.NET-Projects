Create PROCEDURE [dbo].[usp_VTC_GetHoursSummary] (
  @Client     varchar(4),
  @GroupCode  int,
  @SiteNo     int,
  @SSN        int,
  @THDRecordID  BIGINT = 0  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
) AS

SET NOCOUNT ON
--*/

/*
DECLARE @Client    varchar(4)
DECLARE @GroupCode int
DECLARE @SiteNo    int
DECLARE @EmplRecordID   int

SET @Client = 'CIG1'
SET @GroupCode = 900000
SET @SiteNo = 1
SET @EmplRecordID = '3350541'
*/

CREATE TABLE #tmpHours (
  TransDate     datetime,
  Hours         numeric(7,2),
  MissingPunch  int
)

DECLARE @PPED       datetime
DECLARE @TransDate  datetime

SET @PPED = (
  SELECT MAX(PayrollPeriodEndDate)
  FROM TimeHistory..tblPeriodEndDates
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND Status <> 'C'
)

SET @TransDate = @PPED

WHILE @TransDate > DATEADD(day, -7, @PPED)
BEGIN
  INSERT INTO #tmpHours
  SELECT @TransDate, ISNULL(SUM(thd.Hours), 0), ISNULL(SUM(CASE WHEN thd.RecordID <> @THDRecordID AND (thd.InDay = 10 OR thd.OutDay = 10) THEN 1 ELSE 0 END), 0)
  FROM TimeHistory..tblTimeHistDetail thd
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.PayrollPeriodEndDate = @PPED
    AND thd.TransDate = @TransDate
    AND thd.SSN = @SSN
  SET @TransDate = DATEADD(day, -1, @TransDate)
END

SELECT * FROM #tmpHours ORDER BY TransDate

DROP TABLE #tmpHours



