Create PROCEDURE [dbo].[usp_PATE_PayFile] (
  @Client      char(4),
--  @PPED        datetime,
  @JobID       BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 11Oct2016 >--
)
AS

SET NOCOUNT ON
--*/

/*
DECLARE @Client     char(4)
--DECLARE @PPED       datetime
DECLARE @JobID      int

SET @Client = 'PATE'
--SET @PPED = '7/23/06'
SET @JobID = 1
*/

DECLARE @PPED1  datetime
DECLARE @PPED2  datetime
DECLARE @PPED3  datetime
DECLARE @PPED4  datetime

SET @PPED1 = (
  SELECT TOP 1 PayrollPeriodEndDate
  FROM tblPeriodEndDates
  WHERE Client = @Client
  ORDER BY PayrollPeriodEndDate DESC
)
SET @PPED2 = DATEADD(d, -7, @PPED1)
SET @PPED3 = DATEADD(d, -14, @PPED1)
SET @PPED4 = DATEADD(d, -21, @PPED1)


UPDATE TimeHistory..tblTimeHistDetail
SET Client = 'PAT2'
WHERE RecordID IN (
SELECT thd.RecordID
FROM TimeHistory..tblTimeHistDetail thd
INNER JOIN TimeHistory..tblTimeHistDetail thd2
ON thd.Client = thd2.Client
AND thd.GroupCode = thd2.GroupCode
AND thd.SSN = thd2.SSN
AND thd.PayrollPeriodEndDate = thd2.PayrollPeriodEndDate
AND thd.SiteNo = thd2.SiteNo
AND thd.DeptNo = thd2.DeptNo
AND thd.TransDate = thd2.TransDate
AND thd.Hours = thd2.Hours
AND thd.ClockAdjustmentNo = ''
AND thd2.ClockAdjustmentNo = '@'
WHERE thd.Client = @Client
AND (thd.PayrollPeriodEndDate = @PPED2 OR thd.PayrollPeriodEndDate = @PPED3 OR thd.PayrollPeriodEndDate = @PPED4)
AND thd.AprvlStatus IN ('A', 'L')
AND thd.JobID = 0
)

UPDATE TimeHistory..tblTimeHistDetail
SET Client = 'PAT2'
WHERE RecordID IN (
SELECT thd.RecordID
FROM TimeHistory..tblTimeHistDetail thd
INNER JOIN TimeHistory..tblTimeHistDetail thd2
ON thd.Client = thd2.Client
AND thd.GroupCode = thd2.GroupCode
AND thd.SSN = thd2.SSN
AND thd.PayrollPeriodEndDate = thd2.PayrollPeriodEndDate
AND thd.SiteNo = thd2.SiteNo
AND thd.DeptNo = thd2.DeptNo
AND thd.TransDate = thd2.TransDate
AND thd.Hours = thd2.Hours
AND thd.ClockAdjustmentNo = '@'
AND thd2.ClockAdjustmentNo = '@'
AND thd.AprvlAdjOrigRecID = thd2.AprvlAdjOrigRecID
WHERE thd.Client = @Client
AND (thd.PayrollPeriodEndDate = @PPED2 OR thd.PayrollPeriodEndDate = @PPED3 OR thd.PayrollPeriodEndDate = @PPED4)
AND thd.AprvlStatus IN ('A', 'L')
AND thd.JobID = 0
AND thd.RecordID > thd2.RecordID
)
  
-- Set the PPED status so that the weeks are locked down and people can nolonger make modifications on the web
IF EXISTS(SELECT 1
					FROM Scheduler.dbo.tblSetup
					WHERE JobName = 'PATETimeCard'
					AND StartDate < @PPED1
					AND Enabled = '1')
BEGIN
	-- Do nothing.  There are more jobs to run for the week, so allow people to continue to approve items in the bottom week
	SELECT @PPED1 = @PPED1
END
ELSE
BEGIN
	-- This is the final opportunity for transactions from the bottom week to get picked up by the payfile.  Therefore, close down 
	-- the week, otherwise people will be approving transactions that will NOT get picked up by a payfile
	UPDATE TimeHistory.dbo.tblPeriodEndDates
	SET Status = 'C',
			WeekClosedDateTime = GetDate(),
			MaintUserName = 'PATEPayFile',
			MaintDateTime = GetDate()
	WHERE Client = @Client
	AND PayrollPeriodEndDate <= @PPED4
	AND Status <> 'C'
END

