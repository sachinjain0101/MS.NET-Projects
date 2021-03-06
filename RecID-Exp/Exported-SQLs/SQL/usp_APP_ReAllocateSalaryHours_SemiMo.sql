USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_APP_ReAllocateSalaryHours_SemiMo]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_APP_ReAllocateSalaryHours_SemiMo]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_APP_ReAllocateSalaryHours_SemiMo] AS' 
END
GO







/*
***********************************************************************************
 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

 SP to re-allocate generated salary records. This procedure is called after the generate
 salary record procedure is called. This procedure will re-allocate the hours in the 
 detail records based on the percentages setup in the tblEmplAllocation table. 
 1. First sum all hours in tblTimeHistdetail by adjustment number for all employees that
    are in the allocation table.
 2. Loop through each summary record and re-allocate the hours based on the percentages 
    in the allocation table into a temp table
 3. Generate a primary site and primary dept record for each detail transaction ( note the allocation table only
    holds non-primary site/department allocations
 4. Delete the current detail records for the associated adjustment code and add new 
    detail records based on the re-allocation of steps 2 and 3 above.


***********************************************************************************
 Copyright (c) Cignify Corporation, as an unpublished work first licensed in
 2002.  This program is a confidential, unpublished work of authorship created
 in 2002.  It is a trade secret which is the property of Cignify Corporation.

 All use, disclosure, and/or reproduction not specifically authorized by
 Cignify Corporation, is prohibited.  This program is protected by
 domestic and international copyright and/or trade secret laws.
 All rights reserved.

***********************************************************************************
REVISION HISTORY

DATE      INIT  Description
--------  ----  --------------------------------------------------------------------------------
04-22-02  DEH   Creation
05-13-02  DEH   Added ALL to the union statement.               
06-14-02  DEH   Added logic to save adjustments from the clock to the timecurrent..tbladjustments
                table before deleting them from timehistory..tblTimeHistdetail
07-15-02  DEH   Added logic to prevent selection of new Hourly allocations.

***********************************************************************************
*/

--/*
ALTER      procedure [dbo].[usp_APP_ReAllocateSalaryHours_SemiMo]
(
  @Client char(4),
  @groupCode int,
  @PPED datetime,     --PayrollPeriodEndDate
  @MPD datetime       --MasterPayrollDate
)
AS
--*/
/*
declare @Client char(4)
declare @groupcode int
declare @PPED datetime
declare @MPD datetime


Select @Client = 'GAMB'
Select @GroupCode = 610100
Select @PPED = '7/20/02'
Select @MPD = '7/15/02'

Drop Table #tmpRecs
Drop Table #tmpThd
*/

Set nocount on

declare @InTrans char(1)
declare @SSN int
declare @Adj varchar(3) --< Srinsoft 08/24/2015  @Adj char(1) to varchar(3) for clockadjustmentno >--
declare @AdjName varchar(12)
declare @EmpStatus char(1)
declare @BillRate numeric(7,2)
declare @PayRate numeric(7,2)
declare @AgencyNo int
declare @Hours numeric(7,2)
DECLARE @Notification varchar(1024)
DECLARE @SaveError int


