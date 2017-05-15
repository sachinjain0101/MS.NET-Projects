CREATE Procedure [dbo].[usp_APP_LSA_Calc_Baylor_Sun_Hickory]
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

Select @Client = 'LSA'
Select @GroupCode = 251103
Select @PPED = '11/29/2003'

drop table #tmpRecs
*/

DECLARE @MPD datetime
DECLARE @SSN int
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @enStatus char(1)
DECLARE @SaveError int
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 16Aug2016 >--

select t.ssn, SiteNo = e.PrimarySite, deptNo = e.Primarydept, enStatus = e.Status, e.LastName, e.FirstName,
SunInCnt = sum(case when t.inday = 1 
                    and t.intime >= '12/30/1899 06:20:00'
                    and t.intime <= '12/30/1899 06:40:00'
               Then 1 else 0 End ),
SunOutCnt = sum(case when t.Outday = 1 
                    and t.Outtime >= '12/30/1899 23:15:00'
                    and t.Outtime <= '12/30/1899 23:40:00'
               Then 1 else 0 End ),
SatInCnt = 0,
SatOutCnt = 0,
SunHrs = sum(case when inday = 1 then t.Hours else 0 end ),
SatHrs = 0
into #tmpRecs
from tblTimeHistDetail as t
inner join timecurrent..tblEmplnames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
where t.client = @Client
and t.groupcode = @GroupCode
and t.Payrollperiodenddate = @PPED
and datepart(weekday, t.TransDate) = 1
and t.deptno in(5,6,7,9,10,11,13,14,15,17,18,19,21,22,23)
group by t.ssn, e.PrimarySite, e.PrimaryDept, e.Status, e.LastName, e.FirstName

insert into #tmpRecs 
select t.ssn, SiteNo = e.PrimarySite, deptNo = e.Primarydept, enStatus = e.Status, e.LastName, e.FirstName,
SunInCnt = sum(case when datepart(weekday, t.transdate) = 1 
                    and t.intime >= '12/30/1899 14:20:00'
                    and t.intime <= '12/30/1899 14:40:00'
               Then 1 else 0 End ),
SunOutCnt = sum(case when datepart(weekday, t.transdate) = 1 
                    and t.Outtime >= '12/30/1899 07:15:00'
                    and t.Outtime <= '12/30/1899 07:40:00'
               Then 1 else 0 End ),
SatInCnt = 0,
SatOutCnt = 0,
SunHrs = sum(case when datepart(weekday, t.transdate) = 1 then t.Hours else 0 end ),
SatHrs = 0
from tblTimeHistDetail as t
inner join timecurrent..tblEmplnames as e
on e.client = t.client
and e.groupcode = t.groupcode
and e.ssn = t.ssn
where t.client = @Client
and t.groupcode = @GroupCode
and t.Payrollperiodenddate = @PPED
and datepart(weekday, t.TransDate) = 1
and t.deptno in(5,6,7,9,10,11,13,14,15,17,18,19,21,22,23)
group by t.ssn, e.PrimarySite, e.PrimaryDept, e.Status, e.LastName, e.FirstName

-- =============================================
-- 
-- =============================================
DECLARE cBaylor CURSOR
READ_ONLY
FOR Select SSN, SiteNo, DeptNo, enStatus from #tmpRecs 
where (SunInCnt >= 1 and SunOutCnt >= 1 and SunHrs >= 15.95)

OPEN cBaylor

FETCH NEXT FROM cBaylor INTO @SSN, @SiteNo, @DeptNo, @enStatus
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
      delete from tblTimeHistDetail where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'Y'
                and AdjustmentName = 'BAYLOR'
                and UserCode = 'B_P'
                and SSN = @SSN
                and InDay = 1

      delete from [TimeCurrent].[dbo].[tblAdjustments] where client = @Client
                and GroupCode = @GroupCode
                and PayrollPeriodEndDate = @PPED
                and ClockAdjustmentNo = 'Y'
                and AdjustmentName = 'BAYLOR'
                and IPAddr = '000.000.000.000'    --Indicates system generated
                and SSN = @SSN
                and SunVal > 0

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
        convert(char(10), @PPED,101), @enStatus, 0.00, 0.00, 0.00, 0.00, 1, 1, 
        '12/30/1899 00:00:00', 1, '12/30/1899 00:00:00', 4.00, 0.00, '1', 0, '3', '3', 'Y', 
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
	FETCH NEXT FROM cBaylor INTO @SSN, @SiteNo, @DeptNo, @enStatus
END

CLOSE cBaylor
DEALLOCATE cBaylor

Select Client = @Client, GroupCode = @GroupCode, PPED = @PPED, SSN, LastName, FirstName from #tmpRecs 
where (SunInCnt >= 1 and SunOutCnt >= 1 and SunHrs >= 15.95)

drop table #tmpRecs

return

RollBackTransaction:
Rollback Transaction

return @SaveError













