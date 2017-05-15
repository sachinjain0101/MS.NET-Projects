CREATE   PROCEDURE [dbo].[usp_WTE_InsertAdjustment] (
  @Client       varchar(4),
  @GroupCode    int,
  @SSN          int,
  @PPED         datetime,
  @SiteNo       int,
  @DeptNo       int,
  @TransDate    datetime,
  @ClockAdjustmentNo  varchar(3), --< Srinsoft 09/09/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
  @Hours        numeric(5,2),
  @Dollars      numeric(7,2)
)
AS


SET NOCOUNT ON
--*/

/*
DECLARE  @Client       varchar(4)
DECLARE  @GroupCode    int
DECLARE  @SSN          int
DECLARE  @PPED         datetime
DECLARE  @SiteNo       int
DECLARE  @DeptNo       int
DECLARE  @TransDate    datetime
DECLARE  @ClockAdjustmentNo  char(1)
DECLARE  @Hours        numeric(5,2)
DECLARE  @Dollars      numeric(7,2)

SET @Client       = 'CIG1'
SET @GroupCode    = 900000
SET @SSN          = 999001777
SET @PPED         = '12/09/06'
SET @SiteNo       = 2
SET @DeptNo       = 3
SET @TransDate    = '2006-12-06 00:00:00.000'
SET @ClockAdjustmentNo = ' '
SET @Hours        = 0
SET @Dollars      = 0
*/

DECLARE @AdjustmentName     varchar(20)
DECLARE @AdjustmentCodeFull varchar(3)
DECLARE @AdjustmentCode     varchar(3) --< Srinsoft 09/09/2015 Changed @AdjustmentCode char(1) to varchar(3) >--
DECLARE @HoursCode					varchar(20)

SELECT 
  @AdjustmentName = AdjustmentName, 
  @AdjustmentCodeFull = AdjustmentCode,
  @AdjustmentCode = LEFT(AdjustmentCode, 1),
	@HoursCode = isnull(ADP_HoursCode,'')
FROM TimeCurrent.dbo.tblAdjCodes
WHERE Client = @Client
  AND GroupCode = @GroupCode
  AND ClockAdjustmentNo = @ClockAdjustmentNo

DECLARE @EmpStatus    tinyint 
DECLARE @AgencyNo     smallint 
DECLARE @BillRate     numeric(7,2) 
DECLARE @PayRate      numeric(7,2) 
DECLARE @DivisionID   BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 02Nov2016 >--

SELECT 
  @EmpStatus = empls.Status, 
  @AgencyNo = empls.AgencyNo, 
  @BillRate = depts.BillRate,
  @PayRate = depts.PayRate,
  @DivisionID = empls.DivisionID
FROM TimeCurrent.dbo.tblEmplNames empls
LEFT JOIN TimeCurrent.dbo.tblEmplSites_Depts depts
ON depts.Client = empls.Client
  AND depts.GroupCode = empls.GroupCode
  AND depts.SiteNo = @SiteNo
  AND depts.DeptNo = @DeptNo
  AND depts.SSN = empls.SSN
  AND depts.RecordStatus = '1'
WHERE empls.Client = @Client
  AND empls.GroupCode = @GroupCode
  AND empls.SSN = @SSN
  AND empls.RecordStatus = '1'

DECLARE @RecordID   BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--

INSERT INTO TimeHistory.dbo.tblTimeHistDetail (
  Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate,
  SiteNo, DeptNo, CostID, TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate,
  ShiftNo, InDay, InTime, OutDay, OutTime,
  Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName,
  DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID
) VALUES (
  @Client, @GroupCode, @SSN, @PPED, @PPED,
  @SiteNo, @DeptNo, '0', @TransDate, @EmpStatus, @BillRate, 0.00, 0.00, @PayRate,
  1, DATEPART(dw, @TransDate), '1899-12-30 00:00:00.000', DATEPART(dw, @TransDate), '1899-12-30 00:00:00.000',
  @Hours, @Dollars, 0, @AgencyNo, 'S', 'S', @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName,
  '0', '0', 'V', 0, 'VTS', @DivisionID
)

SET @RecordID = scope_identity()

IF @Client in('HILT','HLT1') AND LTRIM(RTRIM(@HoursCode)) = 'FLH'
BEGIN
  UPDATE TimeCurrent.dbo.tblEmplNames
  SET floatHolidayDate = @TransDate
  WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND SSN = @SSN
END

SELECT @RecordID AS RecordID




