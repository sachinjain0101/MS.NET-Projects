CREATE  PROCEDURE [dbo].[usp_WTE_UpdateTransaction] (
  @Client       varchar(4),
  @GroupCode    int,
  @RecordID     BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Sept2016 >--
  @SiteNo       int,
  @DeptNo       int,
  @SSN          int,
  @TransDate    datetime,
  @InDateTime   datetime,
  @OutDateTime  datetime,
  @ClockAdjustmentNo  varchar(3), --< Srinsoft 09/09/2015  Changed @ClockAdjustmentNo  char(1) to varchar(3) >--
  @Hours        numeric(5,2),
  @Dollars      numeric(7,2)
)
AS


SET NOCOUNT ON
--*/

/*
DECLARE  @Client       varchar(4)
DECLARE  @GroupCode    int
DECLARE  @RecordID     int
DECLARE  @SiteNo       int
DECLARE  @DeptNo       int
DECLARE  @SSN          int
DECLARE  @InDateTime   datetime
DECLARE  @OutDateTime  datetime
DECLARE  @ClockAdjustmentNo  char(1)
DECLARE  @Hours        numeric(5,2)
DECLARE  @Dollars      numeric(7,2)

SET @Client       = 'CIG1'
SET @GroupCode    = 900000
SET @RecordID     = 318192385
SET @SiteNo       = 2
SET @DeptNo       = 3
SET @SSN          = 999001777
SET @InDateTime   = '2006-12-06 00:45:00.000'
SET @OutDateTime  = '2006-12-06 02:00:00.000'
SET @ClockAdjustmentNo = ' '
SET @Hours        = 0
SET @Dollars      = 0
*/

DECLARE @AdjustmentName     varchar(20)
DECLARE @AdjustmentCodeFull varchar(3)
DECLARE @AdjustmentCode     varchar(3) --< Srinsoft 09/09/2015 Changed @AdjustmentCode  char(1) to varchar(3) >--
DECLARE @OldTransDate DATETIME
DECLARE @PPED DATETIME

SELECT 
  @AdjustmentName = AdjustmentName, 
  @AdjustmentCodeFull = AdjustmentCode,
  @AdjustmentCode = LEFT(AdjustmentCode, 1)
FROM TimeCurrent.dbo.tblAdjCodes
WHERE Client = @Client
  AND GroupCode = @GroupCode
  AND ClockAdjustmentNo = @ClockAdjustmentNo

-- If Hilton or Hilton Test then handle floating holiday logic.
--
IF @Client IN ('HILT','HLT1') 
BEGIN
  DECLARE @PrevAdjNo       varchar(3)--< Srinsoft 09/02/2016 Changed @PrevAdjNo  char(1) to varchar(3) >--
  DECLARE @PrevTransDate  datetime

  SELECT @PrevAdjNo = ClockAdjustmentNo, @PrevTransDate = TransDate
  FROM TimeHistory.dbo.tblTimeHistDetail
  WHERE RecordID = @RecordID

  IF @PrevAdjNo = '5' AND @ClockAdjustmentNo <> '5'
  BEGIN
    UPDATE TimeCurrent.dbo.tblEmplNames
    SET FloatHolidayDate = NULL
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND SSN = @SSN
  END

  IF @PrevAdjNo <> '5' AND @ClockAdjustmentNo = '5'
  BEGIN
    UPDATE TimeCurrent.dbo.tblEmplNames
    SET FloatHolidayDate = @PrevTransDate
    WHERE Client = @Client
      AND GroupCode = @GroupCode
      AND SSN = @SSN
  END
END

DECLARE @InTime   datetime
DECLARE @OutTime  datetime

SET @InTime = '1899-12-30 00:00.000'
SET @InTime = DATEADD(hh, DATEPART(hh, @InDateTime), @InTime)
SET @InTime = DATEADD(mi, DATEPART(mi, @InDateTime), @InTime)

SET @OutTime = '1899-12-30 00:00.000'
SET @OutTime = DATEADD(hh, DATEPART(hh, @OutDateTime), @OutTime)
SET @OutTime = DATEADD(mi, DATEPART(mi, @OutDateTime), @OutTime)

SELECT @OldTransDate = TransDate,
       @PPED = PayrollPeriodEndDate
FROM TimeHistory..tblTimeHistDetail
WHERE RecordID = @RecordID

UPDATE TimeHistory.dbo.tblTimeHistDetail
SET 
  TransDate = @TransDate,
  SiteNo = @SiteNo,
  DeptNo = @DeptNo,
  ClockAdjustmentNo = @ClockAdjustmentNo,
	AdjustmentCode = @AdjustmentCode,
	AdjustmentName = @AdjustmentName,
	ActualInTime = @InDateTime,
	ActualOutTime = @OutDateTime,
  InTime = @InTime,
  OutTime = @OutTime,
  InDay = DATEPART(dw, @InDateTime),
  OutDay = DATEPART(dw, @OutDateTime),
  Hours = @Hours,
  Dollars = @Dollars,
  UserCode = 'VTS'
WHERE RecordID = @RecordID

DELETE 
FROM TimeHistory..tblWTE_Spreadsheet_Breaks
WHERE Client = @Client
AND GroupCode = @GroupCode
AND SSN = @SSN
AND PayrollPeriodEndDate = @PPED
AND TransDate = @OldTransDate
