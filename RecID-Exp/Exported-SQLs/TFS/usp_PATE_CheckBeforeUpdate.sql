Create PROCEDURE [dbo].[usp_PATE_CheckBeforeUpdate]
(
@THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Aug2016 >--
@Client varchar(4),
@GroupCode int,
@SSN int,
@PPED datetime,
@Account varchar(10),
@TransDate datetime
) AS

SELECT thd.RecordId
FROM TimeHistory.dbo.tblTimeHistDetail thd
INNER JOIN TimeCurrent..tblGroupDepts gd
ON gd.Client = thd.Client
AND gd.GroupCode = thd.GroupCode
AND gd.ClientDeptCode = @Account
AND gd.DeptNo = thd.DeptNo
WHERE thd.Client = @Client
AND thd.GroupCode = @GroupCode
AND thd.PayrollPeriodEndDate = @PPED
AND thd.TransDate = @TransDate
AND thd.SSN = @SSN
AND thd.RecordId <> @THDRecordId
AND thd.ClockAdjustmentNo = '1'


