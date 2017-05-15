Create PROCEDURE [dbo].[usp_WGET_Text_TimeCard]
(
	@Client varchar(4),
	@Groupcode int,
	@CalcPPED datetime,
	@SSN int,
	@ForceSend char(1) = '0',
  	@ForceDate char(1) = '1',
  	@SiteNo INT = 0  --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 16Sept2016 >--
)
AS
SET NOCOUNT ON

DECLARE @PPED datetime
DECLARE @PPED2 datetime
DECLARE @PPED3 datetime
DECLARE @EmplName varchar(80)
DECLARE @eCell varchar(20)
DECLARE @eCarr int
DECLARE @Email varchar(200)
DECLARE @textmessage varchar(1000)
DECLARE @SendMessage char(1)
DECLARE @savPPED datetime
DECLARE @curPPED datetime
DECLARE @data1 varchar(20)
DECLARE @data2 numeric(9,2)
DECLARE @data2a numeric(9,2)
DECLARE @data3 varchar(12)
Declare @MaxIn datetime
Declare @MaxOut datetime
Declare @LastPunch datetime
DECLARE @Sort int
DECLARE @crlf char(2)
DECLARE @Subject varchar(20)
DECLARE @Recs int
DECLARE @Sent char(1)
DECLARE @LastCardSent datetime
DECLARE @ParamSiteNo INT  --< @ParamSiteNo data type is changed from  SMALLINT to INT by Srinsoft on 16Sept2016 >--

Set @Sent = '0'

IF @SiteNo = 0
BEGIN
	
	SELECT @ParamSiteNo = B.SiteNo
	FROM
	(
		SELECT top 1 A.SiteNo, A.PunchTime
		FROM
		(	
			Select SiteNo, InTimestamp PunchTime 
			from timehistory..tbltimehistDetail
			where Client = @Client
			AND GroupCode = @Groupcode
			AND SSN = @SSN
			AND ISNULL(InTimestamp,0) > 0
			AND ClockAdjustmentNo = ''

			UNION ALL
	
			Select  SiteNo, OutTimestamp PunchTime 
			from timehistory..tbltimehistDetail
			where Client = @Client
			AND GroupCode = @Groupcode
			AND SSN = @SSN
			AND ISNULL(OutTimestamp,0) > 0
			AND ClockAdjustmentNo = ''
		)A
		Order by A.PunchTime DESC
	)B
	 
END
ELSE
BEGIN
	SET @ParamSiteNo = @SiteNo
END


Select 
	@EmplName = LastName + ',' + FirstName,
	@eCell = isnull(CellPhoneNumber,''),
	@eCarr = isnull(CellPhoneCarrier,0),
	@LastCardSent = isnull(ExportEffectiveDate,'1/1/1970')
from TimeCurrent..tblEMplNames 
where client = @CLient and Groupcode = @Groupcode and SSN = @SSN 

IF @EmplName is NULL
BEGIN
	Update TimeCurrent..tblEmplNames Set PrintMaintAuditRpt = '0' where client = @CLient and Groupcode = @Groupcode and SSN = @SSN 
	Select 'ERROR NO MATCH' as result
	RETURN
END

if isnull(@eCell,'') = '' 
BEGIN
	Update TimeCurrent..tblEmplNames Set PrintMaintAuditRpt = '0' where client = @CLient and Groupcode = @Groupcode and SSN = @SSN 
	Select 'ERROR NO CELL #' as result
	RETURN
END

IF @ForceDate = '1'
BEGIN
  Set @PPED = @CalcPPED
  Set @PPED2 = @PPED
  Set @PPED3 = @PPED
END
ELSE
BEGIN
  IF @ForceSend = '1'
  BEGIN
    -- Get most recent payrollperiodenddate
    Set @PPED = (select max(PayrollPeriodEndDate) from TimeHistory..tblPeriodenddates where client = @Client and groupcode = @Groupcode and status <> 'C' and payrollperiodenddate > dateadd(day, -30, getdate()))
    Set @PPED2 = @PPED
    Set @PPED3 = @PPED
  END
  ELSE
  BEGIN
    Set @PPED = (select min(PayrollPeriodEndDate) from TimeHistory..tblPeriodenddates where client = @Client and groupcode = @Groupcode and status <> 'C' and payrollperiodenddate > dateadd(day, -30, getdate()))
    Set @PPED2 = dateadd(day,7,@PPED)
    Set @PPED3 = dateadd(day,14,@PPED)
  END
