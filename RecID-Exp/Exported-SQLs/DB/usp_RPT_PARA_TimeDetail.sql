CREATE  Procedure [dbo].[usp_RPT_PARA_TimeDetail]
(
	@Client varchar(4),
	@Group int,
	@Date datetime,
  @Sites varchar(1024),
  @Dept varchar(1024),
  @Shift varchar(32),
  @TranDate varchar(20) = 'ALL',
	@ClusterID int = 4
)
AS


/*
DECLARE	@Client varchar(4)
DECLARE	@Group int
DECLARE	@Date datetime
DECLARE  @Sites varchar(1024)
DECLARE  @Dept varchar(1024)
DECLARE  @Shift varchar(32)
DECLARE  @TranDate varchar(20)
DECLARE	@ClusterID int


Set @Client = 'STFM'
Set @Group = 525400
Set @Date = '3/2/08'
Set @Sites = 'all'
set @dept = 'all'
set @shift = 'all'
set @TranDate = 'xss'
Set @ClusterID = 4
*/

Set NOCOUNT ON

DECLARE @tDate datetime
DECLARE @DOW int

if isNULL(@Sites,'') = ''
	Set @Sites = 'ALL'

If isNULL(@Dept,'') = ''
	Set @Dept = 'ALL'

If isNULL(@Shift,'') = ''
	Set @Shift = 'ALL'

select en.LastName, en.FirstName, en.FileNo, t.RecordID, t.SSN,
t.ShiftNo, 
t.deptNo, gd.deptName_Long,
DOWName = Left(datename(weekday,t.TransDate),3),
t.TransDate, 
InAdjFlag = case when inSrc = '3' then case when isnull(t.AdjustmentName,'') <> '' then t.ADjustmentName else 'Adj' end else '' end, t.InTime, t.ActualInTime, 
OutAdjFlag = case when OutSrc = '3' then 'Adj' else '' end, t.OutTime, t.ActualOutTime,
AdjHours = cast(0.00 as numeric(6,2)),
t.RegHours,
t.OT_Hours,
t.BillRate
into #tmpPunches
from TimeHistory..tblTimeHistDetail as t
Inner Join TimeCurrent..tblEmplNames as en
on en.client = t.Client 
and en.Groupcode = t.groupcode
and en.SSN = t.SSN
Inner Join TimeCurrent..tblGroupDepts as gd
on gd.Client = t.Client
and gd.Groupcode = T.groupcode
and gd.DeptNo = t.DeptNo
where t.Client = @Client
and t.Groupcode = @Group
and t.Payrollperiodenddate = @Date
and t.ClockADjustmentNo not in('1','8')
and TimeHistory.dbo.usp_GetTimeHistoryClusterDefAsFn(@Group,t.SiteNo, t.DeptNo, t.AgencyNo, t.SSN, en.DivisionID, t.shiftNo, @ClusterID) = 1
and TimeCurrent.dbo.fn_InCSV(@Sites,ltrim(str(t.SiteNo)),1) = 1
and TimeCurrent.dbo.fn_InCSV(@Dept,ltrim(str(t.deptNo)),1) = 1
and TimeCurrent.dbo.fn_InCSV(@Shift,ltrim(str(t.ShiftNo)),1) = 1

Set @TranDate = isnull(@TranDate, 'ALL')

IF @TranDate <> 'ALL'
BEGIN
  Set @tDate = '1/1/1970'
  --YesterDay
  IF @TranDate = '0'
  BEGIN
    Set @tDate = convert(varchar(12), getdate(), 101)
    Set @tDate = dateadd(day, -1, @tDate)
  END
  -- Sunday (1) through Saturday (7)
  IF @TranDate in('1','2','3','4','5','6','7')
  BEGIN
    Set @DOW = cast(@TranDate as int)
    Set @tDate = @Date
    while datepart(weekday,@tDate) <> @DOW
    begin
       Set @tDate = dateadd(day, -1, @tDate)
    end
  END
  IF @tDate <> '1/1/1970'
    Delete from #tmpPunches where TransDate <> @tDate

END


DECLARE cPunches CURSOR
READ_ONLY
FOR Select RecordID, SSN, TransDate from #tmpPunches
order by SSN, TransDate, ActualInTime

DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 31Aug2016 >--
DECLARE @SSN int
DECLARE @recTransDate datetime
DECLARE @AdjHoursReg numeric(9,2)
DECLARE @AdjHoursOT numeric(9,2)

DECLARE @savTransDate datetime
DECLARE @savSSN int
Set @savTransDate = '1/1/2000'
Set @SavSSN = 0

OPEN cPunches

FETCH NEXT FROM cPunches INTO @RecordID, @SSN, @recTransDate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		IF @SavTransDate <> @recTransDate OR @SSN <> @SavSSN
		BEGIN
			Set @savTransDate = @recTransDate
			Set @savSSN = @SSN
			Set @AdjHoursReg = 0
			Set @AdjHoursOT = 0
			Select @AdjHoursReg = SUM(RegHours), @AdjHoursOT = Sum(OT_Hours) 
			from TimeHistory..tblTimeHistDetail 
			where Client = @Client
			and Groupcode = @Group
			and Payrollperiodenddate = @Date
			and SSN = @SSN
			and TransDate = @recTransDate
			and ClockADjustmentNo in('1','8')

			Update #tmpPunches
				Set AdjHours = isnull(@AdjHoursReg,0) + isnull(@ADjHoursOT,0),
						RegHours = RegHours + (isnull(@AdjHoursReg,0)),
						OT_Hours = OT_Hours + (isnull(@AdjHoursOT,0))
			where RecordID = @RecordID
		END
	END
	FETCH NEXT FROM cPunches INTO @RecordID, @SSN, @recTransDate
END

CLOSE cPunches
DEALLOCATE cPunches

Select lastName, FirstName, FileNo, 
SSN = right(str(SSN),4), 
ShiftNo, DeptName_Long,
DowName, TransDate, 
InAdjFlag, 
InTime = Convert( varchar(5), InTime, 108), 
ActualInTime = convert(varchar(5), ActualInTime, 108),
OutAdjFlag,
OutTime = convert(varchar(5), OutTime, 108),
ActualOutTime = convert(varchar(5),ActualOutTime,108),ADjHours,RegHours, OT_Hours,BillRate,
TotHours = (RegHours + OT_Hours),
BillRate_OT = (BillRate * 1.50),
RegAmt = (RegHours * BillRate),
OTAmt = (OT_Hours * (BillRate * 1.50)),
TotAmt = (RegHours * BillRate) + (OT_Hours * (BillRate * 1.50))
from #tmpPunches order by ShiftNo, DeptName_Long, LastName, FirstName, SSN, TransDate, ActualInTime

Drop Table #tmpPunches



