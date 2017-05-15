Create PROCEDURE [dbo].[usp_PLite_FixPunchPost]
  (
     @Client char(4),
     @GroupCode int,
     @SSN int,
     @SiteNo int,
     @PPED datetime,
     @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
     @InTime char(5),
     @OutTime char(5),
     @InDay char(1),
     @OutDay char(1),
     @TransDate Datetime,
     @PunchType char(3),
     @UserID int
  )
AS
--*/
/*
--Testing /Debugging
Declare @Client char(4)
Declare @GroupCode int
Declare @SSN int
Declare @SiteNo int
Declare @PPED datetime
Declare @RecordID int
Declare @InTime char(5)
Declare @OutTime char(5)
Declare @InDay char(1)
Declare @OutDay char(1)
Declare @TransDate datetime
Declare @PunchType char(3)
Declare @UserID int

--
--select * from timehistory..tblTimeHistdetail where RecordID = 78323453
--select * from timecurrent..tblFixedPunch where OrigRecordID = 78323453
--delete from timecurrent..tblFixedPunch where OrigRecordID = 78323453
--

select @Client = 'DAVI'
select @GroupCode = 300100
select @SSN = 371723636
select @SiteNo = 156
select @PPED = '10/06/01'
select @RecordID = 78323453
select @InTime = '08:10'
select @OutTime = '18:32'
select @InDay = '6'
select @OutDay = '6'
select @TransDate = '10/05/2001'
select @PunchType = 'IN'
select @UserID = 1209

*/

Declare @IpAddr varchar(20)
Declare @emplNames_Status char(1)
Declare @fpExist BIGINT  --< @fpExists data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
Declare @thdExist BIGINT  --< @thdExists data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
DECLARE @FPGenBreak char(1)
DECLARE @savError int
Declare @fpRecordID int
Declare @InTrans char(1)
Declare @UserCode char(3)
Declare @UserName varchar(20)
Declare @Count int

Select @InTrans = '0'
Select @IPAddr = 'EpicSvc'
Select @savError = 0

-- See if the Client/Group has FixPunchgenBreak ON/OFF
Select @FPGenBreak = (SELECT FixPunchGensBreak FROM TimeCurrent..tblClientGroups where client = @Client and groupcode = @GroupCode)

-- Check to make sure the record we are working with has not been deleted by a re-calc or some other
-- function
Select @thdExist = (select recordid from TimeHistory..tblTimeHistdetail where RecordID = @RecordID )

-- Get the Employee Status from the employee table, used in the insert to table fixed punch
Select @emplNames_Status = (Select Top 1 Status from TimeCurrent..tblEmplNames where Client = @client and GroupCode = @GroupCode and SSN = @SSN )

--Get User Information from the UserID Passed
Select @UserCode = (Select UserCode from timecurrent..tblUser where userid = @UserID)
Select @UserName = (Select LogonName from timecurrent..tblUser where userid = @UserID)

