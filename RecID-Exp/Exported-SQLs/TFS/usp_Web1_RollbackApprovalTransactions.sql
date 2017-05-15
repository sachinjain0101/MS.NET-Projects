Create PROCEDURE [dbo].[usp_Web1_RollbackApprovalTransactions]
	
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
	
	
