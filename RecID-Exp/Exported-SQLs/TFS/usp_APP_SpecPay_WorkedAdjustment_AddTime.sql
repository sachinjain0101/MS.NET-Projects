Create PROCEDURE [dbo].[usp_APP_SpecPay_WorkedAdjustment_AddTime]
(
	 @AdjName VARCHAR(10)
	,@MinToQualify DECIMAL(5,2)
	,@MaxToMatch DECIMAL(5,2)
	,@Client CHAR(4)
	,@GroupCode INT
	,@PPED DATETIME
	,@SSN INT
)
AS
SET NOCOUNT ON;
DECLARE
 @SiteNo INT
,@DeptNo INT
,@ShiftNo INT
,@TransDate DATE
,@DayOfTheWeek TINYINT
,@InsertAmount NUMERIC(7,2);
CREATE TABLE #tempTHDBaseTable
(
	 RowNum TINYINT
	,RecordID BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
	,Client VARCHAR(4)
	,GroupCode INT
	,PayrollPeriodEndDate DATE
	,SSN INT
	,SiteNo INT
	,DeptNo INT
	,ShiftNo TINYINT
	,TransDate DATE
	,DayOfTheWeek TINYINT
	,ClockAdjustmentNo VARCHAR(3)   --< Srinsoft 08/25/2015 Changed ClockAdjustmentNo CHAR(1) to VARCHAR(3) >--
	,AdjustmentName VARCHAR(10)
	,[Hours] NUMERIC(7,2) 
	,TotHours NUMERIC(7,2)
);
CREATE UNIQUE CLUSTERED INDEX uclixTempTHDBaseTable
ON #tempTHDBaseTable
(
	 RowNum,RecordID
	,Client,GroupCode,PayrollPeriodEndDate,SSN
	,SiteNo,DeptNo,ShiftNo,TransDate
	,DayOfTheWeek
	,ClockAdjustmentNo,AdjustmentName
	,[Hours],TotHours
);
INSERT INTO #tempTHDBaseTable
	SELECT
	 RowNum = ROW_NUMBER()
		OVER(PARTITION BY SiteNo,DeptNo,TransDate ORDER BY ShiftNo)
	,RecordID
	,Client,GroupCode,PayrollPeriodEndDate,SSN
	,SiteNo,DeptNo,ShiftNo,TransDate
	,DayOfTheWeek = DATEPART(DW,TransDate)
	,ClockAdjustmentNo,AdjustmentName
	,[Hours]
	,TotHours = SUM([Hours])
		OVER(PARTITION BY SiteNo,DeptNo,TransDate)
	FROM TimeHistory.dbo.tblTimeHistDetail
	WHERE Client = @Client AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED AND SSN = @SSN;

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
--This section loads new "AddHrsToMakeTotalOf4" adjustments if needed
DECLARE curInsertNewTHDAdjustmentEntry CURSOR READ_ONLY FOR
SELECT DISTINCT
SiteNo,DeptNo,ShiftNo,TransDate,DayOfTheWeek
,TotHrsInsert = ABS(TotHours - @MaxToMatch)
FROM #tempTHDBaseTable
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SSN = @SSN
AND TotHours >= @MinToQualify
AND TotHours < @MaxToMatch
AND RowNum = 1
ORDER BY SiteNo,DeptNo,TransDate;

OPEN curInsertNewTHDAdjustmentEntry;

FETCH NEXT FROM curInsertNewTHDAdjustmentEntry
INTO @SiteNo,@DeptNo,@ShiftNo,@TransDate,@DayOfTheWeek,@InsertAmount;

WHILE @@FETCH_STATUS = 0
BEGIN
 IF NOT EXISTS
 (
  SELECT * FROM #tempTHDBaseTable WHERE ClockAdjustmentNo = '1'
  AND AdjustmentName = @AdjName AND TransDate = @TransDate
 )
  BEGIN
   IF ISNULL(@InsertAmount,0) > 0
    BEGIN
			EXEC TimeHistory.dbo.usp_Web1_AddAdjustment
			 @Client = @Client,@GroupCode = @GroupCode
			,@SiteNo = @SiteNo,@SSN = @SSN,@DeptNo = @DeptNo
			,@ShiftNo = @ShiftNo,@PPED = @PPED
			,@ClockAdjustmentNo = '1',@AdjType = 'H'
			,@Amount = @InsertAmount,@Day = @DayOfTheWeek,@UserID = 0
			,@ReasonCodeID = 0,@ShiftDiffClass = ''
			,@UserComment = 'usp_APP_SpecPay_WorkedAdjustment_AddTime'
			,@AdjName = @AdjName;
		END
	END

	FETCH NEXT FROM curInsertNewTHDAdjustmentEntry
	INTO @SiteNo,@DeptNo,@ShiftNo,@TransDate,@DayOfTheWeek,@InsertAmount;
END

