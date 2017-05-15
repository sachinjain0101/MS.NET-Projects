CREATE            procedure [dbo].[usp_CigTrans_GetTimeHistDetail](
   @RecordId BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 22Aug2016 >--
)
AS

--*/

/*
declare @Client char(4)
declare @GroupCode int 
declare @Siteno int 

select @Client 			= 'GAMB'
select @GroupCode 		= 720200
select @SiteNo  			= 540829437
*/

SET NOCOUNT ON

select clocktype = case when sn.clocktype not in('T','V') then 'J' else sn.clocktype end
, sn.QtrHourRounding
, sn.TenthHourRounding
, cg.fixpunchgensbreak, cg.AuditNewPunch, cg.AuditFixPunch, cg.AutoPunchOutIfChangeDepartments
, thd.RecordId, thd.Client, thd.GroupCode, thd.SiteNo
, thd.DeptNo, thd.SSN, thd.PayrollPeriodEndDate, thd.TransDate
, thd.InDay, thd.InTime, thd.OutDay, thd.OutTime, thd.ActualInTime, thd.ActualOutTime
, thd.ClkTransNo, thd.DaylightSavTime, thd.InSrc, thd.OutSrc
, thd.MasterPayrollDate, thd.JobId, thd.BillRate, thd.BillOTRate, thd.BillOTRateOverride, thd.PayRate
, thd.ShiftNo, thd.Hours, thd.Dollars, thd.ClockAdjustmentNo, thd.AdjustmentCode, thd.AdjustmentName, thd.AgencyNo
, thd.Holiday, thd.EmpStatus, thd.TransType
, isnull(sn.MaxWorkSpan, 16) as MaxWorkSpan
from timehistory..tbltimehistdetail thd
inner join timecurrent..tblsitenames sn
  on thd.client = sn.client
  and thd.groupcode = sn.groupcode
  and sn.recordstatus = '1'
inner join timecurrent..tblclientgroups cg
  on thd.client = cg.client
  and thd.groupcode = cg.groupcode
  and cg.recordstatus = '1'
where thd.recordid = @recordid






