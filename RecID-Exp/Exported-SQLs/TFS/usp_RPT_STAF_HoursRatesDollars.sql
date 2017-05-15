Create PROCEDURE	[dbo].[usp_RPT_STAF_HoursRatesDollars]
(
 @Client VARCHAR(4)
,@Group INT
,@Date DATETIME
,@DateFrom DATETIME
,@DateTo DATETIME
,@Report CHAR(4)
,@ClusterID INT
) AS
SET NOCOUNT ON;

IF OBJECT_ID('tempdb.dbo.#BaseTable') IS NOT NULL
DROP TABLE #BaseTable;
CREATE TABLE #BaseTable
(
 SSN INT,FileNo VARCHAR(100),EmplBadge INT,FirstName_Emp VARCHAR(20),LastName_Emp VARCHAR(20)
,SiteNo INT,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 31Aug2016 >--
SiteName VARCHAR(60),DeptNo INT,  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 31Aug2016 >--
DeptName VARCHAR(30),DeptName_Long VARCHAR(50)
,ShiftNo SMALLINT,FirstName_Sup VARCHAR(20),LastName_Sup VARCHAR(20),GroupName VARCHAR(50),DivisionName VARCHAR(50)
,AgencyName VARCHAR(50),Custom1 VARCHAR(50),RegHours_Sum MONEY,OTHours_Sum MONEY,BillRate MONEY,PayRate MONEY
,RegBillRate MONEY,RegPayRate MONEY,OTBillRate MONEY,OTPayRate MONEY,RegBillDollars_Sum MONEY,RegPayDollars_Sum MONEY
,OTBillDollars_Sum MONEY,OTPayDollars_Sum MONEY,TotalBillDollars_Sum MONEY,TotalPayDollars_Sum MONEY
,PPED DATE,TransDate DATE,ClockAdjustmentNo VARCHAR(3), --< Srinsoft 09/07/2015 Changed ClockAdjustmentNo CHAR(1) to VARCHAR(3) for #BaseTable >--
[Status] VARCHAR(10),StartDate_Min DATE,StartDate_Max DATE
);

IF @DateFrom IS NOT NULL
BEGIN
DECLARE	@PPEDStart DATE,@PPEDEnd DATE,@PPEDPrevDF DATE;
SELECT
 @PPEDStart = MIN(PayrollPeriodEndDate)
,@PPEDEnd = MAX(PayrollPeriodEndDate)
,@PPEDPrevDF = DATEADD(WEEK,-1,MAX(PayrollPeriodEndDate))
FROM TimeHistory.dbo.tblPeriodEndDates (NOLOCK)
WHERE Client = @Client AND GroupCode = @Group
AND PayrollPeriodEndDate BETWEEN DATEADD(DAY,-6,@DateFrom) AND DATEADD(DAY,+6,@DateTo);

INSERT INTO #BaseTable
SELECT
 THD.SSN
,tcEN.FileNo
,tcEN.EmplBadge
,FirstName_Emp = tcEN.FirstName
,LastName_Emp = tcEN.LastName
,THD.SiteNo
,tcSN.SiteName
,THD.DeptNo
,tcGD.DeptName
,tcGD.DeptName_Long
,THD.ShiftNo
,FirstName_Sup = tcU.FirstName
,LastName_Sup = tcU.LastName
,tcCG.GroupName
,DivisionName = ISNULL(tcD.DivisionName,'')
,AgencyName = ISNULL(tcA.AgencyName,'')
,Custom1 = CASE WHEN ISNULL(thEND.Custom1,'') = '' THEN ISNULL(tcEND.Custom1,'') ELSE ISNULL(thEND.Custom1,'') END
,RegHours_Sum = SUM(THD.RegHours)
,OTHours_Sum = SUM(THD.OT_Hours)
,BillRate = ISNULL(AVG(thEND.BillRate),0)
,PayRate = ISNULL(AVG(thEND.PayRate),0)
,RegBillRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Bill','REG')
,RegPayRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Pay','REG')
,OTBillRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Bill','OT')
,OTPayRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Pay','OT')
,RegBillDollars_Sum = SUM(THD.RegBillingDollars)
,RegPayDollars_Sum = SUM(THD.RegDollars)
,OTBillDollars_Sum = SUM(THD.OTBillingDollars)
,OTPayDollars_Sum = SUM(THD.OT_Dollars)
,TotalBillDollars_Sum = SUM(THD.RegBillingDollars + THD.OTBillingDollars)
,TotalPayDollars_Sum = SUM(THD.Dollars)
,PPED = CAST(THD.PayrollPeriodEndDate AS DATE)
,TransDate = CAST(THD.TransDate AS DATE)
,ClockAdjustmentNo = CASE WHEN THD.ClockAdjustmentNo IN ('','@') THEN '1' ELSE THD.ClockAdjustmentNo END
,[Status] = CASE WHEN th_EN.SSN IS NULL THEN 'New' ELSE
 CASE tcEN.[Status] WHEN '9' THEN 'Term' ELSE 'Active' END END
