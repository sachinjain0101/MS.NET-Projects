CREATE PROCEDURE [dbo].[usp_RPT_Emp_LessThanExpectedHours] 
 (
  @Client varchar(4),
  @Group int,
  @Date datetime,
  @DateFrom datetime,
  @DateTo datetime,
  @MasterPayrollDate datetime,
  @Sites varchar(500),
  @ClusterID int = 0
)
AS


SET NOCOUNT ON

--DECLARE   @Client varchar(4)= 'AREN',
--  @Group int= 270600,
--  @Date datetime= NULL, 
--  @DateFrom datetime= NULL, 
--  @DateTo datetime= NULL, 
--  @MasterPayrollDate datetime = '2014-10-04',
--  @Sites varchar(500) = NULL,
--  @ClusterID int = 0

DECLARE @PPEDStart DATETIME,
		@PPEDEnd DATETIME,
		@WeekMultiplier INT = 1

SET @Sites = ISNULL(@Sites, 'ALL')

IF @MasterPayrollDate IS NOT NULL
BEGIN
	SET @PPEDStart = DATEADD(DAY, - 7, @Masterpayrolldate)
	SET @PPEDEnd = @MasterPayrolldate
	SET @DateFrom = DATEADD(DAY, - 7, @PPEDStart)
	SET @DateTo = DATEADD(DAY, 1, @PPEDEnd)
	SET @WeekMultiplier = 2
END
ELSE
BEGIN
	SET @PPEDStart = @Date
	SET @PPEDEnd = @Date
	SET @DateFrom = DATEADD(DAY, - 7, @PPEDStart)
	SET @DateTo = DATEADD(DAY, 1, @PPEDEnd)
END

IF OBJECT_ID('tempdb..#All') IS NOT NULL
    DROP TABLE #All

CREATE TABLE [dbo].[#All](
	[PrimarySite] [INT] NULL,  --< PrimarySiteNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
	[SiteName][varchar](100) NULL,
	[CoCode] [varchar](100) NULL,
	[SSN] [int] NOT NULL,
	[FileNo] [varchar](100) NULL,
	[EmplName] [varchar](100) NULL,
	[Rank] [bigint] NULL,
	[SubStatus1] [char](1) NULL,
	[SubStatus2] [char](1) NULL,
	[SiteNo] [INT] NOT NULL,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
	[DeptName] [varchar](100) NULL,
	[ExpectHours] [int] NULL,
	[Variance] [numeric](38, 2) NULL,
	[TotHrs] [numeric](38, 2) NULL,
	[RegHrs] [numeric](38, 2) NULL,
	[OTHrs] [numeric](38, 2) NULL,
	[DTHrs] [numeric](38, 2) NULL,
	[A2Hrs] [numeric](38, 2) NULL,
	[A3Hrs] [numeric](38, 2) NULL,
	[A4Hrs] [numeric](38, 2) NULL,
	[A5Hrs] [numeric](38, 2) NULL,
	[AAHrs] [numeric](38, 2) NULL,
	[JHrs] [numeric](38, 2) NULL,
	[THrs] [numeric](38, 2) NULL,
	[UHrs] [numeric](38, 2) NULL,
	[TotOHrs] [numeric](38, 2) NULL,
	[A6Hrs] [numeric](38, 2) NULL,
	[A7Hrs] [numeric](38, 2) NULL,
	[A9Hrs] [numeric](38, 2) NULL,
	[ABHrs] [numeric](38, 2) NULL,
	[ACHrs] [numeric](38, 2) NULL,
	[AEHrs] [numeric](38, 2) NULL,
	[TotEHrs] [numeric](38, 2) NULL
) 

