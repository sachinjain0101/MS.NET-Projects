Create PROCEDURE [dbo].[usp_WEB1_MoveHours_TransferHours_MC]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @TransInfo varchar(100),
  @SSN int,
  @NewSite int,
  @NewDept int,
  @Hours numeric(8,2),
  @UserName varchar(32),
  @UserCode varchar(5),
  @UserID int
)
AS

SET NOCOUNT ON

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 14Sept2016 >--
DECLARE @TransDate datetime
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @ShiftNo int
DECLARE @ShiftDiffClass char(1)
DECLARE @Holiday char(1)

-- =================== 
-- The @TransInfo field contains all the following fields packed into one field.
--  Position  1 - 10 (Len 10) TransDate      Example: 01/12/2006
--  Position 11 - 14 (Len  4) SiteNo         Example: 1002
--  Position 15 - 17 (Len  3) DeptNo         Example: 004
--  Position 18 - 18 (Len  1) ShiftNo        Example: 2
--  Position 19 - 19 (Len  1) ShiftDiffClass Example: 1
--  Position 20 - 20 (Len  1) Holiday        Example: 0

Set @TransDate = left(@Transinfo,10)
Set @SiteNo = substring(@TransInfo,11,4)
Set @DeptNo = substring(@TransInfo,15,3)
Set @ShiftNo = substring(@TransInfo,18,1)
Set @ShiftDiffClass = substring(@TransInfo,19,1)
Set @Holiday = substring(@TransInfo,20,1)

DECLARE @PayType CHAR(1)
-- 0 - hourly, 1- salary
SELECT  @PayType = ISNULL(EN.PayType, 0)
FROM    TimeCurrent..tblEmplNames AS EN WITH (NOLOCK)
INNER JOIN TimeCurrent..tblValidPayTypes AS VPT WITH (NOLOCK)
ON      VPT.PayType = ISNULL(EN.PayType, 0)
WHERE   EN.Client = @Client
        AND EN.GroupCode = @GroupCode
        AND EN.SSN = @SSN

BEGIN TRANSACTION

  -- Create negating transactions
  INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]
        ([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime],           [OutDay], [OutTime],          [Hours],       [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [UserCode], [DivisionID], [CostID], [ShiftDiffAmt],[ActualInTime],[ActualOutTime],[xAdjHours] )
  Select TOP 1 [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], '1899-12-30 00:00', (-1 * @Hours), [Dollars], '1',                 [AdjustmentCode], case when @Client in('DVPC','DAVT') then 'MOVED' else 'WORKED' end,         101,         [AgencyNo], '3',     '3',      [DaylightSavTime], [Holiday], '', 0, NULL, [AprvlAdjOrigRecID], 'V',                 [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], @UserCode,  [DivisionID], [CostID], [ShiftDiffAmt],[ActualInTime],[ActualOutTime],1
  From TimeHistory..tblTimeHistDetail
  where client = @Client and groupcode = @Groupcode and PayrollPeriodEndDate = @PPED
  and SSN = @SSN and TransDate = @TransDate and DeptNo = @DeptNo and SiteNo = @SiteNo 
  and ShiftNo = @ShiftNo and isnull(ShiftDiffClass,'0') = @ShiftDiffClass
  and Holiday = @Holiday
  -- include salary hours if employee is salaried US5087
  AND ( ( @PayType = 1
			AND ClockAdjustmentNo = 'S'
        )
        OR ( @PayType = 0
				AND ClockAdjustmentNo IN ( '', ' ' )
            )
    )

  if @@Error <> 0 
  begin
    goto RollBackTransaction
  end  
  Set @RecordID = SCOPE_IDENTITY()

  -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
  -- so it will get sent back to the time clock.
  INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
        [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
        [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
        [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
        [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
        [RecordStatus], [IPAddr], [ShiftNo])
  (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
        '', AdjustmentName, 'H', 
        Case when InDay = 2 then Hours else 0 end,
        Case when InDay = 3 then Hours else 0 end,
        Case when InDay = 4 then Hours else 0 end,
        Case when InDay = 5 then Hours else 0 end,
        Case when InDay = 6 then Hours else 0 end,
        Case when InDay = 7 then Hours else 0 end,
        Case when InDay = 1 then Hours else 0 end,
        Case when InDay < 1 or InDay > 7 then Hours else 0 end,
        Hours, AgencyNo, @UserName,@UserID,getdate(),null,null,null,null,'1','99.99.99.99',ShiftNo
  from tblTimeHistdetail
  where RecordID = @RecordID)

  if @@Error <> 0 
  begin
    goto RollBackTransaction
  end  

  -- Create Positive Transaction in new Department
  --
  INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]
        ([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime],           [OutDay], [OutTime],          [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [UserCode], [DivisionID], [CostID], [ShiftDiffAmt],[ActualInTime],[ActualOutTime],[xAdjHours])
  Select TOP 1 [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate],CASE WHEN @NewSite = 0 THEN [SiteNo] ELSE @NewSite END, @NewDept, [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], '1899-12-30 00:00',  @Hours, [Dollars], '1',                 [AdjustmentCode], case when @Client in('DVPC','DAVT') then 'MOVED' else 'WORKED' end,         101,         [AgencyNo], '3',     '3',      [DaylightSavTime], [Holiday], '', 0, NULL, [AprvlAdjOrigRecID], 'V',                 [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], @UserCode,  [DivisionID], [CostID], [ShiftDiffAmt],[ActualInTime],[ActualOutTime],1
  From TimeHistory..tblTimeHistDetail
  where client = @Client and groupcode = @Groupcode and PayrollPeriodEndDate = @PPED
  and SSN = @SSN and TransDate = @TransDate and DeptNo = @DeptNo and SiteNo = @SiteNo 
  and ShiftNo = @ShiftNo and isnull(ShiftDiffClass,'0') = @ShiftDiffClass
  and Holiday = @Holiday
  -- include salary hours if employee is salaried US5087
  AND ( ( @PayType = 1
			AND ClockAdjustmentNo = 'S'
        )
        OR ( @PayType = 0
				AND ClockAdjustmentNo IN ( '', ' ' )
            )
    )

  if @@Error <> 0 
  begin
    goto RollBackTransaction
  end  
  Set @RecordID = SCOPE_IDENTITY()

  -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
  -- so it will get sent back to the time clock.
  INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
        [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
        [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
        [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
        [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
        [RecordStatus], [IPAddr], [ShiftNo])
  (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
        '', AdjustmentName, 'H', 
        Case when InDay = 2 then Hours else 0 end,
        Case when InDay = 3 then Hours else 0 end,
        Case when InDay = 4 then Hours else 0 end,
        Case when InDay = 5 then Hours else 0 end,
        Case when InDay = 6 then Hours else 0 end,
        Case when InDay = 7 then Hours else 0 end,
        Case when InDay = 1 then Hours else 0 end,
        Case when InDay < 1 or InDay > 7 then Hours else 0 end,

        Hours, AgencyNo, @UserName,@UserID,getdate(),null,null,null,null,'1','99.99.99.99',ShiftNo
  from tblTimeHistdetail
  where RecordID = @RecordID)
 
  if @@Error <> 0 
  begin
    goto RollBackTransaction
  end  


COMMIT TRANSACTION

RETURN

RollBackTransaction:
ROLLBACK TRANSACTION

RETURN









