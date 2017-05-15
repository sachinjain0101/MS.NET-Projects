CREATE     Procedure [dbo].[usp_APP_ShiftDiff_AddSplitRec]
( 
  @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
  @Client char(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int,
  @InDay int,
  @OutDay int,
  @InSrc char(1),
  @OutSrc char(1),
  @InTime datetime,
  @OutTime datetime,
  @Changed_InPunch char(1),
  @Changed_OutPunch char(1),
  @TransDate datetime,
  @NewInTime datetime,
  @NewOutTime datetime,
  @NewShiftNo int,
  @ShiftDiffAmt numeric(5,2),
  @MinHours numeric(5,2),
  @UpdateFlag int
)
AS

--*/

/*
-- DEBUG SECTION
Declare @Client char(4)
Declare @GroupCode int
Declare @PPED datetime
Declare @SSN int

Select @Client = 'LIFE'
Select @GroupCode = 3
Select @PPED = '10/19/2002'
Select @SSN = 999991111
*/
DECLARE @NewInDay int
DECLARE @NewOutDay int
DECLARE @TotHrs numeric(7,2)
DECLARE @NewInSrc char(1)
DECLARE @NewChanged_InPunch char(1)
DECLARE @NewOutSrc char(1)
DECLARE @NewChanged_OutPunch char(1)
DECLARE @intMinutes int
DECLARE @NewHours numeric(5,2)
DECLARE @CalcShiftDiff char(1)
DECLARE @ShiftDiffNo      int
DECLARE @NewInUserCode        varchar(5)
DECLARE @NewOutUserCode       varchar(5)
DECLARE @thdInTime datetime
DECLARE @thdOutTime datetime


SET NOCOUNT ON

Set @CalcShiftDiff = '1'

IF @Client in('GAMB','CROW')
BEGIN
  SELECT @CalcShiftDiff = EN.ShiftDiffClass
  FROM TimeCurrent.dbo.tblEmplNames as EN
  WHERE EN.Client = @Client 
    AND EN.GroupCode = @GroupCode  
    AND EN.SSN = @SSN       
  
  If @CalcShiftDiff is NULL
    Set @CalcShiftDiff = '0'
END

if @Client = 'GAMB' 
BEGIN
  IF @GroupCode = 720200 
  BEGIN
    Set @CalcShiftDiff = '1'
  END
  ELSE
  BEGIN
    if @NewShiftNo = 2
    BEGIN
      Set @CalcShiftDiff = '1'
      Set @NewShiftNo = 1
    END
    ELSE
    BEGIN
      Set @CalcShiftDiff = '0'
      Set @NewShiftNo = 1
    END
  END
END

SET @ShiftDiffNo = @NewShiftNo

--Determine InDay for this segment of the split
If DatePart(weekday, @NewInTime) = DatePart(weekday, @InTime)
Begin
  SET @NewInDay = @InDay
End
Else
Begin
  SET @NewInDay = @OutDay
End
    
-- If in time has changed, In Source becomes PNE & Changed_InPunch is set to false
If @NewInTime = @InTime
BEGIN
    SET @NewInSrc = @Insrc
    SET @NewChanged_InPunch = @Changed_InPunch
    SET @NewInUserCode = (SELECT UserCode FROM Timehistory.dbo.tblTimeHistDetail WHERE RecordID = @RecordID)
END
Else
BEGIN
    SET @NewInSrc = '3'
    SET @NewChanged_InPunch = '0'
    SET @NewInUserCode = ''
END

--Determine OutDay for this segment of the split
If DatePart(weekday, @NewOutTime) = DatePart(weekday, @OutTime)
BEGIN
  SET @NewOutDay = @OutDay
END
ELSE
BEGIN
  SET @NewOutDay = @InDay
END

--If out time has changed, Out Source becomes PNE & Changed_OutPunch is set to false
If @NewOutTime = @OutTime
BEGIN
    SET @NewOutSrc = @OutSrc
    SET @NewChanged_OutPunch = @Changed_OutPunch
    SET @NewOutUserCode = (SELECT OutUserCode FROM Timehistory.dbo.tblTimeHistDetail WHERE RecordID = @RecordID)
END
ELSE
BEGIN
    SET @NewOutSrc = '3'
    SET @NewChanged_OutPunch = '0'
    SET @NewOutUserCode = ''
END

--Calculate hours
SET @intMinutes = DateDiff(minute, @NewInTime, @NewOutTime)
SET @NewHours = Round( (@intMinutes / 60.0), 2)

-- Should we update the original Record or insert a new split record.

SET @thdInTime  = '12/30/1899 ' + convert(varchar(8),@NewInTime,108)
SET @thdOutTime = '12/30/1899 ' + convert(varchar(8),@NewOutTime,108)

DECLARE @SiteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 18Aug2016 >--
DECLARE @TimeOnDST datetime
DECLARE @TimeOffDST datetime
DECLARE @InPunch datetime
DECLARE @OutPunch Datetime
DECLARE @DaylightSavTime char(1)


Set @TimeOnDST = '3/8/' + str(datepart(yyyy, getdate()),4) + ' 02:00' 
IF (DATEPART(dw, @TimeOnDST) <> 1)
BEGIN
	SELECT @TimeOnDST = dateadd(dd, 7-DATEPART(dw, @TimeOnDST)+1, @TimeOnDST)
END


Set @TimeOffDST = '11/1/' + str(datepart(yyyy, getdate()),4)  + ' 02:00' 
IF (DATEPART(dw, @TimeOffDST) <> 1)
BEGIN
	SELECT @TimeOffDST = dateadd(dd, 7-DATEPART(dw, @TimeOffDST)+1, @TimeOffDST)
END


Set @InPunch = TimeHistory.dbo.PunchDateTime2(@TransDate, @NewInDay, @Newintime) 
Set @OutPunch = TimeHistory.dbo.PunchDateTime2(@TransDate, @NewOutDay, @NewOuttime) 

IF DATEADD(hh, -1, @TimeOffDST) between @InPunch and @OutPunch
BEGIN  
  Select @SiteNo = SiteNo,
         @DaylightSavTime = DaylightSavTime
  from TimeHistory..tblTimeHistDetail
  where RecordID = @RecordID
  EXEC [TimeHistory].[dbo].[usp_APP_GetDSTAdjustedHours2] @Client, @GroupCode, @SiteNo, @InPunch, @OutPunch, @TimeOnDST, @TimeOffDST, @DaylightSavTime, @NewHours OUTPUT 
END

IF @TimeOnDST between @InPunch and @OutPunch
BEGIN  
  Select @SiteNo = SiteNo,
         @DaylightSavTime = DaylightSavTime
  from TimeHistory..tblTimeHistDetail
  where RecordID = @RecordID
  EXEC [TimeHistory].[dbo].[usp_APP_GetDSTAdjustedHours2] @Client, @GroupCode, @SiteNo, @InPunch, @OutPunch, @TimeOnDST, @TimeOffDST, @DaylightSavTime, @NewHours OUTPUT 
END

if @UpdateFlag = 0
BEGIN
  -- Insert the new record based on new values and values from the original rec.
  INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail]([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [CountAsOT], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [Borrowed], [DivisionID], [ShiftDiffAmt], [UserCode], [OutUserCode], [ActualInTime], [ActualOutTime], [InSiteNo], [OutSiteNo], [InVerified], [OutVerified], [InClass], [OutClass], [InTimeStamp], [OutTimeStamp], [InRoundOFF], [OutRoundOFF], CostID)
  (SELECT [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], @NewShiftNo, @NewInDay, @thdInTime, @NewOutDay, @thdOutTIme, @NewHours, [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], @NewChanged_InPunch, @NewChanged_OutPunch, [AgencyNo], @NewInSrc, @NewOutSrc, [DaylightSavTime], [Holiday], [CountAsOT], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], (CASE @CalcShiftDiff WHEN 0 THEN ' ' ELSE substring(str(@ShiftDiffNo,3),3,1) END), [Borrowed], [DivisionID], (CASE @CalcShiftDiff WHEN 0 THEN 0.00 ELSE @ShiftDiffAmt END), @NewInUserCode, @NewOutUserCode,
    CASE WHEN @thdInTime = [InTime] THEN ActualInTime ELSE NULL END,
    CASE WHEN @thdOutTime = [OutTime] THEN ActualOutTime ELSE NULL END, 
    CASE WHEN @thdInTime = [InTime] THEN [InSiteNo] ELSE 0 END,
    CASE WHEN @thdOutTime = [OutTime] THEN [OutSiteNo] ELSE 0 END, 
    CASE WHEN @thdInTime = [InTime] THEN [InVerified] ELSE '0' END,
    CASE WHEN @thdOutTime = [OutTime] THEN [OutVerified] ELSE '0' END, 
    CASE WHEN @thdInTime = [InTime] THEN [InClass] ELSE '|' END,
    CASE WHEN @thdOutTime = [OutTime] THEN [OutClass] ELSE '|' END, 
    CASE WHEN @thdInTime = [InTime] THEN [InTimestamp] ELSE 0 END,
    CASE WHEN @thdOutTime = [OutTime] THEN [OutTimestamp] ELSE 0 END, 
    [InRoundOFF], [OutRoundOFF], CostID
    from Timehistory.dbo.tblTimeHistDetail where RecordID = @RecordID )

  SET @RecordID = SCOPE_IDENTITY()
  Select @RecordID as RecordID
