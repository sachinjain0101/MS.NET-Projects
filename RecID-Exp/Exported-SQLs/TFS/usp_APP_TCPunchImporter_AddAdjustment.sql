Create PROCEDURE [dbo].[usp_APP_TCPunchImporter_AddAdjustment]
(
  @Client      char(4),
  @GroupCode   int,
  @SiteNo      int,
  @SSN         int,
  @DeptNo      int,
  @ShiftNo     int,
  @TransDate   datetime,
  @ClockAdjustmentNo  varchar(3),  --< Srinsoft 08/25/2015 Changed @ClockAdjustmentNo char(1) to varchar(3) >--
  @AdjType     char(1),
  @Amount      numeric(5,2),
  @Day         tinyint,
  @UserID      int
)
AS
--*/

/*
DECLARE @Client      char(4)
DECLARE @GroupCode   int
DECLARE @SiteNo      int
DECLARE @SSN         int
DECLARE @DeptNo      int
DECLARE @ShiftNo     int
DECLARE @PPED        datetime
DECLARE @ClockAdjustmentNo  char(1)
DECLARE @AdjType     char(1)
DECLARE @Amount      numeric(5,2)
DECLARE @Day         tinyint
DECLARE @UserID      int

SET @Client = 'LITE'
SET @GroupCode = 170100
SET @SiteNo = 1
SET @SSN = 111111111
SET @DeptNo = 1
SET @ShiftNo = 1
SET @PPED = '4/19/03'
SET @ClockAdjustmentNo = '1'
SET @AdjType = 'H'
SET @Amount = '15.05'
SET @Day = 2
SET @UserID = @GroupCode
*/

DECLARE @ErrorCode   int
DECLARE @RecordID    BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--

SET @ErrorCode = 0

if @DeptNo = 0
BEGIN
  Set @DeptNo = (Select PrimaryDept
                  from TimeCurrent..tblEmplNames as e
                where e.client = @Client 
                  and e.Groupcode = @GroupCode 
                  and e.ssn = @SSN)

  if @DeptNo = 99
  BEGIN
    Set @DeptNo = (Select top 1 Department
                   from TimeCurrent..tblEmplNames_depts
                    where client = @Client 
                      and Groupcode = @GroupCode 
                      and ssn = @SSN and RecordStatus = '1')
  END
END

DECLARE @PPED datetime

IF @ErrorCode = 0
BEGIN
  --
  -- Get the PPED from the database.
CheckPPED:
  
  Set @PPED = (Select Payrollperiodenddate from tblPeriodEndDates where client = @Client and groupcode = @GroupCode 
                and PayrollPeriodEndDate >= @TransDate 
                and PayrollPeriodEndDate <= dateadd(day,6,@TransDate))

  IF @PPED is NULL 
  BEGIN
    -- This may occur if the first transaction of the week is a TIP transactions.
    -- So add the new week.
    --
    Set @PPED = (Select MAX(Payrollperiodenddate) from tblPeriodEndDates where client = @Client and groupcode = @GroupCode )

    While @PPED < @TransDate
    BEGIN
      Set @PPED = dateadd(day, 7, @PPED)
    END

    EXEC [TimeCurrent].[dbo].[usp_SetupPayWeek_ClockImporter] @Client, @GroupCode, @PPED

  END


  BEGIN TRANSACTION
  
  DECLARE @MasterPayrollDate      datetime

  SET @MasterPayrollDate = (
    SELECT MasterPayrollDate
    FROM tblPeriodEndDates
    WHERE Client = @Client AND GroupCode = @GroupCode AND PayrollPeriodEndDate = @PPED
  )
  IF @MasterPayrollDate IS NOT NULL
  BEGIN

    -- Check for a duplicate.
    -- 
    Set @RecordID = (Select top 1 RecordID from timehistory.dbo.tblTimeHistDetail where client = @Client and GroupCode = @GroupCode
                      and Payrollperiodenddate = @PPED and SSN = @SSN 
                      and Siteno = @SiteNo and DeptNo = @DeptNo
                      and ClockAdjustmentNo = @ClockAdjustmentNo
                      and Dollars = @Amount
                      and TransDate = @Transdate )
    if not (@RecordID is NULL)
    BEGIN
      Return
    END

    -- tblAdjustments
    INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], 
      [HoursDollars], [SunVal], [MonVal], [TueVal], [WedVal], [ThuVal], [FriVal], [SatVal], [WeekVal], [TotalVal], [UserID], [TransDateTime], [RecordStatus], [IPAddr], [ShiftNo])
    SELECT @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @ClockAdjustmentNo, AdjustmentCode, AdjustmentName,
      @AdjType, 
      (CASE @Day WHEN 1 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 2 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 3 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 4 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 5 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 6 THEN @Amount ELSE 0 END),
      (CASE @Day WHEN 7 THEN @Amount ELSE 0 END),
      0, @Amount, @UserID, GETDATE(), '1', '0.0.0.0', @ShiftNo
    FROM TimeCurrent..tblAdjCodes
    WHERE Client = @Client AND GroupCode = @GroupCode AND ClockAdjustmentNo = @ClockAdjustmentNo-- AND PayrollPeriodEndDate = @PPED
  
    -- tblTimeHistDetail
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [ShiftNo], [JobID],
      [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars],
      [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], 
      [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [AprvlAdjOrigClkAdjNo])
    SELECT TOP 1 @Client, @GroupCode, @SSN, @PPED, @MasterPayrollDate, @SiteNo, @DeptNo, @ShiftNo, 0,
      CASE WHEN @Day <= DATEPART(dw, @PPED)
      THEN DATEADD(day, -(DATEPART(dw, @PPED) - @Day), @PPED)
      ELSE DATEADD(day, ((@Day - DATEPART(dw, @PPED)) - 7), @PPED)
      END,
      empls.Status, 0, 0, 0, 0, @Day, '1899-12-30 00:00:00.000', @Day, '1899-12-30 00:00:00.000', 
    CASE @AdjType WHEN 'H' THEN @Amount ELSE 0 END, CASE @AdjType WHEN 'D' THEN @Amount ELSE 0 END,
      @ClockAdjustmentNo, '', adjs.AdjustmentName, 0, empls.AgencyNo, '0', ' ', '0', '0',
      ' ', 0, NULL, NULL, NULL
    FROM TimeCurrent..tblEmplNames AS empls
    INNER JOIN TimeCurrent..tblAdjCodes AS adjs
    ON adjs.Client = empls.Client
      AND adjs.GroupCode = empls.GroupCode
--      AND adjs.PayrollPeriodEndDate = empls.PayrollPeriodEndDate
      AND adjs.ClockAdjustmentNo = @ClockAdjustmentNo
    WHERE empls.Client = @Client
      AND empls.GroupCode = @GroupCode
      AND empls.SSN = @SSN
      AND empls.RecordStatus = '1'

  END
  ELSE
  BEGIN
    -- It won't let me do this inline
    DECLARE @strPPED    AS varchar(10)
    SET @strPPED = CONVERT(varchar(10), @PPED, 101)

    RAISERROR ('Group %d is not set up for Pay Period %s', 16, 1, @GroupCode, @strPPED)
    SET @ErrorCode = @@error
    GOTO ErrorHandler
  END

  ErrorHandler:
  IF @ErrorCode = 0
    COMMIT TRANSACTION
  ELSE
    ROLLBACK TRANSACTION
END

RETURN @ErrorCode