INSERT INTO #ALL
SELECT 
	en.PrimarySite,
	sn.SiteName,
	CoCode = sn.PayrollUploadCode,
	en.SSN,
	en.FileNo,
	EmplName = en.LastName + ',' + en.FirstName,
	Rank = DENSE_RANK() OVER (PARTITION BY en.SSN ORDER BY t.SiteNo, LTRIM(Str(t.DeptNo)) + ' - ' + gd.DeptName_Long DESC),
	en.SubStatus1,
	en.SubStatus2,
	t.SiteNo,
	DeptName = LTRIM(Str(t.DeptNo) + ' - ' + gd.DeptName_Long),
	ExpectHours = CASE	en.SubStatus1 
						WHEN '2' THEN 20 * @WeekMultiplier
						WHEN '3' THEN 30 * @WeekMultiplier
						WHEN '4' THEN 40 * @WeekMultiplier
					END,
	Variance = NULL,
	TotHrs = SUM(t.Hours),
	RegHrs = SUM(CASE WHEN t.ClockadjustmentNO IN ('1', '8', '', ' ') THEN t.RegHours ELSE 0.00 END),
	OTHrs = SUM(OT_Hours),
	DTHrs = SUM(DT_Hours),
	A2Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '2' THEN t.regHours ELSE 0.00 END),
	A3Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '3' THEN t.regHours ELSE 0.00 END),
	A4Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '4' THEN t.regHours ELSE 0.00 END),
	A5Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '5' THEN t.regHours ELSE 0.00 END),
	AAHrs = SUM(CASE WHEN t.ClockADjustmentNo = 'A' THEN t.regHours ELSE 0.00 END),
	JHrs = SUM(CASE WHEN t.ClockADjustmentNo = 'J' THEN t.regHours ELSE 0.00 END),
	THrs = SUM(CASE WHEN t.ClockADjustmentNo = 'C' THEN t.regHours ELSE 0.00 END),
	UHrs = SUM(CASE WHEN t.ClockADjustmentNo = 'U' THEN t.regHours ELSE 0.00 END),
	TotOHrs = SUM(CASE WHEN t.ClockADjustmentNo IN ('2', '3', '4', '5', 'A', 'J', 'C', 'U') THEN t.regHours ELSE 0.00 END),
	A6Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '6' THEN t.Dollars ELSE 0.00 END),
	A7Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '7' THEN t.Dollars ELSE 0.00 END),
	A9Hrs = SUM(CASE WHEN t.ClockADjustmentNo = '9' THEN t.Dollars ELSE 0.00 END),
	ABHrs = SUM(CASE WHEN t.ClockADjustmentNo = 'B' THEN t.Dollars ELSE 0.00 END),
	ACHrs = SUM(CASE WHEN t.ClockADjustmentNo = 'C' THEN t.Dollars ELSE 0.00 END),
	AEHrs = SUM(CASE WHEN t.ClockADjustmentNo = 'E' THEN t.Dollars ELSE 0.00 END),
	TotEHrs = SUM(CASE WHEN t.ClockADjustmentNo IN ('6', '7', '9', 'B', 'C', 'E') THEN t.Dollars ELSE 0.00 END)
FROM TimeHistory.dbo.tblTimeHistDetail AS t
INNER JOIN TimeCurrent.dbo.tblEmplNames AS en
	ON en.client = t.client
		AND en.groupcode = t.groupcode
		AND en.ssn = t.ssn
INNER JOIN TimeCurrent.dbo.tblSiteNames AS sn
	ON sn.client = en.client
		AND sn.groupcode = en.groupcode
		AND sn.siteno = en.primarysite
INNER JOIN TimeCurrent.dbo.tblGroupdepts AS gd
	ON gd.client = t.client
		AND gd.groupcode = t.groupcode
		AND gd.deptno = t.deptno
WHERE t.client = @Client
	AND t.groupcode = @Group
	AND t.payrollperiodenddate >= @PPEDStart
	AND t.payrollperiodenddate <= @PPEDEnd
	AND EXISTS (SELECT ClusterID FROM dbo.tvf_GetTimeHistoryClusterDefAsFn(t.GroupCode, en.PrimarySite, t.deptNo, en.AgencyNo, t.ssn, en.DivisionID, t.ShiftNo, @ClusterID))
	AND TimeCurrent.dbo.fn_InCSV(@Sites, en.PrimarySite, 1) = 1
	AND en.PayType <> 1			-- 1 is for Salaried employees
	AND en.SubStatus2 <> 'Y'	-- Y is for PRN employee
	AND ISNULL(en.SubStatus1,'0') <> '0'
