CREATE Procedure [dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_OLDv2] 
(
	@Client varchar(4),
	@GroupCode int,
	@PPED_2 datetime,
	@ReturnRecs char(1) = 'N',
	@CloseProcessing char(1) = 'N'
)
AS

SET NOCOUNT ON

DECLARE @CalcStart datetime
DECLARE @PPED_1 datetime
DECLARE @MPD datetime
DECLARE @WeekLocked char(1)

Set @CalcStart = getdate()
Set @MPD = (SElect masterpayrolldate from TimeHistory..tblPeriodenddates where client = @Client and Groupcode = @Groupcode and PayrollPeriodenddate = @PPED_2)

IF @MPD <> @PPED_2
BEGIN
	Select SSN = 0 where 1 = -1
	RETURN
END

-- ELSE RE-CALC unpaid PTO balances.
Set @PPED_1 = dateadd(day, -7, @PPED_2)

Declare @Date1 datetime
Declare @Date2 datetime
Declare @Date3 datetime
Declare @Date4 datetime

Set @Date1 = '1/1/1970'
Set @Date2 = '1/1/1970'
Set @Date3 = '1/1/1970'
Set @Date4 = '1/1/1970' 

-- =============================================
-- Set the holiday dates for exclusion
-- =============================================
DECLARE cHolidays CURSOR
READ_ONLY
FOR 
select Distinct TransDate from TimeCurrent..tblOverTimeDays 
where client = @Client and GroupCode = @Groupcode
and TransDate >= dateadd(day,-6,@PPED_1) 
and TransDate <= @PPED_2

DECLARE @Holidaydate datetime
OPEN cHolidays

FETCH NEXT FROM cHolidays INTO @HolidayDate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    IF @Date1 = '1/1/1970'
    BEGIN
      Set @Date1 = @HolidayDate
    END
    ELSE
    BEGIN
      IF @Date2 = '1/1/1970'
      BEGIN
        Set @Date2 = @HolidayDate
      END
      ELSE
      BEGIN
        IF @Date3 = '1/1/1970'
        BEGIN
          Set @Date3 = @HolidayDate
        END
        ELSE
        BEGIN
          IF @Date4 = '1/1/1970'
          BEGIN
            Set @Date4 = @HolidayDate
          END
        END
      END
    END  
	END
	FETCH NEXT FROM cHolidays INTO @HolidayDate
END

CLOSE cHolidays
DEALLOCATE cHolidays


