CREATE   Procedure [dbo].[usp_APP_DSWaters_FixSalary]
	@Client varchar(4), 
	@GroupCode int,
	@PPED datetime, 
	@SSN int 
AS


SET NOCOUNT ON
--*/

DECLARE @PayType tinyint
DECLARE @Agency int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 26Sept2016 >--


Select @PayType = PayType, @Agency = AgencyNo, @SiteNo = PrimarySite, @DeptNo = PrimaryDept
from TimeCurrent.dbo.tblEmplNames 
Where Client = @Client
and GroupCode = @GroupCode
and SSN = @SSN

  IF @PayType = 1
  BEGIN
    IF @SiteNo is NULL
      Set @SiteNo = 0
    If @SiteNo = 0 
    BEGIN
        Set @SiteNo = (Select Top 1 SiteNo from TimeCurrent..tblEmplSites where client = @Client and GroupCode = @GroupCode and SSN = @SSN and RecordStatus = '1')
    END
    
    IF @DeptNo is NULL
      Set @DeptNo = 0
    If @DeptNo = 0 
    BEGIN
        Set @DeptNo = (Select Top 1 DeptNo from TimeCurrent..tblEmplSites_Depts where client = @Client and GroupCode = @GroupCode and SSN = @SSN and SiteNo = @SiteNo and RecordStatus = '1')
    END

    -- Delete any existing salary recs.
    -- 
    Delete from [TimeHistory].[dbo].[tblTimeHistDetail]
        WHERE Client = @Client
          AND GroupCode = @GroupCode
          AND PayrollPeriodEndDate = @PPED
          AND SSN = @SSN
          AND AdjustmentName = 'SALARY'
    
    -- JobID is used to determine if transaction records came from different spread sheets
    -- so we need to default the salary hours to an existing jobid if possible.
    --
    Set @JobID = (Select Top 1 Jobid from [TimeHistory].[dbo].[tblTimeHistDetail]
        WHERE Client = @Client
          AND GroupCode = @GroupCode
          AND PayrollPeriodEndDate = @PPED
          AND SSN = @SSN
          AND ClockAdjustmentNo = 'X' )

    if @JobID is NULL
      Set @JobID = 0

    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]
    ([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], 
    [DeptNo], [JobID], [TransDate], [ShiftNo], [InDay], [InTime], 
    [OutDay], [OutTime], [Hours], [xAdjHours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], 
    [TransType], [AgencyNo], [InSrc], [CountAsOT], [UserCode])
    VALUES(@Client, @GroupCode, @SSN, @PPED, @PPED, @SiteNo, @DeptNo, @JobID, @PPED, 1, 7, '12-30-1899 12:00:00', 
    7, '12-30-1899 12:00:00', 40.00, 0.00, 0.00, 'S', 'S', 'SALARY', 
    100, @Agency, '3', '0', 'GSR')

    -- Need to insure that total hours are = 40 for salary employees.
    --
    DECLARE @SumHours numeric(9,2)

    Set @SumHours = (Select SUM(Hours) from TimeHistory..tblTimeHistDetail
        WHERE Client = @Client
          AND GroupCode = @GroupCode
          AND PayrollPeriodEndDate = @PPED
          AND SSN = @SSN)
  
    if @SumHours is NULL
      Set @SumHours = 0
    
    if @SumHours > 40.00
    BEGIN
      UPDATE TimeHistory..tblTimeHistDetail
      SET Hours = Hours - (SELECT CASE WHEN sum(Hours) IS NULL THEN 0 ELSE sum(Hours) END 
      					 FROM TimeHistory..tblTimeHistDetail AS THD
      					 WHERE THD.Client = tblTimeHistDetail.Client
      					   AND THD.GroupCode = tblTimeHistDetail.GroupCode
      					   AND THD.SSN = tblTimeHistDetail.SSN
      					   AND PayrollPeriodEndDate = @PPED
                   AND AdjustmentName <> 'SALARY' )
      WHERE Client = @Client
        AND GroupCode = @GroupCode
        AND PayrollPeriodEndDate = @PPED
        AND SSN = @SSN
        AND AdjustmentName = 'SALARY'
        
  
      IF (@@ERROR = 0)
      begin
        -- Remove any negative 'REG' records 
        ------------------------------------------------------------
        DELETE tblTimeHistDetail
        WHERE Client = @Client
          AND GroupCode = @GroupCode
          AND PayrollPeriodEndDate = @PPED
          AND SSN = @SSN
          AND AdjustmentName = 'SALARY'
          AND Hours < 0
      end
    End   
  END  




