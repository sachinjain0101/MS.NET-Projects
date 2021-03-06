Create PROCEDURE [dbo].[usp_APP_ReAllocateSalaryHours_HCPA] 
(
  @Client     char(4),
  @GroupCode  int,
  @PPED       datetime,     --PayrollPeriodEndDate
  @MPD        datetime,      --MasterPayrollDate
	@SingleSSN	int = NULL
) AS

SET NOCOUNT ON

DECLARE @InTrans        char(1)
DECLARE @SSN            int
DECLARE @Adj            VARCHAR(3) --< Srinsoft converted from Char(1) to Varchar(3) for @Adj on 05/11/2016 >--
DECLARE @AdjName        varchar(12)
DECLARE @EmpStatus      char(1)
DECLARE @BillRate       numeric(7,2)
DECLARE @PayRate        numeric(7,2)
DECLARE @AgencyNo       int
DECLARE @Hours          numeric(7,2)
DECLARE @Notification   varchar(1024)
DECLARE @SaveError      int

-- Create a temp table to hold the new time hist detail transactions.
--
CREATE TABLE #tmpThd(
  Client               char(4) NOT NULL, 
  GroupCode            int  NOT NULL, 
  SSN                  int NOT NULL, 
  PayrollPeriodEndDate datetime NOT NULL,  
  MasterPayrollDate    datetime NOT NULL,
  SiteNo               int NOT NULL, 
  DeptNo               int NOT NULL, 
  JobID                bigint NOT NULL, 
  TransDate            datetime NOT NULL, 
  EmpStatus            char(1) NOT NULL, 
  BillRate             numeric(7,2) NOT NULL, 
  BillOTRate           numeric(7,2) NOT NULL, 
  BillOTRateOverride   numeric(7,2) NOT NULL, 
  PayRate              numeric(7,2) NOT NULL, 
  ShiftNo              smallint NOT NULL, 
  InDay                smallint NOT NULL, 
  InTime               datetime NOT NULL, 
  OutDay               smallint NOT NULL, 
  OutTime              datetime NOT NULL, 
  OrigHours            numeric(7,2) NOT NULL, 
  AllocatedHours       numeric(5,2) NOT NULL, 
  Dollars              numeric(7,2) NOT NULL, 
  TransType            smallint NOT NULL, 
  AgencyNo             smallint NOT NULL, 
  InSrc                char(1) NOT NULL, 
  OutSrc               char(1) NOT NULL, 
  ClockAdjustmentNo    VARCHAR(3) NOT NULL, --< Srinsoft converted from Char(1) to Varchar(3) for ClockAdjustmentNo on 05/11/2016 >--
  AdjustmentCode       VARCHAR(3) NOT NULL, --< Srinsoft converted from Char(1) to Varchar(3) for AdjustmentCode on 05/11/2016 >--
  AdjustmentName       varchar(12) NOT NULL, 
  DaylightSavTime      char(1) NOT NULL, 
  Holiday              char(1) NOT NULL, 
  HandledByImporter    char(1) NOT NULL, 
  ClkTransNo           bigint NOT NULL, 
  UserCode             varchar(5) NOT NULL, 
  DivisionID           bigint NOT NULL,
  Percentage           numeric(5,2) NOT NULL,
  CrossOverStatus      char(1) NULL DEFAULT ' ',
  CrossoverOtherGroup  int NULL DEFAULT 0
)

CREATE TABLE #tmpRecs(
  SSN                int NOT NULL, 
  ClockAdjustmentNo  VARCHAR(3) NULL, --< Srinsoft converted from Char(1) to Varchar(3) for ClockAdjustmentNo on 05/11/2016 >--
  AdjustmentName     varchar(12) NULL,
  TotHours           numeric(7,2) NULL
)

  

