CREATE PROCEDURE [dbo].[usp_RPT_EmployeeDailyAndCumulativeWorkedHoursSummary]
(
	 @Client CHAR(4)
	,@Group INT
	,@Date DATETIME
	,@DateFrom DATETIME = NULL
	,@DateTo DATETIME = NULL
	,@ClusterId INT
) AS

SET NOCOUNT ON;

DECLARE
 @WEDate DATE =
	CASE
		WHEN DATEPART(DW,@Date) = DATEPART(DW,GETDATE()-1) THEN DATEADD(DD,-7,@Date)
		ELSE @Date
	END
,@TDates DATE = GETDATE()-1;

CREATE TABLE #tmpTHD
(
	 Client CHAR(4)
	,GroupCode INT
	,PayrollPeriodEndDate DATE
	,SSN INT
	,SiteNo INT  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
	,DeptNo INT  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
	,TransDate DATE
	,RegPayRate NUMERIC(7,2)
	,BillRate NUMERIC(7,2)
	,TotalHoursWorked NUMERIC(5,2)
	,CumulativeHours NUMERIC(5,2)
	,TotalBilled MONEY
);
INSERT INTO #tmpTHD
	SELECT DISTINCT
	THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo,THD.TransDate
	,RegPayRate = THD.PayRate
	,THD.BillRate
	,TotalHoursWorked = SUM(THD.[Hours])
	,CumulativeHours = SUM(SUM(THD.[Hours])) OVER (PARTITION BY THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo)
	,TotalBilled = SUM(SUM(THD.RegBillingDollars + THD.OTBillingDollars)) OVER (PARTITION BY THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo)
	FROM
	TimeHistory.dbo.tblTimeHistDetail THD
	INNER JOIN
	TimeCurrent.dbo.tblAdjCodes cAC
	ON cAC.Client = THD.Client
	AND cAC.GroupCode = THD.GroupCode
	AND cAC.ClockAdjustmentNo =
		CASE WHEN THD.ClockAdjustmentNo IN ( '', '@' ) THEN '1'
			ELSE THD.ClockAdjustmentNo
		END
	CROSS APPLY TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn
		(THD.GroupCode,NULL,NULL,NULL,NULL,NULL,NULL,@ClusterID)
	WHERE
	THD.Client = @Client AND THD.GroupCode = @Group
	AND THD.PayrollPeriodEndDate = @WEDate
	AND THD.TransDate <= @TDates
	AND THD.InDay < 10 AND THD.OutDay < 10
	AND (cAC.Billable <> 'N' OR cAC.Billable IS NULL)
	AND cAC.Worked = 'Y'
	GROUP BY
	 THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo,THD.TransDate
	,THD.PayRate,THD.BillRate;

SELECT DISTINCT
[Name] = cEN.LastName + ', ' + cEN.FirstName
,EmpNo = cEN.FileNo
,SupervisorName = 
	CASE
		WHEN CHARINDEX(', ',cDN.DeptName) > 1 THEN
				SUBSTRING(RIGHT(cDN.DeptName,LEN(cDN.DeptName) - CHARINDEX('-',cDN.DeptName)) ,CHARINDEX('-',RIGHT(cDN.DeptName,LEN(cDN.DeptName) - CHARINDEX('-',cDN.DeptName))) + 1,50)
		ELSE cDN.DeptName
	END
,[Date] = CONVERT(CHAR(10),THD.TransDate,101)
,THD.TotalHoursWorked
,THD.CumulativeHours
,THD.RegPayRate
,RegMarkup = '27.25%'
,OTPayRate = THD.RegPayRate * 1.5
,OTMarkup = '24.73%'
,THD.TotalBilled
,WEDate = CONVERT(CHAR(10),THD.PayrollPeriodEndDate,101)
,BusinessUnit = cDN.DeptName
FROM
#tmpTHD THD
INNER JOIN
TimeCurrent.dbo.tblEmplNames cEN
ON cEN.Client = THD.Client 
AND cEN.GroupCode = THD.GroupCode 
AND cEN.SSN = THD.SSN 
INNER JOIN
TimeCurrent.dbo.tblDeptNames cDN
ON cDN.Client = THD.Client
AND cDN.GroupCode = THD.GroupCode
AND cDN.DeptNo = THD.DeptNo
WHERE 
THD.TransDate = @TDates
ORDER BY 
[Name];

DROP TABLE #tmpTHD;
