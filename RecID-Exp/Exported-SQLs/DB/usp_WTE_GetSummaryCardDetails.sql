CREATE PROCEDURE [dbo].[usp_WTE_GetSummaryCardDetails] (
  @Client       varchar(4),
  @GroupCode    int,
  @SSN          int,
  @PPED         datetime,
  @SiteNo       int,
  @DeptNo       int,
  @TransDate    datetime
)
AS

--*/

/*
DECLARE  @Client       varchar(4)
DECLARE  @GroupCode    int
DECLARE  @SSN          int
DECLARE  @PPED         datetime
DECLARE  @SiteNo       int
DECLARE  @DeptNo       int
DECLARE  @TransDate    datetime

SET @Client       = 'CIG1'
SET @GroupCode    = 900000
SET @SSN          = 999001777
SET @PPED         = '12/2/06'
SET @SiteNo       = 2
SET @DeptNo       = 4
SET @TransDate    = '12/01/06'
*/


DECLARE @MPMinDateTime  datetime
DECLARE @MPMinTransDate datetime
DECLARE @MPMinRecordID  BIGINT  --< @MPMinRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--

SET @MPMinDateTime = DATEADD(hour, -16, TimeHistory.dbo.SiteDateTime(@Client, @GroupCode, 1, GETUTCDATE()))
SET @MPMinTransDate = DATEADD(d, -1, @MPMinDateTime)

SET @MPMinRecordID = (
  SELECT ISNULL(MAX(thd.RecordID), 0)
  FROM TimeHistory.dbo.tblTimeHistDetail thd
  WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.SSN = @SSN
    AND thd.PayrollPeriodEndDate = @PPED
    AND thd.TransDate > @MPMinTransDate
    AND thd.ClockAdjustmentNo IN ('', ' ')
    AND thd.InDay NOT IN (10, 11)
    AND thd.OutDay IN (10, 11)
    AND TimeHistory.dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) > @MPMinDateTime
)

IF @Client in('DAVT','HCPA')
BEGIN
  SELECT thd.RecordID, thd.ClockAdjustmentNo, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, 
    thd.Hours, thd.OT_Hours, thd.DT_Hours, thd.Dollars, thd.UserCode, thd.OutUserCode, thd.InSrc, thd.OutSrc,
    thd.AdjustmentName,
    CASE WHEN thd.RecordID = @MPMinRecordID THEN 1 ELSE 0 END AS CurrentPunch
  FROM TimeHistory.dbo.tblTimeHistDetail thd with(nolock)
  WHERE thd.Client = @Client
	  AND thd.GroupCode = @GroupCode
	  AND thd.SSN = @SSN
	  AND thd.PayrollPeriodEndDate = @PPED
	  AND thd.TransDate = @TransDate
	  AND thd.SiteNo = @SiteNo
	  AND thd.DeptNo = @DeptNo
  ORDER BY CASE WHEN thd.ClockAdjustmentNo IN ('', ' ') THEN 0 ELSE 1 END, thd.InTime
END
ELSE
BEGIN
  SELECT thd.RecordID, thd.ClockAdjustmentNo, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, 
    thd.Hours, thd.OT_Hours, thd.DT_Hours, thd.Dollars, thd.UserCode, thd.OutUserCode, thd.InSrc, thd.OutSrc,
    adjs.AdjustmentName,
    CASE WHEN thd.RecordID = @MPMinRecordID THEN 1 ELSE 0 END AS CurrentPunch
  FROM TimeHistory.dbo.tblTimeHistDetail thd
  LEFT JOIN TimeCurrent.dbo.tblAdjCodes adjs
  ON adjs.Client = thd.Client
	  AND adjs.GroupCode = thd.GroupCode
	  AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
  WHERE thd.Client = @Client
	  AND thd.GroupCode = @GroupCode
	  AND thd.SSN = @SSN
	  AND thd.PayrollPeriodEndDate = @PPED
	  AND thd.TransDate = @TransDate
	  AND thd.SiteNo = @SiteNo
	  AND thd.DeptNo = @DeptNo
  ORDER BY CASE WHEN thd.ClockAdjustmentNo IN ('', ' ') THEN 0 ELSE 1 END, thd.InTime
END




