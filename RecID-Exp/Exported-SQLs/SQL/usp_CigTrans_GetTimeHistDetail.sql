USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_CigTrans_GetTimeHistDetail]    Script Date: 3/31/2015 11:53:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CigTrans_GetTimeHistDetail]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_CigTrans_GetTimeHistDetail] AS' 
END
GO






/*

exec timehistory..usp_CigTrans_GetTimeHistDetail 'GAMB',101000,2562037

EXEC sp_changeobjectowner 'usp_CigTrans_GetTimeHistDetail', 'dbo'
*/

--/*
ALTER            procedure [dbo].[usp_CigTrans_GetTimeHistDetail](
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






GO
