Create PROCEDURE [dbo].[usp_PLite_ChngDeptPost]
  (
     @Client char(4),
     @GroupCode int,
     @SiteNo int,
     @PPED datetime,
     @SSN int,
     @NewDeptNo int,
     @OldDeptNo int,
     @ShiftNo int,
     @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
     @UserID int
  )
AS
--*/
/*
--Testing /Debugging
Declare @Client char(4)
Declare @GroupCode int
Declare @SiteNo int
Declare @PPED datetime
Declare @SSN int
Declare @NewDeptNo int
Declare @OldDeptNo int
Declare @ShiftNo int
Declare @RecordID int
Declare @UserID int

--
--select * from timehistory..tblTimeHistdetail where RecordID = 78323453
--select * from timecurrent..tblFixedPunch where OrigRecordID = 78323453
--delete from timecurrent..tblFixedPunch where OrigRecordID = 78323453
--

select @Client = ,
select @GroupCode = ,
select @SiteNo = ,
select @PPED = ,
select @SSN = ,
select @NewDeptNo = ,
select @OldDeptNo = ,
select @ShiftNo = ,
select @RecordID = ,
select @UserID = 

*/

Declare @IpAddr varchar(20)
Declare @emplNames_Status char(1)
Declare @ChkValidSiteDept int
Declare @fpExist BIGINT  --< @fpExist data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
Declare @thdExist BIGINT  --< @thdExist data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
DECLARE @savError int
Declare @ErrMsg varchar(128)
Declare @InTrans char(1)
Declare @UserCode char(3)
Declare @UserName varchar(20)
Declare @Count int

Select @InTrans = '0'
Select @IPAddr = 'EpicSvc'
Select @savError = 0


--Determine if Site/Dept combo is valid.  If not, then run through process 
--of assigning new department to employee
-------------------------------------------------------------------------------
SELECT @ChkValidSiteDept = (SELECT COUNT(*)
			    FROM tblEmplSites_Depts 
			    WHERE Client = @Client
		  	      and GroupCode = @GroupCode
		 	      and SSN = @SSN
		  	      and SiteNo = @SiteNo
		  	      and DeptNo = @NewDeptNo
		  	      and RecordStatus = '1')
	
	
IF @ChkValidSiteDept = '0'
BEGIN
  Begin Transaction
  
  EXEC TimeCurrent..usp_PLite_AddEmpSiteDept_In_TC_EmplSitesDept @Client, @GroupCode, @SSN, @SiteNo, @NewDeptNo
  if @@Error <> 0 
  Begin
    Select @ErrMsg = 'Failed to insert tc_SiteDept. ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + ltrim(str(@SSN)) + ',' + ltrim(str(@SiteNo)) + ',' + ltrim(str(@NewDeptNo))
    Select @savError = @@Error
    goto ErrSiteDept
  End
  EXEC TimeCurrent..usp_PLite_AddEmpSiteDept_In_TC_EmplNamesDepts @Client, @GroupCode, @SSN, @NewDeptNo
  if @@Error <> 0 
  Begin
    Select @ErrMsg = 'Failed to insert tc_EmplDept. ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + ltrim(str(@SSN)) + ',' + ltrim(str(@SiteNo)) + ',' + ltrim(str(@NewDeptNo))
    Select @savError = @@Error
    goto ErrSiteDept
  End
  EXEC usp_PLite_AddEmpSiteDept_In_TH_EmplSitesDept @Client, @GroupCode, @SSN, @PPED, @SiteNo, @NewDeptNo
  if @@Error <> 0 
  Begin
    Select @ErrMsg = 'Failed to insert th_SiteDept. ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + ltrim(str(@SSN)) + ',' + ltrim(str(@SiteNo)) + ',' + ltrim(str(@NewDeptNo)) + ',' + convert(char(10),@PPED,101)
    Select @savError = @@Error
    goto ErrSiteDept
  End
  EXEC usp_PLite_AddEmpSiteDept_In_TH_EmplNamesDepts  @Client, @GroupCode, @SSN, @PPED, @NewDeptNo
  if @@Error <> 0 
  Begin
    Select @ErrMsg = 'Failed to insert th_EmplDept. ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + ltrim(str(@SSN)) + ',' + ltrim(str(@SiteNo)) + ',' + ltrim(str(@NewDeptNo)) + ',' + convert(char(10),@PPED,101)
    Select @savError = @@Error
    goto ErrSiteDept
  End

  Commit Transaction
