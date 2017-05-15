CREATE PROCEDURE [dbo].[usp_Web1_InsertUpdate_UDF_FieldDefValue] 
(
  @THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 14Sept2016 >--
	@Client VARCHAR(4),
	@GroupCode INT,
	@SSN INT,
	@SiteNo INT,
	@DeptNo INT,
	@PPED DATE,
	@TransDate DATE,
	@FieldId INT,
	@FieldValue VARCHAR(512),
	@Position INT,
	@MaintUserName VARCHAR(20)
)

AS



IF @THDRecordId = 0
BEGIN
	IF EXISTS (
		SELECT 1
		FROM TimeHistory..tblTimeHistDetail_UDF
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SSN = @SSN
		AND SiteNo = @SiteNo
		AND DeptNo = @DeptNo
		AND Payrollperiodenddate = @PPED
		AND TransDate = @TransDate
		AND FieldID = @FieldId
		AND POSITION = @Position 
	)
	BEGIN
    UPDATE TimeHistory..tblTimeHistDetail_UDF
    SET FieldValue = @FieldValue,
        MaintDateTime = GETDATE(),
        MaintUserName = @MaintUserName
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SSN = @SSN
		AND SiteNo = @SiteNo
		AND DeptNo = @DeptNo
		AND Payrollperiodenddate = @PPED
		AND TransDate = @TransDate
		AND FieldID = @FieldId
		AND POSITION = @Position 
    AND FieldValue <> @FieldValue    
	END
  ELSE
  BEGIN
		INSERT INTO TimeHistory..tblTimeHistDetail_UDF
		        ( THDRecordID ,
		          FieldID ,
		          FieldValue ,
		          MaintDateTime ,
		          MaintUserName ,
		          Payrollperiodenddate ,
		          Client ,
		          GroupCode ,
		          SiteNo ,
		          DeptNo ,
		          SSN ,
		          TransDate ,
		          InTime ,
		          PunchTimeStamp ,
		          Position
		        )
		VALUES  ( 0, 
		          @FieldId,
		          @FieldValue,
		          GETDATE(),
		          @MaintUserName,
		          @PPED,
		          @Client ,
		          @GroupCode,
		          @SiteNo,
		          @DeptNo,
		          @SSN,
		          @TransDate,
		          '',
		          0,
		          @Position
		        )
  END
END
ELSE
BEGIN
	IF EXISTS (
		SELECT 1
		FROM TimeHistory..tblTimeHistDetail_UDF
		WHERE THDRecordID = @THDRecordId
		AND FieldID = @FieldId
		AND POSITION = @Position
	)
	BEGIN
    UPDATE TimeHistory..tblTimeHistDetail_UDF
    SET FieldValue = @FieldValue,
        MaintDateTime = GETDATE(),
        MaintUserName = @MaintUserName
		WHERE THDRecordID = @THDRecordId
		AND FieldID = @FieldId
		AND POSITION = @Position 
    AND FieldValue <> @FieldValue    
	END
	ELSE
	BEGIN
		INSERT INTO TimeHistory..tblTimeHistDetail_UDF
		        ( THDRecordID ,
		          FieldID ,
		          FieldValue ,
		          MaintDateTime ,
		          MaintUserName ,
		          Payrollperiodenddate ,
		          Client ,
		          GroupCode ,
		          SiteNo ,
		          DeptNo ,
		          SSN ,
		          TransDate ,
		          InTime ,
		          PunchTimeStamp ,
		          Position
		        )
		VALUES  ( @THDRecordId, 
		          @FieldId,
		          @FieldValue,
		          GETDATE(),
		          @MaintUserName,
		          '',
		          '' ,
		          0,
		          0,
		          0,
		          0,
		          '',
		          '',
		          0,
		          @Position
		        )
	END
END



