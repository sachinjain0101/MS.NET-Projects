Create PROCEDURE [dbo].[usp_APP_XLSImport_DSWaters_Insert_THD]
(
  @Client char(4),
  @GroupCode int,
  @PPED datetime,
  @FileNo varchar(12),
  @SiteNo int,
  @DeptNo int,
  @Adjcode char(1),
  @AdjName varchar(20),
  @Hours numeric(5,2),
  @Dollars numeric(7,2),
  @HoursType char(2),
  @PayCode char(3),
  @UserID int,
  @JobID BIGINT,  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 04Oct2016 >--
  @Comments varchar(1024) = '',
  @Email varchar(50)
)
AS
--*/
/*
DECLARE @Client char(4)
DECLARE  @GroupCode int
DECLARE  @PPED datetime
DECLARE  @SSN int
DECLARE  @SiteNo int
DECLARE  @DeptNo int
DECLARE  @Adjcode char(1)
DECLARE  @AdjName varchar(20)
DECLARE  @Hours numeric(5,2)
DECLARE  @Dollars numeric(7,2)
DECLARE  @HoursType char(2)
DECLARE  @PayCode char(3)


SELECT @Client = 'DAVI'
SELECT  @GroupCode = 300200
SELECT  @PPED  = '09/15/01'
SELECT  @SSN = 304749241
SELECT  @SiteNo = 320
SELECT  @DeptNo = 39
SELECT  @Adjcode = 'X'
SELECT  @AdjName = '5Q'
SELECT  @Hours = 4.00
SELECT  @Dollars = 0.00
SELECT  @HoursType = 'OT'
SELECT  @PayCode = '5P'
*/

Set NOCOUNT ON

DECLARE @AgencyNo int
DECLARE @enStatus char(1)
DECLARE @CountAsOT char(1)
DECLARE @InDay tinyint 
DECLARE @strMsg varchar(512)
DECLARE @SSN int
DECLARE @DivisionID BIGINT  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 26Oct2016 >--
DECLARE @RecordID int
DECLARE @PrimaryDept int
DECLARE @Comments1 varchar(1200)
DECLARE @PayType tinyint

-- Validate Site, Dept and PPED.
Set @RecordID = (Select RecordID from TimeCurrent.dbo.tblSiteNames where client = @Client and groupcode = @GroupCode and siteno = @SiteNo)
if @RecordID is NULL 
BEGIN
  -- Send Notification
  --
  Set @strMsg = 'Invalid site number.' 
  Select RetMessage = @strMsg, SSN = 0
  Return
END

if @CLient = 'SUNT'
BEGIN
  if @DeptNo <> 0 
  BEGIN
    -- Validate dept
    DECLARE @ClientDeptCode varchar(10)
  
    Set @ClientDeptCode = right('000' + ltrim(str(@DeptNo)), 3 )
    Set @DeptNo = NULL
    Set @DeptNo = (Select top 1 DeptNo from TimeCurrent.dbo.tblGroupDepts where client = @Client and groupcode = @GroupCode and ClientDeptCode = @ClientDeptCode)
    if @DeptNo is NULL 
    BEGIN
      -- Send Notification
      --
      Set @strMsg = 'Invalid department number.' 
      Select RetMessage = @strMsg, SSN = 0
      Return
    END
  END
END

-- Validate PPED
Set @RecordID = (Select RecordID from TimeHistory.dbo.tblPeriodenddates where client = @Client and groupcode = @GroupCode and PayrollPeriodenddate = @PPED and Status <> 'C')
if @RecordID is NULL 
BEGIN
  -- Send Notification
  --
  Set @strMsg = 'Invalid week ending date. Date is closed or does not exist in PeopleNet.' 
  Select RetMessage = @strMsg, SSN = 0
  Return
END

Select @CountAsOT = '0'
Select @InDay = 7

if @HoursType = 'RG' 
Begin
  Select @CountAsOT = '0'
  Select @InDay = 7
end

-- In order to force the Hours into over time , set the InDay = 10, Calc engine is set to 
-- recognize an "X" adjustment with InDay = 10 as OT time.
--
if @HoursType = 'OT' 
Begin
  Select @CountAsOT = '1'
  Select @InDay = 10
