CREATE   PROCEDURE [dbo].[usp_APP_ReAllocateHourlyHours_DAVT] 
(
  @Client     char(4),
  @GroupCode  int,
  @PPED       datetime,     --PayrollPeriodEndDate
  @MPD        datetime,      --MasterPayrollDate
	@SSN	      int
) AS


SET NOCOUNT ON
--*/

/*
DECLARE  @Client     char(4)
DECLARE  @GroupCode  int
DECLARE  @PPED       datetime
DECLARE  @MPD        datetime

SET @Client     = 'DAVI'
SET @GroupCode  = 301100
SET @PPED       = '12/25/04'
SET @MPD        = '12/25/04'

SET NOCOUNT ON
*/

DECLARE @InTrans        char(1)
DECLARE @Adj            varchar(3)  --< Srinsoft 08/24/2015 Changed @Adj char(1) to varchar(3) >--
DECLARE @AdjName        varchar(12)
DECLARE @EmpStatus      char(1)
DECLARE @BillRate       numeric(7,2)
DECLARE @PayRate        numeric(7,2)
DECLARE @AgencyNo       int
DECLARE @Hours          numeric(7,2)
DECLARE @RegHours       numeric(7,2)
DECLARE @OTHours        numeric(7,2)
DECLARE @DTHours        numeric(7,2)
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
  JobID                BIGINT NOT NULL,   --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--
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
  aRegHours            numeric(5,2) NOT NULL, 
  aOTHours             numeric(5,2) NOT NULL, 
  aDTHours             numeric(5,2) NOT NULL, 
  Dollars              numeric(7,2) NOT NULL, 
  TransType            smallint NOT NULL, 
  AgencyNo             smallint NOT NULL, 
  InSrc                char(1) NOT NULL, 
  OutSrc               char(1) NOT NULL, 
  ClockAdjustmentNo    varchar(3) NOT NULL,   --< Srinsoft 08/24/2015 Changed ClockAdjustmentNo char(1) to varchar(3) >--
  AdjustmentCode       varchar(3) NOT NULL,  --< Srinsoft 09/15/2015 Changed AdjustmentCode char(1) to varchar(3) >--
  AdjustmentName       varchar(12) NOT NULL, 
  DaylightSavTime      char(1) NOT NULL, 
  Holiday              char(1) NOT NULL, 
  HandledByImporter    char(1) NOT NULL, 
  ClkTransNo           BIGINT NOT NULL,   --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--
  UserCode             varchar(5) NOT NULL, 
  DivisionID           BIGINT NOT NULL,  --< @DivisionId data type is changed from  INT to BIGINT by Srinsoft on 26Oct2016 >--
  Percentage           numeric(5,2) NOT NULL,
  CrossOverStatus      char(1) NULL DEFAULT ' ',
  CrossoverOtherGroup  int NULL DEFAULT 0
)

CREATE TABLE #tmpRecs(
  SSN                int NOT NULL, 
  ClockAdjustmentNo  varchar(3) NULL, --< Srinsoft 08/24/2015 Changed ClockAdjustmentNo char(1) to varchar(3) >--
  AdjustmentName     varchar(12) NULL,
  RegHours           numeric(7,2) NULL,
  OTHours            numeric(7,2) NULL,
  DTHours            numeric(7,2) NULL
)

