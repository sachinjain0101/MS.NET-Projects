CREATE PROCEDURE [Reports].[rpt_GetTimecardHeader_Approver]

	@DetailRecordId BIGINT  --< @DetailRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >--
	, @FrequencyId int = 2

AS


DECLARE @PPED datetime, @PPSD datetime

SELECT TOP 1 @PPED = PayrollPeriodEndDate FROM TimeHistory..tblTimeHistDetail WHERE RecordID = @DetailRecordId

SELECT @PPED = CASE @FrequencyId
		WHEN 5 THEN CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(DATEADD(mm,1,@PPED))),DATEADD(mm,1,@PPED)),101)
		ELSE @PPED
	END



SELECT 
	gr.LogoImage
	, en.FirstName
	, en.LastName
	, @PPED as PeriodEndDate
	
FROM            
	TimeHistory..tblTimeHistDetail thd

	JOIN TimeCurrent..tblEmplNames en
		ON thd.Client = en.Client
		AND thd.GroupCode = en.GroupCode
		AND thd.SSN = en.SSN

	JOIN TimeCurrent..tblGroups g 
		ON g.Client = en.Client
		AND g.GroupCode = en.GroupCode
	
	JOIN TimeCurrent.dbo.vwGroups AS gr 
		ON gr.RecordId = g.RecordID
		
WHERE
	thd.RecordID = @DetailRecordId


