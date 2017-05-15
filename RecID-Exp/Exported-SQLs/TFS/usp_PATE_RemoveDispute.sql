Create PROCEDURE [dbo].[usp_PATE_RemoveDispute]
(
@THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
@Client varchar(4),
@GroupCode int,
@PPED datetime,
@SSN int
) AS

DECLARE @AdjRecordID int

UPDATE TimeHistory.dbo.tblTimeHistDetail
SET AprvlStatus = '', 
		AprvlStatus_Userid = 0, 
		AprvlStatus_Date = NULL
WHERE RecordId = @THDRecordID

DELETE FROM TimeHistory.dbo.tblTimeHistDetail
WHERE Client = @Client
AND GroupCode = @GroupCode
AND PayrollPeriodEndDate = @PPED
AND SSN = @SSN
AND AprvlAdjOrigRecId = @THDRecordId

DELETE FROM TimeHistory.dbo.tblTimeHistDetail_Disputes
WHERE DetailRecordId = @THDRecordId

SELECT @AdjRecordID = adj.Record_No
FROM TimeHistory..tblTimeHistDetail thd
INNER JOIN TimeCurrent..tblAdjustments adj
ON adj.Client = thd.Client
AND adj.GroupCode = thd.GroupCode
AND adj.SiteNo = thd.SiteNo
AND adj.SSN = thd.SSN
AND adj.DeptNo = thd.DeptNo
AND adj.ShiftNo = thd.ShiftNo
AND adj.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
AND adj.ClockAdjustmentNo IN ('$','@')
AND ((adj.SunVal <> 0 AND datepart(dw, thd.TransDate) = 1) OR
		 (adj.MonVal <> 0 AND datepart(dw, thd.TransDate) = 2) OR
		 (adj.TueVal <> 0 AND datepart(dw, thd.TransDate) = 3) OR
		 (adj.WedVal <> 0 AND datepart(dw, thd.TransDate) = 4) OR
		 (adj.ThuVal <> 0 AND datepart(dw, thd.TransDate) = 5) OR
		 (adj.FriVal <> 0 AND datepart(dw, thd.TransDate) = 6) OR
		 (adj.SatVal <> 0 AND datepart(dw, thd.TransDate) = 7))
WHERE thd.RecordId = @THDRecordID

DELETE FROM TimeCurrent..tblAdjustments
WHERE Record_No = @AdjRecordID


