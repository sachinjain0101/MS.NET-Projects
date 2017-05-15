Create PROCEDURE [Reports].[rpt_GetTimecardProjects_Approver]
	
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



SELECT 
	sn.SiteName
	, CASE WHEN IsNULL(gd.DeptName_Long, '')= '' THEN gd.DeptName ELSE gd.DeptName_Long END AS DeptName
	, sp.ProjectNum as Project
	, sp.TransDate
	, SUM(sp.Hours) as Hours

FROM
	TimeHistory..tblWTE_Timesheets t

	JOIN TimeHistory..tblWTE_Spreadsheet_Assignments sa
		ON t.RecordId = sa.TimesheetId

	JOIN #SampleTable s
		ON sa.Client = s.Client
		AND sa.GroupCode = s.GroupCode
		AND sa.SSN = s.SSN
		ANd sa.SiteNo = s.SiteNo
		AND sa.DeptNo = s.DeptNo

	JOIN TimeHistory..tblWTE_Spreadsheet_Project sp
		ON sp.SpreadsheetAssignmentId = sa.RecordId

	JOIN TimeCurrent.dbo.tblSiteNames sn 
		ON  sn.Client = sp.Client 
		AND sn.GroupCode = sp.GroupCode	
		AND sn.SiteNo = sp.SiteNo

	JOIN TimeCurrent.dbo.tblGroupDepts gd 
		ON  gd.Client = sp.Client	
		AND gd.GroupCode = sp.GroupCode 
		AND gd.DeptNo = sp.DeptNo

WHERE
	t.TimesheetEndDate = @PPED
	AND t.FrequencyId = @FrequencyId
	

GROUP BY
	sp.TransDate
	, sn.SiteName
	, gd.DeptName
	, gd.DeptName_Long
	, sp.ProjectNum


