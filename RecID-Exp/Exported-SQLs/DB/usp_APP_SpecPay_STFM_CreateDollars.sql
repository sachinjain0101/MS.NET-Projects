CREATE PROCEDURE [dbo].[usp_APP_SpecPay_STFM_CreateDollars]
(
	 @ClockAdjustmentNo VARCHAR(3)
	,@AdjustmentName VARCHAR(10)
	,@Client VARCHAR(4)
	,@GroupCode INT
	,@PPED DATETIME
	,@SSN INT
) AS

SET NOCOUNT ON;

DECLARE
 @Dollars MONEY = 0
,@MPD DATE
,@SN INT  --< Here @Sn is referring SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 18Aug2016 >--
,@DN INT  --< Here @Dn is referring DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 18Aug2016 >--
,@DOW TINYINT;

IF EXISTS
(
	SELECT 1 FROM TimeCurrent.dbo.tblEmplNames
	WHERE Client = @Client AND GroupCode = @GroupCode
	AND SSN = @SSN AND ISNULL(SubStatus4,'N') = 'Y' 
)
BEGIN
	;WITH cteBaseData AS
	(
		SELECT 
		WorkDay = ROW_NUMBER() OVER(ORDER BY THD.TransDate)
		,THD.TransDate
		,THD.PayRate
		,Dollars = THD.PayRate * 8
		,MPD = MAX(THD.MasterPayrollDate)
		,SN = MAX(ISNULL(THD.SiteNo,0))
		,DN = MAX(ISNULL(THD.DeptNo,0))
		FROM
		TimeHistory.dbo.tblTimeHistDetail THD
		INNER JOIN
		TimeCurrent.dbo.tblEmplNames tcEN
		ON tcEN.Client = THD.Client
		AND tcEN.GroupCode = THD.GroupCode
		AND tcEN.SSN = THD.SSN
		WHERE
		THD.Client = @Client AND THD.GroupCode = @GroupCode
		AND THD.PayrollPeriodEndDate = @PPED AND THD.SSN = @SSN
		AND THD.[Hours] <> 0 AND THD.ClockAdjustmentNo <> 'P'
		AND ISNULL(tcEN.SubStatus4,'N') = 'Y'
		GROUP BY THD.TransDate,THD.PayRate
		HAVING SUM(THD.[Hours]) > 0
	)
	SELECT
	 @Dollars = SUM(Dollars)
	,@MPD = MPD
	,@SN = SN
	,@DN = DN
	,@DOW = DATEPART(DW,MPD)
	FROM cteBaseData
	WHERE WorkDay < 6
	GROUP BY MPD,SN,DN,DATEPART(DW,MPD);
	-----------------------------------------------------------------------------------------------
	--This section UPDATES existing "SAL" adjustments if needed
	IF EXISTS
	(
		SELECT 1 FROM TimeHistory.dbo.tblTimeHistDetail
		WHERE Client = @Client AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate = @PPED AND SSN = @SSN
		AND ClockAdjustmentNo = @ClockAdjustmentNo
		AND AdjustmentName = @AdjustmentName
		AND InSrc = '3' AND OutSrc = '3'
		AND Dollars <> @Dollars
		AND @Dollars <> 0
	)
	BEGIN
		UPDATE THD SET Dollars = @Dollars
		FROM
		TimeHistory.dbo.tblTimeHistDetail THD WITH(NOLOCK)
		WHERE
		THD.Client = @Client
		AND THD.GroupCode = @GroupCode
		AND THD.PayrollPeriodEndDate = @PPED
		AND THD.SSN = @SSN
		AND THD.ClockAdjustmentNo = @ClockAdjustmentNo
		AND THD.AdjustmentName = @AdjustmentName
		AND InSrc = '3' AND OutSrc = '3'
		AND THD.Dollars <> @Dollars;
	END
	-----------------------------------------------------------------------------------------------
	--This section loads new "SAL" adjustments if needed
	 IF NOT EXISTS
	 (
		SELECT 1 FROM TimeHistory.dbo.tblTimeHistDetail WITH(NOLOCK)
		WHERE Client = @Client AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate = @PPED AND SSN = @SSN
		AND ClockAdjustmentNo = @ClockAdjustmentNo
		AND AdjustmentName = @AdjustmentName
		AND InSrc = '3' AND OutSrc = '3'
	 )
		BEGIN
			INSERT INTO TimeHistory.dbo.tblTimeHistDetail
			(
				 Client,GroupCode,SSN,PayrollPeriodEndDate,MasterPayrollDate,SiteNo,DeptNo  --ALL NOT NULLABLE IN THD
				,ClockAdjustmentNo,AdjustmentName,Dollars,TransDate,InSrc,OutSrc,InDay
				,OutDay,HandledByImporter,ClkTransNo,AgencyNo,ShiftNo
			)
			SELECT
				Client = @Client
			,GroupCode = @GroupCode
			,SSN = @SSN
			,PayrollPeriodEndDate = @PPED
			,MasterPayrollDate = @MPD
			,SiteNo = @SN
			,DeptNo = @DN
			,ClockAdjustmentNo = @ClockAdjustmentNo
			,AdjustmentName = @AdjustmentName
			,Dollars = @Dollars
			,TransDate = @MPD
			,InSrc = '3'
			,OutSrc = '3'
			,InDay = @DOW
			,OutDay = @DOW
			,HandledByImporter = 'V'
			,ClkTransNo = 406
			,AgencyNo = 1
			,ShiftNo = 1;
		END
	-----------------------------------------------------------------------------------------------
	--This section DELETES existing "SAL" adjustments if needed
	IF ISNULL(@Dollars,0) = 0
	BEGIN
		IF EXISTS
		(
			SELECT 1 FROM TimeHistory.dbo.tblTimeHistDetail
			WHERE Client = @Client AND GroupCode = @GroupCode
			AND PayrollPeriodEndDate = @PPED AND SSN = @SSN
			AND ClockAdjustmentNo = @ClockAdjustmentNo
			AND AdjustmentName = @AdjustmentName
			AND InSrc = '3' AND OutSrc = '3'
		)
		BEGIN
			DELETE THD
			FROM TimeHistory.dbo.tblTimeHistDetail THD
			WHERE
			THD.Client = @Client
			AND THD.GroupCode = @GroupCode
			AND THD.PayrollPeriodEndDate = @PPED
			AND THD.SSN = @SSN
			AND THD.ClockAdjustmentNo = @ClockAdjustmentNo
			AND THD.AdjustmentName = @AdjustmentName
			AND InSrc = '3' AND OutSrc = '3'
			AND THD.Dollars <> @Dollars;;
		END
	END
END