,StartDate_Min = MIN(thEND.AssignmentStartDate)
,StartDate_Max = MAX(thEND.AssignmentStartDate)
FROM TimeHistory.dbo.tblTimeHistDetail THD WITH(NOLOCK)
INNER JOIN TimeCurrent.dbo.tblEmplNames tcEN WITH(NOLOCK)
ON tcEN.Client = THD.Client
AND tcEN.GroupCode = THD.GroupCode
AND tcEN.SSN = THD.SSN
INNER JOIN TimeCurrent.dbo.tblSiteNames tcSN WITH(NOLOCK)
ON tcSN.Client = THD.Client
AND tcSN.GroupCode = THD.GroupCode
AND tcSN.SiteNo = THD.SiteNo
INNER JOIN TimeCurrent.dbo.tblGroupDepts tcGD WITH(NOLOCK)
ON tcGD.Client = THD.Client
AND tcGD.GroupCode = THD.GroupCode
AND tcGD.DeptNo = THD.DeptNo
INNER JOIN TimeCurrent.dbo.tblClientGroups tcCG WITH(NOLOCK)
ON tcCG.Client = THD.Client
AND tcCG.GroupCode = THD.GroupCode
LEFT JOIN TimeHistory.dbo.tblEmplNames th_EN WITH(NOLOCK)
ON th_EN.Client = THD.Client
AND th_EN.GroupCode = THD.GroupCode
AND th_EN.PayrollPeriodEndDate = @PPEDPrevDF
AND th_EN.SSN = THD.SSN
LEFT JOIN TimeCurrent.dbo.tblUser tcU WITH(NOLOCK)
ON tcU.UserID = THD.AprvlStatus_UserID
LEFT JOIN TimeHistory.dbo.tblEmplNames_Depts thEND WITH(NOLOCK)
ON thEND.Client = THD.Client
AND thEND.GroupCode = THD.GroupCode
AND thEND.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
AND thEND.SSN = THD.SSN
AND thend.Department = thd.DeptNo
LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts tcEND WITH(NOLOCK)
ON tcEND.Client = THD.Client
AND tcEND.GroupCode = THD.GroupCode
AND tcEND.Department = THD.DeptNo
AND tcEND.SSN = THD.SSN
AND thend.Department = thd.DeptNo
LEFT JOIN TimeCurrent.dbo.tblDivisions tcD WITH(NOLOCK)
ON tcD.Client = tcEN.Client
AND tcD.GroupCode = tcEN.GroupCode
AND tcD.Division = tcEN.DivisionID
LEFT JOIN TimeCurrent.dbo.tblAgencies tcA WITH(NOLOCK)
ON tcA.Client = THD.Client
AND tcA.GroupCode = THD.GroupCode
AND tcA.Agency = THD.AgencyNo
WHERE 
THD.Client = @Client
AND THD.GroupCode = @Group
AND THD.PayrollPeriodEndDate BETWEEN @PPEDStart AND @PPEDEnd
AND THD.TransDate BETWEEN @DateFrom AND @DateTo
AND EXISTS (SELECT 1 FROM TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn (THD.GroupCode,THD.SiteNo,THD.DeptNo,THD.AgencyNo,THD.SSN,THD.DivisionID,THD.ShiftNo,@ClusterID))

GROUP BY
 THD.Client
,THD.GroupCode
,THD.PayrollPeriodEndDate
,tcEN.FileNo
,THD.SSN
,tcEN.EmplBadge
,tcEN.LastName
,tcEN.FirstName
,THD.SiteNo
,tcSN.SiteName
,THD.DeptNo
,tcGD.DeptName
,tcGD.DeptName_Long
,THD.ShiftNo
,tcU.FirstName
,tcU.LastName
,tcCG.GroupName
,ISNULL(tcD.DivisionName,'')
,ISNULL(tcA.AgencyName,'')
,CASE WHEN ISNULL(thEND.Custom1,'') = '' THEN ISNULL(tcEND.Custom1,'') ELSE ISNULL(thEND.Custom1,'') END
,CAST(THD.PayrollPeriodEndDate AS DATE)
,CAST(THD.TransDate AS DATE)
,CASE WHEN THD.ClockAdjustmentNo IN ('','@') THEN '1' ELSE THD.ClockAdjustmentNo END
,CASE WHEN th_EN.SSN IS NULL THEN 'New' ELSE CASE tcEN.[Status] WHEN '9' THEN 'Term' ELSE 'Active' END END
END