-- Create a temp table to hold the new time hist detail transactions.
--
Create table #tmpThd(
  Client char(4) NOT NULL, 
  GroupCode int  NOT NULL, 
  SSN int NOT NULL, 
  PayrollPeriodEndDate datetime NOT NULL,  
  MasterPayrollDate datetime NOT NULL,
  SiteNo int NOT NULL, 
  DeptNo int NOT NULL, 
  JobID BIGINT NOT NULL,   --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--
  TransDate datetime NOT NULL, 
  EmpStatus char(1) NOT NULL, 
  BillRate numeric(7,2) NOT NULL, 
  BillOTRate numeric(7,2) NOT NULL, 
  BillOTRateOverride numeric(7,2) NOT NULL, 
  PayRate numeric(7,2) NOT NULL, 
  ShiftNo smallint NOT NULL, 
  InDay smallint NOT NULL, 
  InTime datetime NOT NULL, 
  OutDay smallint NOT NULL, 
  OutTime datetime NOT NULL, 
  OrigHours numeric(7,2) NOT NULL, 
  AllocatedHours numeric(5,2) NOT NULL, 
  Dollars numeric(7,2) NOT NULL, 
  TransType smallint NOT NULL, 
  AgencyNo smallint NOT NULL, 
  InSrc char(1) NOT NULL, 
  OutSrc char(1) NOT NULL, 
  ClockAdjustmentNo varchar(3) NOT NULL, --< Srinsoft 08/24/2015  ClockAdjustmentNo char(1) to varchar(3) >--
  AdjustmentCode varchar(3) NOT NULL,  --< Srinsoft 09/22/2015 Changed AdjustmentCode char(1) to varchar(3) >--
  AdjustmentName varchar(12) NOT NULL, 
  DaylightSavTime char(1) NOT NULL, 
  Holiday char(1) NOT NULL, 
  HandledByImporter char(1) NOT NULL, 
  ClkTransNo BIGINT NOT NULL,   --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--
  UserCode varchar(5) NOT NULL, 
  DivisionID BIGINT NOT NULL,  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 26Oct2016 >--
  Percentage numeric(5,2) NOT NULL)

Create table #tmpRecs(
  SSN int NOT NULL, 
  ClockAdjustmentNo varchar(3) NULL, --< Srinsoft 08/24/2015  ClockAdjustmentNo char(1) to varchar(3) >--
  AdjustmentName varchar(12) NULL,
  TotHours numeric(7,2) NULL)
  

-- ======================================================================================
-- Summarize the current detail transactions by AdjustmentNo for each SSN
-- that has allocation records in the allocation table.
-- If the Client is GAMBRO then exclude PTO and Unscheduled PTO
-- else include all transactions
-- ======================================================================================
if @Client IN('GAMB','GTS')
Begin
  Insert into #tmpRecs (SSN, ClockAdjustmentNo, AdjustmentName, TotHours)
  (
    select thd.SSN, thd.ClockAdjustmentNo, thd.AdjustmentName, 
    Sum(thd.Hours) as TotHours
    from Timehistory..tblTimeHistdetail as thd
    where thd.Client = @Client
    and thd.groupCode = @GroupCode
    and thd.MasterpayrollDate = @MPD
    and ( thd.ClockAdjustmentNo NOT IN ('2','3','4',' ','') and NOT thd.ClockAdjustmentNo IS NULL )
    and thd.Dollars = 0.00
    and thd.Hours <> 0.00
    and thd.SSN IN(	select Distinct a.SSN 
			from timecurrent..tblEmplAllocation as a
			inner join timecurrent..tblemplnames as n		
			on a.client = n.client
				and a.groupcode = n.groupcode
				and a.ssn = n.ssn
			where a.client = @Client 
				and a.groupcode = @GroupCode 
				and a.ssn = thd.SSN 	
        and a.recordstatus = '1' 	
        and a.SiteNo > 0
				and n.paytype = 1	)
    group by thd.SSN, thd.ClockAdjustmentNo, thd.adjustmentname
  Union ALL
    select thd.SSN, thd.ClockAdjustmentNo, thd.AdjustmentName, 
    Sum(thd.Hours) as TotHours
    from Timehistory..tblTimeHistdetail_Partial as thd
    where thd.Client = @Client
    and thd.groupCode = @GroupCode
    and thd.MasterpayrollDate = @MPD
    and ( thd.ClockAdjustmentNo NOT IN ('2','3','4',' ','') and NOT thd.ClockAdjustmentNo IS NULL )
    and thd.Dollars = 0.00
    and thd.Hours <> 0.00
    and thd.SSN IN(	select Distinct a.SSN 
			from timecurrent..tblEmplAllocation as a
			inner join timecurrent..tblemplnames as n		
			on a.client = n.client
				and a.groupcode = n.groupcode
				and a.ssn = n.ssn
			where a.client = @Client 
				and a.groupcode = @GroupCode 
				and a.ssn = thd.SSN
        and a.SiteNo > 0
        and a.recordstatus = '1' 	
				and n.paytype = 1	)
    group by thd.SSN, thd.ClockAdjustmentNo, thd.adjustmentname
  )