IF @Date1 <> '1/1/1970'
BEGIN
  -- We have a holiday for this client group.

  Create Table #tmpHol
  (
    RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
    GroupCOde int,
    SSN int,
    Dateadded datetime,
    Hours numeric(9,2),
    ClockAdjustmentNo varchar(3), --< Srinsoft 09/096/2015 Changed ClockAdjustmentNo char(1) to varchar(3) >--
    UserCode varchar(5)
  )
 
  Insert into #tmpHol(recordID, Groupcode, SSN, DateAdded, Hours, ClockAdjustmentNo, UserCode)
  Select t.RecordID, t.Groupcode, t.SSN, e.Dateadded, t.Hours, t.ClockAdjustmentNo, t.userCode
  from TimeHistory..tblTimeHistDetail as t with(nolock)
  Inner Join TimeCurrent..tblEmplNames as e with(nolock)
  on e.client = t.client 
  and e.groupcode = t.groupcode 
  and e.ssn = t.ssn
  where t.Client = @Client 
  and t.groupcode = @groupcode 
  and t.PayrollPeriodenddate in(@PPED_1, @PPED_2)
  and t.TransDate in(@Date1, @Date2, @Date3, @Date4)
  and isnull(e.startdate,e.dateadded) > dateadd(day,-104,getdate())
  and t.Hours <> 0
  and t.ClockADjustmentNo in('2','P')
 -- and t.UserCode in('PRO','HOL')

  --select * from #tmpHol order by GroupCode, ssn
  
  Update TimeHistory..tblTimeHistDetail
    Set ClockAdjustmentNo = 'C', 
        AdjustmentName = 'HOLPTO', 
        JobID = 406
  where Client = @Client 
  and groupcode = @groupcode 
  and PayrollPeriodenddate in(@PPED_1, @PPED_2)
  and RecordID in(select RecordID from #tmpHol)

  Drop Table #tmpHol
END  

DECLARE @LastRecalc datetime

Set @LastRecalc = '1/1/2011'
if @CloseProcessing = 'Y'
BEGIN
  Set @LastRecalc = CONVERT(varchar(12),getdate(),101) + ' 15:30'
END


/*
Select Client, GroupCode, SSN, PayrollPeriodenddate, sum(Hours) from TimeHistory..tblTimeHistDetail
where client = @Client and groupcode = @GroupCode and payrollperiodenddate in(@PPED_1, @PPED_2)
and clockadjustmentno in('2','5','P','C') --and Holiday = '0'
Group By Client, GroupCode, SSN, PayrollPeriodenddate
Having Sum(Hours) > 0.00
*/
DECLARE cSSNs CURSOR
READ_ONLY
FOR 
Select t.Client, 
t.GroupCode, 
t.SSN, 
t.PayrollPeriodenddate, 
WeekLocked = isnull(en.WeekLocked,'0'), 
PTOTaken = sum(case when t.ClockADjustmentNo = '2' then t.Hours else 0.00 end),
uPTOTaken = sum(case when t.ClockADjustmentNo = 'P' then t.Hours else 0.00 end),
TotPTO = sum(case when t.ClockADjustmentNo IN('P','2') then t.Hours else 0.00 end),
PTOBalance = a.Balance, 
EffDate = a.effWeekEndDate 
from TimeHistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeHistory..tblEmplnames as en with(nolock)
on en.client = t.client
and en.groupcode = t.groupcode
and en.ssn = t.ssn
and en.payrollperiodenddate = t.payrollperiodenddate
Inner Join TimeCurrent..tblEmplAccruals as a with(nolock)
on a.client = t.client
and a.groupcode = t.groupcode
and a.ssn = t.ssn
and a.clockadjustmentNo = '2'
where t.client = @Client 
--and t.groupcode = @GroupCode 
and t.payrollperiodenddate in(@PPED_1, @PPED_2)
and t.clockadjustmentno in('2','P') 
and isnull(en.WeekLocked,'0') <> '1'
and isnull(en.LastRecalcTime,'1/1/1970') > @LastRecalc  
--and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode )
Group By t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, en.weeklocked, 
a.Balance, 
a.effWeekEndDate 
Having sum(case when t.ClockADjustmentNo IN('P','2') then t.Hours else 0.00 end) > a.Balance


/*
Select t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, WeekLocked = isnull(en.WeekLocked,'0'), sum(t.Hours) 
from TimeHistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeHistory..tblEmplnames as en with(nolock)
on en.client = t.client
and en.groupcode = t.groupcode
and en.ssn = t.ssn
and en.payrollperiodenddate = t.payrollperiodenddate
where t.client = @Client 
and t.groupcode = @GroupCode 
and t.payrollperiodenddate in(@PPED_1, @PPED_2)
and t.clockadjustmentno in('2','P') 
and isnull(en.WeekLocked,'0') <> '1'
and isnull(en.LastRecalcTime,'1/1/1970') > @LastRecalc  
Group By t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, en.weeklocked 
Having Sum(t.Hours) <> 0.00
*/

