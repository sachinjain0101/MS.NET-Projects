Create PROCEDURE [dbo].[usp_Web1_TaskPanel_GetValidationErrors_Summ]
(
  @Client varchar(4),
  @UserID int
)
AS
SET NOCOUNT ON 

IF @Client = 'HCPA'
BEGIN
  EXEC TimeHistory.dbo.usp_Web1_TaskPanel_GetValidationErrors_Summ_HCPA @Client, @UserID
  Return
END

DECLARE @PPED Datetime
DECLARE @PPED2 datetime
Set @PPED = (select MIN(MasterPayrollDate) from TimeHistory..tblPeriodEndDates where client = 'DAVT' and Status <> 'C' and groupcode not in(509900,503900))
Set @PPED2 = dateadd(day,-7,@PPED)

Declare @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 12Oct2016 >--
Set @JobID = (select max(jobID) from refreshwork.[dbo].[tblWork_DAVT_DeptRefresh_Audit] with(nolock))

-- Invalid Combinations..

-- Missing Empl ID with time

-- Site not setup in Dept Refresh

-- Salary teammates w/ time in two groups

-- 
Declare @tmpCount table
(
  PPED varchar(20)
  ,groupcode int
  ,TransCount int
)

Insert into @tmpCount
select 
PPED = convert(varchar(12),t.Payrollperiodenddate, 101),
t.Groupcode, 
TransCount = sum(1)
from Timehistory..tblTimeHistdetail as t with (nolock)
Inner Join TimeCurrent..tblClientGroups as g
on g.client = t.client and g.groupcode = t.groupcode 
inner join TImeCurrent..tblSIteNames as sn with (nolock)
on sn.client = t.Client
and sn.siteno = t.siteno 
inner join TimeCurrent..tblEmplNames as en with(nolock)
on en.client = t.client and en.groupcode = t.groupcode and en.ssn = t.ssn 
left Join TimeCurrent..tblDeptNames as dn with (nolock)
on dn.Client = sn.Client
and dn.Groupcode = sn.groupcode
and dn.SiteNo = sn.SiteNo
and dn.DeptNo = t.DeptNo
where
t.Client = 'DAVT'
--and t.groupcode <> 509300
and t.Payrollperiodenddate in(@PPED, @PPED2)
and isnull(t.crossoverstatus,'') <> '2'
and isnull(dn.recordstatus,'0') = '0'
AND t.deptno <> 88        -- skip travel department
--and en.PayType = 0
Group BY 
t.Payrollperiodenddate, 
t.Groupcode, 
G.GroupName

Insert into @tmpCount
select 
PPED = convert(varchar(12),@PPED, 101),
Groupcode,
Sum(1)
from refreshwork.[dbo].[tblWork_DAVT_DeptRefresh_Audit] with(nolock)
where jobid = @JobID
and ActionDesc like 'Validation%'
group by
Groupcode

Insert into @tmpCount
select 
PPED = convert(varchar(12),en.Payrollperiodenddate, 101),
en.Groupcode,
Sum(1)
from TimeHistory..tblEmplnames as en with(nolock)
Inner Join TimeCurrent..tblClientGroups as g
on g.client = en.client
and g.groupcode = en.groupcode 
where en.client = @Client
and en.payrollperiodenddate in(@PPED, @PPED2)
and en.HasTrans = 1
and ( len(isnull(en.fileNo,'')) <> 6 or (left(en.fileNo,1) = '9' and len(fileno) = 6) )
and en.agencyNo <= 3
group by
en.PayrollPeriodEndDate , en.groupcode 

select c.PPED, c.GroupCode, g.GroupName, TransCount = sum(TransCount)
from @tmpCount as c
Inner Join TimeCurrent..tblClientGroups as g
on g.client = 'DAVT'
and g.groupcode = c.groupcode
group by c.PPED, c.groupcode, g.GroupName
order by GroupName, PPED
