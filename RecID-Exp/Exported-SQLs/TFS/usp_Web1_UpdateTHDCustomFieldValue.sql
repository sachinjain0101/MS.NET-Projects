Create PROCEDURE [dbo].[usp_Web1_UpdateTHDCustomFieldValue] (
  @THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
  @FieldId int,
  @FieldValue varchar(8000),
  @MaintUserName varchar(10)
)

AS
--*/

DECLARE @SaveIncostID char(1)
DECLARE @Client varchar(4)
DECLARE @PPED datetime
DECLARE @GroupCode int
DECLARE @Siteno int
DECLARE @DeptNo int
DECLARE @SSN int
DECLARE @TransDate datetime
DECLARE @InTime datetime
DECLARE @PunchTimeStamp bigint

SET @SaveIncostID = '0'

IF EXISTS (SELECT 1
  FROM TimeHistory..tblTimeHistDetail_UDF
  WHERE THDRecordId = @THDRecordId
  AND FieldId = @FieldId)
BEGIN
  UPDATE TimeHistory..tblTimeHistDetail_UDF
    SET FieldValue = @FieldValue, MaintDateTime = GETDATE(), MaintUserName = @MaintUserName 
  WHERE FieldId = @FieldId
  AND THDRecordID = @THDRecordId
END
ELSE
BEGIN
  -- Check to see if the UDF came in from a clock -- if so it would not have a thdRecordID instead it
  -- would have a PunchTimeStamp == OutTimeStamp
  --
  Select 
    @PunchTimeStamp = isnull(outTimestamp,0),
    @Client = Client,
    @GroupCode = GroupCode,
    @TransDate = TransDate,
    @SSN = SSN,
    @PPED = PayrollPeriodEndDate 
  from TimeHistory..tblTimeHistDetail 
  where RecordID = @THDRecordId 
  --and isnull(outTimestamp,0) <> 0
  
  IF @PunchTimeStamp = 0
  BEGIN
    -- No Record found from a clock -- so no UDF record is found for this TimeHistDetail Record.
    -- Need to add one.
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_UDF]([THDRecordID], [FieldID], [FieldValue], [MaintDateTime], [MaintUserName], [PayrollPeriodEndDate], [Client], [GroupCode], [SiteNo], [DeptNo], [SSN], [TransDate], [PunchTimeStamp])
    Select RecordId, @FieldID, @FieldValue, getdate(),@MaintUserName, PayrollPeriodEndDate, Client, Groupcode, SiteNo, DeptNo, SSN, TransDate, isnull(OutTimeStamp,0)
    from TimeHistory..tblTImeHistDetail
    where RecordID = @THDRecordID
  END
  ELSE
  BEGIN
    IF EXISTS(Select 1 FROM TimeHistory..tblTimeHistDetail_UDF
              WHERE FieldId = @FieldId
              and Client = @Client
              and GroupCode = @GroupCode
              and TransDate = @TransDate 
              and SSN = @SSN  
              and PunchTimeStamp = @PunchTimeStamp )
    BEGIN 
      -- If it's there then update it.
      -- else add a new record with all the particulars..
      UPDATE TimeHistory..tblTimeHistDetail_UDF
        SET FieldValue = @FieldValue, MaintDateTime = GETDATE(), MaintUserName = @MaintUserName, THDRecordID = @THDRecordId  
      WHERE FieldId = @FieldId
      and Client = @Client
      and GroupCode = @GroupCode
      and TransDate = @TransDate 
      and SSN = @SSN  
      and PunchTimeStamp = @PunchTimeStamp
      
    END
    ELSE
    BEGIN
      INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_UDF]([THDRecordID], [FieldID], [FieldValue], [MaintDateTime], [MaintUserName], [PayrollPeriodEndDate], [Client], [GroupCode], [SiteNo], [DeptNo], [SSN], [TransDate], [PunchTimeStamp])
      Select RecordId, @FieldID, @FieldValue, getdate(),@MaintUserName, PayrollPeriodEndDate, Client, Groupcode, SiteNo, DeptNo, SSN, TransDate, isnull(OutTimeStamp,0)
      from TimeHistory..tblTImeHistDetail
      where RecordID = @THDRecordID
    END
  END
END

SELECT 
  SaveInCostID = @SaveIncostID
FROM TimeCurrent..tblUDF_FieldDefs
WHERE FieldID = @FieldId

IF @SaveIncostID = '1'
BEGIN
  UPDATE TimeHistory..tblTimeHistDetail
    SET CostID = @FieldValue
  WHERE RecordID = @THDRecordId
END