--DECLARE @Client Varchar(4)
--DECLARE @Groupcode int
DECLARE @PPED datetime
DECLARE @SSN int
DECLARE @Hours numeric(8,2)
DECLARE @PTOBalance numeric(7,2)
DECLARE @PTOBalance1 numeric(7,2)
DECLARE @PTOBalance2 numeric(7,2)
DECLARE @EILBalance numeric(7,2)
DECLARE @PTOTaken numeric(7,2)
DECLARE @uPTOTaken numeric(7,2)
DECLARE @PTOTaken2 numeric(7,2)
DECLARE @uPTOTaken2 numeric(7,2)
DECLARE @EILTaken numeric(7,2)
DECLARE @EILTaken2 numeric(7,2)
DECLARE @TempHours numeric(7,2)
DECLARE @SiteOpen int
DECLARE @SiteOpen2 int
DECLARE @PPEDStart datetime
DECLARE @PPEDEnd datetime
DECLARE @EffDate datetime


OPEN cSSNS

FETCH NEXT FROM cSSNS INTO @Client, @Groupcode, @SSN, @PPED, @WeekLocked, @PTOTaken, @uPTOTaken, @PTOTaken2, @PTOBalance, @EffDate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    
    if exists(select recordid from TimeHistory..tblTimeHistDetail with(nolock) where client = @Client and groupcode = @Groupcode
    and SSN = @SSN and clockadjustmentno in('2','5','P') and Payrollperiodenddate = @PPED
    and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode ) )
    BEGIN
    	-- Employee has EIL or PTO
    	-- Get Balances from the file
    	Select 
    		@PTOBalance = Balance, 
    		@EffDate = effWeekEndDate 
    	from TimeCurrent..tblEmplAccruals with(nolock)
    	where client = @Client 
    	and groupcode = @Groupcode
    	and SSN = @SSN 
    	and clockadjustmentno = '2'
    
    	Set @EILBalance = 0
    
    	Set @PPEDStart = dateadd(day,7,@EffDate)
    	Set @PPEDEnd = dateadd(day,14,@EffDate)
    
    	--Print @PTOBalance
    	--PRint @EffDate
    	--Print @EILBalance
    	--Print @PPEDStart
    	--Print @PPEDENd

      insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
      Values(@GroupCode, @SSN, 'Balances', @PTOBalance, @EILBalance, 0,0,@EffDate, '')
    
    	-- If the PPED is not in the effective dates then skip this calc.
    	-- Either the effective date is wrong or the Balances have not been updated for this week yet.
    	--
    	IF @PPED <> @PPEDStart and @PPED <> @PPEDEnd
      BEGIN
        insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
        Values(@GroupCode, @SSN, 'Eff Date Check', @PTOBalance, @EILBalance, 0,0,@EffDate, 'Record out of EffDate Range. Skipped')
     		goto NextRecord --RETURN
      END
    	-- Calculate the PTO / EIL Taken for week1 and week 2.
    	-- 
      -- 2 = PTO
      -- > = Unpaid PTO
      -- P = Unscheduled PTO
      -- < = Unpaid Unscheduled PTO
      -- 5 = EIL / SICK
      -- - = Unpaid EIl / Sick
      --
      --  Count the number of sites that are closed.
      --  for week one and week two.
      --
    
    	Select @PTOTaken = sum(case when t.ClockADjustmentNo = '2' and t.PayrollPeriodEndDate = @PPEDStart then t.Hours else 0.00 end),
    				 @uPTOTaken = sum(case when t.ClockADjustmentNo = 'P' and t.PayrollPeriodEndDate = @PPEDStart then t.Hours else 0.00 end),
    			   @EILTaken = 0,
    	       @PTOTaken2 = sum(case when t.ClockADjustmentNo = '2' and t.PayrollPeriodEndDate = @PPEDEnd then t.Hours else 0.00 end),
    				 @uPTOTaken2 = sum(case when t.ClockADjustmentNo = 'P' and t.PayrollPeriodEndDate = @PPEDEnd then t.Hours else 0.00 end),
    			   @EILTaken2 = 0,
    				 @SiteOpen = sum(case when isnull(sn.WeekClosed,'') not in('M','C') and t.PayrollPeriodEndDate = @PPEDStart then 1 else 0 end),
    				 @SiteOpen2 = sum(case when isnull(sn.WeekClosed,'') not in('M','C') and t.PayrollPeriodEndDate = @PPEDEnd then 1 else 0 end)
    	From TimeHistory..tblTimeHistDetail as t with(nolock)
    	Inner Join TimeHistory..tblSiteNames as sn with(nolock)
    	on sn.Client = @Client
    	and sn.Groupcode = @GroupCode
    	and sn.PayrollPeriodEndDate = t.PayrollPeriodenddate
    	and sn.SiteNo = t.SiteNo	
    	where t.client = @Client 
    		and t.groupcode = @Groupcode
    		and t.SSN = @SSN 
    		and t.Payrollperiodenddate IN(@PPEDStart, @PPEDEnd)
    		and t.clockadjustmentno in('2','P')
    
    
      -- Ignore the site open counts 8/23/2010 -- Per Molly H. from Davita.
      --
      Set @SiteOpen = 0
      Set @SiteOpen2 = 0

    	--PRINT @PTOBalance
    	--Print @PTOTaken
    	--Print @uPTOTaken 
    	--Print @PTOTaken2
    	--Print @uPTOTaken2
    	--PRINT @PTOBalance - (@PTOTaken + @uPTOTaken + @PTOTaken2 + @uPTOTaken2)

      insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
      Values(@GroupCode, @SSN, 'Balances 2', @PTOBalance, @EILBalance, (@PTOTaken + @uPTOTaken + @PTOTaken2 + @uPTOTaken2),0,@EffDate, '')

      -- If the PTO Balance goes negative then switch from Paid PTO to unpaid PTO.
      -- Davita has two type of PTO, Scheduled PTO and Unscheduled PTO. These are different pay codes.
      -- Therefore, the system has to deduct accordingly. Deduct from Unscheduled first and then scheduled.
      --	
    	IF @PTOBalance - (@PTOTaken + @uPTOTaken + @PTOTaken2 + @uPTOTaken2) >= 0
      BEGIN
        insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
        Values(@GroupCode, @SSN, 'PTO Bal Check', @PTOBalance, @EILBalance, (@PTOTaken + @uPTOTaken + @PTOTaken2 + @uPTOTaken2),0,@EffDate, 'Balance OK, Checking EIL')
    		GOTO CheckEIL
      END

    	--Print 'Step 1'
      IF @PPED = @PPEDStart
      BEGIN
      	-- Only calculate when all sites are closed.
      	-- mainly due to trans clocks.
      	IF @SiteOpen > 0
        BEGIN
          insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
          Values(@GroupCode, @SSN, 'SiteOpenCheck', @PTOBalance, @EILBalance, (@PTOTaken + @uPTOTaken + @PTOTaken2 + @uPTOTaken2),0,@EffDate, 'Open Site on Card.Skipped')

       		goto NextRecord --RETURN
        END
    
      	-- Calculating the first week. So only deduct from the first week.
      	Set @PTOBalance1 = (@PTOBalance - (@PTOTaken + @uPTOTaken) ) * -1
      	IF @uPTOTaken > 0 and @PTOBalance1 > 0
      	BEGIN
      		IF @uPTOTaken >= @PTOBalance1
      		BEGIN
      			Set @uPTOTaken = @PTOBalance1
      			Set @PTOBalance1 = 0
    				Set @TempHours = @uPTOTaken * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, 'P', 'UNSCPTO', @TempHours, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '<', 'UnPD UnSch', @uPTOTaken, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
            Values(@GroupCode, @SSN, 'AddUnpaidUnsh Wk1', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken > Balance', @PPED_1)
      		END
      		ELSE
      		BEGIN
      			Set @PTOBalance1 = @PTOBalance1 - @uPTOTaken
    				Set @TempHours = @uPTOTaken * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, 'P', 'UNSCPTO', @TempHours, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '<', 'UnPD UnSch', @uPTOTaken, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
            Values(@GroupCode, @SSN, 'AddUnpaidUnsh Wk1', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken < Balance', @PPED_1)
      		END
          -- AutoApprove the UN PAID hours if the original hours were approved.
          --
          if exists (Select 1 from Timehistory..tblTimeHistDetail with(nolock)
              where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and ClockAdjustmentNo = 'P'
              and isnull(AprvlStatus,'') = 'A')
          BEGIN
            Update Timehistory..tblTimeHistDetail
              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
            where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and isnull(AprvlStatus,'') <> 'A'
              and ( (ClockAdjustmentNo = '<') OR (ClockADjustmentNo = 'P' and Hours < 0.00 and UserCode = 'SYS') )
          END  
      	END
    
      	IF @PTOTaken > 0 and @PTOBalance1 > 0
      	BEGIN
      		IF @PTOTaken >= @PTOBalance1
      		BEGIN
      			Set @PTOTaken = @PTOBalance1
    				Set @TempHours = @PTOTaken * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '2', 'PTO', @TempHours, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '>', 'UnPD PTO', @PTOTaken, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
            Values(@GroupCode, @SSN, 'AddUnpaid Wk1', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken > Balance', @PPED_1)
      		END
      		ELSE
      		BEGIN
    				Set @TempHours = @PTOTaken * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '2', 'PTO', @TempHours, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '>', 'UnPD PTO', @PTOTaken, 0.00, @PPED, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
            Values(@GroupCode, @SSN, 'AddUnpaid Wk1', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken < Balance', @PPED_1)
      		END
          -- AutoApprove the UN PAID hours if the original hours were approved.
          --
          if exists (Select 1 from Timehistory..tblTimeHistDetail with(nolock) 
              where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and ClockAdjustmentNo = '2'
              and isnull(AprvlStatus,'') = 'A')
          BEGIN
            Update Timehistory..tblTimeHistDetail
              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
            where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and isnull(AprvlStatus,'') <> 'A'
              and ( (ClockAdjustmentNo = '>') OR (ClockADjustmentNo = '2' and Hours < 0.00 and UserCode = 'SYS') )
          END  
      	END
        GOTO CheckEIL
      END
    
    
    	--Print 'Step 2'
    	--Print @SiteOpen2
      IF @PPED = @PPEDEnd
      BEGIN
      	-- Only calculate when all sites are closed.
      	-- mainly due to trans clocks.
      	IF @SiteOpen2 > 0
        BEGIN
          insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
          Values(@GroupCode, @SSN, 'SiteOpenCheck2', @PTOBalance, @EILBalance, (@PTOTaken + @uPTOTaken + @PTOTaken2 + @uPTOTaken2),0,@EffDate, 'Open Site on Card.Skipped')

       		goto NextRecord --RETURN
      END
    
      	-- Calculating the 2nd week. Deduct first week and second week totals
      	Set @PTOBalance2 = (@PTOBalance - (@PTOTaken2 + @uPTOTaken2 + @PTOTaken + @uPTOTaken) ) * -1
    		--Print @PTOBalance2  
      
      	IF @uPTOTaken2 > 0 and @PTOBalance2 > 0
      	BEGIN
      		IF @uPTOTaken2 >= @PTOBalance2
      		BEGIN
      			Set @uPTOTaken2 = @PTOBalance2
      			Set @PTOBalance2 = 0
    				Set @TempHours = @uPTOTaken2 * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, 'P', 'UNSCPTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '<', 'UnPD UnSch', @uPTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message,PPED)
            Values(@Groupcode, @SSN, '2nd AddUnpaidUnsch Wk2', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken > Balance', @PPED_2)
      		END
      		ELSE
      		BEGIN
      			Set @PTOBalance2 = @PTOBalance2 - @uPTOTaken2
    				Set @TempHours = @uPTOTaken2 * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, 'P', 'UNSCPTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '<', 'UnPD UnSch', @uPTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
            Values(@Groupcode, @SSN, '2nd AddUnpaidUnSch Wk2', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken < Balance', @PPED_2)
      		END
          -- AutoApprove the UN PAID hours if the original hours were approved.
          --
          if exists (Select 1 from Timehistory..tblTimeHistDetail with(nolock)
              where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and ClockAdjustmentNo = 'P'
              and isnull(AprvlStatus,'') = 'A')
          BEGIN
            Update Timehistory..tblTimeHistDetail
              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
            where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and isnull(AprvlStatus,'') <> 'A'
              and ( (ClockAdjustmentNo = '<') OR (ClockADjustmentNo = 'P' and Hours < 0.00 and UserCode = 'SYS') )
          END  
      	END
      
      	IF @PTOTaken2 > 0 and @PTOBalance2 > 0
      	BEGIN
      		IF @PTOTaken2 >= @PTOBalance2
      		BEGIN
      			Set @PTOTaken2 = @PTOBalance2
    				Set @TempHours = @PTOTaken2 * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '2', 'PTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '>', 'UnPD PTO', @PTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
            Values(@Groupcode, @SSN, '2nd AddUnpaid Wk2', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken > Balance', @PPED_2)
      		END
      		ELSE
      		BEGIN
    				Set @TempHours = @PTOTaken2 * -1
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '2', 'PTO', @TempHours, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
      			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '>', 'UnPD PTO', @PTOTaken2, 0.00, @PPEDEnd, @PPEDEnd, 'SYS', 'N'
            insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message,PPED)
            Values(@Groupcode, @SSN, '2nd AddUnpaid Wk2', @PTOBalance, @EILBalance, @TempHours,0,@EffDate, 'PTOTaken < Balance', @PPED_2)
      		END
          -- AutoApprove the UN PAID hours if the original hours were approved.
          --
          if exists (Select 1 from Timehistory..tblTimeHistDetail with(nolock) 
              where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and ClockAdjustmentNo = '2'
              and isnull(AprvlStatus,'') = 'A')
          BEGIN
            Update Timehistory..tblTimeHistDetail
              Set AprvlStatus = 'A',AprvlStatus_UserID = 7584, AprvlStatus_Date = getdate()
            where client = @Client
              and groupcode = @Groupcode
              and SSN = @SSN
              and Payrollperiodenddate = @PPED
              and isnull(AprvlStatus,'') <> 'A'
              and ( (ClockAdjustmentNo = '>') OR (ClockADjustmentNo = '2' and Hours < 0.00 and UserCode = 'SYS') )
          END  
      	END
        GOTO CheckEIL
      END
    
    CheckEIL:

    END
    ELSE
    BEGIN
      -- remove any un-paid PTO that may be there.
      
      insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message)
      Values(@Groupcode, @SSN, 'Empl Skipped', 0, 0,0 ,0,@PPED, 'No valid records on TimeCard.')
    END
	END
NextRecord:
	FETCH NEXT FROM cSSNS INTO @Client, @Groupcode, @SSN, @PPED, @WeekLocked, @PTOTaken, @uPTOTaken, @PTOTaken2, @PTOBalance, @EffDate
END

CLOSE cSSNS
DEALLOCATE cSSNS

if @ReturnRecs = 'Y'
BEGIN
	--recalc Command.
	--
	select Client = 'DAVT', GroupCode, SSN, PPED, lastname = message, Step
	from [TimeCurrent].[dbo].[tblWork_DAVT_UnpaidPTO_Audit] with(nolock)
	where message not in('', 'Balance OK, Checking EIL', 'EIL Balance OK. Skipped', 'Open Site on Card.Skipped')
  and message not like '%skipped%'
	and GroupCode = @GroupCode
	and isnull(dateadded,'1/1/1970') >= @CalcStart
END	