IF @Date IS NOT NULL
BEGIN
DECLARE @PPEDPrevD DATE = DATEADD(WEEK,-1,@Date);

INSERT INTO #BaseTable
SELECT
 THD.SSN
,tcEN.FileNo
,tcEN.EmplBadge
,FirstName_Emp = tcEN.FirstName
,LastName_Emp = tcEN.LastName
,THD.SiteNo
,tcSN.SiteName
,THD.DeptNo
,tcGD.DeptName
,tcGD.DeptName_Long
,THD.ShiftNo
,FirstName_Sup = tcU.FirstName
,LastName_Sup = tcU.LastName
,tcCG.GroupName
,DivisionName = ISNULL(tcD.DivisionName,'')
,AgencyName = ISNULL(tcA.AgencyName,'')
,Custom1 = CASE WHEN ISNULL(thEND.Custom1,'') = '' THEN ISNULL(tcEND.Custom1,'') ELSE ISNULL(thEND.Custom1,'') END
,RegHours_Sum = SUM(THD.RegHours)
,OTHours_Sum = SUM(THD.OT_Hours)
,BillRate = ISNULL(AVG(thEND.BillRate),0)
,PayRate = ISNULL(AVG(thEND.PayRate),0)
,RegBillRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Bill','REG')
,RegPayRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Pay','REG')
,OTBillRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Bill','OT')
,OTPayRate = TimeHistory.dbo.fn_GetEmplRate (THD.Client,THD.GroupCode,THD.SSN,THD.SiteNo,THD.DeptNo,THD.PayrollPeriodEndDate,'Pay','OT')
,RegBillDollars_Sum = SUM(THD.RegBillingDollars)
,RegPayDollars_Sum = SUM(THD.RegDollars)
,OTBillDollars_Sum = SUM(THD.OTBillingDollars)
,OTPayDollars_Sum = SUM(THD.OT_Dollars)
,TotalBillDollars_Sum = SUM(THD.RegBillingDollars + THD.OTBillingDollars)
,TotalPayDollars_Sum = SUM(THD.Dollars)
,PPED = CAST(THD.PayrollPeriodEndDate AS DATE)
,TransDate = CAST(THD.TransDate AS DATE)
,ClockAdjustmentNo = CASE WHEN THD.ClockAdjustmentNo IN ('','@') THEN '1' ELSE THD.ClockAdjustmentNo END
,[Status] = CASE WHEN th_EN.SSN IS NULL THEN 'New' ELSE
 CASE tcEN.[Status] WHEN '9' THEN 'Term' ELSE 'Active' END END