end

-- In order to force the Hours into double time , set the InDay = 9, Calc engine is set to 
-- recognize an "X" adjustment with InDay = 9 as DT.
--
if @HoursType = 'DT' 
Begin
  Select @CountAsOT = '1'
  Select @InDay = 9
end

if LEN(@FileNo) < 4 
BEGIN
  Set @FileNo = right('0000' + @FileNo, 4 )
END

-- Get the Employee information.
-- for this fileno.
--
Select Top 1 @SSN = SSN, @AgencyNo = AgencyNo, @DivisionID = DivisionID, 
       @PrimaryDept = isNULL(PrimaryDept,0),
       @PayType = isnull(PayType, 0 ),
       @enStatus = Status
from TimeCurrent.dbo.tblEmplnames 
where Client = @Client and GroupCode = @GroupCode and FileNo = @FileNo 

if @SSN is NULL
Begin
  --Send Notification
  --
  Set @strMsg = 'Employee does not exist in PeopleNet.' 
  Select RetMessage = @strMsg, SSN = 0
  Return
End
Else
Begin
  IF @enStatus = '9'
  Begin
    --Send Notification
    --
    Set @strMsg = 'Employee is not active in PeopleNet.' 
    Select RetMessage = @strMsg, SSN = 0
    Return
  End
  -- If Department number is zero then default to primary department.
  -- If Primary Department is 0 then error out.
  if @DeptNo = 0
  BEGIN
    IF @PrimaryDept = 0
    BEGIN
      Set @strMsg = 'Employee does not have a primary department set.' 
      Select RetMessage = @strMsg, SSN = @SSN
      Return
    END
    ELSE
    BEGIN
      Set @DeptNo = @PrimaryDept
    END
  END

  --If the paytype = 1 ( Salary ) and the hours are OT or DT then
  --Skip the insert. Salary Employees can only get Reg or Non-worked time.
  --
  IF @PayType = 1
  BEGIN
    IF @HoursType in('OT','DT')
    BEGIN
      -- Don't post the transaction, but post the comments.
      --
      if LEN(@Comments) > 0 
      BEGIN
        Set @Comments1 = 'ID:' + ltrim(str(@JobID)) + '  : ' + @Comments
        -- Insert comments for this SSN for this PPED.
        INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
        VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Comments1, @UserID, @Email, '0')
      END
  
      Set @strMsg = 'Salary Employee cannot have OT or DT. OT/DT Transaction not posted.' 
      Select RetMessage = @strMsg, SSN = @SSN
      Return
    END
  END
  -- Insert the detail for this employee.
  -- If the paytype is 1 ( Salary ) then only insert non-worked time.
  -- Recalc will insert the worked time ( generate the salary records )
  --
  if @PayType = 1 AND @Adjcode = 'X' 
    GOTO SkipInsert

  INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]
  ([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], 
  [DeptNo], [TransDate], [ShiftNo], [InDay], [InTime], 
  [OutDay], [OutTime], [Hours], [xAdjHours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], 
  [TransType], [AgencyNo], [InSrc], [CountAsOT], [UserCode], [AprvlStatus_UserID], [JobID], [DivisionID])
  VALUES(@Client, @GroupCode, @SSN, @PPED, @PPED, @SiteNo, @DeptNo, @PPED, 1, @InDay, '12-30-1899 12:00:00', 
  7, '12-30-1899 12:00:00', @Hours,  @Hours, @Dollars, @AdjCode, @AdjCode, @AdjName, 
  100, @AgencyNo, '3',  @CountAsOT, 'XLS', @UserID, @JobID, @DivisionID )

SkipInsert:
  if LEN(@Comments) > 0 
  BEGIN
    Set @Comments1 = 'ID:' + ltrim(str(@JobID)) + '  : ' + @Comments

    -- Insert comments for this SSN for this PPED.
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
    VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Comments1, @UserID, @Email, '0')
  END

  Select RetMessage = '', SSN = @SSN

End







