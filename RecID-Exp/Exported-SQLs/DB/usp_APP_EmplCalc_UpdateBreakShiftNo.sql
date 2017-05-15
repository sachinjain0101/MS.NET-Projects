CREATE PROCEDURE [dbo].[usp_APP_EmplCalc_UpdateBreakShiftNo] (
  @Client    varchar(4), 
  @GroupCode int,
  @SSN       int,
  @PPED      datetime, 
  @RecordID  BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 03Aug2016 >--
) AS


SET NOCOUNT ON
--*/

/*
DECLARE @Client    varchar(4)
DECLARE @GroupCode int
DECLARE @SSN       int
DECLARE @PPED      datetime
DECLARE @RecordID  int

SET @Client    = 'VANG'
SET @GroupCode = 554500
SET @SSN       = 148545122
SET @PPED      = '3/05/05'
SET @RecordID  = 212068050
*/

-- If possible, assign ShiftNo of the record with the most hours in that DeptNo for that TransDate
-- If not, assign ShiftNo of the record with the most hours of any DeptNo for that TransDate
-- Else, assign ShiftNo to 1.  Breaks should never have a 0 ShiftNo

IF (
  SELECT COUNT(RecordID) 
  FROM tblTimeHistDetail 
  WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED
    AND SSN = @SSN AND RecordID = @RecordID AND InDay < 10 AND OutDay < 10 AND ClockAdjustmentNo = '8'
) = 1 -- Validate the data just in case
BEGIN
  DECLARE @TransDate      datetime
  DECLARE @DeptNo         int
  DECLARE @ShiftNo        int

  SELECT @TransDate = TransDate, @DeptNo = DeptNo
  FROM tblTimeHistDetail WHERE RecordID = @RecordID
  
  SET @ShiftNo = (
    SELECT TOP 1 ShiftNo
    FROM tblTimeHistDetail
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND PayrollPeriodEndDate = @PPED
      AND SSN = @SSN
      AND TransDate = @TransDate
      AND Hours > 0
      AND ClockAdjustmentNo IN ('', ' ', '1')
    ORDER BY CASE DeptNo WHEN @DeptNo THEN 0 ELSE 1 END, Hours DESC
  )

  IF @ShiftNo IS NOT NULL
    UPDATE tblTimeHistDetail SET ShiftNo = @ShiftNo WHERE RecordID = @RecordID
  ELSE
    UPDATE tblTimeHistDetail SET ShiftNo = 1 WHERE RecordID = @RecordID
END


