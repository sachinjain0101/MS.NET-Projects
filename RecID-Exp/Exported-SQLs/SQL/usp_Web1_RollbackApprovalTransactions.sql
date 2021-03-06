USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_RollbackApprovalTransactions]    Script Date: 3/31/2015 11:53:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_RollbackApprovalTransactions]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_RollbackApprovalTransactions] AS' 
END
GO
-- CASE: 105099



ALTER PROCEDURE [dbo].[usp_Web1_RollbackApprovalTransactions]
	
	@transactions varchar(max)

AS

SELECT * INTO #IdList FROM TimeCurrent..Split(@transactions, ',')

CREATE TABLE #Transactions (
	Id BIGINT  --< Id data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
	)

INSERT #Transactions (Id)
SELECT CAST(items as int) FROM #IdList



-- tblTimeHistDetail_BackupApproval
DELETE FROM TimeHistory..tblTimeHistDetail_BackupApproval WHERE THDRecordId IN (SELECT Id FROM #Transactions)

-- tblTimeHistDetail_Disputes
DELETE FROM TimeHistory..tblTimeHistDetail_Disputes WHERE DetailRecordID IN (SELECT Id FROM #Transactions)

UPDATE 
	TimeHistory..tblTimeHistDetail 
SET 
	AprvlStatus = ''
	, AprvlStatus_UserID = 0
	, AprvlStatus_Date = NULL

WHERE 
	RecordID IN (SELECT Id FROM #Transactions)
	
	
GO
