USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_GambroWklyLbrSum_AllocateSalary]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GambroWklyLbrSum_AllocateSalary]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GambroWklyLbrSum_AllocateSalary] AS' 
END
GO

/*
***********************************************************************************
 $Archive: /SQLServer/StoredProcs/TimeHistory/usp_APP_GenNetSalaryRecs_GAMB.PRC $
 $Author: Dale Humphries $
 $Date: 4/26/02 4:02p $
 $Modtime: 4/26/02 4:00p $
 $Workfile: usp_APP_GenNetSalaryRecs_GAMB.PRC $
 $Revision: 3 $

 OWNER      :     (C) Copyright 2002 by Cignify Corporation
 PRODUCT    :     PeopleNet
 DESCRIPTION:     

 Helper SP for usp_GambroWklyLbrSum
 SP to re-allocate generated salary records. This procedure is called after the generate
 salary record procedure is called in the usp_GambroMthlyAcc procedure.
 This procedure will re-allocate the hours in the 
 detail records based on the percentages setup in the tblEmplAllocation table. 
 1. First sum all hours in tblTimeHistdetail by adjustment number for all employees that
    are in the allocation table.
 2. Loop through each summary record and re-allocate the hours based on the percentages 
    in the allocation table into a temp table
 3. ALTER  a primary site and primary dept record for each detail transaction ( note the allocation table only
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
$History: $

***********************************************************************************
*/

--/*
ALTER     procedure [dbo].[usp_GambroWklyLbrSum_AllocateSalary]
(
  @Client char(4),
  @groupCode int,
  @PPED datetime     --PayrollPeriodEndDate
)
AS
--*/
/*
declare @Client char(4)
declare @groupcode int
declare @PPED datetime


Select @Client = 'GAMB'
Select @GroupCode = 101000
Select @PPED = '4/20/02'


Drop Table #tmpRecs
Drop Table #tmpThd
*/
set nocount on

declare @InTrans char(1)
declare @SSN int
declare @Adj varchar(3)  --< Srinsoft 08/28/2015 Changed @Adj char(1) to varchar(3) for ClockAdjustmentno >--
declare @AdjName varchar(12)
declare @EmpStatus char(1)
declare @BillRate numeric(7,2)
declare @PayRate numeric(7,2)
declare @AgencyNo int
declare @Hours numeric(7,2)
DECLARE @Notification varchar(1024)


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
  JobID BIGINT NOT NULL,   --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 05Oct2016 >--
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
  ClockAdjustmentNo varchar(3) NOT NULL,   --< Srinsoft 08/28/2015 Changed ClockAdjustmentNo char(1) to varchar(3) for ClockAdjustmentno >--
  AdjustmentCode varchar(3) NOT NULL,   --< Srinsoft 09/22/2015 Changed AdjustmentCode char(1) to varchar(3) for AdjustmentCode >--
  AdjustmentName varchar(12) NOT NULL, 
  DaylightSavTime char(1) NOT NULL, 
  Holiday char(1) NOT NULL, 
  HandledByImporter char(1) NOT NULL, 
  ClkTransNo BIGINT NOT NULL,    --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 05Oct2016 >--
  UserCode varchar(5) NOT NULL, 
  DivisionID int NOT NULL,
  Percentage numeric(5,2) NOT NULL)

Create table #tmpRecs(
  SSN int NOT NULL, 
  ClockAdjustmentNo varchar(3) NULL, --< Srinsoft 08/28/2015 Changed ClockAdjustmentNo char(1) to varchar(3) for ClockAdjustmentno >--
  TotHours numeric(7,2) NULL)
  
