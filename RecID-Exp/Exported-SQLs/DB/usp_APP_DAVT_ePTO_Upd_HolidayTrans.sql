CREATE Procedure [dbo].[usp_APP_DAVT_ePTO_Upd_HolidayTrans]
AS


Set NOCOUNT ON

Create table #tmpRecs
(
 RecordID BIGINT,  --< RecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
 GroupCode int,
 SSN int,
 PayrollPeriodenddate datetime,
 TransDate datetime,
 ClockADjustmentNo varchar(3), --< Srinsoft 08/10/2015 Changed  ClockADjustmentNo char(1) tio varchar(3) >--
 AdjustmentName varchar(20),
 Hours numeric(9,2),
 UserCode varchar(8),
 StartDate datetime,
 HireDays int
)


DECLARE @CLient varchar(4)
DECLARE @GroupCode int
DECLARE @PPED datetime
DECLARE @Transdate datetime

Set @Client = 'DAVT'

DECLARE cDays CURSOR
READ_ONLY
FOR 
		Select Distinct ot.Client, ot.Groupcode, p.payrollPeriodenddate, ot.TransDate
		from TimeCurrent..tblOvertimedays as ot
		inner join TimeHistory..tblPeriodenddates as p
		on p.Client = ot.Client
		and p.groupcode = ot.Groupcode
		and p.Status <> 'C'
		and p.payrollperiodenddate >= dateadd(day,-28,getdate())
		where ot.Client = 'DAVT'
		and ot.Transdate between dateadd(day, -6, p.PayrollPeriodenddate) and p.PayrollPeriodenddate
	
OPEN cDays

FETCH NEXT FROM cDays INTO @Client, @GroupCode, @PPED, @TransDate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		insert into #tmpRecs
		select t.RecordID, t.GroupCode, t.SSN, t.PayrollPeriodenddate, t.TransDate, t.ClockADjustmentNo, t.AdjustmentName, t.Hours, t.UserCode,
		e.StartDate, datediff(day, e.startdate, t.TransDate)
		From TimeHistory..tblTimeHistDetail as t
		inner Join TimeCurrent..tblEmplNames as e
		on e.client = t.client and e.groupcode = t.groupcode and e.SSN = t.SSN
		where
		t.Client = @Client
		and t.Groupcode = @GroupCode
		and t.PayrollperiodEndDate = @PPED
		and t.TransDate = @TransDate
		and t.UserCode = 'PRO'
		and t.ClockADjustmentNo in('2','P')
		and datediff(day, e.startdate, t.TransDate) <= 90
		
	END
	FETCH NEXT FROM cDays INTO @Client, @GroupCode, @PPED, @TransDate
END

CLOSE cDays
DEALLOCATE cDays

--

DECLARE cRecs CURSOR
READ_ONLY
FOR 
	Select RecordID, GroupCode, SSN, PayrollPeriodenddate, TransDate, ClockADjustmentNo, ADjustmentName, Hours
	from #tmpRecs order by GroupCode, TransDate

DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
DECLARE @SSN int
DECLARE @AdjNo varchar(3) --< Srinsoft 08/10/2015 Changed @AdjNo char(1) to varchar(3) for ColumnAdjustmentno >--
DECLARE @AdjName varchar(20)
DECLARE @Hours numeric(9,2)
DECLARE @Comment varchar(1500)

Set @Client = 'DAVT'

OPEN cRecs

FETCH NEXT FROM cRecs INTO @RecordID, @Groupcode, @SSN, @PPED, @TransDate, @AdjNo, @AdjName, @Hours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Update TimeHistory..tblTimeHistDetail
			Set ClockADjustMentNo = 'C', AdjustmentName = 'HOLPTO'
		where RecordID = @RecordID

		Set @Comment = 'Employee has been hired for less than 90 days. The ePTO(' + ltrim(rtrim(@AdjName)) + ') for ' + convert(varchar(12), @TransDate, 101) + ' with hours of ' + ltrim(str(@Hours,6,2)) + ' was changed to HOLPTO.'
		INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
		VALUES(@Client, @GroupCode, @PPED, @SSN, getdate(), @Comment, 0, 'System-ePTO', '0')

	END
	FETCH NEXT FROM cRecs INTO @RecordID, @Groupcode, @SSN, @PPED, @TransDate, @AdjNo, @AdjName, @Hours
END

CLOSE cRecs
DEALLOCATE cRecs

drop table #tmpRecs

