Create PROCEDURE [dbo].[usp_SplitTimeHistDetailRecord]
(
  @RecordID BIGINT,   --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--
  @NewInDay integer, 
  @NewInTime varchar(10), 
  @NewInSrc char(1),
  @NewOutDay integer, 
  @NewOutTime varchar(10), 
  @NewOutSrc char(1),
  @NewHours numeric(7,2),
  @NewChanged_InPunch char(1),
  @NewChanged_OutPunch char(1)
)
As

Declare @NewRecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 02Sept2016 >--

/*
INSERT INTO [Audit].[dbo].[tblSimpleAuditLog]
           ([DateTimeAdded]
           ,[LogSource]
           ,[LogID1]
           ,[LogID2]
           ,[LogID3]
           ,[LogID4]
           ,[LogID5]
           ,[LogMessage])
     VALUES
           (getdate()
           ,'usp_SplitTimeHistDetailRecord'
           ,ltrim(str(@RecordID))
           ,''
           ,''
           ,''
           ,''
           ,'')

*/

BEGIN TRY
	BEGIN TRANSACTION;

		-- Use InClass and OutClass to identify where the split was (out time or in time).
		-- If OutClass  = '|' (pipe) then the out time was split.
		-- If  InClass  = '|' (pipe) then the in time was split.
		--
		INSERT INTO TimeHistory..tblTimeHistDetail
		([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [RegHours], [OT_Hours], [DT_Hours], [RegDollars], [OT_Dollars], [DT_Dollars], [RegBillingDollars], [OTBillingDollars], [DTBillingDollars], [CountAsOT], [RegDollars4], [OT_Dollars4], [DT_Dollars4], [RegBillingDollars4], [OTBillingDollars4], [DTBillingDollars4], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [AllocatedRegHours], [AllocatedOT_Hours], [AllocatedDT_Hours], [Borrowed], [UserCode], [DivisionID], [CostID], [ShiftDiffAmt], [OutUserCode], [ActualInTime], [ActualOutTime], [InSiteNo], [OutSiteNo], [Inverified], [OutVerified], [InClass], [OutClass], [InTimeStamp], [OutTimeStamp], [InRoundOFF], [OutRoundOFF] )
		SELECT [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], 0, @NewInDay, CONVERT(DateTime, '12/30/1899 ' + @NewInTime), @NewOutDay, CONVERT(DateTime, '12/30/1899 ' + @NewOutTime),@NewHours, [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], @NewChanged_InPunch, @NewChanged_OutPunch, [AgencyNo], @NewInSrc, @NewOutSrc, [DaylightSavTime], [Holiday], [RegHours], [OT_Hours], [DT_Hours], [RegDollars], [OT_Dollars], [DT_Dollars], [RegBillingDollars], [OTBillingDollars], [DTBillingDollars], [CountAsOT], [RegDollars4], [OT_Dollars4], [DT_Dollars4], [RegBillingDollars4], [OTBillingDollars4], [DTBillingDollars4], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [AllocatedRegHours], [AllocatedOT_Hours], [AllocatedDT_Hours], [Borrowed], 
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewInTime) = InTime THEN [UserCode] ELSE '' END,
		[DivisionID], [CostID], [ShiftDiffAmt], 
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewOutTime) = OutTime THEN [OutUserCode] ELSE '' END,
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewInTime) = InTime THEN ActualInTime ELSE NULL END,
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewOutTime) = OutTime THEN ActualOutTime ELSE NULL END, 
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewInTime) = InTime THEN [InSiteNo] ELSE 0 END,
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewOutTime) = OutTime THEN [OutSiteNo] ELSE 0 END, 
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewInTime) = InTime THEN [InVerified] ELSE '0' END,
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewOutTime) = OutTime THEN [OutVerified] ELSE '0' END, 
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewInTime) = InTime THEN [InClass] ELSE '|' END,
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewOutTime) = OutTime THEN [OutClass] ELSE '|' END, 
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewInTime) = InTime THEN [InTimestamp] ELSE 0 END,
		CASE WHEN CONVERT(DateTime, '12/30/1899 ' + @NewOutTime) = OutTime THEN [OutTimestamp] ELSE 0 END, 
		[InRoundOFF], [OutRoundOFF] 
		FROM TimeHistory..tblTimehistDetail
		WHERE RecordID = @RecordID


		IF (XACT_STATE()) = 1
		BEGIN
			COMMIT TRANSACTION;
			Set @NewRecordID = scope_Identity()
		END
		ELSE
		BEGIN
			ROLLBACK TRANSACTION;
			return
		END

END TRY
BEGIN CATCH

  IF (XACT_STATE()) <> 0
  BEGIN
    ROLLBACK TRANSACTION;
		return
  END

END CATCH


--run this part only if current date is near end of DST
DECLARE @currYear varchar(4)
SET @currYear = str(datepart(yyyy, getdate()),4)
IF getdate() between '10/30/' + @currYear and '11/18/' + @currYear
BEGIN
  DECLARE @Client char(4)
  DECLARE @GroupCode int
  DECLARE @SiteNo INT  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 02Sept2016 >--
  DECLARE @InPunch datetime
  DECLARE @OutPunch datetime
  DECLARE @TimeOnDST datetime
  DECLARE @TimeOffDST datetime
  DECLARE @DaylightSavTime char(1)
  DECLARE @DSTAdjustedHours numeric(6,2)


	Set @TimeOnDST = '3/8/' + @currYear + ' 02:00' 
	IF (DATEPART(dw, @TimeOnDST) <> 1)
	BEGIN
		SELECT @TimeOnDST = dateadd(dd, 7-DATEPART(dw, @TimeOnDST)+1, @TimeOnDST)
	END
	
	
	Set @TimeOffDST = '11/1/' + @currYear  + ' 02:00' 
	IF (DATEPART(dw, @TimeOffDST) <> 1)
	BEGIN
		SELECT @TimeOffDST = dateadd(dd, 7-DATEPART(dw, @TimeOffDST)+1, @TimeOffDST)
	END

  Select @Client = Client,
         @GroupCode = GroupCode,
         @SiteNo = SiteNo,
         @InPunch = dbo.PunchDateTime2(TransDate, InDay, intime), 
         @OutPunch = dbo.PunchDateTime2(TransDate, OutDay, Outtime), 
         @DaylightSavTime = DaylightSavTime
  from TimeHistory..tblTimeHistDetail
  where RecordID = @NewRecordID

  IF DATEADD(hh, -1, @TimeOffDST) between @InPunch and @OutPunch
  BEGIN  
    EXEC [TimeHistory].[dbo].[usp_APP_GetDSTAdjustedHours2] @Client, @GroupCode, @SiteNo, @InPunch, @OutPunch, @TimeOnDST, @TimeOffDST, @DaylightSavTime, @DSTAdjustedHours OUTPUT 
    Update TimeHistory..tblTimeHistdetail Set Hours = @DSTAdjustedHours where RecordID = @NewRecordID
  END

END

