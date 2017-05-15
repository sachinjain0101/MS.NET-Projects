Create PROCEDURE [dbo].[usp_APP_SuntoryUpload]

	(
		@Client  Char(4),
		@GroupCode  Int,
		@PayrollDate DateTime
	)
As
--*/

-- If GroupCode parameter is zero then Recordset will include all groups
-- Returns: GroupCode, CompID, ssn,  ProID, Code,Amount ,  AmountType,  CodeType, Division, Department

	 set nocount on 
/*
DECLARE @GroupCode As Int
DECLARE @Client As Char(4)
DECLARE @PayrollDate As DateTime

Set @Client = 'SUNT'
Set @GroupCode = 528900
Set @Payrolldate = '3/29/02'
drop table #SuntoryUpLoad

*/


CREATE TABLE #SuntoryUpload (
	[GroupCode] Int NULL ,
	[SSN] Int NULL ,
	[SiteNo] INT NULL ,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
	[DeptNo] INT NULL ,  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
	[Code] [varchar] (10) NULL ,
	[Amount] [numeric](10, 2) NULL,
	[AmountType] char(1) NULL)
  

if @Payrolldate <= '4/5/02'
BEGIN
  -- Run special section that is set for weekly only for 3/29/02 and 4/5/02 pay periods

  -- Add regular hours
  
  Insert Into #SuntoryUpload
  Select th.GroupCode,th.ssn, th.SiteNo, th.DeptNo, '105', Sum(th.RegHours),'H'
  From TimeHistory..tblTimeHistDetail As th
  Inner Join TimeCurrent..tblSiteNames as SN On
  th.Client = SN.Client And
  th.GroupCode  = SN.GroupCode  And
  th.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Where th.Client = @Client and
  ((th.GroupCode = @GroupCode) OR (@GroupCode = 0)) and
  th.PayrollPeriodEndDate = @PayrollDate and
  ((th.ClockAdjustmentNo = ' ') Or (th.ClockAdjustmentNo = '1') Or (th.ClockAdjustmentNo = '8'))
  and th.RegHours <> 0 
  Group By th.GroupCode,th.ssn, th.SiteNo, th.DeptNo
  
  -- Add OT hours 
  
  Insert Into #SuntoryUpload
  Select th.GroupCode,ssn, th.SiteNo, th.DeptNo, '135',Sum(th.OT_Hours),'H'
  From TimeHistory..tblTimeHistDetail as th
  Inner Join TimeCurrent..tblSiteNames as SN On
  th.Client = SN.Client And
  th.GroupCode  = SN.GroupCode  And
  th.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Where th.Client = @Client and
  ((th.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  th.PayrollPeriodEndDate = @PayrollDate and
  ((th.ClockAdjustmentNo = ' ') Or (th.ClockAdjustmentNo = '1') Or (th.ClockAdjustmentNo = '8'))
  and th.OT_Hours <> 0 
  Group By th.GroupCode, th.ssn, th.SiteNo, th.DeptNo
  
  -- Add DT hours 
  
  Insert Into #SuntoryUpload
  Select th.GroupCode,th.ssn, th.SiteNo, th.DeptNo, '140',Sum(th.DT_Hours),'H'
  From TimeHistory..tblTimeHistDetail as th
  Inner Join TimeCurrent..tblSiteNames as SN On
  th.Client = SN.Client And
  th.GroupCode  = SN.GroupCode  And
  th.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Where th.Client = @Client and
  ((th.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  th.PayrollPeriodEndDate = @PayrollDate and
  ((th.ClockAdjustmentNo = ' ') Or (th.ClockAdjustmentNo = '1') Or (th.ClockAdjustmentNo = '8'))
  and th.DT_Hours <> 0 
  Group By th.GroupCode,th.ssn, th.SiteNo, th.DeptNo
  
  -- Add Hourly Adjustments
  
  Insert Into #SuntoryUpload
  Select thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo, 
  ac.AdjustmentCode, Sum(thd.Hours) ,'H'
  From TimeHistory..tblTimeHistDetail as thd
  Inner Join TimeCurrent..tblSiteNames as SN On
  thd.Client = SN.Client And
  thd.GroupCode  = SN.GroupCode  And
  thd.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Left Join TimeCurrent..tblAdjCodes as ac On
  ac.Client = thd.Client and
  ac.GroupCode = thd.GroupCode and
  ac.ClockAdjustmentNo = thd.ClockAdjustmentNo
  Where thd.Client = @Client and
  ((thd.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  thd.PayrollPeriodEndDate = @PayrollDate and
  thd.ClockAdjustmentNo NOT IN(' ','','1','S','8')
  and thd.Hours <> 0 
  Group By thd.Groupcode, thd.ssn, thd.SiteNo, thd.DeptNo, ac.AdjustmentCode
  
  
  -- Add Dollar Adjustments
  
  Insert Into #SuntoryUpload
  Select thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo, 
  ac.AdjustmentCode, Sum(thd.Dollars) ,'$'
  From TimeHistory..tblTimeHistDetail as thd
  Inner Join TimeCurrent..tblSiteNames as SN On
  thd.Client = SN.Client And
  thd.GroupCode  = SN.GroupCode  And
  thd.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Left Join TimeCurrent..tblAdjCodes as ac On
  ac.Client = thd.Client and
  ac.GroupCode = thd.GroupCode and
  ac.ClockAdjustmentNo = thd.ClockAdjustmentNo
  Where thd.Client = @Client and
  ((thd.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  thd.PayrollPeriodEndDate = @PayrollDate and
  ((thd.ClockAdjustmentNo <> ' ') And (thd.ClockAdjustmentNo <> '1') And (thd.ClockAdjustmentNo <> '8'))
  and thd.Hours = 0 and thd.Dollars <> 0
  Group By thd.Groupcode, thd.ssn, thd.SiteNo, thd.DeptNo, ac.AdjustmentCode
  
  
  
  -- Reverse Salary Adjustments
  
  Insert Into #SuntoryUpload
  Select thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo,  
  CASE WHEN en.substatus3 in ('5','6') THEN 'HRS' ELSE '100' END,
  Sum(thd.RegHours) * -1 , 'H'
  From TimeHistory..tblTimeHistDetail as thd
  Inner Join TimeCurrent..tblSiteNames as SN On
  thd.Client = SN.Client And
  thd.GroupCode  = SN.GroupCode  And
  thd.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Left Join TimeCurrent..tblEmplNames as en On
  en.Client = thd.Client And
  en.GroupCode = thd.GroupCode And
  en.SSN = thd.SSN
  Where thd.Client = @Client and
  ((thd.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  thd.PayrollPeriodEndDate = @PayrollDate and
  thd.ClockAdjustmentNo NOT IN(' ','','S','1','8')
  and thd.RegHours <> 0 
  and en.paytype = '1'
  Group By thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo,  
  CASE WHEN en.substatus3 in ('5','6') THEN 'HRS' ELSE '100' END
  
  -- Select * From #suntoryUpload Where Amount <> 0 order by ProID 
  
  Select su.GroupCode,cg.ADP_CompanyCode as CompID, su.ssn, en.FileNo as ProID, 
  su.Code,
  su.Amount , su.AmountType, 'E' as CodeType,
  en.DivisionID As Division, 
  (LTRIM(gd.ClientDeptCode) + en.SubStatus1 + en.SubStatus2 + en.SubStatus3) As Department, su.DeptNo
  From #suntoryupload as su
  Left Join TimeCurrent..tblClientGroups as cg On
  cg.Client = @Client And
  cg.GroupCode = su.GroupCode
  Left Join TimeCurrent..tblEmplNames as en On
  en.Client = @Client And
  en.GroupCode = su.GroupCode And
  en.SSN = su.SSN
  Left Join TimeCurrent..tblGroupDepts as gd on
  gd.Client = @Client and
  gd.Groupcode = su.GroupCode and
  gd.Deptno = su.DeptNo
  Left Join TimeCurrent..tblSiteNames as sn on
  sn.Client = @Client and
  sn.Groupcode = su.GroupCode and
  sn.SiteNo = su.SiteNo
  Order by en.FileNo, su.Code
  
  Drop Table #suntoryupload
END
ELSE
BEGIN

  -- Add regular hours
  
  Insert Into #SuntoryUpload
  Select th.GroupCode,th.ssn, th.SiteNo, th.DeptNo, '105', Sum(th.RegHours),'H'
  From TimeHistory..tblTimeHistDetail As th
  Inner Join TimeCurrent..tblSiteNames as SN On
  th.Client = SN.Client And
  th.GroupCode  = SN.GroupCode  And
  th.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Where th.Client = @Client and
  ((th.GroupCode = @GroupCode) OR (@GroupCode = 0)) and
  th.MasterPayrollDate = @PayrollDate and
  ((th.ClockAdjustmentNo = ' ') Or (th.ClockAdjustmentNo = '1') Or (th.ClockAdjustmentNo = '8'))
  and th.RegHours <> 0 
  Group By th.GroupCode,th.ssn, th.SiteNo, th.DeptNo
  
  -- Add OT hours 
  
  Insert Into #SuntoryUpload
  Select th.GroupCode,ssn, th.SiteNo, th.DeptNo, '135',Sum(th.OT_Hours),'H'
  From TimeHistory..tblTimeHistDetail as th
  Inner Join TimeCurrent..tblSiteNames as SN On
  th.Client = SN.Client And
  th.GroupCode  = SN.GroupCode  And
  th.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Where th.Client = @Client and
  ((th.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  th.MasterPayrollDate = @PayrollDate and
  ((th.ClockAdjustmentNo = ' ') Or (th.ClockAdjustmentNo = '1') Or (th.ClockAdjustmentNo = '8'))
  and th.OT_Hours <> 0 
  Group By th.GroupCode, th.ssn, th.SiteNo, th.DeptNo
  
  -- Add DT hours 
  
  Insert Into #SuntoryUpload
  Select th.GroupCode,th.ssn, th.SiteNo, th.DeptNo, '140',Sum(th.DT_Hours),'H'
  From TimeHistory..tblTimeHistDetail as th
  Inner Join TimeCurrent..tblSiteNames as SN On
  th.Client = SN.Client And
  th.GroupCode  = SN.GroupCode  And
  th.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Where th.Client = @Client and
  ((th.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  th.MasterPayrollDate = @PayrollDate and
  ((th.ClockAdjustmentNo = ' ') Or (th.ClockAdjustmentNo = '1') Or (th.ClockAdjustmentNo = '8'))
  and th.DT_Hours <> 0 
  Group By th.GroupCode,th.ssn, th.SiteNo, th.DeptNo
  
  -- Add Hourly Adjustments
  
  Insert Into #SuntoryUpload
  Select thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo, 
  ac.AdjustmentCode, Sum(thd.Hours) ,'H'
  From TimeHistory..tblTimeHistDetail as thd
  Inner Join TimeCurrent..tblSiteNames as SN On
  thd.Client = SN.Client And
  thd.GroupCode  = SN.GroupCode  And
  thd.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Left Join TimeCurrent..tblAdjCodes as ac On
  ac.Client = thd.Client and
  ac.GroupCode = thd.GroupCode and
  ac.ClockAdjustmentNo = thd.ClockAdjustmentNo
  Where thd.Client = @Client and
  ((thd.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  thd.MasterPayrollDate = @PayrollDate and
  thd.ClockAdjustmentNo NOT IN(' ','','1','S','8')
  and thd.Hours <> 0 
  Group By thd.Groupcode, thd.ssn, thd.SiteNo, thd.DeptNo, ac.AdjustmentCode
  
  
  -- Add Dollar Adjustments
  
  Insert Into #SuntoryUpload
  Select thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo, 
  ac.AdjustmentCode, Sum(thd.Dollars) ,'$'
  From TimeHistory..tblTimeHistDetail as thd
  Inner Join TimeCurrent..tblSiteNames as SN On
  thd.Client = SN.Client And
  thd.GroupCode  = SN.GroupCode  And
  thd.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Left Join TimeCurrent..tblAdjCodes as ac On
  ac.Client = thd.Client and
  ac.GroupCode = thd.GroupCode and
  ac.ClockAdjustmentNo = thd.ClockAdjustmentNo
  Where thd.Client = @Client and
  ((thd.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  thd.MasterPayrollDate = @PayrollDate and
  ((thd.ClockAdjustmentNo <> ' ') And (thd.ClockAdjustmentNo <> '1') And (thd.ClockAdjustmentNo <> '8'))
  and thd.Hours = 0 and thd.Dollars <> 0
  Group By thd.Groupcode, thd.ssn, thd.SiteNo, thd.DeptNo, ac.AdjustmentCode
  
  
  
  -- Reverse Salary Adjustments
  
  Insert Into #SuntoryUpload
  Select thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo,  
  CASE WHEN en.substatus3 in ('5','6') THEN 'HRS' ELSE '100' END,
  Sum(thd.RegHours) * -1 , 'H'
  From TimeHistory..tblTimeHistDetail as thd
  Inner Join TimeCurrent..tblSiteNames as SN On
  thd.Client = SN.Client And
  thd.GroupCode  = SN.GroupCode  And
  thd.SiteNo = SN.SiteNo And
  SN.IncludeInUpload = '1'
  Left Join TimeCurrent..tblEmplNames as en On
  en.Client = thd.Client And
  en.GroupCode = thd.GroupCode And
  en.SSN = thd.SSN
  Where thd.Client = @Client and
  ((thd.GroupCode = @GroupCode) or (@GroupCode = 0)) and
  thd.MasterPayrollDate = @PayrollDate and
  thd.ClockAdjustmentNo NOT IN(' ','','S','1','8')
  and thd.RegHours <> 0 
  and en.paytype = '1'
  Group By thd.GroupCode, thd.ssn, thd.SiteNo, thd.DeptNo,  
  CASE WHEN en.substatus3 in ('5','6') THEN 'HRS' ELSE '100' END
  
  -- Select * From #suntoryUpload Where Amount <> 0 order by ProID 
  
  Select su.GroupCode,cg.ADP_CompanyCode as CompID, su.ssn, en.FileNo as ProID, 
  su.Code,
  su.Amount , su.AmountType, 'E' as CodeType,
  en.DivisionID As Division, 
  (LTRIM(gd.ClientDeptCode) + en.SubStatus1 + en.SubStatus2 + en.SubStatus3) As Department, su.DeptNo
  From #suntoryupload as su
  Left Join TimeCurrent..tblClientGroups as cg On
  cg.Client = @Client And
  cg.GroupCode = su.GroupCode
  Left Join TimeCurrent..tblEmplNames as en On
  en.Client = @Client And
  en.GroupCode = su.GroupCode And
  en.SSN = su.SSN
  Left Join TimeCurrent..tblGroupDepts as gd on
  gd.Client = @Client and
  gd.Groupcode = su.GroupCode and
  gd.Deptno = su.DeptNo
  Left Join TimeCurrent..tblSiteNames as sn on
  sn.Client = @Client and
  sn.Groupcode = su.GroupCode and
  sn.SiteNo = su.SiteNo
  Order by en.FileNo, su.Code
  
  Drop Table #suntoryupload

END