END
ELSE
BEGIN
  -- Update Original
  Update Timehistory.dbo.tblTimeHistDetail
      Set Inday = @NewInDay,
          OutDay = @NewOutDay,
          InSrc = @NewInSrc,
          OutSrc = @NewOutSrc,
          InTime = '12/30/1899 ' + convert(varchar(8),@NewInTime,108),
          OutTime = '12/30/1899 ' + convert(varchar(8),@NewOutTime,108),
          ActualIntime = CASE WHEN @thdInTime = [InTime] THEN ActualInTime ELSE NULL END,
          ActualOutTime = CASE WHEN @thdOutTime = [OutTime] THEN ActualOutTime ELSE NULL END, 
          UserCode = @NewInUserCode,
          OutUserCode = @NewOutUserCode,
          Changed_InPunch = @NewChanged_InPunch,
          Changed_OutPunch = @NewChanged_OutPunch,
          ShiftDiffClass = (CASE @CalcShiftDiff WHEN '0' THEN ' ' ELSE substring(str(@ShiftDiffNo,3),3,1) END),
          ShiftDiffAmt = (CASE @CalcShiftDiff WHEN '0' THEN 0.00 ELSE @ShiftDiffAmt END),
          ShiftNo = @NewShiftNo,
          Hours = @NewHours,
          InSiteNo = CASE WHEN @thdInTime = [InTime] THEN [InSiteNo] ELSE 0 END,
          OutSiteNo = CASE WHEN @thdOutTime = [OutTime] THEN [OutSiteNo] ELSE 0 END, 
          InVerified = CASE WHEN @thdInTime = [InTime] THEN [InVerified] ELSE '0' END,
          OutVerified = CASE WHEN @thdOutTime = [OutTime] THEN [OutVerified] ELSE '0' END, 
          InClass = CASE WHEN @thdInTime = [InTime] THEN [InClass] ELSE '|' END,
          OutClass = CASE WHEN @thdOutTime = [OutTime] THEN [OutClass] ELSE '|' END, 
          InTimeStamp = CASE WHEN @thdInTime = [InTime] THEN [InTimestamp] ELSE 0 END,
          OutTimeStamp = CASE WHEN @thdOutTime = [OutTime] THEN [OutTimestamp] ELSE 0 END 
  Where RecordID = @RecordID

END