END
Set @crlf = char(13) + char(10)
--Set @Email = (select Email from TimeCurrent.dbo.tblMobileCarriers where RecordID = @eCarr)
--Set @Email = @eCell + @Email
Set @textmessage = ''
Set @savPPED = '1/1/2000'
Set @Recs = 0
Set @LastPunch = '1/1/2000'

-- =============================================
-- Create cursor of time records and build text message(s)
-- =============================================
DECLARE cText CURSOR
READ_ONLY
FOR 
select PPED = PayrollPeriodenddate, Sort = datepart(weekday,TransDate), 
Col1 = cast( Upper(left(datename(weekday,TransDate),2)) as varchar(20) ), 
Col2 = sum(Hours), Col2a = Sum(Dollars),
Col3 = left(case when clockadjustmentNo in ('1','8','',' ') then '' else ADjustmentName end,3),
MaxIn = max(timehistory.dbo.PunchDateTime2(TransDate, inDay, inTime )), 
MaxOut = max(timehistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime )) 
from TimeHistory..tblTimeHistDetail
where client = @Client
and Groupcode = @GroupCode
and ssn = @SSN
and payrollperiodenddate in(@PPED,@PPED2,@PPED3)
group By PayrollPeriodenddate, TransDate, left(case when clockadjustmentNo in ('1','8','',' ') then '' else ADjustmentName end,3) 
UNION ALL
Select 
PPED = PayrollPeriodenddate,
Sort = case when regHours <> 0.00 and ClockAdjustmentNo in('1','8','',' ') then 10
		        when Hours <> 0.00 and ClockAdjustmentNo not in('1','8','',' ') then 15
					  when Dollars <> 0.00 then 16 else 10 end,
Col1 = case when regHours <> 0.00 and ClockAdjustmentNo in('1','8','',' ') then 'TOT:' + @crlf + 'RG'
		        when Hours <> 0.00 and ClockAdjustmentNo not in('1','8','',' ') then 'OTH'
					  when Dollars <> 0.00 then 'DLR' else '' end,
Col2 = sum(case when regHours <> 0.00 and ClockAdjustmentNo in('1','8','',' ') then reghours
		        when Hours <> 0.00 and ClockAdjustmentNo not in('1','8','',' ') then hours 
					  when Dollars <> 0.00 then dollars else 0.00 end),
Col2a = 0.00,
Col3 = '',MaxIn = '1/1/2000', MaxOut = '1/1/2000'
from TimeHistory..tblTimeHistDetail
where client = @Client
and Groupcode = @groupCode
and ssn = @SSN
and payrollperiodenddate in(@PPED,@PPED2,@PPED3)
group By PayrollPeriodenddate,
case when regHours <> 0.00 and ClockAdjustmentNo in('1','8','',' ') then 10
		 when Hours <> 0.00 and ClockAdjustmentNo not in('1','8','',' ') then 15
		 when Dollars <> 0.00 then 16 else 10 end,
case when regHours <> 0.00 and ClockAdjustmentNo in('1','8','',' ') then 'TOT:' + @crlf + 'RG'
		 when Hours <> 0.00 and ClockAdjustmentNo not in('1','8','',' ') then 'OTH'
		 when Dollars <> 0.00 then 'DLR' else '' end