-- ======================================================================================
-- Summarize the current detail transactions by AdjustmentNo for each SSN
-- that has allocation records in the allocation table.
-- If the Client is GAMBRO then exclude PTO and Unscheduled PTO
-- else include all transactions
-- ======================================================================================
  Insert into #tmpRecs (SSN, ClockAdjustmentNo, TotHours)
  (select thd.SSN, thd.ClockAdjustmentNo, Sum(CASE WHEN thd.Hours IS NULL THEN 0 ELSE thd.Hours END) as TotHours
  from #Payroll_THD as thd
  where thd.Client = @Client 
  and thd.groupCode = @GroupCode
  and thd.payrollperiodenddate = @PPED
  and thd.ClockAdjustmentNo NOT IN ('2','3','4','',' ')
  and thd.ClockAdjustmentNo IS NOT NULL
  and thd.dollars = 0.00
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
  group by thd.SSN, thd.ClockAdjustmentNo)

-- ======================================================================================
-- Add in the important stuff from tblEmplNames so we can complete the transactions when
-- inserting new ones into the detail table.
-- Create a read only cursor to process.
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
select thd.SSN, thd.ClockAdjustMentNo, 
en.Status, en.BillRate, en.PayRate, en.AgencyNo , thd.TotHours
from #tmpRecs as thd
Left Join timecurrent..tblEmplnames as en
on en.client = @client
and en.groupcode = @groupcode
and en.ssn = thd.ssn
order by thd.SSN, thd.ClockAdjustmentNo

OPEN csrThd

FETCH NEXT FROM csrThd INTO @SSN, @Adj, @EmpStatus, @BillRate, @PayRate, @AgencyNo, @Hours
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
    Select Client, GroupCode, SSN, @PPED, @PPED, SiteNo, DeptNo, Jobid = 0, 
    convert(char(10), @PPED,101), @EmpStatus, @BillRate, BillOTRate = 0.00, BillOTRateOverride = 0.00, 
    @PayRate, ShiftNo = 1, Inday = datepart(weekday, @PPED), InTime = '12/30/1899 00:00:00', OutDay = 0, OutTime = '12/30/1899 00:00:00', 
    @Hours, AllocatedHours = (convert(numeric(5,2), @Hours * (Percentage / 100))),
    Dollars = 0.00, TransType = 1, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', '', 
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
    Select tt.Client, tt.GroupCode, tt.SSN, @PPED, @PPED, 
    en.PrimarySite,en.PrimaryDept, Jobid = 0, 
    convert(char(10), @PPED,101), @EmpStatus, @BillRate, BillOTRate = 0.00, BillOTRateOverride = 0.00, 
    @PayRate, ShiftNo = 1, Inday = datepart(weekday, @PPED), InTime = '12/30/1899 00:00:00', OutDay = 0, OutTime = '12/30/1899 00:00:00', 
    @Hours, AllocatedHours = (@Hours - SUM(tt.AllocatedHours)),
    Dollars = 0.00, TransType = 1, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', '', 
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
    -- ======================================================================================

    Begin transaction
      Select @InTrans = '1'
  
      delete from #Payroll_THD
      where Client = @Client
        and GroupCode = @groupcode
        and ClockADjustmentNo = @Adj
        and SSN = @SSN
        and PayrollPeriodEndDate = @PPED
        
      Insert into #Payroll_THD
      Select Client, GroupCode, SSN, SiteNo, DeptNo, TransDate, '0', PayRate, PayRate, '0',
            ClockAdjustmentNo,'0',AllocatedHours, 0,0,0,AllocatedHours, PayrollPeriodEndDate, ''
      from #tmpThd where SSN = @SSN and ClockAdjustmentNo = @Adj

      if @@Error <> 0 
      begin
        goto RollBackTransaction
      end  
      select @InTrans = '0'
  
    Commit Transaction

	END
	FETCH NEXT FROM csrThd INTO @SSN, @Adj, @EmpStatus, @BillRate, @PayRate, @AgencyNo, @Hours
END


CLOSE csrTHD
DEALLOCATE csrThd

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
EXEC [Scheduler].[dbo].[usp_APP_AddNotification] '2', '1', 'usp_GambroMthlyAcc_AllocateSalary', 0, 0, @Notification, ''





GO
