CREATE procedure [dbo].[usp_ALERT_DupPunch]
(
	@Client varchar(4),
	@Groupcode int = 0,
	@Emails varchar(400) = ''
)

AS


Set nocount on

DECLARE @PPED datetime
DECLARE @SSN int
DECLARE @ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--

Create table #tmpPunches
(
	PPED date,
	GroupCode int,
	SSN int,
	Intime datetime,
	OutTime datetime,
	Hours numeric(7,2),
	ClkTransNo BIGINT  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
)

if @Groupcode > 0
BEGIN
	DECLARE cGroups CURSOR
	READ_ONLY
	FOR 
	select GroupCode, PayrollPeriodenddate 
	from TimeHistory..tblPeriodenddates 
	where client = @Client 
	and Groupcode = @Groupcode 
	and MasterPayrollDate >= '10/1/14' 
	and Status <> 'C'
END
ELSE
BEGIN
	DECLARE cGroups CURSOR
	READ_ONLY
	FOR 
	select GroupCode, PayrollPeriodenddate 
	from TimeHistory..tblPeriodenddates 
	where client = @Client 
	and MasterPayrollDate >= '10/1/14' 
	and Status <> 'C'
END

OPEN cGroups

FETCH NEXT FROM cGroups INTO @GroupCode, @PPED
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Insert into #tmpPunches
		select PayrollPeriodenddate, 
		GroupCode, 
		SSN, 
		timehistory.dbo.PunchDateTime2(Transdate,inday,intime),  
		timehistory.dbo.PunchDateTime2(Transdate,Outday,Outtime),  
		Hours,
		ClkTransNo 
		from TimeHistory..tblTImeHistDetail with(nolock) 
		where client = @Client
		and groupcode = @GroupCode
		and PayrollPeriodEndDate = @PPED
		and clockadjustmentNo in('',' ')
		and TransType <> '7'
		and Inday < 8
		and outday < 8
		and hours <> 0
	END
	FETCH NEXT FROM cGroups INTO @GroupCode, @PPED
END

CLOSE cGroups
DEALLOCATE cGroups


Create Table #tmpDups
(
	PPED date,
	GroupCode int,
	SSN int,
	InTIme datetime,
	Hours numeric(7,2),
	ClkTransNo BIGINT,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
	DupCount int
)

Create Table #tmpAllDups
(
	PPED date,
	GroupCode int,
	SSN int,
	InTIme datetime,
	Hours numeric(7,2),
	ClkTransNo BIGINT,  --< @ClkTransNo data type is changed from  INT to BIGINT by Srinsoft on 21Sept2016 >--
	DupCount int
)

Insert into #tmpDups 
select PPED, GroupCode, SSN, InTIme, Hours, ClkTransNo, sum(1) 
from #tmpPunches 
group by PPED, GroupCOde, SSN, Intime , Hours, ClkTransNo
having sum(1) > 1 

Insert into #tmpAllDups 
select PPED, GroupCode, SSN, InTIme, Hours, 0 , sum(1) 
from #tmpPunches 
group by PPED, GroupCOde, SSN, Intime , Hours
having sum(1) > 1 

DECLARE @HTML VARCHAR(8000)

SELECT @HTML = ( 
SELECT g.GroupName + '</td><td>' + 
 en.FileNo + ' ' +  en.LastName + ',' + en.FirstName  + '</td><td>' + 
 convert(varchar(32),d.Intime,100)
from #tmpAllDups as d
inner Join TImeCurrent..tblEmplNames as en with(nolock)
on en.client = @Client
and en.groupcode = d.groupcode
and en.ssn = d.ssn
Inner Join TimeCurrent..tblClientGroups as g with(nolock)
on g.client = @Client 
and g.groupcode = d.groupcode 
order by g.GroupName, en.FileNo
FOR XML path( 'tr' )
)

Set @HTML = replace(@HTML, '&lt;/td&gt;', '</td>')
Set @HTML = replace(@HTML, '&lt;td&gt;', '<td>')

SELECT @HTML = '<HTML><TABLE border="1" cellpadding="3"><TR><td>Group</td><td>Empl ID - Name</td><td>Dup Punch</td></TR>' + @HTML + '</TABLE></HTML>'

Print @HTML

EXEC Scheduler..usp_Email_SendDirect 
	@Client
	, 0
	, 0
	, @Emails
	, 'Reports@Peoplenet-us.com'
	, 'Peoplenet Alert'
	, ''
	, ''
	, 'Duplicate Punch Alert'
	, @HTML
	, ''
	, '1'
	, 'DupPunchAlert'
	, 1

Drop table #tmpPunches
Drop table #tmpAllDups 
Drop table #tmpDups 