End
Else
Begin
  Insert into #tmpRecs (SSN, ClockAdjustmentNo, AdjustmentName, TotHours)
  (select thd.SSN, thd.ClockAdjustmentNo, thd.AdjustmentName, 
  Sum(thd.Hours) as TotHours
  from Timehistory..tblTimeHistdetail as thd
  where thd.Client = @Client 
  and thd.groupCode = @GroupCode
  and thd.masterpayrolldate = @MPD
  and thd.SSN IN(select Distinct SSN from timecurrent..tblEmplAllocation where client = @Client and groupcode = @groupcode and ssn = thd.SSN )
  group by thd.SSN, thd.ClockAdjustmentNo, thd.adjustmentname )
End

-- ======================================================================================
-- Add in the important stuff from tblEmplNames so we can complete the transactions when
-- inserting new ones into the detail table.
-- Create a read only cursor to process.
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
select thd.SSN, thd.ClockAdjustMentNo, thd.AdjustmentName,
en.Status, en.BillRate, en.PayRate, en.AgencyNo , SUM(thd.TotHours) as TotHours
from #tmpRecs as thd
Left Join timecurrent..tblEmplnames as en
on en.client = @client
and en.groupcode = @groupcode
and en.ssn = thd.ssn
Group By thd.SSN, thd.ClockAdjustMentNo, thd.AdjustmentName,
en.Status, en.BillRate, en.PayRate, en.AgencyNo
order by thd.SSN, thd.ClockAdjustmentNo

OPEN csrThd