-- ======================================================================================
-- Summarize the current detail transactions by AdjustmentNo for each SSN
-- that has allocation records in the allocation table.
-- If the Client is GAMBRO then exclude PTO and Unscheduled PTO
-- else include all transactions
-- ======================================================================================
Insert into #tmpRecs (SSN, ClockAdjustmentNo, AdjustmentName, TotHours)
(select thd.SSN, 
				thd.ClockAdjustmentNo, 
				thd.AdjustmentName, 
  			Sum(thd.Hours) as TotHours
  from Timehistory..tblTimeHistdetail as thd with(nolock)
	Left Join TimeCurrent..tblAdjCodes ac
	on thd.Client = ac.Client
	and thd.GroupCode = ac.GroupCode
	and thd.ClockAdjustmentNo = ac.ClockAdjustmentNo
  where thd.Client = @Client 
  and thd.groupCode = @GroupCode
  and thd.payrollperiodenddate = @PPED
  and thd.ClockAdjustmentNo NOT IN ('',' ')
  and thd.ClockAdjustmentNo IS NOT NULL
  and thd.Dollars = 0.00
	and thd.hours <> 0.00
	AND thd.TransType <> 7
	and IsNull(ac.Worked, 'Y') <> 'N'
  and thd.SSN IN(select a.SSN 
								from timecurrent..tblEmplAllocation as a with(nolock)
								inner join timecurrent..tblemplnames as n	with(nolock)	
								on a.client = n.client
								and a.groupcode = n.groupcode
								and a.ssn = n.ssn
								where a.client = @Client 
--									and a.groupcode = @GroupCode 
								and a.ssn = thd.SSN 	
							  and a.recordstatus = '1' 	
							  and a.SiteNo > 0
								and (@SingleSSN IS NULL OR (@SingleSSN IS NOT NULL AND a.SSN = @SingleSSN))
								and n.paytype = 1
							  and a.Percentage > 0.00
							  group By a.SSN
							  Having Sum(1) > 0)
group by 	thd.SSN, 
					thd.ClockAdjustmentNo, 
					thd.adjustmentname)
  
--select * from #tmpRecs

-- ======================================================================================
-- Add in the important stuff from tblEmplNames so we can complete the transactions when
-- inserting new ones into the detail table.
-- Create a read only cursor to process.
-- ======================================================================================
DECLARE csrThd CURSOR
READ_ONLY
FOR 
select thd.SSN, thd.ClockAdjustMentNo, thd.AdjustmentName,
en.Status, en.BillRate, en.PayRate, en.AgencyNo , thd.TotHours
from #tmpRecs as thd
Left Join timecurrent..tblEmplnames as en
on en.client = @client
and en.groupcode = @groupcode
and en.ssn = thd.ssn
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
    Select 	Client, GroupCode, SSN, @PPED, @MPD, SiteNo, DeptNo, Jobid = 0, 
				    convert(char(10), @PPED,101), @EmpStatus, @BillRate, BillOTRate = 0.00, BillOTRateOverride = 0.00, 
				    @PayRate, ShiftNo = 1, Inday = datepart(weekday, @PPED), InTime = '12/30/1899 00:00:00', OutDay = 0, OutTime = '12/30/1899 00:00:00', 
				    @Hours, AllocatedHours = (convert(numeric(5,2), @Hours * (Percentage / 100))),
				    Dollars = 0.00, TransType = 1, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', @AdjName, 
				    DaylightSavTime = '0', Holiday = '0', HandledByImporter = 'V', ClkTransNo = 9999, UserCode = 'GSA', DivisionID = 0, Percentage,
						' ', 0
    from timecurrent..tblEmplAllocation
    where Client = @Client
      and GroupCode = @GroupCode
      and SSN = @SSN
			and RecordStatus = '1'
			and (Hours <> 0 OR Percentage <> 0)