,StartDate_Min = MIN(thEND.AssignmentStartDate)
,StartDate_Max = MAX(thEND.AssignmentStartDate)
FROM TimeHistory.dbo.tblTimeHistDetail THD WITH(NOLOCK)
INNER JOIN TimeCurrent.dbo.tblEmplNames tcEN WITH(NOLOCK)
ON tcEN.Client = THD.Client
AND tcEN.GroupCode = THD.GroupCode
AND tcEN.SSN = THD.SSN
INNER JOIN TimeCurrent.dbo.tblSiteNames tcSN WITH(NOLOCK)
ON tcSN.Client = THD.Client
AND tcSN.GroupCode = THD.GroupCode
AND tcSN.SiteNo = THD.SiteNo
INNER JOIN TimeCurrent.dbo.tblGroupDepts tcGD WITH(NOLOCK)
ON tcGD.Client = THD.Client
AND tcGD.GroupCode = THD.GroupCode
AND tcGD.DeptNo = THD.DeptNo
INNER JOIN TimeCurrent.dbo.tblClientGroups tcCG WITH(NOLOCK)
ON tcCG.Client = THD.Client
AND tcCG.GroupCode = THD.GroupCode
LEFT JOIN TimeHistory.dbo.tblEmplNames th_EN WITH(NOLOCK)
ON th_EN.Client = THD.Client
AND th_EN.GroupCode = THD.GroupCode
AND th_EN.PayrollPeriodEndDate = @PPEDPrevD
AND th_EN.SSN = THD.SSN
LEFT JOIN TimeCurrent.dbo.tblUser tcU WITH(NOLOCK)
ON tcU.UserID = THD.AprvlStatus_UserID
LEFT JOIN TimeHistory.dbo.tblEmplNames_Depts thEND WITH(NOLOCK)
ON thEND.Client = THD.Client
AND thEND.GroupCode = THD.GroupCode
AND thEND.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
AND thEND.SSN = THD.SSN
AND thend.Department = thd.DeptNo
LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts tcEND WITH(NOLOCK)
ON tcEND.Client = THD.Client
AND tcEND.GroupCode = THD.GroupCode
AND tcEND.Department = THD.DeptNo
AND tcEND.SSN = THD.SSN
LEFT JOIN TimeCurrent.dbo.tblDivisions tcD WITH(NOLOCK)
ON tcD.Client = tcEN.Client
AND tcD.GroupCode = tcEN.GroupCode
AND tcD.Division = tcEN.DivisionID
LEFT JOIN TimeCurrent.dbo.tblAgencies tcA WITH(NOLOCK)
ON tcA.Client = THD.Client
AND tcA.GroupCode = THD.GroupCode
AND tcA.Agency = THD.AgencyNo
--CROSS APPLY TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn
--	(THD.GroupCode,THD.SiteNo,THD.DeptNo,THD.AgencyNo,THD.SSN,THD.DivisionID,THD.ShiftNo,@ClusterID)
WHERE 
THD.Client = @Client
AND THD.GroupCode = @Group
AND THD.PayrollPeriodEndDate = @Date
AND EXISTS (SELECT 1 FROM TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn (THD.GroupCode,THD.SiteNo,THD.DeptNo,THD.AgencyNo,THD.SSN,THD.DivisionID,THD.ShiftNo,@ClusterID))
GROUP BY
 THD.Client
,THD.GroupCode
,THD.PayrollPeriodEndDate
,tcEN.FileNo
,THD.SSN
,tcEN.EmplBadge
,tcEN.LastName
,tcEN.FirstName
,THD.SiteNo
,tcSN.SiteName
,THD.DeptNo
,tcGD.DeptName
,tcGD.DeptName_Long
,THD.ShiftNo
,tcU.FirstName
,tcU.LastName
,tcCG.GroupName
,ISNULL(tcD.DivisionName,'')
,ISNULL(tcA.AgencyName,'')
,CASE WHEN ISNULL(thEND.Custom1,'') = '' THEN ISNULL(tcEND.Custom1,'') ELSE ISNULL(thEND.Custom1,'') END
,CAST(THD.PayrollPeriodEndDate AS DATE)
,CAST(THD.TransDate AS DATE)
,CASE WHEN THD.ClockAdjustmentNo IN ('','@') THEN '1' ELSE THD.ClockAdjustmentNo END
,CASE WHEN th_EN.SSN IS NULL THEN 'New' ELSE
 CASE tcEN.[Status] WHEN '9' THEN 'Term' ELSE 'Active' END END
END

IF @Report = '1310'
BEGIN
SELECT
 BT.FileNo
,LastName = BT.LastName_Emp
,FirstName = BT.FirstName_Emp
,SRSFacility = BT.SiteName
,KMI = CASE WHEN BT.DeptName_Long LIKE '% - SR%' THEN RIGHT(BT.DeptName_Long,LEN(BT.DeptName_Long)- CHARINDEX(' - SR',BT.DeptName_Long) - 2) ELSE '' END
,Department = CASE WHEN BT.DeptName_Long LIKE '% - SR%' THEN LEFT(BT.DeptName_Long,LEN(BT.DeptName_Long)- CHARINDEX(' - SR',BT.DeptName_Long) - 2) ELSE BT.DeptName_Long END
,Supervisor = BT.DivisionName
,BT.ShiftNo
,StandardHours = SUM(BT.RegHours_Sum)
,OTHours = SUM(BT.OTHours_Sum)
,StandardRate = AVG(BT.RegBillRate)
,OTRate = AVG(BT.OTBillRate)
,StandardEarned = SUM(BT.RegBillDollars_Sum)
,OTEarned = SUM(BT.OTBillDollars_Sum)
,TotalPay = SUM(BT.TotalBillDollars_Sum)
,[Status] = MAX(BT.[Status])
,[Date] = BT.PPED
FROM #BaseTable BT
INNER JOIN TimeCurrent.dbo.tblAdjCodes cAC WITH(NOLOCK)
ON cAC.Client = @Client
AND cAC.GroupCode = @Group
AND cAC.ClockAdjustmentNo =
 CASE WHEN BT.ClockAdjustmentNo IN ('','@') THEN '1' ELSE BT.ClockAdjustmentNo END
