Create PROCEDURE [dbo].[usp_APP_CROW_Calc_Baylor_WE_Eufala]
( 
  @Client char(4),
  @GroupCode int,
  @PPED datetime

)
AS

SET NOCOUNT ON
--*/

/*
-- DEBUG SECTION
Declare @Client char(4)
Declare @GroupCode int
Declare @PPED datetime

Select @Client = 'CROW'
Select @GroupCode = 145000
Select @PPED = '11/06/2003'

drop table #tmpRecs
*/

DECLARE @MPD datetime
DECLARE @SSN int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @enStatus char(1)
DECLARE @SaveError int
DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 29July2016 >--
DECLARE @TransDate datetime
DECLARE @BaylorHours numeric(7,2)
DECLARE @PayRate numeric(7,2)

Set @TransDate = dateadd(day, -1, @PPED)

select t.ssn, SiteNo = isNULL(e.PrimarySite,0), 
t.deptNo, enStatus = e.Status, e.LastName, e.FirstName,
TotHours = sum(Hours),
BaylorHours = cast(0.00 as numeric(7,2)),
PayRate = cast(0.00 as numeric(7,2))
into #tmpRecs
from tblTimeHistDetail as t
inner join timecurrent..tblEmplnames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
where t.client = @Client
and t.groupcode = @GroupCode
and t.Payrollperiodenddate = @PPED
and 
(    (t.Inday = 1 and t.InTime >= '12/30/1899 04:00' )
  or (t.Inday = 7 and t.InTime <= '12/30/1899 23:59' )
  or ( (t.Inday = 2 and t.InTime >= '12/30/1899 00:00') and (t.Inday = 2 and t.OutTime <= '12/30/1899 08:00') )
  OR ( (t.Inday = 1 and t.InTime >= '12/30/1899 00:00') and (t.Inday = 1 and t.OutTime <= '12/30/1899 08:00') )
  or (t.Inday = 1 and t.ClockAdjustmentNo in('1','8'))
  or (t.Inday = 7 and t.ClockAdjustmentNo in('1','8'))
)
and t.Inday < 8 and t.OutDay < 8
and t.deptno in(71,72,73,74,75,79,80,81,82)
and t.ClockAdjustmentNo in('','8','1')
group by t.ssn, e.PrimarySite, t.DeptNo, e.Status,e.LastName, e.FirstName