Set @MPD = (Select masterpayrolldate from Timehistory..tblPeriodenddates where client = @client and groupcode = @groupcode and payrollperiodenddate = @PPED )

  Insert into #tmpRecs (SSN, ClockAdjustmentNo, AdjustmentName, RegHours,OTHours, DTHours)
  (select thd.SSN, 
					thd.ClockAdjustmentNo, 
					thd.AdjustmentName,
          Sum(thd.RegHours), Sum(thd.OT_Hours), Sum(thd.DT_Hours)
   from Timehistory..tblTimeHistdetail as thd
	 Left Join TimeCurrent..tblAdjCodes ac
	 on thd.Client = ac.Client
	 and thd.GroupCode = ac.GroupCode
	 and thd.ClockAdjustmentNo = ac.ClockAdjustmentNo
   where thd.Client = @Client 
   and thd.groupCode = @GroupCode
   and thd.payrollperiodenddate = @PPED
--   and thd.ClockAdjustmentNo NOT IN ('',' ')
--   and thd.ClockAdjustmentNo IS NOT NULL
   and thd.Dollars = 0.00
	 and IsNull(ac.Worked, 'Y') <> 'N'
   and thd.SSN = @SSN 
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
en.Status, en.BillRate, en.PayRate, en.AgencyNo , thd.RegHours, thd.OTHours, thd.DTHours
from #tmpRecs as thd
Left Join timecurrent..tblEmplnames as en
on en.client = @client
and en.groupcode = @groupcode
and en.ssn = thd.ssn
order by thd.SSN, thd.ClockAdjustmentNo

OPEN csrThd

FETCH NEXT FROM csrThd INTO @SSN, @Adj, @AdjName, @EmpStatus, @BillRate, @PayRate, @AgencyNo, @RegHours, @OTHours, @DTHours
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
				    @RegHours + @OTHours + @DTHours, 
            aRegHours = (convert(numeric(5,2), @RegHours * (Percentage / 100))),
            aOTHours = (convert(numeric(5,2), @OTHours * (Percentage / 100))),
            aDTHours = (convert(numeric(5,2), @DTHours * (Percentage / 100))),
				    Dollars = 0.00, TransType = 1, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', @AdjName, 
				    DaylightSavTime = '0', Holiday = '0', HandledByImporter = 'V', ClkTransNo = 406406, UserCode = 'GHA', DivisionID = 0, Percentage,
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
				    @RegHours + @OTHours + @DTHours, 
            aRegHours = (@RegHours - SUM(tt.aRegHours)),
            aOTHours = (@OTHours - SUM(tt.aOTHours)),
            aDTHours = (@DTHours - SUM(tt.aDTHours)),
				    Dollars = 0.00, TransType = 1, @AgencyNo, '3', '0', @Adj, AdjustmentCode = '', @AdjName, 
				    DaylightSavTime = '0', Holiday = '0', HandledByImporter = 'V', ClkTransNo = 406406, UserCode = 'GHA', DivisionID = 0, Percentage = (100 - sum(tt.Percentage)),
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

--select * from #tmpThd

		IF (@Client IN('DAVI','DAVT','DVPC'))
		BEGIN
	    DECLARE @CrossGroup    AS int
	    SET @CrossGroup = ISNULL((SELECT DISTINCT TOP 1 depts.GroupCode
													      FROM #tmpTHD AS thd
													      INNER JOIN TimeCurrent..tblDeptNames AS depts
													      ON depts.Client = thd.Client 
																AND depts.SiteNo = thd.SiteNo 
																AND depts.DeptNo = thd.DeptNo 
																AND depts.GroupCode <> thd.GroupCode 
																AND depts.RecordStatus = '1'
												        INNER JOIN TimeCurrent..tblSiteNames AS sites
												        ON sites.Client = thd.Client 
																AND sites.GroupCode = depts.GroupCode 
																AND sites.SiteNo = depts.SiteNo 
																AND sites.RecordStatus = '1'
												        INNER JOIN TimeCurrent..tblClientGroups AS groups
												        ON groups.Client = thd.Client 
																AND groups.GroupCode = depts.GroupCode 
																AND groups.RecordStatus = '1' 
																AND groups.GroupCode NOT IN (999999, 999899)
												        WHERE thd.SSN = @SSN 
																AND thd.ClockAdjustmentNo = @Adj 
																AND thd.AdjustmentName = @AdjName), 0)
      /*
	    SET @CrossGroup = ISNULL((
	      SELECT DISTINCT TOP 1 en.GroupCode
	      FROM #tmpTHD AS thd
	      INNER JOIN TimeCurrent..tblEmplNames AS en
	      ON en.Client = thd.Client 
				AND en.SSN = thd.SSN
				AND en.GroupCode <> thd.GroupCode
				AND en.RecordStatus = '1'
				AND en.Status <> '9'
	      WHERE thd.SSN = @SSN 
				AND thd.ClockAdjustmentNo = @Adj 
				AND thd.AdjustmentName = @AdjName
	    ), 0)
      */
	
	    IF @CrossGroup <> 0
	    BEGIN
	      UPDATE #tmpTHD 
				SET CrossOverStatus = '4',
						CrossoverOtherGroup = sites.GroupCode
        FROM #tmpTHD AS thd
        LEFT JOIN TimeCurrent..tblSiteNames AS sites 
				ON sites.Client = thd.Client 
				AND sites.SiteNo = thd.SiteNo 
				AND sites.RecordStatus = '1'
	      WHERE thd.SSN = @SSN 
				AND thd.ClockAdjustmentNo = @Adj 
				AND thd.AdjustmentName = @AdjName

	      INSERT INTO #tmpTHD
	      SELECT 	thd.Client, @CrossGroup, thd.SSN, thd.PayrollPeriodEndDate, thd.MasterPayrollDate, 
			          thd.SiteNo, thd.DeptNo, thd.JobID, thd.TransDate, thd.EmpStatus, thd.BillRate, thd.BillOTRate, thd.BillOTRateOverride,
				        thd.PayRate, thd.ShiftNo, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, thd.OrigHours, thd.aregHours, thd.aOTHours, thd.aDTHours, thd.Dollars, thd.TransType, 
			          thd.AgencyNo, thd.InSrc, thd.OutSrc, thd.ClockAdjustmentNo, thd.AdjustmentCode, thd.AdjustmentName,
				        thd.DaylightSavTime, thd.Holiday, thd.HandledByImporter, thd.ClkTransNo, thd.UserCode, thd.DivisionID, thd.Percentage, '2', sites.GroupCode
	      FROM #tmpTHD AS thd
        LEFT JOIN TimeCurrent..tblSiteNames AS sites 
				ON sites.Client = thd.Client 
				AND sites.SiteNo = thd.SiteNo 
				AND sites.RecordStatus = '1'
	      WHERE thd.SSN = @SSN 
				AND thd.ClockAdjustmentNo = @Adj 
				AND thd.AdjustmentName = @AdjName

	    END
		END
    -- ======================================================================================
    -- Delete the adjustment number from the detail table and insert the re-allocated detail records
    -- If the adjustment came from a clock, then add it to the timecurrent..tbladjustments so 
    -- there is an audit record of the original transaction. This will help with research.
    -- All PeopleNet transactions should be in the tblAdjustments table.
    -- ======================================================================================


--    /*
    Begin transaction
      Select @InTrans = '1'

      /*
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
      */

      -- Save the original Transactions to the ORIG table.
      --
      INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Orig]([Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [RegHours], [OT_Hours], [DT_Hours], [RegDollars], [OT_Dollars], [DT_Dollars], [RegBillingDollars], [OTBillingDollars], [DTBillingDollars], [CountAsOT], [RegDollars4], [OT_Dollars4], [DT_Dollars4], [RegBillingDollars4], [OTBillingDollars4], [DTBillingDollars4], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [AllocatedRegHours], [AllocatedOT_Hours], [AllocatedDT_Hours], [Borrowed], [UserCode], [DivisionID], [CostID], [ShiftDiffAmt], [OutUserCode], [ActualInTime], [ActualOutTime], [InSiteNo], [OutSiteNo], [InVerified], [OutVerified], [InClass], [OutClass], [InTimestamp], [outTimestamp], [CrossoverStatus], [CrossoverOtherGroup])
      Select [Client], [GroupCode], [SSN], [PayrollPeriodEndDate], [MasterPayrollDate], [SiteNo], [DeptNo], [JobID], [TransDate], [EmpStatus], [BillRate], [BillOTRate], [BillOTRateOverride], [PayRate], [ShiftNo], [InDay], [InTime], [OutDay], [OutTime], [Hours], [Dollars], [ClockAdjustmentNo], [AdjustmentCode], [AdjustmentName], [TransType], [Changed_DeptNo], [Changed_InPunch], [Changed_OutPunch], [AgencyNo], [InSrc], [OutSrc], [DaylightSavTime], [Holiday], [RegHours], [OT_Hours], [DT_Hours], [RegDollars], [OT_Dollars], [DT_Dollars], [RegBillingDollars], [OTBillingDollars], [DTBillingDollars], [CountAsOT], [RegDollars4], [OT_Dollars4], [DT_Dollars4], [RegBillingDollars4], [OTBillingDollars4], [DTBillingDollars4], [xAdjHours], [AprvlStatus], [AprvlStatus_UserID], [AprvlStatus_Date], [AprvlAdjOrigRecID], [HandledByImporter], [AprvlAdjOrigClkAdjNo], [ClkTransNo], [ShiftDiffClass], [AllocatedRegHours], [AllocatedOT_Hours], [AllocatedDT_Hours], [Borrowed], [UserCode], [DivisionID], [CostID], [ShiftDiffAmt], [OutUserCode], [ActualInTime], [ActualOutTime], [InSiteNo], [OutSiteNo], [InVerified], [OutVerified], [InClass], [OutClass], [InTimestamp], [outTimestamp], [CrossoverStatus], [CrossoverOtherGroup]
      FROM TimeHistory.dbo.tblTimeHistdetail
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
																		ShiftNo, InDay, InTime, OutDay, OutTime, Hours, RegHours, OT_Hours, DT_Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, 
																		ClockAdjustmentNo, AdjustmentCode, AdjustmentName, DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, 
																		UserCode, DivisionID, CrossoverStatus, CrossoverOtherGroup)
      (Select Client, GroupCode, SSN, PayrollPeriodEndDate,  MasterPayrollDate, SiteNo, DeptNo, JobID, 
				      TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, InTime, OutDay, OutTime, 
				      aRegHours + aOTHours + aDTHours ,aRegHours, aOTHours, aDTHours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, AdjustmentCode, AdjustmentName, 
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
--    */
	END
	FETCH NEXT FROM csrThd INTO @SSN, @Adj, @AdjName, @EmpStatus, @BillRate, @PayRate, @AgencyNo, @RegHours, @OTHours, @DTHours
END

CLOSE csrTHD
DEALLOCATE csrThd

--SELECT * FROM #tmpTHD

DROP TABLE #tmpRecs
DROP TABLE #tmpTHD

--/*
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