UNION ALL
Select PPED = PayrollPeriodenddate, Sort = 11,
Col1 = 'OT',
Col2 = sum(OT_Hours),
Col2a = 0.00,
Col3 = '',MaxIn = '1/1/2000', MaxOut = '1/1/2000'
from TimeHistory..tblTimeHistDetail
where client = @Client
and Groupcode = @groupCode
and ssn = @SSN
and payrollperiodenddate in(@PPED,@PPED2,@PPED3)
group By PayrollPeriodenddate
UNION ALL
Select PPED = PayrollPeriodenddate,Sort = 12,
Col1 = 'DT',
Col2 = sum(DT_Hours),
Col2a = 0.00,
Col3 = '',MaxIn = '1/1/2000', MaxOut = '1/1/2000'
from TimeHistory..tblTimeHistDetail
where client = @Client
and Groupcode = @groupCode
and ssn = @SSN
and payrollperiodenddate in(@PPED,@PPED2,@PPED3)
group By PayrollPeriodenddate
UNION ALL
select Max(en.PayrollPeriodenddate),
Sort = 20, 
Col1 = rtrim(ltrim(a.AccrualName)), 
Col2 = ae.Balance,
Col2a = 0.00,
Col3 = '',MaxIn = '1/1/2000', MaxOut = '1/1/2000'
from TimeHistory..tblEmplNames as en
Inner Join TimeCurrent..tblEmplAccruals as ae 
on ae.Client = @Client and ae.Groupcode = @Groupcode and ae.SSN = @SSN 
Inner Join TimeCurrent..tblAccruals as a
on a.Client = @Client and a.Groupcode = @Groupcode and a.AccrualNo = ae.ClockAdjustmentNo
where en.Client = @Client and en.Groupcode = @Groupcode and en.ssn = @SSN
and en.payrollperiodenddate in(@PPED,@PPED2,@PPED3)
and ae.EffWeekEndDate >= dateadd(day,-28,@PPED2)
group by rtrim(ltrim(a.AccrualName)), ae.Balance
order by PayrollPeriodenddate, Sort

OPEN cText

FETCH NEXT FROM cText INTO @curPPED, @Sort, @Data1, @Data2, @Data2a, @Data3, @MaxIn, @MaxOut
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		if @savPPED = '1/1/2000'
		BEGIN
			Set @savPPED = @curPPED
			Set @textmessage = ''
			Set @LastPunch = '1/1/2000'
		END
		if @savPPED <> @curPPED
		BEGIN
			-- Send text for this week.
			--
			Set @textmessage = @crlf + convert(varchar(10),@savPPED,101) + @crlf + @textmessage + 'LP:' + convert(varchar(5), @LastPunch, 1 ) + ' ' + right(convert(varchar(25), @LastPunch, 100),7)
			Set @Subject = 'TIMECARD' -- convert(varchar(10),@savPPED,101)
			--Print @textmessage
			Set @SendMessage = '0'
			Select @SendMessage = case when isnull(ExportEffectiveDate,'1/1/2000') < isnull(LastRecalcTime,'1/1/2001') then '1' else '0' end
				from Timehistory..tblEmplNames where client = @Client and GroupCode = @Groupcode and SSN = @SSN
				and PayrollPeriodenddate = @savPPED

			-- IF the time card has changed for this week send it.
			-- or if we should force a send
			-- or if this is called from EmplCalc then send time card >= the EmplCalc PPED passed in
			--
			IF isnull(@SendMessage,'1') = '1' OR @ForceSend = '1' OR @SavPPED >= @CalcPPED
			BEGIN
				--Print @textMessage
				EXEC [Scheduler].[dbo].[usp_APP_TextMan_SendTextMessage] @Client, @GroupCode, @SSN, @savPPED, @eCell, @Subject, @textMessage, 'EMPL',@ParamSiteNo
				Set @Sent = '1'
			END

			Set @savPPED = @curPPED
			Set @textmessage = ''
		END
		if isnull(@MaxIn,'1/1/2000') > @LastPunch
			Set @LastPunch = @MaxIn

		if isnull(@MaxOut,'1/1/2000') > @LastPunch
			Set @LastPunch = @MaxOut

		-- @data2a is for dollars.
		Set @data1 = @data1 + ' '
		if @data2a > 0.00
		BEGIN
			Set @data1 = @data1 + '$'
			Set @data2 = @data2a
		END
		IF @Data2 <> 0.00
		BEGIN
			Set @textmessage = @textmessage + @data1 + ltrim(str(@data2,6,2)) + case when @data3 <> '' then ' ' + @data3 else '' end + @crlf
			Set @Recs = @Recs + 1
		END
	END
	FETCH NEXT FROM cText INTO @curPPED, @Sort, @Data1, @Data2, @Data2a, @Data3, @MaxIn, @MaxOut
