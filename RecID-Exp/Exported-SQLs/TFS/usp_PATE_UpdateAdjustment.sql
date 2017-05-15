Create PROCEDURE [dbo].[usp_PATE_UpdateAdjustment] (
  @Client      char(4),
  @GroupCode   int,
  @SiteNo      int,
  @SSN         int,
  @DeptNo      int,
  @ShiftNo     int,
  @PPED        datetime,
  @ClockAdjustmentNo  varchar(3), --< Srinsoft 08/28/2015 Changed  @ClockAdjustmentNo  char(1) to varchar(3) >--
  @AdjType     char(1), 
  @Amount      numeric(5,2),
  @NewAmount   numeric(5,2),
  @Day         tinyint,
  @Sales       numeric(9,2),
  @Brand       varchar(2),
  @UserID      int,
  @ReasonCodeID  int = 0
)
AS

DECLARE @ReturnCode int
SET @ReturnCode = 0

/*
DECLARE @GroupCode    int

SET @GroupCode = (
  SELECT GroupCode
  FROM TimeCurrent..tblGroupDepts
  WHERE Client = @Client
    AND DeptNo = @DeptNo
)
*/

DECLARE @UserCode     varchar(5)
DECLARE @THDRecordID  BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
DECLARE @DoDelete			char(1)
DECLARE @UDFMappingId INT

SELECT @UDFMappingId = TimeCurrent.dbo.fn_UDF_TemplateMappingId(@Client,@GroupCode,0,0,0,'PATE')

INSERT INTO timecurrent..tblPATETxn (	Client,
																		  GroupCode,
																		  SiteNo,
																		  SSN,
																		  DeptNo,
																		  ShiftNo,
																		  PPED,
																		  ClockAdjustmentNo,
																		  AdjType,
																		  Amount,
																		  Day,
																		  Sales,
																		  Brand,
																		  UserID,
																		  ReasonCodeID,
																		  Source,
																		  MaintDateTime)
																		  
VALUES(	@Client,
			  @GroupCode,
			  @SiteNo,
			  @SSN,
			  @DeptNo,
			  @ShiftNo,
			  @PPED,
			  @ClockAdjustmentNo,
			  @AdjType,
			  @Amount,
			  @Day,
			  @Sales,
			  @Brand,
			  @UserID,
			  @ReasonCodeID,
			  CASE WHEN @UserID = 21521 THEN 'IVR' ELSE '' END,
			  GETDATE())


-- If the new amount is zero then do a delete instead of an update
IF (IsNull(@Amount, 0) <> 0 AND IsNull(@NewAmount, 0) = 0)
BEGIN
	SET @DoDelete = '1'
END
ELSE
BEGIN
	SET @DoDelete = '0'
END

SET @UserCode = (SELECT UserCode FROM TimeCurrent..tblUser WHERE UserID = @UserID)

SET @THDRecordID = (
  SELECT RecordID FROM tblTimeHistDetail
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND SiteNo = @SiteNo
    AND SSN = @SSN
    AND DeptNo = @DeptNo
    AND ShiftNo = @ShiftNo
    AND PayrollPeriodEndDate = @PPED
    AND Hours = @Amount
    AND ClockAdjustmentNo = @ClockAdjustmentNo
    AND InDay = @Day
)

IF @THDRecordID IS NOT NULL
BEGIN

	-- If a default value for Brand exists, then overwrite the blank brand
	SELECT @Brand = CASE WHEN @Brand = '' THEN IsNull(fd.DefaultValue, '') ELSE @Brand END
	FROM TimeCurrent.dbo.tblUDF_WebApps wa
	INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
	ON t.TemplateCode = 'PATE'
	AND t.Client = @Client
  INNER JOIN TimeCurrent..tblUDF_TemplateMapping tm
  ON t.TemplateID = tm.TemplateID
  AND tm.TemplateMappingID = @UDFMappingId
	INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
	ON fd.TemplateId = t.TemplateId
	AND fd.FieldName = 'Brand'
	WHERE wa.WebAppCode = 'PATE'

	IF (@DoDelete = '0')
	BEGIN
	  UPDATE tblTimeHistDetail SET Hours = @NewAmount, UserCode = @UserCode WHERE RecordID = @THDRecordID
	
	  DECLARE @PateRecordID int
	  SET @PateRecordID = (
	    SELECT RecordID
	    FROM tblTimeHistDetail_PATE
	    WHERE THDRecordID = @THDRecordID
	  )
	
	  IF @PateRecordID IS NULL
	  BEGIN
	    INSERT INTO tblTimeHistDetail_PATE (THDRecordID, Brand)
	    VALUES (@THDRecordID, @Brand)
	  END
	  ELSE
	  BEGIN
	    UPDATE tblTimeHistDetail_PATE SET Brand = @Brand WHERE THDRecordID = @THDRecordID
	  END
	END
END

DECLARE @AdjRecordID  int

SET @AdjRecordID = (
  SELECT Record_No FROM TimeCurrent..tblAdjustments
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND SiteNo = @SiteNo
      AND SSN = @SSN
      AND DeptNo = @DeptNo
      AND ShiftNo = @ShiftNo
      AND PayrollPeriodEndDate = @PPED
      AND ClockAdjustmentNo = @ClockAdjustmentNo
      AND SunVal = (CASE @Day WHEN 1 THEN @Amount ELSE SunVal END)
      AND MonVal = (CASE @Day WHEN 2 THEN @Amount ELSE MonVal END)
      AND TueVal = (CASE @Day WHEN 3 THEN @Amount ELSE TueVal END)
      AND WedVal = (CASE @Day WHEN 4 THEN @Amount ELSE WedVal END)
      AND ThuVal = (CASE @Day WHEN 5 THEN @Amount ELSE ThuVal END)
      AND FriVal = (CASE @Day WHEN 6 THEN @Amount ELSE FriVal END)
      AND SatVal = (CASE @Day WHEN 7 THEN @Amount ELSE SatVal END)
)

IF @AdjRecordID IS NOT NULL AND @DoDelete = '0'
BEGIN
  UPDATE TimeCurrent..tblAdjustments 
  SET SunVal = (CASE @Day WHEN 1 THEN @NewAmount ELSE 0 END),
      MonVal = (CASE @Day WHEN 2 THEN @NewAmount ELSE 0 END),
      TueVal = (CASE @Day WHEN 3 THEN @NewAmount ELSE 0 END),
      WedVal = (CASE @Day WHEN 4 THEN @NewAmount ELSE 0 END),
      ThuVal = (CASE @Day WHEN 5 THEN @NewAmount ELSE 0 END),
      FriVal = (CASE @Day WHEN 6 THEN @NewAmount ELSE 0 END),
      SatVal = (CASE @Day WHEN 7 THEN @NewAmount ELSE 0 END),
      Sales = @Sales,
      UserID = @UserID
  WHERE Record_No = @AdjRecordID
END

IF (@DoDelete = '1')
BEGIN
	-- I'm going to do updates for now until we see that this works ok, this can be changed to delete later on
	UPDATE TimeHistory.dbo.tblTimeHistDetail SET Client = 'PAT1' WHERE RecordId = @THDRecordID
	UPDATE TimeCurrent..tblAdjustments SET Client = 'PAT1' WHERE Record_No = @AdjRecordID
END

SELECT @ReturnCode AS ReturnCode


