Create PROCEDURE [dbo].[usp_Web1_DeleteUDF_FieldValues] 
(
	@Client VARCHAR(4),
	@GroupCode INT,
	@SSN INT,
	@SiteNo INT,
	@DeptNo INT,
	@PPED DATE,
	@TransDate DATE,
	@Position INT,
	@THDRecordId BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
)

AS

IF @THDRecordId > 0
BEGIN
	DELETE
	FROM TimeHistory..tblTimeHistDetail_UDF
	WHERE THDRecordID = @THDRecordId
	AND Position = @Position
END
ELSE
BEGIN
	DELETE
	FROM TimeHistory..tblTimeHistDetail_UDF
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND SiteNo = @SiteNo
	AND DeptNo = @DeptNo
	AND Payrollperiodenddate = @PPED
	AND TransDate = @TransDate
	AND Position = @Position
END


