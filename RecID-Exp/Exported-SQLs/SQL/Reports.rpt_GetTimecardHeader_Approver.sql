USE [TimeHistory]
GO
/****** Object:  StoredProcedure [Reports].[rpt_GetTimecardHeader_Approver]    Script Date: 3/31/2015 11:53:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Reports].[rpt_GetTimecardHeader_Approver]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [Reports].[rpt_GetTimecardHeader_Approver] AS' 
END
GO






ALTER PROCEDURE [Reports].[rpt_GetTimecardHeader_Approver]

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


GO