END

CLOSE cText
DEALLOCATE cText

-- Check to see if there was any records for this employee:
-- 
IF @Recs > 0
BEGIN
	Set @textmessage = @crlf + convert(varchar(10),@savPPED,101) + @crlf + @textmessage + 'LP:' + + convert(varchar(5), @LastPunch, 101 ) + ' ' + right(convert(varchar(25), @LastPunch, 100),7)
	Set @Subject = 'TIMECARD' --convert(varchar(10),@savPPED,101)
	Set @SendMessage = '0'
	Select @SendMessage = case when isnull(ExportEffectiveDate,'1/1/2000') < isnull(LastRecalcTime,'1/1/2001') then '1' else '0' end
		from Timehistory..tblEmplNames where client = @Client and GroupCode = @Groupcode and SSN = @SSN
		and PayrollPeriodenddate = @savPPED

	-- IF the time card has changed for this week send it.
	-- or if we should force a send
	-- or if this is called from EmplCalc then send time card >= the EmplCalc PPED passed in
	--
	IF isnull(@SendMessage,'1') = '1' OR @ForceSend = '1' OR @SavPPED >= @CalcPPED
	BEGIN
		--Print @textmessage
		EXEC [Scheduler].[dbo].[usp_APP_TextMan_SendTextMessage] @Client, @GroupCode, @SSN, @savPPED, @eCell, @Subject, @textMessage, 'EMPL',@ParamSiteNo
		Set @Sent = '1'
	END
END
ELSE
BEGIN
	-- Send message indicating there was no time for this week.
	--
	Set @textmessage = 'Your time card for the current week does not contain hours.' 
	IF @LastPunch <> '1/1/2000'
		Set @textmessage = @textmessage + @crlf + 'LP:' + convert(varchar(17), @LastPunch, 9 )
	ELSE
		Set @textmessage = @textmessage + @crlf + 'SENT: ' + convert(varchar(17), getdate(), 9 )
	Set @Subject = 'Time Card'
	Set @SendMessage = '0'
	Select @SendMessage = case when isnull(ExportEffectiveDate,'1/1/2000') < isnull(LastRecalcTime,'1/1/2001') then '1' else '0' end
		from Timehistory..tblEmplNames where client = @Client and GroupCode = @Groupcode and SSN = @SSN
		and PayrollPeriodenddate = @savPPED

	IF isnull(@SendMessage,'1') = '1' OR @ForceSend = '1' OR @SavPPED >= @CalcPPED
	BEGIN
		EXEC [Scheduler].[dbo].[usp_APP_TextMan_SendTextMessage] @Client, @GroupCode, @SSN, '1/1/2008', @eCell, @Subject, @textMessage, 'EMPL',@ParamSiteNo
	  Set @Sent = '1'
	END
END

Update TimeCurrent..tblEmplNames Set PrintMaintAuditRpt = '0',ExportEffectiveDate = getdate() where client = @CLient and Groupcode = @Groupcode and SSN = @SSN 

/*
if @LastCardSent = '1/1/1970'
BEGIN
	-- First Time. Send Welcome message and 
	--
	Set @textMessage = 'NOTE: To get an email timecard instead of a text please reply to this text & enter your email addr.'
  Set @Subject = 'WELCOME'
	EXEC [Scheduler].[dbo].[usp_APP_TextMan_SendTextMessage] @Client, @GroupCode, @SSN, '1/1/2008', @eCell, @Subject, @textMessage, 'EMPL',@ParamSiteNo
END
*/

IF @Sent = '0'
	Select 'NO CHANGES' as result
ELSE
	Select 'TEXT SENT' as result






