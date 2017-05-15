Create PROCEDURE [dbo].[usp_WTE_DeleteTransaction] (
  @Client       varchar(4),
  @GroupCode    int,
  @SSN          int,
  @PPED         datetime,
	@RecordID			BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
)
AS

SET NOCOUNT ON
--*/

/*
DECLARE  @Client       varchar(4)
DECLARE  @GroupCode    int
DECLARE  @SSN          int
DECLARE  @PPED         datetime
DECLARE  @RecordID		 int

SET @Client       = 'CIG1'
SET @GroupCode    = 900000
SET @SSN          = 999001777
SET @PPED         = '12/09/06'
*/

-- If Hilton or Hilton Test then handle floating holiday logic.
--
DECLARE @TransDate DATETIME

IF @Client IN ('HILT','HLT1') 
BEGIN
  DECLARE @PrevAdjNo      varchar(3) --< Srinsoft 09/09/2015 Changed @PrevAdjNo char(1) to varchar(3) for Clockadjustmentno >--
  DECLARE @PrevTransDate  datetime

  SELECT @PrevAdjNo = ClockAdjustmentNo
  FROM TimeHistory.dbo.tblTimeHistDetail
  WHERE RecordID = @RecordID

  IF @PrevAdjNo = '5'
  BEGIN
    UPDATE TimeCurrent.dbo.tblEmplNames
    SET FloatHolidayDate = NULL
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND SSN = @SSN
  END

END

SELECT @TransDate = TransDate
FROM TimeHistory..tblTimeHistDetail
WHERE RecordID = @RecordID

DELETE FROM TimeHistory.dbo.tblTimeHistDetail
WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = @PPED
	AND RecordID = @RecordID

DELETE
FROM TimeHistory..tblWTE_Spreadsheet_Breaks
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND TransDate = @TransDate



