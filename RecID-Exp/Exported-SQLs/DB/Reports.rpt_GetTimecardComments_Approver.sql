CREATE PROCEDURE [Reports].[rpt_GetTimecardComments_Approver]
	
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

SELECT @PPED = CASE @FrequencyId
		WHEN 5 THEN CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(DATEADD(mm,1,@PPED))),DATEADD(mm,1,@PPED)),101)
		ELSE @PPED
	END


SELECT DISTINCT
	t.TimesheetEndDate as EndOfWeek
	, sa.SiteName
	, sa.DepartmentName
	, sa.Comments
	
FROM
	#SampleTable s
	
	LEFT JOIN TimeHistory..tblWTE_Spreadsheet_Assignments sa
		ON  sa.Client = s.Client
		AND sa.GroupCode = s.GroupCode
		AND sa.SSN = s.SSN
		AND sa.SiteNo = s.SiteNo
		AND sa.DeptNo = s.DeptNo

	LEFT JOIN TimeHistory..tblWTE_Timesheets t
		ON t.RecordId = sa.TimesheetId

WHERE
	t.FrequencyId = @FrequencyId
	AND t.TimesheetEndDate = @PPED
	AND LTRIM(RTRIM(sa.Comments)) <> ''