CLOSE curInsertNewTHDAdjustmentEntry;
DEALLOCATE curInsertNewTHDAdjustmentEntry;
-----------------------------------------------------------------------------------------------
--This section UPDATES existing "AddHrsToMakeTotalOf4" adjustments if needed
IF EXISTS
(
	SELECT 1 FROM #tempTHDBaseTable Z
	WHERE Client = @Client AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED AND SSN = @SSN
	AND ClockAdjustmentNo = '1' AND AdjustmentName = @AdjName
	AND TotHours >= @MinToQualify AND TotHours <> @MaxToMatch 
	AND (TotHours - [Hours]) < @MaxToMatch AND [Hours] <> TotHours
)
BEGIN
	UPDATE THD SET [Hours] = ABS((Z.TotHours - @MaxToMatch) - THD.[Hours])
	FROM
	TimeHistory.dbo.tblTimeHistDetail THD WITH(NOLOCK)
	INNER JOIN
	#tempTHDBaseTable Z
	ON Z.RecordID = THD.RecordID
	WHERE
	THD.Client = @Client
	AND THD.GroupCode = @GroupCode
	AND THD.PayrollPeriodEndDate = @PPED
	AND THD.SSN = @SSN
	AND Z.ClockAdjustmentNo = '1'
	AND Z.AdjustmentName = @AdjName
	AND Z.TotHours >= @MinToQualify
	AND Z.TotHours <> @MaxToMatch
	AND (Z.TotHours - Z.[Hours]) < @MaxToMatch
	AND THD.[Hours] <> Z.TotHours;

	UPDATE TCA SET
	 MonVal = CASE WHEN THD.InDay = 2 THEN THD.[Hours] ELSE 0 END
	,TueVal = CASE WHEN THD.InDay = 3 THEN THD.[Hours] ELSE 0 END
	,WedVal = CASE WHEN THD.InDay = 4 THEN THD.[Hours] ELSE 0 END
	,ThuVal = CASE WHEN THD.InDay = 5 THEN THD.[Hours] ELSE 0 END
	,FriVal = CASE WHEN THD.InDay = 6 THEN THD.[Hours] ELSE 0 END
	,SatVal = CASE WHEN THD.InDay = 7 THEN THD.[Hours] ELSE 0 END
	,SunVal = CASE WHEN THD.InDay = 1 THEN THD.[Hours] ELSE 0 END
	,WeekVal = CASE WHEN THD.InDay < 1 or InDay > 7 THEN THD.[Hours] ELSE 0 END
	,TotalVal = THD.[Hours]
	FROM
	TimeCurrent.dbo.tblAdjustments TCA WITH(NOLOCK)
	INNER JOIN
	#tempTHDBaseTable Z
	ON Z.RecordID = TCA.THDRecordID
	INNER JOIN
	TimeHistory.dbo.tblTimeHistDetail THD WITH(NOLOCK)
	ON THD.RecordID = TCA.THDRecordID
	WHERE
	TCA.Client = @Client
	AND TCA.GroupCode = @GroupCode
	AND TCA.PayrollPeriodEndDate = @PPED
	AND TCA.SSN = @SSN
	AND Z.ClockAdjustmentNo = '1'
	AND Z.AdjustmentName = @AdjName
	AND Z.TotHours >= @MinToQualify
	AND Z.TotHours <> @MaxToMatch
	AND (Z.TotHours - Z.[Hours]) < @MaxToMatch;
END
-----------------------------------------------------------------------------------------------
--This section DELETES existing "AddHrsToMakeTotalOf4" adjustments if needed
IF EXISTS
(
	SELECT 1 FROM #tempTHDBaseTable Z
	WHERE Client = @Client AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED AND SSN = @SSN
	AND ClockAdjustmentNo = '1' AND AdjustmentName = @AdjName
	AND (TotHours < @MinToQualify OR (TotHours - [Hours]) >= @MaxToMatch)
)
BEGIN
	DELETE TCA
	FROM TimeCurrent.dbo.tblAdjustments TCA
	INNER JOIN
	#tempTHDBaseTable Z
	ON Z.RecordID = TCA.THDRecordID
	INNER JOIN
	TimeHistory.dbo.tblTimeHistDetail THD WITH(NOLOCK)
	ON THD.RecordID = TCA.THDRecordID
	WHERE
	TCA.Client = @Client
	AND TCA.GroupCode = @GroupCode
	AND TCA.PayrollPeriodEndDate = @PPED
	AND TCA.SSN = @SSN
	AND Z.ClockAdjustmentNo = '1'
	AND Z.AdjustmentName = @AdjName
	AND (Z.TotHours < @MinToQualify OR (Z.TotHours - Z.[Hours]) >= @MaxToMatch);

	DELETE THD
	FROM TimeHistory.dbo.tblTimeHistDetail THD
	INNER JOIN
	#tempTHDBaseTable Z
	ON Z.RecordID = THD.RecordID
	WHERE
	THD.Client = @Client
	AND THD.GroupCode = @GroupCode
	AND THD.PayrollPeriodEndDate = @PPED
	AND THD.SSN = @SSN
	AND Z.ClockAdjustmentNo = '1'
	AND Z.AdjustmentName = @AdjName
	AND (Z.TotHours < @MinToQualify OR (Z.TotHours - Z.[Hours]) >= @MaxToMatch);
END
IF EXISTS
(
 SELECT * FROM tempdb.sys.objects WHERE [name] LIKE '#tempTHDBaseTable%'
)
	DROP TABLE #tempTHDBaseTable;
/*
EXEC TimeHistory.dbo.usp_APP_SpecPay_WorkedAdjustment_AddTime
 @AdjName = 'AddHrsTo4',@MinToQualify = 0.50,@MaxToMatch = 4.00
,@Client = 'RAND',@GroupCode = 336700,@PPED = '20111225',@SSN = 19297;
*/