-- If the thd record exists then move ahead.
IF @thdExist is not Null
BEGIN
  -- Look for a record in tblFixedPunch because a department change could have occurred.
  -- 
  Select @fpExist = (Select OrigRecordID from timecurrent..tblFixedPunch where OrigRecordID = @RecordID )


	--Calculate the hours column based on the new in/out times.
  Declare @InDate datetime
  Declare @OutDate DateTime
  DECLARE @tmpHours numeric(5,2)
  DECLARE @tmpMinutes int

  SELECT @InDate = '12/30/1899 ' + @InTime
  SELECT @OutDate = '12/30/1899 ' + @OutTime
  SELECT @tmpMinutes = datediff(minute, @InDate, @OutDate)
  SELECT @tmpHours = @tmpMinutes / 60.00

  --Updating the timecard
  Begin Transaction
    Select @InTrans = '1'    --Indicate we are in a transaction
    if @fpExist is null
    begin
      -- Data needs to come from tblTimeHistDetail.
      --
      INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch]([OrigRecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], 
                [OldSiteNo], [OldDeptNo], [OldJobID], [OldTransDate], [OldEmpStatus], [OldBillRate], [OldBillOTRate], [OldBillOTRateOverride], 
                [OldPayRate], [OldShiftNo], [OldInDay], [OldInTime], [OldInSrc], [OldOutDay], [OldOutTime], [OldOutSrc], [OldHours], 
                [OldDollars], [OldClockAdjustmentNo], [OldAdjustmentCode], [OldAdjustmentName], [OldTransType], 
                [OldAgencyNo], [OldDaylightSavTime], [OldHoliday], 
                [NewSiteNo], [NewDeptNo], [NewJobID], [NewTransDate], [NewEmpStatus], [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], 
                [NewPayRate], [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], [NewOutDay], [NewOutTime], [NewOutSrc], [NewHours], 
                [NewDollars], [NewClockAdjustmentNo], [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], 
                [NewAgencyNo], [NewDaylightSavTime], [NewHoliday], 
                [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr])
        (SELECT [RecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], 
                [SiteNo], [DeptNo], [JobID], [TransDate], @emplNames_Status, [BillRate], [BillOTRate], [BillOTRateOverride], 
                [PayRate], [ShiftNo], [InDay], [InTime], [Insrc], [OutDay], [OutTime], [OutSrc], [Hours], 
                [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], 
                [AgencyNo], [DaylightSavTime], [Holiday], 
                [SiteNo], [DeptNo], [JobID], @TransDate, [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], 
                [PayRate], [ShiftNo], @InDay, @InDate, [Insrc], @OutDay, @OutTime, [OutSrc], @tmpHours, 
                [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], 
                [AgencyNo], [DaylightSavTime], [Holiday], 
                @UserName, @UserID, getdate(), getdate(), @IPAddr           
            FROM [TimeHistory].[dbo].[tblTimeHistDetail]
           WHERE RecordID = @RecordID)

      if @@Error <> 0 
      Begin
        Select @savError = @@Error
        goto ErrHandler
      End

      -- Get the Record ID of the Fixed punch we just inserted.
      -- We need it to correctly update the Insrc or Outsrc, see below.
      Select @fpRecordID = SCOPE_IDENTITY()

      -- Update the Time Hist detail information.
      Update timehistory..tblTimeHistdetail 
            Set UserCode = @UserCode,
                InDay = @InDay, OutDay = @OutDay, InTime = @InDate, OutTime = @OutDate,
                Hours = @tmpHours --,
                --TransDate = @TransDate
            where RecordID = @RecordID
  
      if @@Error <> 0 
      Begin
        Select @savError = @@Error
        goto ErrHandler
      End
	
      if @TransDate IS NULL
      Begin
        Update timehistory..tblTimeHistdetail Set TransDate = @TransDate where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
	
	Update timecurrent..tblFixedPunch Set NewTransDate = @TransDate where RecordID = @fpRecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End 	

      if @FPGenBreak = '1'
      Begin
        Update timehistory..tblTimeHistdetail Set ShiftNo = 0 where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End    
  
      if @PunchType = 'IN'
      Begin
        Update timehistory..tblTimeHistdetail Set Changed_InPunch = '1', InSrc = '3' where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End

        Update timecurrent..tblFixedPunch Set NewInSrc = '3' where RecordID = @fpRecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End 
  
      if @PunchType = 'OUT'
      Begin
        Update timehistory..tblTimeHistdetail Set Changed_OutPunch = '1', OutSrc = '3' where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End

        Update timecurrent..tblFixedPunch Set NewOutSrc = '3' where RecordID = @fpRecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End 

  END
  ELSE
  BEGIN
      -- Use data from tblFixedPunch to get old values.
      -- and data from tblTimeHistDetail to get the new values.
      --
      INSERT INTO [TimeCurrent].[dbo].[tblFixedPunch](
                [OrigRecordID], [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], 
                [OldSiteNo], [OldDeptNo], [OldJobID], [OldTransDate], [OldEmpStatus], [OldBillRate], [OldBillOTRate], [OldBillOTRateOverride], 
                [OldPayRate], [OldShiftNo], [OldInDay], [OldInTime], [OldInSrc], [OldOutDay], [OldOutTime], [OldOutSrc], [OldHours], 
                [OldDollars], [OldClockAdjustmentNo], [OldAdjustmentCode], [OldAdjustmentName], [OldTransType], 
                [OldAgencyNo], [OldDaylightSavTime], [OldHoliday], 
                [NewSiteNo], [NewDeptNo], [NewJobID], [NewTransDate], [NewEmpStatus], [NewBillRate], [NewBillOTRate], [NewBillOTRateOverride], 
                [NewPayRate], [NewShiftNo], [NewInDay], [NewInTime], [NewInSrc], [NewOutDay], [NewOutTime], [NewOutSrc], [NewHours], 
                [NewDollars], [NewClockAdjustmentNo], [NewAdjustmentCode], [NewAdjustmentName], [NewTransType], 
                [NewAgencyNo], [NewDaylightSavTime], [NewHoliday], 
                [UserName], [UserID], [TransDateTime], [SweptDateTime], [IPAddr])
        (SELECT fp.[OrigRecordID], fp.[Client], fp.[GroupCode], fp.[SSN], fp.[PayrollPeriodEndDate], fp.[MasterPayrollDate], 
                fp.[OldSiteNo], fp.[OldDeptNo], fp.[OldJobID], fp.[OldTransDate], fp.[OldEmpStatus], fp.[OldBillRate], fp.[OldBillOTRate], fp.[OldBillOTRateOverride], 
                fp.[OldPayRate], fp.[OldShiftNo], fp.[OldInDay], fp.[OldInTime], fp.[OldInSrc], fp.[OldOutDay], fp.[OldOutTime], fp.[OldOutSrc], fp.[OldHours], 
                fp.[OldDollars], fp.[OldClockAdjustmentNo], fp.[OldAdjustmentCode], fp.[OldAdjustmentName], fp.[OldTransType], 
                fp.[OldAgencyNo], fp.[OldDaylightSavTime], fp.[OldHoliday], 
                thd.[SiteNo], thd.[DeptNo], thd.[JobID], @TransDate, thd.[EmpStatus], thd.[BillRate], thd.[BillOTRate], thd.[BillOTRateOverride], 
                thd.[PayRate], thd.[ShiftNo], @InDay, @InDate, thd.[Insrc], @OutDay, @OutTime, thd.[OutSrc], @tmpHours, 
                thd.[Dollars], thd.[ClockAdjustmentNo], thd.[AdjustmentCode], thd.[AdjustmentName], thd.[TransType], 
                thd.[AgencyNo], thd.[DaylightSavTime], thd.[Holiday], 
                @UserName, @UserID, getdate(), getdate(), @IPAddr 
           FROM [TimeCurrent].[dbo].[tblFixedPunch] as fp
           Left Join timehistory..tblTimeHistDetail as thd
             on thd.RecordID = @RecordID 
           WHERE FP.OrigRecordID = @RecordID)

      if @@Error <> 0 
      Begin
        Select @savError = @@Error
        goto ErrHandler
      End

      -- Get the Record ID of the Fixed punch we just inserted.
      -- We need it to correctly update the Insrc or Outsrc, see below.
      Select @fpRecordID = SCOPE_IDENTITY()

      -- Update the Time Hist detail information.
      Update timehistory..tblTimeHistdetail 
            Set UserCode = @UserCode,
                InDay = @InDay, OutDay = @OutDay, InTime = @InDate, OutTime = @OutDate,
                Hours = @tmpHours --,
                --TransDate = @TransDate
            where RecordID = @RecordID
      if @@Error <> 0 
      Begin
        Select @savError = @@Error
        goto ErrHandler
      End

      if @TransDate IS NULL
      Begin
        Update timehistory..tblTimeHistdetail Set TransDate = @TransDate where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End

	Update timecurrent..tblFixedPunch Set NewTransDate = @TransDate where RecordID = @fpRecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End 	

      if @FPGenBreak = '1'
      Begin
        Update timehistory..tblTimeHistdetail Set ShiftNo = 0 where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End    
  
      if @PunchType = 'IN'
      Begin
        Update timehistory..tblTimeHistdetail Set Changed_InPunch = '1', InSrc = '3' where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
        Update timecurrent..tblFixedPunch Set NewInSrc = '3' where RecordID = @fpRecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End 
  
      if @PunchType = 'OUT'
      Begin
        Update timehistory..tblTimeHistdetail Set Changed_OutPunch = '1', OutSrc = '3' where RecordID = @RecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
        Update timecurrent..tblFixedPunch Set NewOutSrc = '3' where RecordID = @fpRecordID
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
      End 
    END

    -- Check to see if the employee has any more missing punches.
    -- 
    Select @Count = (select sum(1) from timehistory..tblTimeHistDetail 
                      where Client = @Client
                        and GroupCode = @GroupCode
                        and PayrollperiodEndDate = @PPED
                        and SSN = @SSN
                        and ClockAdjustmentNo IN('',' ')
                        and (inDay = 10 or outDay = 10) )
    if @Count is NULL
    BEGIN
      Update timehistory..tblEmplNames Set MissingPunch = '0' 
                      where Client = @Client
                        and GroupCode = @GroupCode
                        and PayrollperiodEndDate = @PPED
                        and SSN = @SSN
        if @@Error <> 0 
        Begin
          Select @savError = @@Error
          goto ErrHandler
        End
    END
  COMMIT TRANSACTION

END

Return

ErrHandler:
  
  if @InTrans = '1'
    Rollback Transaction

RAISERROR(@savError,16,1)

Return




