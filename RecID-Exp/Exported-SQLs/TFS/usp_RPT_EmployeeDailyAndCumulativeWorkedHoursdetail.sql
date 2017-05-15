Create PROCEDURE dbo.usp_RPT_EmployeeDailyAndCumulativeWorkedHoursDetail
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
 @WEDate DATE 
	SELECT  @WEDate= MIN(PayrollPeriodEndDate)
        FROM    TimeHistory..tblPeriodEndDates AS TPED
        WHERE   Client = @Client
                AND GroupCode = @Group
                AND PayrollPeriodEndDate >= DATEADD(DAY,-1,GETDATE())
DECLARE  @TDates DATE = DATEADD(DAY,-1,GETDATE())

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
	,Reghours		NUMERIC(7,2)
	,OThours		NUMERIC(7,2)
	,RegBillRate	NUMERIC(7,2)
	,OTBillRate	NUMERIC(7,2)
	,RegBilled	NUMERIC(7,2)
	,OTBilled		NUMERIC(7,2)




);
INSERT INTO #tmpTHD
	SELECT DISTINCT
	THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo,THD.TransDate
	,RegPayRate = THD.PayRate
	,THD.BillRate
	,TotalHoursWorked  = SUM(THD.[Hours])
	,CumulativeHours   = SUM(SUM(THD.[Hours])) OVER (PARTITION BY THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo)
	,TotalBilled	    = SUM(SUM(THD.RegBillingDollars + THD.OTBillingDollars)) OVER (PARTITION BY THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,thd.transdate,THD.SSN,THD.SiteNo,THD.DeptNo)
	,RegHours		    = SUM(THD.RegHours)
	,OTHours		    = SUM(THD.OT_Hours)
	,RegBillRate	    = AVG(AVG(thd.BillRate)) OVER (PARTITION BY THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo)
	,OTBillRate	    = AVG(AVG(thd.BillOTRate)) OVER (PARTITION BY THD.Client,THD.GroupCode,THD.PayrollPeriodEndDate,THD.SSN,THD.SiteNo,THD.DeptNo)
	,RegBilled	    = SUM(THD.RegBillingDollars)
	,OTBilled		    = SUM(THD.OTBillingDollars)
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
	WHERE
	THD.Client = @Client AND THD.GroupCode = @Group
	AND THD.PayrollPeriodEndDate = @WEDate
	AND THD.TransDate = @TDates
	AND THD.InDay < 10 AND THD.OutDay < 10
	AND (cAC.Billable <> 'N' OR cAC.Billable IS NULL)
	AND cAC.Worked = 'Y'
	AND EXISTS (SELECT 1 FROM TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn(THD.GroupCode,NULL,NULL,NULL,NULL,NULL,NULL,@ClusterID))
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
,RegHours		
,OTHours		
,RegBillRate	
,OTBillRate	
,RegBilled	
,OTBilled		
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

ORDER BY 
[Name];

DROP TABLE #tmpTHD;
GO