WHERE
cAC.Worked = 'Y'
GROUP BY
 BT.FileNo
,BT.LastName_Emp
,BT.FirstName_Emp
,BT.SiteName
,BT.DeptName_Long
,BT.DivisionName
,BT.ShiftNo
,BT.PPED
ORDER BY FileNo,LastName,FirstName,[Date],ShiftNo;
END

IF @Report = '2061'
BEGIN
SELECT
 Company = GroupName
,LastName = LastName_Emp
,FirstName = FirstName_Emp
,StartDate = MIN(StartDate_Min)
,Employee = FileNo
,Badge = EmplBadge
,[Shift] = ShiftNo
,DeptOnly = Custom1
,Agency = AgencyName
,Supervisor = DivisionName
,PayRate = AVG(PayRate)
,BillRate = AVG(BillRate)
,[Status] = MAX([Status])
FROM #BaseTable
GROUP BY
 GroupName
,LastName_Emp
,FirstName_Emp
,FileNo
,EmplBadge
,ShiftNo
,Custom1
,AgencyName
,DivisionName
ORDER BY GroupName,LastName,FirstName,[Shift];
END

IF @Report = '2062'
BEGIN
SELECT DISTINCT
 AgencyName
,LastName = LastName_Emp
,FirstName = FirstName_Emp
,Employee = FileNo
,[Shift] = ShiftNo
,Supervisor = DivisionName
,WorkedDepartment = DeptName_Long
FROM #BaseTable
ORDER BY LastName,FirstName,[Shift],WorkedDepartment;
END

IF @Report = '2063'
BEGIN
;WITH cteSumHours AS
(
 SELECT
  LastName = LastName_Emp
 ,FirstName = FirstName_Emp
 ,Employee = FileNo
 ,[Shift] = ShiftNo
 ,Department = Custom1
 ,CostNumber = DeptName_Long
 ,WorkedJobCode = NULL
 ,REGULAR = SUM(RegHours_Sum)
 ,OVERTIME = SUM(OTHours_Sum)
 FROM #BaseTable
 GROUP BY
  Custom1
 ,LastName_Emp
 ,FirstName_Emp
 ,FileNo
 ,ShiftNo
 ,DeptName_Long
)
SELECT
 Department
,LastName
,FirstName 
,Employee
,[Shift]
,Department
,CostNumber
,Department
,CostNumber
,WorkedJobCode
,EarningsCode
,[Hours]
FROM cteSumHours
UNPIVOT ([Hours] FOR EarningsCode IN (REGULAR,OVERTIME)) UNP
WHERE [Hours] <> 0
ORDER BY LastName,FirstName,[Shift],EarningsCode DESC;
END

IF @Report = '2064'
BEGIN
;WITH cteSumHours AS
(
 SELECT
  CompanyCode = GroupName
 ,LastName = LastName_Emp
 ,FirstName = FirstName_Emp
 ,Employee = FileNo
 ,TempAgency = AgencyName
 ,Dept = Custom1
 ,CostNumber = DeptName_Long
 ,PayDate = CONVERT(CHAR(10),TransDate,101)
 ,REGULAR = SUM(RegHours_Sum)
 ,OVERTIME = SUM(OTHours_Sum)
 ,RegBillDollars = SUM(RegBillDollars_Sum)
 ,OTBillDollars = SUM(OTBillDollars_Sum)
 FROM #BaseTable
 GROUP BY
  GroupName
 ,LastName_Emp
 ,FirstName_Emp
 ,FileNo
 ,AgencyName
 ,Custom1
 ,DeptName_Long
 ,TransDate
)
SELECT
 CompanyCode
,LastName
,FirstName 
,Employee
,TempAgency
,Dept
,CostNumber
,PayDate
,EarningsCode
,[Hours]
,Dollars = CASE EarningsCode WHEN 'REGULAR' THEN RegBillDollars WHEN 'OVERTIME' THEN OTBillDollars END
FROM cteSumHours
UNPIVOT ([Hours] FOR EarningsCode IN (REGULAR,OVERTIME)) UNP
WHERE [Hours] <> 0
ORDER BY CompanyCode,LastName,FirstName,PayDate,EarningsCode DESC;
END
