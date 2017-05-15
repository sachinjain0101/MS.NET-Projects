Create PROCEDURE [dbo].[usp_Tempo_Clock_CleanupDept9999] AS

SET NOCOUNT ON;

Create table #tmpRecords
(
	RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 25nOV2016 >--
	Client varchar(4),
	Groupcode int,
	Payrollperiodenddate datetime,
	SSN int,
	Deptno int,
	PrimaryDept int,
	Intime datetime,
	Shiftno int,
	dsShiftNo int,
	ShiftStart datetime,
	ShiftEnd datetime
)

DECLARE @Client varchar(4)
DECLARE @GroupCode int 
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >--
DECLARE @PrimaryDept int
DECLARE @JobID BIGINT  --< @JobId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >--
DECLARE @DateTime datetime
Set @DateTime = dateadd(day, -8, getdate())

Set @JobID = 99990000 + (MOnth(getdate()) * 100) + day(getdate())		-- For auditing.

DECLARE cSites CURSOR
READ_ONLY
FOR 
select Distinct Client, GroupCode
from TimeCurrent..tblSiteNames with(nolock)
where clockType = 'W' 
and datelastuploadcreated >= @DateTime
and client not in('CIG1','PNET' )


OPEN cSites

FETCH NEXT FROM cSites into @Client, @Groupcode 
WHILE (@@fetch_status <> -1)
BEGIN
IF (@@fetch_status <> -2)
	BEGIN
		insert into #tmpRecords
		select t.RecordID, t.client, t.GroupCode,t.Payrollperiodenddate, t.SSN, 
					 T.deptNo, en.PrimaryDept, t.InTime, t.ShiftNo,	s.ShiftNo, s.ShiftStart, s.ShiftEnd 
		from Timehistory..tblTimeHistdetail as t with(nolock)
		inner Join TimeCUrrent..tblEmplNames as en 
		on en.client = t.client
		and en.groupcode = t.groupcode
		and en.ssn = t.ssn
		Left Join TimeCurrent..tblDeptSHifts as s
		on s.client = en.client
		and s.groupcode = en.groupcode
		and s.deptno = en.PrimaryDept 
		where t.client = @Client
		and t.groupcode = @Groupcode 
		and t.PayrollPeriodEndDate >= @DateTime 
		and t.deptno = 9999	END
	FETCH NEXT FROM cSites into @Client, @Groupcode 
END

CLOSE cSites
DEALLOCATE cSites


DECLARE cUpdates CURSOR
READ_ONLY
FOR 
select RecordID, PrimaryDept from #tmpRecords

OPEN cUpdates

FETCH NEXT FROM cUpdates into @RecordID, @PrimaryDept 
WHILE (@@fetch_status <> -1)
BEGIN
IF (@@fetch_status <> -2)
	BEGIN
	Update TimeHistory..tblTimeHistDetail
		Set DeptNo = @PrimaryDept,
			ShiftNo = 0,
			JobID = @JobID
	where RecordID = @RecordID

	FETCH NEXT FROM cUpdates into @RecordID, @PrimaryDept 
	END
END

CLOSE cUpdates
DEALLOCATE cUpdates

delete from [TimeCurrent].[dbo].[tblWork_RecalcEmployees] where recalc = '9'

INSERT INTO [TimeCurrent].[dbo].[tblWork_RecalcEmployees]
           ([Client]
           ,[GroupCode]
           ,[PayrollPeriodEndDate]
           ,[SSN]
           ,[ShiftNo]
           ,[TotHours]
           ,[TotCalcHours]
           ,[Recalc])
select Distinct Client, GroupCode, Payrollperiodenddate, SSN, 0, 0, 0,'9'
from #tmpRecords as r

DECLARE @sSQL varchar(1500)
DECLARE @lJobID int

Set @sSQL = 'select *,lastname=''recalc'' from [TimeCurrent].[dbo].[tblWork_RecalcEmployees] with(nolock) where recalc = ''9'''

INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], [GroupCode], [PayrollPeriodEndDate], [Weekly])
VALUES('ReCalcEmpl',getdate(),null,null,null,@Client, 0, '1/1/2010','1')

Select @lJobId = SCOPE_IDENTITY()

INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
VALUES(@lJobID,'SQL',@sSQL)


DECLARE @HTML VARCHAR(8000)

SELECT @HTML = (
select  
r.Client + '</td><td>' + 
c.ClientName + '</td><td>' +  
ltrim(str(r.GroupCode)) + '</td><td>' +  
g.groupName + '</td><td>' +  
ltrim(str(sn.SiteNo)) + '</td><td>' + 
sn.Exportmailbox + '</td><td>' + 
sn.sitename  + '</td><td>' + 
sn.ClockVersion  + '</td><td>' + 
ltrim(str(sum(1))) as td
from [TimeCurrent].[dbo].[tblWork_RecalcEmployees] as r
Inner Join TImeCurrent..tblCLients as c on c.client = r.client
inner join timecurrent..tblCLientgroups as g on g.client = r.client and g.groupcode = r.groupcode
inner join timecurrent..tblsitenames as sn on sn.client = r.client and sn.groupcode = r.groupcode and sn.clocktype = 'W' and sn.recordstatus = '1'
where r.recalc = '9' 
group by r.CLient, c.clientname, r.groupcode, g.groupname, sn.siteno, sn.exportmailbox, sn.sitename, sn.Clockversion
FOR XML path( 'tr' ))

Set @HTML = replace(@HTML, '&lt;/td&gt;', '</td>')
Set @HTML = replace(@HTML, '&lt;td&gt;', '<td>')
SET @HTML = '<HTML><BR>TEMPO CLOCK DEPT 9999 ALERT<BR><TABLE border="1" cellpadding="3"><TR><td>Client</td><td>ClientName</td><td>GroupCode</td><td>GroupName</td><td>Site</td><td>TermID</td><td>SiteName</td><td>Version</td><td>Punches</td></TR>' + @HTML + '</TABLE></HTML>'

--PRINT @HTML

Set @Client = 'PNET'
Set @GroupCode = 0
DECLARE @SiteNo int = 0
DECLARE @MailTo varchar(512) = 'dale.humphries@peoplenet.com,Randy.Young@peoplenet.com,Yecid.Gomez@peoplenet.com'
DECLARE @MailFrom varchar(50) = 'reports@peoplenet-us.com'
DECLARE @MailFromDesc varchar(50) = 'Tempo Clock Alert'
DECLARE @MailCC varchar(500) = ''
DECLARE @MailBCC varchar(500) = ''
DECLARE @MailSubject varchar(500) = 'TEMPO CLOCK DEPT 9999 ALERT'
DECLARE @MailMessage varchar(8000)
DECLARE @MailAttachment varchar(256) = ''
DECLARE @SendasHTML tinyint = 1
DECLARE @Source varchar(50) = 'SQL Script'
DECLARE @Priority tinyint = 1

Set @MailMessage = @HTML

EXECUTE [Scheduler].[dbo].[usp_Email_SendDirect] 
   @Client
  ,@GroupCode
  ,@SiteNo
  ,@MailTo
  ,@MailFrom
  ,@MailFromDesc
  ,@MailCC
  ,@MailBCC
  ,@MailSubject
  ,@MailMessage
  ,@MailAttachment
  ,@SendAsHTML
  ,@Source
  ,@Priority
