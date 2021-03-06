USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_DeleteUDF_FieldValues]    Script Date: 3/31/2015 11:53:39 AM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_Web1_DeleteUDF_FieldValues]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_DeleteUDF_FieldValues] AS' 
END
GO


ALTER PROCEDURE [dbo].[usp_Web1_DeleteUDF_FieldValues] 
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


GO
