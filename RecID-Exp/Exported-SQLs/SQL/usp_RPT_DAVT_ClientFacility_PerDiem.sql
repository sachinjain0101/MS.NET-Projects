USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_RPT_DAVT_ClientFacility_PerDiem]    Script Date: 3/31/2015 11:53:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_RPT_DAVT_ClientFacility_PerDiem]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_RPT_DAVT_ClientFacility_PerDiem] AS' 
END
GO
/*
AUTHOR:		Ron Glickman
CREATED:	9/16/2014
US261 - TA1032
Template: DavitaMC_DVPD.xls

Davita requested a report that would show PerDiem given a date range, or PPED or Master Payroll Date
Date Range Overrides PPED Overrides MPD
 
EXEC TimeHistory.dbo.usp_RPT_DAVT_ClientFacility_PerDiem 'DAVT',509700,NULL,NULL,'1/1/2013','12/31/2014'
*/
ALTER PROCEDURE [dbo].[usp_RPT_DAVT_ClientFacility_PerDiem]
(  
  @Client VARCHAR (4)
 ,@Group INT
 ,@Date DATETIME
 ,@Masterpayrolldate DATETIME
 ,@DateFrom DATETIME
 ,@DateTo DATETIME
) AS
SET NOCOUNT ON;

IF (@Date IS NULL AND @DateFrom IS NULL AND @DateTo IS NULL AND @MasterPayrollDate IS NULL)
 BEGIN
  RAISERROR ('Invalid Date Parameters. @Date,@DateFrom,@DateTo and @MasterPayrollDate are NULL. Verify Job Setup.', 16, 1) ;
  RETURN;
 END

DECLARE
 @StartDate	DATE
,@EndDate	DATE
,@PayrollStartDate DATE = DATEADD(DAY,-6,TimeCurrent.dbo.fn_GetNextDaysDate(@Date,1))
,@PayrollEndDate DATE = TimeCurrent.dbo.fn_GetNextDaysDate(@Date,1)
,@MasterPayrollStartDate DATE = DATEADD(DAY,-6,TimeCurrent.dbo.fn_GetNextDaysDate(@MasterPayrollDate,1))
,@MasterPayrollEndDate	DATE = TimeCurrent.dbo.fn_GetNextDaysDate(@MasterPayrollDate,1);

IF @DateFrom IS NOT NULL   -- date range (Transdate)
 BEGIN
	 SELECT @StartDate = MIN(PayrollPeriodEndDate), @EndDate = MAX(PayrollPeriodEndDate)
	 FROM TimeHistory.dbo.tblTimeHistDetail hd
	 INNER JOIN TimeCurrent.dbo.tblClientGroups cg ON hd.Client = cg.Client
		 AND hd.GroupCode = cg.GroupCode
	 WHERE hd.Client = @Client
		 AND TransDate >= @DateFrom
		 AND TransDate <= @DateTo
 END
ELSE
 BEGIN
	 IF @Date IS NOT NULL   -- payroll period enddate
	  BEGIN
		  SELECT @StartDate = MIN(TransDate), @EndDate = MAX(TransDate)
		  FROM TimeHistory.dbo.tblTimeHistDetail hd
		  INNER JOIN TimeCurrent.dbo.tblClientGroups cg ON hd.Client = cg.Client
			  AND hd.GroupCode = cg.GroupCode
		  WHERE HD.Client = @Client
			  AND PayrollPeriodEndDate BETWEEN @PayrollStartDate
				  AND @PayrollEndDate
	  END
	 ELSE   -- master payroll date
	  BEGIN
		  SELECT @StartDate = MIN(TransDate), @EndDate = MAX(TransDate)
		  FROM TimeHistory.dbo.tblTimeHistDetail hd
		  INNER JOIN TimeCurrent.dbo.tblClientGroups cg ON hd.Client = cg.Client
			  AND hd.GroupCode = cg.GroupCode
		  WHERE HD.Client = @Client
			  AND MasterPayrollDate BETWEEN @MasterPayrollStartDate
				  AND @MasterPayrollEndDate
	  END
END;

CREATE TABLE #CF
(
Client CHAR(4)
,GroupCode INT
,SiteNo INT  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
,CityCode VARCHAR(40)
)
INSERT INTO #CF
SELECT DISTINCT
 Client
,GroupCode
,SiteNo
,CityCode = SUBSTRING(ClientFacility,9,40)
FROM TimeCurrent.dbo.tblSiteNames (NOLOCK)
WHERE Client = @Client
AND RecordStatus = '1'
AND ClientFacility LIKE 'PerDiem:%';

SELECT 	
 en.Fileno
,en.LastName
,en.FirstName
,en.PrimarySite
,sn.CityCode
,PayrollPeriodEndDate = CONVERT(CHAR(10),thd.PayrollPeriodEndDate,101)
,TotWorkedHours = SUM(case when ac.Worked = 'Y' then thd.[Hours] else 0.00 end)
,TotNonWorkedHours = SUM(case when ac.worked = 'Y' then 0.00 else thd.[Hours] end)
,TotHours = SUM(thd.[Hours])
FROM #CF sn
JOIN TimeHistory.dbo.tblTimeHistDetail thd (NOLOCK)
ON thd.Client = sn.Client
AND thd.GroupCode = sn.GroupCode
AND thd.SiteNo = sn.SiteNo
JOIN TimeCurrent.dbo.tblEmplNames en (NOLOCK)
ON thd.Client = en.Client
AND thd.GroupCode = en.GroupCode
AND thd.SSN = en.SSN
JOIN TimeCurrent.dbo.tblAdjCodes ac (NOLOCK)
ON thd.Client = ac.Client
AND thd.GroupCode = ac.GroupCode
AND ac.ClockAdjustmentNo = case when thd.ClockAdjustmentNo in('',' ','8') then '1' else thd.ClockAdjustmentNo END
WHERE thd.Client = @Client 
AND thd.GroupCode >= 0
AND thd.PayrollPeriodEndDate >= @StartDate AND thd.PayrollPeriodEndDate <= @EndDate
AND thd.TransDate >= ISNULL(@DateFrom,@StartDate) AND thd.TransDate <= ISNULL(@DateTo,@EndDate)
AND en.substatus1 = 'Z'	
GROUP BY en.Fileno, en.LastName, en.FirstName, en.PrimarySite, sn.CityCode, thd.PayrollPeriodenddate  
HAVING SUM(thd.[Hours]) <> 0
ORDER BY CityCode, PayrollPeriodenddate, LastName, FirstName
OPTION (FORCE ORDER,OPTIMIZE FOR UNKNOWN);

DROP TABLE #CF;
GO