FETCH NEXT FROM csrThd INTO @SSN, @Adj, @AdjName, @EmpStatus, @BillRate, @PayRate, @AgencyNo, @Hours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- ======================================================================================
    -- Insert new re-allocated records for this SSN and Adjustment No from the temp table.
    -- This Insert will create a new transaction for each record in the allocation table. The
    -- hours will be allocated based on the percentage in the allocation table.
    -- ======================================================================================
    Insert into #tmpThd    
    Select Client, GroupCode, SSN, @PPED, @MPD, SiteNo, DeptNo, Jobid = 0, 
    convert(char(10), @MPD,101), @EmpStatus, @BillRate, BillOTRate = 0.00, BillOTRateOverride = 0.00, 
    @PayRate, ShiftNo = 1, Inday = datepart(weekday, @MPD), InTime = '12/30/1899 00:00:00', OutDay = 0, OutTime = '12/30/1899 00:00:00', 
    @Hours, AllocatedHours = (convert(numeric(5,2), @Hours * (Percentage / 100))),
    Dollars = 0.00, TransType = 9, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', @AdjName, 
    DaylightSavTime = '0', Holiday = '0', HandledByImporter = 'V', ClkTransNo = 9999, UserCode = 'GSR', DivisionID = 0, Percentage
    from timecurrent..tblEmplAllocation
    where Client = @Client
      and GroupCode = @GroupCode
      and SSN = @SSN

    -- ======================================================================================
    -- Summarize what was just created for this adjustment number/SSN from the allocation table.
    -- Subtract the summarized total from the total hours for this adjustment number to get the 
    -- hours that should be re-allocated to the primary site/department.
    -- Create a record for the primary Site/Department in the temp trans table.
    -- ======================================================================================
    Insert into #tmpThd    
    Select tt.Client, tt.GroupCode, tt.SSN, @PPED, @MPD, 
    en.PrimarySite,en.PrimaryDept, Jobid = 0, 
    convert(char(10), @MPD,101), @EmpStatus, @BillRate, BillOTRate = 0.00, BillOTRateOverride = 0.00, 
    @PayRate, ShiftNo = 1, Inday = datepart(weekday, @MPD), InTime = '12/30/1899 00:00:00', OutDay = 0, OutTime = '12/30/1899 00:00:00', 
    @Hours, AllocatedHours = (@Hours - SUM(tt.AllocatedHours)),
    Dollars = 0.00, TransType = 9, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', @AdjName, 
    DaylightSavTime = '0', Holiday = '0', HandledByImporter = 'V', ClkTransNo = 9999, UserCode = 'GSR', DivisionID = 0, Percentage = (100 - sum(tt.Percentage))
    from #tmpThd as TT
    Left Join TimeCurrent..tblEmplNames as EN
    on en.Client = tt.client
    and en.groupCode = tt.GroupCode
    and en.SSN = tt.SSN
    where tt.Client = @Client
      and tt.GroupCode = @GroupCode
      and tt.SSN = @SSN
      and tt.ClockAdjustmentNo = @Adj
    Group By tt.client, tt.GroupCode, tt.SSN, en.PrimarySite, en.PrimaryDept

    -- ======================================================================================
    -- Delete the adjustment number from the detail table and insert the re-allocated detail records
    -- If the adjustment came from a clock, then add it to the timecurrent..tbladjustments so 
    -- there is an audit record of the original transaction. This will help with research.
    -- All PeopleNet transactions should be in the tblAdjustments table.
    -- ======================================================================================

    Begin transaction
      Select @InTrans = '1'

      INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
            [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
            [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
            [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
            [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
            [RecordStatus], [IPAddr], [ShiftNo])
      (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
            'CLK', AdjustmentName, 'H', 
            Case when InDay = 2 then Hours else 0 end,
            Case when InDay = 3 then Hours else 0 end,
            Case when InDay = 4 then Hours else 0 end,
            Case when InDay = 5 then Hours else 0 end,
            Case when InDay = 6 then Hours else 0 end,
            Case when InDay = 7 then Hours else 0 end,
            Case when InDay = 1 then Hours else 0 end,
            Case when InDay < 1 or InDay > 7 then Hours else 0 end,
            Hours, AgencyNo, 'GSR',0,getdate(),null,null,0,getdate(),'1','10.3.0.18',ShiftNo
      from tblTimeHistdetail
      where Client = @Client
        and GroupCode = @groupcode
        and ClockADjustmentNo = @Adj
        and SSN = @SSN
        and MasterPayrollDate = @MPD
        and Insrc <> '3')

      if @@Error <> 0 
      begin
        Set @SaveError = @@Error
        goto RollBackTransaction
      end  

      delete from TimeHistory..tblTimeHistdetail
      where Client = @Client
        and GroupCode = @groupcode
        and ClockADjustmentNo = @Adj
        and SSN = @SSN
        and MasterPayrollDate = @MPD
        
      if @@Error <> 0 
      begin
        Set @SaveError = @@Error
        goto RollBackTransaction
      end  

      Insert into tblTimeHistDetail
      (Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
      SiteNo, DeptNo, JobID, 
      TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
      Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
      DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID )
      (
        Select Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate, 
        SiteNo, DeptNo, JobID, 
        TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
        AllocatedHours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
        DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID
        from #tmpThd where SSN = @SSN and ClockAdjustmentNo = @Adj
      )
  
      if @@Error <> 0 
      begin
        Set @SaveError = @@Error
        goto RollBackTransaction
      end  
      select @InTrans = '0'
  
    Commit Transaction

	END
	FETCH NEXT FROM csrThd INTO @SSN, @Adj, @AdjName, @EmpStatus, @BillRate, @PayRate, @AgencyNo, @Hours
END


CLOSE csrTHD
DEALLOCATE csrThd

--select SSN, SiteNo, DeptNo, OrigHours, AllocatedHours, ClockAdjustmentNo, AdjustmentName, Percentage from #tmpthd
--order by SSN, ClockAdjustmentNo

drop table #tmpRecs
drop table #tmpThd

return

RollBackTransaction:
Rollback Transaction

Close csrTHD
DEALLOCATE csrTHD

drop table #tmpRecs
drop table #tmpThd

Select @Notification = 'Failed: ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + convert(char(10),@PPED,101) + ',' + ltrim(str(@SSN))
-- Set parameter values
EXEC [Scheduler].[dbo].[usp_APP_AddNotification] '2', '1', 'SalaryAllocation', 0, 0, @Notification, ''

return @SaveError






GO
