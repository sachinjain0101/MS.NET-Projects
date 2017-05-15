Create PROCEDURE [dbo].[usp_EmplCalc_OT_EsteeLauder]
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

SELECT @Client = 'OLST'
SELECT @GroupCode = 863600
SELECT @PeriodDate = '3/13/05'
SELECT @SSN = 067942076
*/

/*
  * ESTEE LAUDER SPECIAL PAY *

  - OT over 40 for any hours (set by PayRule)
  - If empl works 5 straight days (Mon-Fri) and has 30 or more hours in those days,
    get DT for any hours worked on Sat or Sun or both

*/

BEGIN TRAN

SELECT thd.RecordID, thd.TransDate, thd.Hours, thd.RegHours, thd.OT_Hours, thd.DT_Hours,
  DATEPART(dw, TransDate) AS TransDay
INTO #tmpTrans
FROM tblTimeHistDetail AS thd
WHERE thd.Client = @Client 
  AND thd.GroupCode = @GroupCode 
  AND thd.PayrollPeriodEndDate = @PeriodDate 
  AND thd.SSN = @SSN
  AND thd.Hours <> 0
ORDER BY dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime)

--SELECT * FROM #tmpTrans

SELECT DATEPART(dw, TransDate) AS TransDay, CASE WHEN SUM(Hours) > 0 THEN 1 ELSE 0 END AS bHours
INTO #tmpWeekDays
FROM #tmpTrans
WHERE DATEPART(dw, TransDate) IN (2,3,4,5,6)
GROUP BY DATEPART(dw, TransDate)

IF (SELECT SUM(bHours) FROM #tmpWeekDays) = 5 -- All 5 WeekDays have hours
  AND (SELECT SUM(Hours) FROM #tmpTrans WHERE DATEPART(dw, TransDate) IN (2,3,4,5,6)) >= 30 -- Over 30 Hours
BEGIN
  UPDATE #tmpTrans
  SET RegHours = 0, OT_Hours = Hours, DT_Hours = 0
  WHERE TransDay IN (1,7)

  DECLARE @RecordID       AS BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 24Aug2016 >--
  DECLARE @UpdateReg      AS numeric(7,2)
  DECLARE @UpdateOT       AS numeric(7,2)
  DECLARE @UpdateDT       AS numeric(7,2)
  
  DECLARE csrUpdate CURSOR FOR
    SELECT RecordID, RegHours, OT_Hours, DT_Hours
    FROM #tmpTrans
  
  OPEN csrUpdate
  
    FETCH NEXT FROM csrUpdate INTO @RecordID, @UpdateReg, @UpdateOT, @UpdateDT
    WHILE @@FETCH_STATUS = 0
    BEGIN
      UPDATE tblTimeHistDetail
      SET RegHours = @UpdateReg, OT_Hours = @UpdateOT, DT_Hours = @UpdateDT
      WHERE RecordID = @RecordID
  
      FETCH NEXT FROM csrUpdate INTO @RecordID, @UpdateReg, @UpdateOT, @UpdateDT
    END
  
  CLOSE csrUpdate
  DEALLOCATE csrUpdate
END

--SELECT * FROM #tmpTrans
DROP TABLE #tmpWeekDays

DROP TABLE #tmpTrans

COMMIT TRAN



