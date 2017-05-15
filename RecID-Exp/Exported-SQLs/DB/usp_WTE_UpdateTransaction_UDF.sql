CREATE       PROCEDURE [dbo].[usp_WTE_UpdateTransaction_UDF] (
  @THDRecordID  BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 19Sept2016 >--
  @FieldID      int,
  @FieldValue   varchar(8000)
)
AS


SET NOCOUNT ON
--*/

/*
DECLARE  @THDRecordID  int
DECLARE  @FieldID      int
DECLARE  @FieldValue   varchar(8000)

SET @THDRecordID  = 387435211
SET @FieldID      = '141'
SET @FieldValue   = '123456789012345678901234567890'
*/

DECLARE @RecordID      int

SET @RecordID = (
  SELECT RecordID
  FROM TimeHistory.dbo.tblTimeHistDetail_UDF
  WHERE THDRecordID = @THDRecordID
    AND FieldID = @FieldID
)

IF @RecordID IS NULL
BEGIN
  INSERT INTO TimeHistory.dbo.tblTimeHistDetail_UDF
  (THDRecordID, FieldID, FieldValue, MaintDateTime, MaintUserName)
  VALUES
  (@THDRecordID, @FieldID, @FieldValue, GETDATE(), 'WTE')
END
ELSE
BEGIN
  UPDATE TimeHistory.dbo.tblTimeHistDetail_UDF
  SET THDRecordID = @THDRecordID,
    FieldID = @FieldID,
    FieldValue = @FieldValue,
    MaintDateTime = GETDATE(),
    MaintUserName = 'WTE'
  WHERE RecordID = @RecordID
END

IF ISNULL((
	SELECT SaveInCostId
	FROM TimeCurrent.dbo.tblUDF_FieldDefs
	WHERE FieldID = @FieldID
), 0) = 1
BEGIN

  DECLARE @Client varchar(4)

  Set @Client = (select Client from TimeHistory..tblTimehistdetail where recordID = @THDRecordID )
  
  IF @Client in('HLT1','HILT')
  BEGIN
  	UPDATE TimeHistory.dbo.tblTimeHistDetail 
      SET CostID = @FieldValue, 
  				AdjustmentName = case when ClockAdjustmentNo in('',' ')
  															 and isnull(AdjustmentName,'') <> @FieldValue
  															 and Len(@FieldValue) > 3
  															then left(@FieldValue,10) else AdjustmentName end 
    WHERE RecordID = @THDRecordID
  END
  ELSE
  BEGIN
    IF @Client = 'DAVT'
    BEGIN
    	UPDATE TimeHistory.dbo.tblTimeHistDetail 
        SET CostID = @FieldValue, 
    				AdjustmentName = case when ClockAdjustmentNo in('',' ') and @FieldValue = '1' then 'Travel Amt'
                                  when ClockAdjustmentNo in('',' ') and @FieldValue = '0' then ''
    												 else AdjustmentName end 
      WHERE RecordID = @THDRecordID
    END
    ELSE
    BEGIN
    	UPDATE TimeHistory.dbo.tblTimeHistDetail 
        SET CostID = @FieldValue 
      WHERE RecordID = @THDRecordID
    END
  END
  
END


SELECT defs.FieldDescription, 
  ISNULL(CASE defs.DropDownMethod WHEN 'Custom' THEN options.OptionDesc WHEN 'PreDef' THEN lookup.LookupDescription END, @FieldValue) AS FieldValue
FROM TimeCurrent.dbo.tblUDF_FieldDefs defs
LEFT JOIN TimeCurrent.dbo.tblUDF_FieldOptions options
ON options.FieldID = defs.FieldID
  AND options.OptionValue = @FieldValue
  AND defs.DropDownMethod = 'Custom'
LEFT JOIN TimeCurrent.dbo.tblValidLookup lookup
ON lookup.LookupType = defs.LookupType
  AND lookup.LookupValue = @FieldValue
  AND defs.DropDownMethod = 'PreDef'
WHERE defs.FieldID = @FieldID








