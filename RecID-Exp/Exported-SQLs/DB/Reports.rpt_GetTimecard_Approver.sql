CREATE PROCEDURE [Reports].[rpt_GetTimecard_Approver]

	 @DetailRecordId BIGINT  --< @DetailRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >-- 
	, @FrequencyId int = 2

AS


DECLARE @PPED datetime, @PPSD datetime

SELECT 
	Client, GroupCode, SSN, SiteNo, DeptNo, PayrollPeriodEndDate
INTO #SampleTable 
FROM TimeHistory..tblTimeHistDetail
WHERE RecordId = @DetailRecordId

SELECT TOP 1  @PPED = PayrollPeriodEndDate FROM #SampleTable


SELECT @PPSD = CASE @FrequencyId
		WHEN 5 THEN CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(@PPED)-1), @PPED), 101)
		ELSE DATEADD(day, -6, @PPED)
	  END
	, @PPED = CASE @FrequencyId
		WHEN 5 THEN CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(DATEADD(mm,1,@PPED))),DATEADD(mm,1,@PPED)),101)
		ELSE @PPED
	END



IF @FrequencyId = 2
BEGIN

	SELECT 
		thd.TransDate
		, sn.SiteName
		, CASE WHEN IsNULL(dn.DeptName_Long, '')= '' THEN dn.DeptName ELSE dn.DeptName_Long END AS DeptName
		, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InTime
		, dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutTime
		, CASE 
			WHEN dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) <> dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) THEN 3
			ELSE 1
		END as TimeEntryMethod
		, SUM(thd.Hours) AS [Hours]
		, SUM(thd.RegHours) AS RegHours
		, SUM(thd.OT_Hours) AS OT_Hours
		, SUM(thd.DT_Hours) AS DT_Hours
		, CASE WHEN ISNULL(ac.AdjustmentDescription, '') <> '' THEN ac.AdjustmentDescription ELSE thd.AdjustmentName END AS AdjustmentName
		, SUM(thd.Dollars) as Dollars
		, thd.PayrollPeriodEndDate

	FROM
		#SampleTable s

		JOIN TimeHistory..tblTimeHistDetail thd (NOLOCK)
			ON thd.Client = s.Client
			AND thd.GroupCode = s.GroupCode
			AND thd.SSN = s.SSN
			AND thd.SiteNo = s.SiteNo
			AND thd.DeptNo = s.DeptNo
			AND thd.PayrollPeriodEndDate = s.PayrollPeriodEndDate

		JOIN TimeCurrent..tblSiteNames sn (NOLOCK)
			ON thd.Client = sn.Client
			AND thd.GroupCode = sn.GroupCode
			ANd thd.SiteNo = sn.SiteNo

		JOIN TimeCurrent..tblGroupDepts dn (NOLOCK)
			ON thd.Client = dn.Client
			AND thd.GroupCode = dn.GroupCode
			AND thd.DeptNo = dn.DeptNo

		LEFT JOIN TimeCurrent.dbo.tblAdjCodes ac (NOLOCK)
			ON ac.Client = thd.Client
			AND ac.GroupCode = thd.GroupCode
			AND ac.ClockAdjustmentNo = thd.ClockAdjustmentNo

	GROUP BY thd.PayrollPeriodEndDate, thd.TransDate, sn.SiteName, dn.DeptName, dn.DeptName_Long
		, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, CASE WHEN ISNULL(ac.AdjustmentDescription, '') <> '' THEN ac.AdjustmentDescription ELSE thd.AdjustmentName END

END
ELSE
BEGIN
	SELECT 
		thd.TransDate
		, sn.SiteName
		, CASE WHEN IsNULL(dn.DeptName_Long, '')= '' THEN dn.DeptName ELSE dn.DeptName_Long END AS DeptName
		, dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InTime
		, dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutTime
		, CASE 
			WHEN dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) <> dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) THEN 3
			ELSE 1
		END as TimeEntryMethod
		, SUM(thd.Hours) AS [Hours]
		, SUM(thd.RegHours) AS RegHours
		, SUM(thd.OT_Hours) AS OT_Hours
		, SUM(thd.DT_Hours) AS DT_Hours
		, thd.AdjustmentName
		, SUM(thd.Dollars) as Dollars
		, thd.PayrollPeriodEndDate

	FROM
		#SampleTable s

		JOIN TimeHistory..tblTimeHistDetail thd
			ON thd.Client = s.Client
			AND thd.GroupCode = s.GroupCode
			AND thd.SSN = s.SSN
			AND thd.SiteNo = s.SiteNo
			AND thd.DeptNo = s.DeptNo
			-- pick up PPEDs via Transdates below

		JOIN TimeCurrent..tblSiteNames sn
			ON thd.Client = sn.Client
			AND thd.GroupCode = sn.GroupCode
			ANd thd.SiteNo = sn.SiteNo

		JOIN TimeCurrent..tblGroupDepts dn
			ON thd.Client = dn.Client
			AND thd.GroupCode = dn.GroupCode
			AND thd.DeptNo = dn.DeptNo

	WHERE
		thd.TransDate BETWEEN @PPSD AND @PPED

	GROUP BY thd.PayrollPeriodEndDate, thd.TransDate, sn.SiteName, dn.DeptName, dn.DeptName_Long
		, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, thd.AdjustmentName


END