update #tmpRecs 
  Set SiteNo = (Select top 1 d.SiteNo from TimeCurrent..tblEmplSites as d where 
                  d.Client = @Client
                  and d.GroupCode = @GroupCode
                  and d.SSN = #tmpRecs.SSN)
where SiteNo = 0 or SiteNo is NULL
/*
update #tmpRecs 
  Set DeptNo = (Select top 1 d.DeptNo from TimeCurrent..tblEmplSites_Depts as d where 
                  d.Client = @Client
                  and d.GroupCode = @GroupCode
                  and d.SiteNo = #tmpRecs.SiteNo
                  and d.SSN = #tmpRecs.SSN order by d.DeptSeq)
*/
update #tmpRecs
  Set PayRate = (Select d.PayRate from tblEmplNames_Depts as d where 
                  d.Client = @Client
                  and d.GroupCode = @GroupCode
                  and d.PayrollPeriodEndDate = @PPED
                  and d.Department = #tmpRecs.DeptNo
                  and d.SSN = #tmpRecs.SSN)


update #tmpRecs
  Set PayRate = 0.00 where PayRate is NULL

delete from #tmpRecs where TotHours < 23.50

-- Update Hours for CNA
--
update #tmpRecs Set BaylorHours = 6 where deptno in(74,75,81,82)

--update #tmpRecs 
--  Set BaylorHours = 30.00 - TotHours
--where deptNo in(74,75) and TotHours < 30.00

-- Update Hours for RN & LPN
--
update #tmpRecs Set BaylorHours = 8 where deptno in(71,72,73,79,80)

--update #tmpRecs 
--  Set BaylorHours = 32.00 - TotHours
--where deptNo in(71,72,73) and TotHours < 32.00

delete from #tmpRecs where BaylorHours <= 0.00

-- =============================================
-- Process each Baylor Record and add to tblTimeHistDetail and tblADjustments.
-- =============================================
DECLARE cBaylor CURSOR
READ_ONLY
FOR Select SSN, SiteNo, DeptNo, enStatus, BaylorHours, PayRate from #tmpRecs 

OPEN cBaylor

FETCH NEXT FROM cBaylor INTO @SSN, @SiteNo, @DeptNo, @enStatus, @BaylorHours, @PayRate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
      delete from tblTimeHistDetail where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'Y'
                and AdjustmentName = 'BAYLOR'
                and ClkTransNo = 847105      --Indicates system generated
                and SSN = @SSN
                and InDay = 4

      delete from [TimeCurrent].[dbo].[tblAdjustments] where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'Y'
                and AdjustmentName = 'BAYLOR'
                and IPAddr = '000.000.000.000'    --Indicates system generated
                and SSN = @SSN
                and WedVal > 0

      -- Set the Master Payroll Date to 1/1/1900 since Empl Calc is going to figure it out anyway
      --
      SET @MPD = '1/1/1900'

      BEGIN TRANSACTION
        -- Insert the time detail for this employee.
      
        Insert into [TimeHistory].[dbo].[tblTimeHistDetail]
        (Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, SiteNo, DeptNo, JobID, 
        TransDate, EmpStatus, BillRate, BillOTRate, BillOTRateOverride, PayRate, ShiftNo, InDay, 
        InTime, OutDay, OutTime, Hours, Dollars, TransType, AgencyNo, InSrc, OutSrc, ClockAdjustmentNo, 
        AdjustmentCode, AdjustmentName, DaylightSavTime, Holiday, HandledByImporter, ClkTransNo, UserCode )
        Values
        (@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, @DeptNo, 0, 
        @TransDate, @enStatus, 0.00, 0.00, 0.00, @PayRate, 1, 4, 
        '12/30/1899 00:00:00', 4, '12/30/1899 00:00:00', @BaylorHours, 0.00, '1', 0, '3', '3', 'Y', 
        '', 'BAYLOR', '0', '0', '', 847105, 'B_P')
      
        if @@Error <> 0 
        begin
          Set @SaveError = @@Error
          goto RollBackTransaction
        end  
        Set @RecordID = SCOPE_IDENTITY()
      
        -- Add the adjustment to tblAdjustments for auditing purposes and for physical clocks
        -- so it will get sent back to the time clock.
        INSERT INTO [TimeCurrent].[dbo].[tblAdjustments]([ReverseFlag], [OrigRecord_No], [Client], 
              [GroupCode], [PayrollPeriodEndDate], [SSN], [SiteNo], [DeptNo], [ClockAdjustmentNo], 
              [AdjustmentCode], [AdjustmentName], [HoursDollars], [MonVal], [TueVal], [WedVal], [ThuVal], 
              [FriVal], [SatVal], [SunVal], [WeekVal], [TotalVal], [AgencyNo], [UserName], [UserID], 
              [TransDateTime], [DeletedDateTime], [DeletedByUserName], [DeletedByUserID], [SweptDateTime], 
              [RecordStatus], [IPAddr], [ShiftNo])
        (Select '', RecordID, Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, ClockAdjustmentNo,
              'B_P', AdjustmentName, 'H', 
              Case when InDay = 2 then Hours else 0 end,
              Case when InDay = 3 then Hours else 0 end,
              Case when InDay = 4 then Hours else 0 end,
              Case when InDay = 5 then Hours else 0 end,
              Case when InDay = 6 then Hours else 0 end,
              Case when InDay = 7 then Hours else 0 end,
              Case when InDay = 1 then Hours else 0 end,
              Case when InDay < 1 or InDay > 7 then Hours else 0 end,
              Hours, AgencyNo, 'B_P',0,getdate(),null,null,0,null,'1','000.000.000.000',ShiftNo
        from tblTimeHistdetail
        where RecordID = @RecordID)
      
        if @@Error <> 0 
        begin
          Set @SaveError = @@Error
          goto RollBackTransaction
        end  
      
      COMMIT TRANSACTION

	END
	FETCH NEXT FROM cBaylor INTO @SSN, @SiteNo, @DeptNo, @enStatus, @BaylorHours, @PayRate
END

CLOSE cBaylor
DEALLOCATE cBaylor

Select Client = @Client, GroupCode = @GroupCode, PPED = @PPED, SSN, LastName, FirstName, BaylorHours from #tmpRecs 

drop table #tmpRecs

return

RollBackTransaction:
Rollback Transaction

return --@SaveError