--select * from #tmpThd

    -- ======================================================================================
    -- Summarize what was just created for this adjustment number/SSN from the allocation table.
    -- Subtract the summarized total from the total hours for this adjustment number to get the 
    -- hours that should be re-allocated to the primary site/department.
    -- Create a record for the primary Site/Department in the temp trans table.
    -- ======================================================================================
    Insert into #tmpThd    
    Select 	tt.Client, tt.GroupCode, tt.SSN, @PPED, @MPD, 
				    en.PrimarySite,en.PrimaryDept, Jobid = 0, 
				    convert(char(10), @PPED,101), @EmpStatus, @BillRate, BillOTRate = 0.00, BillOTRateOverride = 0.00, 
				    @PayRate, ShiftNo = 1, Inday = datepart(weekday, @PPED), InTime = '12/30/1899 00:00:00', OutDay = 0, OutTime = '12/30/1899 00:00:00', 
				    @Hours, AllocatedHours = (@Hours - SUM(tt.AllocatedHours)),
				    Dollars = 0.00, TransType = 1, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', @AdjName, 
				    DaylightSavTime = '0', Holiday = '0', HandledByImporter = 'V', ClkTransNo = 9999, UserCode = 'GSA', DivisionID = 0, Percentage = (100 - sum(tt.Percentage)),
						' ', 0
    from #tmpThd as TT
    Left Join TimeCurrent..tblEmplNames as EN
    on en.Client = tt.client
    and en.groupCode = tt.GroupCode
    and en.SSN = tt.SSN
    where tt.Client = @Client
      and tt.GroupCode = @GroupCode
      and tt.SSN = @SSN
      and tt.ClockAdjustmentNo = @Adj
      and tt.adjustmentname = @AdjName
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
            Hours, AgencyNo, 'GSA',0,getdate(),null,null,0,getdate(),'1','10.3.0.18',ShiftNo
      from tblTimeHistdetail
      where Client = @Client
        and GroupCode = @groupcode
        and ClockADjustmentNo = @Adj
        and adjustmentname = @AdjName
        and SSN = @SSN
        and PayrollPeriodEndDate = @PPED and Insrc <> '3')

      if @@Error <> 0 
      begin
        Set @SaveError = @@Error
        goto RollBackTransaction
      end  

      DELETE FROM TimeHistory.dbo.tblTimeHistdetail
      WHERE Client = @Client
        AND GroupCode = @groupcode
        AND ClockAdjustmentNo = @Adj
        AND adjustmentname = @AdjName
        AND SSN = @SSN
        AND PayrollPeriodEndDate = @PPED

      if @@Error <> 0 
      begin
        Set @SaveError = @@Error
        goto RollBackTransaction
      end  
      
	    Insert into tblTimeHistDetail(Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate,
																    SiteNo, DeptNo, JobID, TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, 
																		ShiftNo, InDay, InTime, OutDay, OutTime, Hours, RegHours, Dollars, TransType, AgencyNo, InSrc, OutSrc, 
																		ClockAdjustmentNo, AdjustmentCode, AdjustmentName, DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, 
																		UserCode, DivisionID, CrossoverStatus, CrossoverOtherGroup)
	    (Select Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate, SiteNo, DeptNo, JobID, 
					    TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
					    AllocatedHours, AllocatedHours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
					    DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode, DivisionID, CrossOverStatus, CrossoverOtherGroup
	    from #tmpThd 
			where SSN = @SSN 
			and ClockAdjustmentNo = @Adj 
			and adjustmentname = @AdjName)

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

DROP TABLE #tmpRecs
DROP TABLE #tmpTHD


return

RollBackTransaction:
Rollback Transaction

Close csrTHD
DEALLOCATE csrTHD

drop table #tmpRecs
drop table #tmpThd

--/*
Select @Notification = 'Failed: ' + @Client + ',' + ltrim(str(@GroupCode)) + ',' + convert(char(10),@PPED,101) + ',' + ltrim(str(@SSN))
-- Set parameter values
EXEC [Scheduler].[dbo].[usp_APP_AddNotification] '2', '1', 'SalaryAllocation', 0, 0, @Notification, ''

return @SaveError
--*/
--*/






