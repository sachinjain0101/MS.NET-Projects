CREATE   Procedure [dbo].[usp_APP_XLSImport_GAMB_Insert_THD]
(
  @Client char(4),
  @GroupCode int,
  @PPED datetime,
  @MPD datetime,
  @SSN int,
  @SiteNo int,
  @DeptNo int,
  @Adjcode char(1),
  @AdjName varchar(20),
  @Hours numeric(5,2),
  @Dollars numeric(7,2),
  @DOW tinyint
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
DECLARE  @DOW tinyint

SELECT  @Client = 'GAMB'
SELECT  @GroupCode = 405000
SELECT  @PPED  = '12/08/01'
SELECT  @SSN = 28328490
SELECT  @SiteNo = 5053
SELECT  @DeptNo = 65
SELECT  @Adjcode = 'V'
SELECT  @AdjName = 'ACUTUNS'
SELECT  @Hours = 0.34
SELECT  @Dollars = 0.00
SELECT  @DOW = 4

--select * from tblTimeHistDetail where recordid = 85311163
--Client = 'GAMB' and Groupcode = 405000 --and SSN = 304749241
--and payrollperiodenddate = '12/08/01'
*/

Set NOCOUNT ON

DECLARE @AgencyNo int
DECLARE @CountAsOT char(1)
DECLARE @InDay tinyint 
DECLARE @TransDate datetime 
DECLARE @DupID BIGINT  --< @DupId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
DECLARE @Message varchar(128)
DECLARE @PPED_DOW int
DECLARE @SaveError int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
DECLARE @AdjType char(1)


Select @CountAsOT = '0'
Select @InDay = @DOW
Select @PPED_DOW = datepart(weekday,@PPED)
if @InDay > @PPED_DOW
BEGIN
  Select @TransDate = dateadd(day, -7 + (@Inday - @PPED_DOW), @PPED)
END
ELSE
BEGIN
  Select @TransDate = dateadd(day, (@Inday - @PPED_DOW), @PPED)
END

IF @Hours <> 0.00 
  Set @AdjType = 'H'
ELSE
  Set @AdjType = 'D'

Select @Message = ''

-- Get the agency No for this Employee
Select @AgencyNo = (Select AgencyNo from TimeCurrent..tblEmplnames where Client = @Client and groupCode = @GroupCode and SSN = @SSN )

-- Check to make sure this is not a duplicate. 
Select @DupID = (Select RecordID from [TimeHistory].[dbo].[tblTimeHistDetail]
                  Where Client = @Client
                    and GroupCode = @GroupCode
                    and SSN = @SSN
                    and SiteNo = @SiteNo
                    and DeptNo = @DeptNo
                    and Payrollperiodenddate = @PPED
                    and Transdate = @TransDate
                    and Inday = @InDay
                    and Hours = @Hours
                    and Dollars = @Dollars
                    and ClockAdjustmentNo = @AdjCode
                    and AdjustmentName = @AdjName)

if @DupID is NOT NULL
begin

  -- It is a duplicate so need to return an error message.
  Select @Message = 'Duplicate record detected for SSN ' + ltrim(str(@SSN)) + ' on ' 
    + convert(char(10),@TransDate, 101) + ' with code ' 
    + @AdjCode + '-' + @AdjName + ' for ' 
    + cast(@Hours as varchar(8)) + ' Hours and '
    + cast(@Dollars as varchar(12)) + ' dollars.'

  Select @Message as RetMessage

End
else
begin

  BEGIN TRANSACTION
    -- Insert the detail for this employee.
  
    INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]
    ([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], 
    [DeptNo], [TransDate], [ShiftNo], [InDay], [InTime], 
    [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], 
    [TransType], [AgencyNo], [InSrc], [CountAsOT], [JobID], [UserCode], [HandledByImporter] )
    VALUES(@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, 
    @DeptNo, @TransDate, 1, @InDay, '12-30-1899 00:00:00', 
    @InDay, '12-30-1899 00:00:00', @Hours, @Dollars, @AdjCode, @AdjCode, @AdjName, 
    0, @AgencyNo, '3',  @CountAsOT, 0, 'XLS', 'V' )

    if @@Error <> 0 
    begin
      Set @SaveError = @@Error
      goto RollBackTransaction
    end  
    Set @RecordID = SCOPE_IDENTITY()

    if @AdjType = 'H'
    BEGIN
      -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
      -- so it will get sent back to the time clock.
      INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
            [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
            [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
            [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
            [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
            [RecordStatus], [IPAddr], [ShiftNo])
      (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
            'XLS', AdjustmentName, @AdjType, 
            Case when InDay = 2 then Hours else 0 end,
            Case when InDay = 3 then Hours else 0 end,
            Case when InDay = 4 then Hours else 0 end,
            Case when InDay = 5 then Hours else 0 end,
            Case when InDay = 6 then Hours else 0 end,
            Case when InDay = 7 then Hours else 0 end,
            Case when InDay = 1 then Hours else 0 end,
            Case when InDay < 1 or InDay > 7 then Hours else 0 end,
            Hours, AgencyNo, 'XLS',0,getdate(),null,null,0,null,'1','10.3.0.18',ShiftNo
      from tblTimeHistdetail
      where RecordID = @RecordID)
    END
    ELSE
    BEGIN
      -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
      -- so it will get sent back to the time clock.
      INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
            [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
            [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
            [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
            [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
            [RecordStatus], [IPAddr], [ShiftNo])
      (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
            'XLS', AdjustmentName, @AdjType, 
            Case when InDay = 2 then Dollars else 0 end,
            Case when InDay = 3 then Dollars else 0 end,
            Case when InDay = 4 then Dollars else 0 end,
            Case when InDay = 5 then Dollars else 0 end,
            Case when InDay = 6 then Dollars else 0 end,
            Case when InDay = 7 then Dollars else 0 end,
            Case when InDay = 1 then Dollars else 0 end,
            Case when InDay < 1 or InDay > 7 then Dollars else 0 end,
            Dollars, AgencyNo, 'XLS',0,getdate(),null,null,null,null,'1','10.3.0.18',ShiftNo
      from tblTimeHistdetail
      where RecordID = @RecordID)
    END
    if @@Error <> 0 
    begin
      Set @SaveError = @@Error
      goto RollBackTransaction
    end  

  COMMIT TRANSACTION

  --Return an empty string.
  Select @Message as RetMessage

end

return

RollBackTransaction:
Rollback Transaction

Select @Message = 'Error inserting record for SSN ' + ltrim(str(@SSN)) + ' on ' 
  + convert(char(10),@TransDate, 101) + ' with code ' 
  + @AdjCode + '-' + @AdjName + ' for ' 
  + cast(@Hours as varchar(8)) + ' Hours and '
  + cast(@Dollars as varchar(12)) + ' dollars.'

Select @Message as RetMessage