END
Goto NextStep
ErrSiteDept:
  Rollback Transaction
  Goto ErrHandler

NextStep:

Begin Transaction
Select @InTrans = '1'    --Indicate we are in a transaction

-- Check to make sure the record we are working with has not been deleted by a re-calc or some other
-- function
Select @thdExist = (select recordid from TimeHistory..tblTimeHistdetail where RecordID = @RecordID )

-- Get the Employee Status from the employee table, used in the insert to table fixed punch
Select @emplNames_Status = (Select Top 1 Status from TimeCurrent..tblEmplNames where Client = @client and GroupCode = @GroupCode and SSN = @SSN )


-- If the thd record exists then move ahead.
IF @thdExist is not Null
BEGIN
	Update tblTimeHistDetail
	SET deptno = @NewDeptNo,
	    changed_deptNo = '1',
	    ShiftNo = @ShiftNo
	WHERE recordID=@RecordID
	

	-- Look for a record in tblFixedPunch because a department change could have occurred.
	---------------------------------------------------------------------------------------------------
	Select @fpExist = (Select OrigRecordID from timecurrent..tblFixedPunch where OrigRecordID = @RecordID )

	IF @fpExist = '0'
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
                [SiteNo], @OldDeptNo, [JobID], [TransDate], @emplNames_Status, [BillRate], [BillOTRate], [BillOTRateOverride], 
                [PayRate], [ShiftNo], [InDay], [InTime], [Insrc], [OutDay], [OutTime], [OutSrc], [Hours], 
                [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], 
                [AgencyNo], [DaylightSavTime], [Holiday], 
                [SiteNo], @NewDeptNo, [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], 
                [PayRate], [ShiftNo], [InDay], [InTime], [Insrc], [OutDay], [OutTime], [OutSrc], [Hours], 
                [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], 
                [AgencyNo], [DaylightSavTime], [Holiday], 
                @UserName, @UserID, getdate(), getdate(), @IPAddr           
            FROM [TimeHistory].[dbo].[tblTimeHistDetail]
           WHERE RecordID = @RecordID)
	ELSE
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
                fp.[OldSiteNo], @OldDeptNo, fp.[OldJobID], fp.[OldTransDate], fp.[OldEmpStatus], fp.[OldBillRate], fp.[OldBillOTRate], fp.[OldBillOTRateOverride], 
                fp.[OldPayRate], fp.[OldShiftNo], fp.[OldInDay], fp.[OldInTime], fp.[OldInSrc], fp.[OldOutDay], fp.[OldOutTime], fp.[OldOutSrc], fp.[OldHours], 
                fp.[OldDollars], fp.[OldClockAdjustmentNo], fp.[OldAdjustmentCode], fp.[OldAdjustmentName], fp.[OldTransType], 
                fp.[OldAgencyNo], fp.[OldDaylightSavTime], fp.[OldHoliday], 
                thd.[SiteNo], @NewDeptNo, thd.[JobID], thd.[TransDate], thd.[EmpStatus], thd.[BillRate], thd.[BillOTRate], thd.[BillOTRateOverride], 
                thd.[PayRate], thd.[ShiftNo], thd.[InDay], thd.[InTime], thd.[Insrc], thd.[OutDay], thd.[OutTime], thd.[OutSrc], thd.[Hours], 
                thd.[Dollars], thd.[ClockAdjustmentNo], thd.[AdjustmentCode], thd.[AdjustmentName], thd.[TransType], 
                thd.[AgencyNo], thd.[DaylightSavTime], thd.[Holiday], 
                @UserName, @UserID, getdate(), getdate(), @IPAddr 
           FROM [TimeCurrent].[dbo].[tblFixedPunch] as fp
           Left Join timehistory..tblTimeHistDetail as thd
             on thd.RecordID = @RecordID 
           WHERE FP.OrigRecordID = @RecordID)

COMMIT TRANSACTION

END

Return

ErrHandler:
  
  if @InTrans = '1'
    Rollback Transaction

RAISERROR(@savError,16,1)

Return