GROUP BY 
	sn.SiteName,
	sn.PayrollUploadCode,
	en.SSN,
	en.FileNo,
	en.basehours,
	en.LastName,
	en.FirstName,
	en.PrimarySite,
	en.SubStatus1,
	en.SubStatus2,
	t.SiteNo,
	t.DeptNo,
	gd.DeptName_Long
ORDER BY sn.PayrollUploadCode,
	EmplName,
	t.SiteNo,
	t.DeptNo

IF OBJECT_ID('tempdb..#Final') IS NOT NULL
    DROP TABLE #Final

--Final table insert only those that appear just ones
SELECT 
	PrimarySite,
	SiteName,
	CoCode,
	SSN,
	FileNo,
	EmplName,
	SubStatus1,
	SubStatus2,
	SiteNo,
	DeptName,
	ExpectHours,
	Variance = CASE	SubStatus1 
						WHEN '2' THEN 20 * @WeekMultiplier - TotHrs
						WHEN '3' THEN 30 * @WeekMultiplier - TotHrs
						WHEN '4' THEN 40 * @WeekMultiplier - TotHrs
				END,
	TotHrs,
	RegHrs,
	OTHrs, 
	DTHrs, 
	A2Hrs, 
	A3Hrs, 
	A4Hrs, 
	A5Hrs, 
	AAHrs, 
	JHrs, 
	THrs, 
	UHrs, 
	TotOHrs,
	A6Hrs, 
	A7Hrs, 
	A9Hrs, 
	ABHrs, 
	ACHrs, 
	AEHrs, 
	TotEHrs
INTO #Final 
FROM #All ta 
WHERE ta.ssn NOT IN (
		--Multiple record SSN's
		SELECT ta.SSN
		FROM #All ta 
		WHERE ta.Rank > 1
		GROUP BY  ta.SSN)

--Final table insert only those that appear multiple times
INSERT INTO #Final 
SELECT 
	PrimarySite,
	SiteName,
	CoCode,
	SSN,
	FileNo,
	EmplName,
	MAX(SubStatus1),
	MAX(SubStatus2),
	SiteNo = '',
	DeptName = 'Multi',
	MAX(ExpectHours),
	Variance = CASE	MAX(SubStatus1) 
						WHEN '2' THEN 20 * @WeekMultiplier - SUM(TotHrs)
						WHEN '3' THEN 30 * @WeekMultiplier - SUM(TotHrs)
						WHEN '4' THEN 40 * @WeekMultiplier - SUM(TotHrs)
					END,
	SUM(TotHrs),
	SUM(RegHrs),
	SUM(OTHrs), 
	SUM(DTHrs), 
	SUM(A2Hrs), 
	SUM(A3Hrs), 
	SUM(A4Hrs), 
	SUM(A5Hrs), 
	SUM(AAHrs), 
	SUM(JHrs), 
	SUM(THrs), 
	SUM(UHrs), 
	SUM(TotOHrs),
	SUM(A6Hrs), 
	SUM(A7Hrs), 
	SUM(A9Hrs), 
	SUM(ABHrs), 
	SUM(ACHrs), 
	SUM(AEHrs), 
	SUM(TotEHrs)
FROM #All ta 
WHERE ta.ssn IN (
		--Multiple record SSN's
		SELECT ta.SSN
		FROM #All ta 
		WHERE ta.Rank > 1
		GROUP BY  ta.SSN)
GROUP BY	
	PrimarySite,
	SiteName,
	CoCode,
	SSN,
	FileNo,
	EmplName
	
SELECT * FROM #Final
WHERE dbo.#Final.TotHrs	 < dbo.#Final.ExpectHours	