SELECT 
  thd.RecordID,
  'RELBU' AS BUSINESS_UNIT,
  REPLACE(UPPER(CONVERT(varchar(11), thd.PayrollPeriodEndDate, 106)), ' ', '-') AS PAY_END_DT,
  LEFT(groups.ClientGroupID1 + SPACE(15), 15) AS CUST_ID,
  REPLACE(UPPER(CONVERT(varchar(11), thd.TransDate, 106)), ' ', '-') AS DATE_WRK,
  LEFT(depts.ClientDeptCode2 + SPACE(10), 10) AS RNA_ORDER_POINT,
  RIGHT(SPACE(11) + empls.FileNo, 11) AS EMPLID,
  thd.Hours AS RNA_TOT_HRS,
  CASE WHEN origTHD.RecordID IS NOT NULL THEN origTHD.PayRate ELSE CASE WHEN ISNULL(thd.PayRate,0) = 0 THEN empls.PayRate ELSE thd.PayRate END END AS VI_PAY_RATE,
  CASE WHEN origTHD.RecordID IS NOT NULL THEN origTHD.BillRate ELSE CASE WHEN ISNULL(thd.BillRate,0) = 0 THEN empls.BillRate ELSE thd.BillRate END END AS RATE_AMOUNT,
  adjs.Sales AS RNA_SALES_AMT,
--  RIGHT(SPACE(1) + IsNull(pate.COOP, SPACE(1)), 1) AS CO_OP,
	RIGHT(SPACE(1) + CASE WHEN IsNull(pate.coop, '') IN ('', 'N', '0', '000') THEN 'N' ELSE 'Y' END, 1) as CO_OP,
  RIGHT(SPACE(4) + IsNull(pate.Event, SPACE(4)), 4) AS RNA_EVENT_CD,
  RIGHT(SPACE(3) + IsNull(pate.Season, SPACE(3)), 3) AS RNA_SEASON_CD,
  RIGHT(SPACE(2) + IsNull(pate.Brand, SPACE(2)), 2) AS RNA_BRAND_NO,
--  SPACE(3) AS RNA_STORE_SHARE
	RIGHT('000' + CASE WHEN IsNull(pate.coop, '') IN ('', 'N', '0', '000') THEN '000' ELSE pate.CoOp END, 3) as RNA_STORE_SHARE
INTO #tmpTHD
FROM tblTimeHistDetail thd
INNER JOIN TimeCurrent..tblClientGroups groups
ON groups.Client = thd.Client
  AND groups.GroupCode = thd.GroupCode
  and groups.GroupCode NOT IN (890075, 890074)
INNER JOIN TimeCurrent..tblEmplNames empls
ON empls.Client = thd.Client
  AND empls.GroupCode = thd.GroupCode
  AND empls.SSN = thd.SSN
INNER JOIN TimeCurrent..tblGroupDepts depts
ON depts.Client = thd.Client
  AND depts.GroupCode = thd.GroupCode
  AND depts.DeptNo = thd.DeptNo
LEFT JOIN TimeCurrent..tblAdjustments adjs
  ON adjs.Client = thd.Client
  AND adjs.GroupCode = thd.GroupCode
  AND adjs.SSN = thd.SSN
  AND adjs.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
  AND adjs.SiteNo = thd.SiteNo
  AND adjs.DeptNo = thd.DeptNo
  /*
  AND adjs.ClockAdjustmentNo = thd.ClockAdjustmentNo
  AND ISNULL(adjs.Sales,0) <> 0
  */
  AND CASE DATEPART(dw, thd.TransDate)
      WHEN 1 THEN adjs.SunVal
      WHEN 2 THEN adjs.MonVal
      WHEN 3 THEN adjs.TueVal
      WHEN 4 THEN adjs.WedVal
      WHEN 5 THEN adjs.ThuVal
      WHEN 6 THEN adjs.FriVal
      WHEN 7 THEN adjs.SatVal
      END = thd.Hours
  AND adjs.ClockAdjustmentNo IN ('1','@')
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail OrigTHD
ON origTHD.RecordID = thd.AprvlAdjOrigRecID
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_PATE pate
ON pate.THDRecordID = CASE WHEN origTHD.RecordID IS NULL THEN thd.RecordID ELSE origTHD.RecordID END
WHERE thd.Client = @Client
--	AND (thd.PayrollPeriodEndDate = @PPED1 OR thd.PayrollPeriodEndDate = @PPED2 OR thd.PayrollPeriodEndDate = @PPED3 OR thd.PayrollPeriodEndDate = @PPED4)
	AND (thd.PayrollPeriodEndDate = @PPED2 OR thd.PayrollPeriodEndDate = @PPED3 OR thd.PayrollPeriodEndDate = @PPED4)
  AND thd.ClockAdjustmentNo IN ('1', '@')
  AND thd.AprvlStatus IN ('A', 'L')
  AND thd.JobID = 0
  AND thd.PayrollPeriodEndDate <= '7/13/2014'
  --AND Not (thd.GroupCode IN (890020, 890021) AND thd.PayrollPeriodEndDate = '10/13/2013')
ORDER BY thd.PayrollPeriodEndDate, groups.ClientGroupID1, empls.FileNo, thd.TransDate

