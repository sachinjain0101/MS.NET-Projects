CREATE           Procedure [dbo].[usp_APP_XLSImport_Adjustment_Insert_THD]
(
  @Client char(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int,
  @SiteNo int,
  @DeptNo int,
  @Adjcode varchar(3),  --< Srinsoft 08/06/2015 Changed @Adjcode char(1) to varchar(3) for Clockadjustmentno >--
  @AdjName varchar(20),
  @Hours numeric(5,2),
  @Dollars numeric(7,2),
  @TransDate datetime,
  @MPD datetime,
  @UserCode varchar(10) = null,
  @ResultSetFlag char(1) = 'Y',
  @ForceInsertFlag char(1) = 'N',
  @SuppressAdjustment CHAR(1) = 'N',
  @AllowDupes CHAR(1) = '0'
)
AS

--*/
/*
--EXEC usp_APP_XLSImport_Adjustment_Insert_THD 'FOUN',360000,'6/2/02',449213269,3,15,'4','HOLIDAY',8,0, '05/27/2002', '06/02/2002'
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
DECLARE  @TransDate datetime
DECLARE  @MPD datetime

SELECT  @Client = 'FOUN'
SELECT  @GroupCode = 360200
SELECT  @PPED  = '6/02/02'
SELECT  @SSN = 575673542
SELECT  @SiteNo = 23
SELECT  @DeptNo = 15
SELECT  @Adjcode = '4'
SELECT  @AdjName = 'HOLIDAY'
SELECT  @Hours = 7.20
SELECT  @Dollars = 0.00
SELECT  @TransDate = '5/27/02'
SELECT  @MPD = '6/9/02'
--575673542	ALATORRE	LEONOR	23	15	05/27/02	4	 7.50 
*/

Set NOCOUNT ON

DECLARE @CountAsOT char(1)
DECLARE @DupID BIGINT  --< @DupId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
DECLARE @Message varchar(300)
--Set the default values.
DECLARE @InDay tinyint 
DECLARE @InTime datetime 
DECLARE @OutDay tinyint 
DECLARE @OutTime datetime 
DECLARE @InSrc char(1) 
DECLARE @OutSrc char(1) 
DECLARE @EmpStatus tinyint 
DECLARE @BillRate numeric(7,2) 
DECLARE @PayRate numeric(7,2) 
DECLARE @BillOTRate numeric(7,2) 
DECLARE @BillOTRateOverride numeric(7,2) 
DECLARE @TransType tinyint 
DECLARE @ShiftNo tinyint 
DECLARE @HandledByImporter char(1) 
DECLARE @DaylightSavTime char(1) 
DECLARE @Holiday char(1) 
DECLARE @AgencyNo smallint 
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
DECLARE @SaveError int
DECLARE @UC varchar(10)
DECLARE @PrimarySite int
DECLARE @PrimaryDept int

SELECT @BillOTRate = 0.00
SELECT @BillOTRateOverride = 0.00
SELECT @InDay = datepart(weekday, @TransDate)
SELECT @InTime = '12/30/1899 00:00:00'
SELECT @OutDay = @InDay
SELECT @OutTime = '12/30/1899 00:00:00'
SELECT @InSrc = '3'
SELECT @OutSrc = '3'
SELECT @TransType = 0
SELECT @ShiftNo = 1
SELECT @HandledByImporter = 'V'
SELECT @DaylightSavTime = '0'  --Need to determine this on the fly.
SELECT @Holiday = '0'          --Need to determine what this is and how to determine it.
Select @CountAsOT = '0'
Select @Message = ''

if @UserCode is NULL
	SELECT @UC = 'XLS'
else
	SELECT @UC = @UserCode

-- Determine if the SSN exist for this Client/Groupcode 
Select @RecordID = RecordID, 
       @PrimarySite = isNULL(PrimarySite,0), 
       @PrimaryDept = isnull(PrimaryDept,0) 
from TimeCurrent..tblEmplNames 
  where client = @Client 
    and Groupcode = @Groupcode 
    and SSN = @SSN

if @RecordID is NULL
Begin

  Select @Message = 'SSN does not exist. Adjustment was not added.'
  goto ReturnError

End

IF @SiteNo = 0 
  Set @SiteNo = @PrimarySite

IF @DeptNo = 0
  Set @DeptNo = @PrimaryDept

IF len(@AdjName) > 10
  Set @AdjName = left(@AdjName,10)

IF @ForceInsertFlag = 'N'
BEGIN
  -- Determine if the SiteNo exist for this Client/Groupcode 
  Set @RecordID = (Select RecordID from TimeCurrent..tblSiteNames where client = @Client and Groupcode = @Groupcode and SiteNo = @SiteNo )
  if @RecordID is NULL
  Begin
  
    Select @Message = 'Invalid Site Number. Adjustment was not added.'
    goto ReturnError
  
  End
  
  -- Determine if the DeptNo exist for this Client/Groupcode/SiteNo 
  Set @RecordID = (Select RecordID from TimeCurrent..tblDeptNames where client = @Client and Groupcode = @Groupcode and SiteNo = @SiteNo and DeptNo = @DeptNo )
  if @RecordID is NULL
  Begin
  
    Select @Message = 'Invalid Department Number. Adjustment was not added.'
    goto ReturnError
  
  End
END

-- Check to make sure this is not a duplicate. 
Select @DupID = (Select max(RecordID) from [TimeHistory].[dbo].[tblTimeHistDetail] WITH (NOLOCK)
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

-- GambroPTORecalc may change HOL PTO to PTOHOLN (PTO HOLiday Newhire) so consider them equivalent
if @DupID is NULL and @AdjCode = '4' and @AdjName = 'HOL PTO'
begin
Select @DupID = (Select max(RecordID) from [TimeHistory].[dbo].[tblTimeHistDetail] WITH (NOLOCK)
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
                    and ClockAdjustmentNo = '{'
                    and AdjustmentName = 'PTOHOLN')
end

if @DupID is NOT NULL AND @AllowDupes = '0'
begin
  -- It is a duplicate so need to return an error message.
  Select @Message = 'Duplicate record. Transaction not added.'
  goto ReturnError
End

DECLARE curEmpInfo CURSOR FOR
SELECT en.Status, en.AgencyNo, ed.BillRate, ed.PayRate
From timeCurrent..tblEmplNames as en
Left Join timecurrent..tblEmplSites_Depts as ed on
    ed.Client = en.Client
    and ed.GroupCode = en.GroupCode
    and ed.DeptNo = @DeptNo
    and ed.SiteNo = @SiteNo
    and ed.SSN = en.SSN
    and ed.RecordStatus = 1
where en.Client = @Client
      and en.GroupCode = @GroupCode
      and en.SSN = @SSN
      and en.RecordStatus = 1

OPEN curEmpInfo
Fetch Next From curEmpInfo Into @EmpStatus, @AgencyNo, @BillRate, @PayRate

/*
if @@Fetch_Status = 0
  Begin

  End
Else
  Begin
  --Not Sute what to do here? maybe raise an error or something...
  End
*/
CLOSE CurEmpInfo
DEALLOCATE CurEmpInfo

if @AgencyNo is NULL 
  SELECT @AgencyNo = 0      

if @EmpStatus is NULL
  Select @EmpStatus = '1'

if @BillRate is NULL
  Select @BillRate = 0.00

if @PayRate is NULL
  Select @PayRate = 0.00


BEGIN TRANSACTION
  -- Insert the detail for this employee.

  Insert into [TimeHistory].[dbo].[tblTimeHistDetail]
  (Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID, 
  TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, 
  InTime, OutDay, OutTime, Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, 
  AdjustmentCode, AdjustmentName, DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, ActualInTime )
  Values
  (@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, @DeptNo, 0, 
  convert(char(10), @TransDate,101), @EmpStatus, @BillRate, @BillOTRate, @BillOTRateOverride, @PayRate, @ShiftNo, @InDay, 
  @InTime, @OutDay, @OutTime, @Hours, @Dollars, @TransType, @AgencyNo, @InSrc, @OutSrc, @AdjCode, 
  '', @AdjName, @DaylightSavTime, @Holiday, @HandledByImporter, 9800, @UC, case when @Client = 'DAVT' and @AdjCode in('N','6') then getdate() else NULL end)

  if @@Error <> 0 
  begin
    Set @SaveError = @@Error
    goto RollBackTransaction
  end  
  Set @RecordID = SCOPE_IDENTITY()

	IF @Hours <> 0.00
	BEGIN
	  IF @SuppressAdjustment = 'Y'
	  BEGIN
          INSERT INTO TimeHistory..tblTimeHistDetail_Comments
                  ( Client ,
                    GroupCode ,
                    PayrollPeriodEndDate ,
                    SSN ,
                    CreateDate ,
                    Comments ,
                    UserID ,
                    UserName ,
                    ManuallyAdded
                  )
          VALUES  ( @Client ,
                    @GroupCode ,
                    @PPED , 
                    @SSN , 
                    GETDATE() , 
                    '' + @Adjname + '' + ' system adjustment added for (' + CAST(@Hours AS VARCHAR) + ' Hours on ' + datename(dw,@TransDate)  + ')' , -- Comments - text
                    0 , 
                    'SYS' , 
                    ''  
                  )
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
				@UC, AdjustmentName, 'H', 
				Case when InDay = 2 then Hours else 0 end,
				Case when InDay = 3 then Hours else 0 end,
				Case when InDay = 4 then Hours else 0 end,
				Case when InDay = 5 then Hours else 0 end,
				Case when InDay = 6 then Hours else 0 end,
				Case when InDay = 7 then Hours else 0 end,
				Case when InDay = 1 then Hours else 0 end,
				Case when InDay < 1 or InDay > 7 then Hours else 0 end,
				Hours, AgencyNo, @UC,0,getdate(),null,null,null,null,'1','10.3.0.18',ShiftNo
		  from tblTimeHistdetail
		  where RecordID = @RecordID)
	  
		  if @@Error <> 0 
		  begin
			Set @SaveError = @@Error
			goto RollBackTransaction
		  end  
	  END
	END

COMMIT TRANSACTION

Set @Message = ''
--Return an empty string.
IF @ResultSetFlag = 'Y'
  Select @Message as RetMessage

return

RollBackTransaction:
Rollback Transaction

Select @Message = 'Error inserting record. Transaction not added.'

ReturnError:
Select @Message = @Client + ',' + ltrim(str(@GroupCode)) + ',' + ltrim(str(@SSN)) + ',' + ltrim(str(@SiteNo)) + ',' + ltrim(str(@DeptNo)) + ',' + ltrim(str(@SiteNo)) + ',' +
                  @AdjCode + ',' + @AdjName + ',' + cast(@Hours as varchar(8)) + ',' + convert(char(10),@TransDate, 101) + ',' + @Message

IF @ResultSetFlag = 'Y'
  Select @Message as RetMessage
--Else
  --PRINT @Message

return









