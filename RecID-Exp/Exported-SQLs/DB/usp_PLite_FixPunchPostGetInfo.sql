CREATE  Procedure [dbo].[usp_PLite_FixPunchPostGetInfo]
  (
     @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
  )
AS


Select en.ShiftClass, en.Status, sn.WeekClosedDateTime, sn.CloseHour from
TimeHistory..tblTimeHistDetail as thd
Left Join TimeCurrent..tblEmplNames as en
on en.Client = thd.Client
and en.GroupCode = thd.GroupCode
and en.SSN = thd.SSN
Left Join TimeHistory..tblSiteNames as sn
on sn.CLient = thd.Client
and sn.GroupCode = thd.GroupCode
and sn.SiteNo = thd.SiteNo
and sn.PayrollPeriodEndDate = thd.PayrollPeriodEndDate
where thd.RecordID = @RecordID