CREATE TABLE #tmpNegHours
(
  BUSINESS_UNIT VARCHAR(20), 
  PAY_END_DT VARCHAR(12), 
  CUST_ID VARCHAR(15), 
  DATE_WRK VARCHAR(12), 
  RNA_ORDER_POINT VARCHAR(10),
  EMPLID VARCHAR(11),
  RNA_TOT_HRS NUMERIC(5,2),
  VI_PAY_RATE NUMERIC(7,2), 
  RATE_AMOUNT NUMERIC(7,2),
  RNA_SALES_AMT NUMERIC(9,2),
  CO_OP CHAR(1),
  RNA_EVENT_CD VARCHAR(4), 
  RNA_SEASON_CD VARCHAR(3), 
  RNA_BRAND_NO VARCHAR(2), 
  RNA_STORE_SHARE VARCHAR(3) 
)

INSERT INTO #tmpNegHours
SELECT BUSINESS_UNIT,
  PAY_END_DT,
  CUST_ID,
  DATE_WRK,
  RNA_ORDER_POINT,
  EMPLID,
  SUM(RNA_TOT_HRS) AS RNA_TOT_HRS,
  VI_PAY_RATE,
  RATE_AMOUNT,
  SUM(RNA_SALES_AMT) AS RNA_SALES_AMT,
  CO_OP,
  RNA_EVENT_CD,
  RNA_SEASON_CD,
  RNA_BRAND_NO,
  RNA_STORE_SHARE
FROM #tmpTHD
GROUP BY BUSINESS_UNIT, PAY_END_DT, CUST_ID, DATE_WRK, RNA_ORDER_POINT,
  EMPLID, VI_PAY_RATE, RATE_AMOUNT, CO_OP,
  RNA_EVENT_CD, RNA_SEASON_CD, RNA_BRAND_NO, RNA_STORE_SHARE
HAVING SUM(RNA_TOT_HRS) < 0

DECLARE @PayEndDt VARCHAR(12)
DECLARE @CustId VARCHAR(15)
DECLARE @DateWrk VARCHAR(12)
DECLARE @RnaOrderPoint VARCHAR(10)
DECLARE @EmplId VARCHAR(11)
DECLARE @ErrorMessage VARCHAR(500)

DECLARE csrDelete CURSOR READ_ONLY
FOR SELECT PAY_END_DT, CUST_ID, DATE_WRK, RNA_ORDER_POINT, EMPLID
    FROM #tmpNegHours tnh
    
OPEN csrDelete
FETCH NEXT FROM csrDelete INTO @PayEndDt,@CustId,@DateWrk,@RnaOrderPoint,@EmplId
WHILE (@@fetch_status <> -1)
BEGIN
  IF (@@fetch_status <> -2)
  BEGIN
    DELETE
    FROM #tmpTHD
    WHERE PAY_END_DT = @PayEndDt
    AND CUST_ID = @CustId
    AND DATE_WRK = @DateWrk
    AND RNA_ORDER_POINT = @RnaOrderPoint
    AND EMPLID = @EmplId
    
    SET @ErrorMessage = 'Employee: ' + @EmplId + ' Cust Id: ' + @CustId + ' Order Point: ' + @RnaOrderPoint + ' Week Ending: ' + @PayEndDt + ' Trans Date: ' + @DateWrk
    
    EXEC Scheduler.dbo.usp_Email_SendDirect 'PATE',0,0,'pat.lynch@peoplenet.com','support@peoplenet-us.com','Peoplenet','','','PATE payfile negative hours',@ErrorMessage,'',0,'',0
    
  END
  FETCH NEXT FROM csrDelete INTO @PayEndDt,@CustId,@DateWrk,@RnaOrderPoint,@EmplId
END
CLOSE csrDelete
DEALLOCATE csrDelete


SELECT BUSINESS_UNIT,
  PAY_END_DT,
  CUST_ID,
  DATE_WRK,
  RNA_ORDER_POINT,
  EMPLID,
  SUM(RNA_TOT_HRS) AS RNA_TOT_HRS,
  VI_PAY_RATE,
  RATE_AMOUNT,
  SUM(RNA_SALES_AMT) AS RNA_SALES_AMT,
  CO_OP,
  RNA_EVENT_CD,
  RNA_SEASON_CD,
  RNA_BRAND_NO,
  RNA_STORE_SHARE
FROM #tmpTHD
GROUP BY BUSINESS_UNIT, PAY_END_DT, CUST_ID, DATE_WRK, RNA_ORDER_POINT,
  EMPLID, VI_PAY_RATE, RATE_AMOUNT, CO_OP,
  RNA_EVENT_CD, RNA_SEASON_CD, RNA_BRAND_NO, RNA_STORE_SHARE
ORDER BY PAY_END_DT, CUST_ID, EMPLID, DATE_WRK

--/*
UPDATE tblTimeHistDetail
SET JobID = @JobID
WHERE RecordID IN (SELECT RecordID FROM #tmpTHD)
--*/

DROP TABLE #tmpTHD



