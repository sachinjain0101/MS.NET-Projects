Create PROCEDURE [dbo].[usp_WEB1_DAVT_CheckUnpaidPTO_Weekly]
(
	@Client varchar(4),
	@GroupCode int,
	@PPED_2 datetime,
	@ReturnRecs char(1) = 'N',
	@CloseProcessing char(1) = 'N'
)
AS
SET NOCOUNT ON
/*
DECLARE	@Client varchar(4)
DECLARE	@GroupCode int
DECLARE	@PPED_2 datetime
DECLARE	@ReturnRecs char(1)

SET @Client = 'DAVT'
SET @GroupCode = 500700
SET @PPED_2 = '8/23/08'
SET @ReturnRecs  = 'Y'
*/
DECLARE @Date1 datetime
DECLARE @Date2 datetime
DECLARE @Date3 datetime
DECLARE @Date4 datetime
DECLARE @CalcStart datetime
DECLARE @PPED_1 datetime
DECLARE @MPD datetime
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
DECLARE @WeekTot numeric(9,2)
DECLARE @RegHours numeric(9,2)
DECLARE @WeeklyOTHours numeric(9,2)
DECLARE @DailyOTHours numeric(9,2)
DECLARE @DTHours numeric(9,2)
DECLARE @unPaid numeric(9,2)
DECLARE @BaseHours numeric(9,2)
DECLARE @FullTime char(1)
DECLARE @SubStatus4 char(1)
DECLARE @AuditRecordID int
DECLARE @AgencyNo smallint
DECLARE @State varchar(3)
DECLARE @SubStatus7 varchar(10)
DECLARE @PrimarySite int
DECLARE @PrimaryDept int
DECLARE @WeekLocked char(1)

Set @Date1 = '1/1/1970'
Set @Date2 = '1/1/1970'
Set @Date3 = '1/1/1970'
Set @Date4 = '1/1/1970'


--if @GroupCode in(502700,502800,502900,503000,503100,503200,503300,503400,503500,503800)
--  Set @Date2 = '11/28/2008'

Set @CalcStart = getdate()
Set @MPD = (Select masterpayrolldate from TimeHistory..tblPeriodenddates where client = @Client and Groupcode = @Groupcode and PayrollPeriodenddate = @PPED_2)

IF @MPD <> @PPED_2
BEGIN
	Select SSN = 0 where 1 = -1
	RETURN
END

-- ELSE RE-CALC unpaid PTO balances.
Set @PPED_1 = dateadd(day, -7, @PPED_2)

IF getdate() < @PPED_2
  Set @PPED_2 = @PPED_1

--Print @PPED_1
--PRINT @PPED_2
-- =============================================
-- Set the holiday dates for exclusion
-- =============================================
DECLARE cHolidays CURSOR
READ_ONLY
FOR 
select Distinct TransDate from TimeCurrent..tblOverTimeDays with (nolock)
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
    ClockAdjustmentNo varchar(3), --< Srinsoft 09/09/2015 Changed ClockAdjustmentNo char(1) to varchar(3) >--
    UserCode varchar(5)
  )
 
  Insert into #tmpHol(recordID, Groupcode, SSN, DateAdded, Hours, ClockAdjustmentNo, UserCode)
  Select t.RecordID, t.Groupcode, t.SSN, e.Dateadded, t.Hours, t.ClockAdjustmentNo, t.userCode
  from TimeHistory..tblTimeHistDetail as t with (nolock)
  Inner Join TimeCurrent..tblEmplNames as e
  on e.client = t.client 
  and e.groupcode = t.groupcode 
  and e.ssn = t.ssn
  where t.Client = @Client 
  and t.groupcode = @groupcode 
  and t.PayrollPeriodenddate in(@PPED_1, @PPED_2)
  and t.TransDate in(@Date1, @Date2, @Date3, @Date4)
  and isnull(e.StartDate,e.dateadded) > dateadd(day,-104,getdate())
  and t.Hours <> 0
  and t.ClockADjustmentNo in('2','P')
  --and t.UserCode in('PRO','HOL')

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

DECLARE cSSNs CURSOR
READ_ONLY
FOR 
Select t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, WeekLocked = isnull(en.WeekLocked,'0'), sum(t.Hours) 
from TimeHistory..tblTimeHistDetail as t with (nolock)
Inner Join TimeHistory..tblEmplnames as en with (nolock)
on en.client = t.client
and en.groupcode = t.groupcode
and en.ssn = t.ssn
and en.payrollperiodenddate = t.payrollperiodenddate
where t.client = @Client 
and t.groupcode = @GroupCode 
and t.payrollperiodenddate in(@PPED_1, @PPED_2)
and t.clockadjustmentno in('2','5','P') 
and t.TransDate not in(@Date1,@Date2,@Date3,@Date4)
and isnull(en.WeekLocked,'0') <> '1'
and ( isnull(en.LastRecalcTime,'1/1/1970') > @LastRecalc OR isnull(t.CrossoverStatus,'') in('2','4') )
Group By t.Client, t.GroupCode, t.SSN, t.PayrollPeriodenddate, en.weeklocked 
Having Sum(t.Hours) <> 0.00

OPEN cSSNS

FETCH NEXT FROM cSSNS INTO @Client, @Groupcode, @SSN, @PPED, @WeekLocked, @Hours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
   
    if exists(select recordid from TimeHistory..tblTimeHistDetail with (nolock) where client = @Client and groupcode = @Groupcode
    and SSN = @SSN and clockadjustmentno in('2','5','P') and Payrollperiodenddate = @PPED
    and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode ) )
    BEGIN

DOITAGAIN:
			-- Get Total Hours for the Week
			--
			Select @WeekTot = Sum(case when clockadjustmentno not in('>','<','-') then hours else 0.00 end ),
             @RegHours = sum(case when RegHours <> 0.00 and clockadjustmentno not in('>','<','-') then RegHours else 0.00 end),
             @WeeklyOTHours = sum(case when OT_Hours <> 0.00 then OT_Hours - AllocatedOT_Hours else 0.00 end),
             @DailyOTHours = sum(case when OT_Hours <> 0.00 then AllocatedOT_Hours else 0.00 end),
             @DTHours = sum(DT_Hours),
						 @PTOTaken = Sum(Case when ClockAdjustmentNo = '2' and TransDate not in(@Date1,@Date2,@Date3,@Date4) then Hours else 0.00 end ),
						 @EILTaken = Sum(Case when ClockAdjustmentNo = '5' then Hours else 0.00 end ),
						 @uPTOTaken = Sum(Case when ClockAdjustmentNo = 'P' and TransDate not in(@Date1,@Date2,@Date3,@Date4) then Hours else 0.00 end ),
             @UnPaid = sum(case when clockadjustmentno in('>','<','-') and UserCode = 'SYW' then Hours else 0.00 end)
				from 	TimeHistory..tblTimeHistDetail with (nolock)
				where client = @Client and groupcode = @Groupcode
			    and SSN = @SSN 
					--and clockadjustmentno not in('>','<','-') 
					and Payrollperiodenddate = @PPED
			    and (isnull(CrossoverOtherGroup,0) = 0 or isnull(CrossoverOtherGroup,0) = @GroupCode )
          and NOT( TransDate in(@Date1,@Date2,@Date3,@Date4) and ClockAdjustmentNo in('2','P') )  -- Exclude Holiday PTO
          

			Select @BaseHours = BaseHours,
				@FullTime = SubStatus1,
        @SubStatus4 = SubStatus4,
        @SubStatus7 = isnull(Substatus7,'0'),
        @PrimarySite = isnull(PrimarySite,0),
        @PrimaryDept = isnull(PrimaryDept,0),
        @AgencyNo = AgencyNo,
        @State = EmpState
			from TimeCurrent..tblEmplNames with (nolock)
      where client = @Client and Groupcode = @Groupcode and SSN = @SSN 

      -- Special Rules 
      --   Facility 3565 - Department 26 Reuse Tech at 50 hours per week
      --   Facility 3211 - Facility wide at 60 hours per week

      IF @PrimarySite = 3565 and @PrimaryDept = 26
        Set @BaseHours = 50

      If @PrimarySite = 3211
        Set @BaseHours = 60

      If @PrimarySite = 1794
        Set @BaseHours = 52

      Set @SubStatus4 = isnull(@SubStatus4,'')
      IF (@WeekTot < @BaseHours and @UnPaid <> 0.00) OR @SubStatus4 = 'L'
      BEGIN
        Delete from TimeHistory..tblTimeHistDetail where client = @Client and groupcode = @groupcode
          and PayrollPeriodenddate = @PPED and ssn = @SSN
          and ClockAdjustmentNo in('>','<','-') and UserCode = 'SYW'
        Delete from TimeHistory..tblTimeHistDetail where client = @Client and groupcode = @groupcode
          and PayrollPeriodenddate = @PPED and ssn = @SSN
          and ClockAdjustmentNo in('2','5','P') and UserCode = 'SYW' and Hours <= 0.00
        IF @SubStatus4 <> 'L'
          INSERT INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]([Client], [GroupCode], [PayrollPeriodEndDate], [SSN], [CreateDate], [Comments], [UserID], [UserName], [ManuallyAdded])
          VALUES(@CLient, @GroupCode, @PPED, @SSN, Getdate(), 'Removed System Generated Weekly UnPaid time due to time card changes.', 0, 'System', '0')


        IF @SubStatus4 = 'L'
          GOTO NEXT_RECORD

        GOTO DOITAGAIN
      END

			Set @BaseHours = isnull(@BaseHours,40.00)
--			IF @FullTime <> 'P' 
      IF @BaseHours = 0
	      Set @BaseHours = 40.00

      IF isnull(@AgencyNo,1) = 1 and isnull(@State,'') = 'CA'
      BEGIN
        Set @regHours = isnull(@RegHours,0)
        Set @WeeklyOTHours = isnull(@WeeklyOTHours,0)
        Set @WeekTot = (@RegHours + @WeeklyOTHours)
      END

			IF isnull(@WeekTot,0) <= @BaseHours OR (@PTOTaken + @uPTOTaken + @EILTaken) <= 0.00
			BEGIN
				GOTO NEXT_RECORD
			END

			-- Employee has Valid Sick, PTO or Unscheduled PTO plus total weekly hours > Base Hours.
			-- This means that the Difference between total hours and Base Hours needs to be moved to unpaid
			-- If the difference is more than the PTO then move all PTO to unpaid.
			--
      insert into TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit(GroupCode, SSN, Step, PTO, EIL, PTOTaken, EILTaken, EffDate, Message, PPED)
      Values(@GroupCode, @SSN, '', @BaseHours, @WeekTot,(@PTOTaken + @uPTOTaken),@EILTaken,NULL, 'Recalc:Week Tot > Base Hours', @PPED)
			Set @AuditRecordID = @@Identity

			-- Take it from Unscheduled PTO first.
		  --
			Set @PTOBalance1 = @WeekTot - @BaseHours
			IF @uPTOTaken > 0
			BEGIN
				IF @uPTOTaken > @PTOBalance1
				BEGIN
          -- Remove Unscheduled PTO and Add Unpaid Unscheduled PTO.
					--
    			Set @uPTOTaken = @PTOBalance1
    			Set @PTOBalance1 = 0
  				Set @TempHours = @uPTOTaken * -1
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, 'P', 'UNSCPTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '<', 'nPD UnSch*', @uPTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
					Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
							Set WeeklyUnpaid40Rule = @TempHours,Step = 'nPD UnSch*'
					where RecordID = @AuditRecordID
				END
				ELSE
				BEGIN
          -- Remove Unscheduled PTO and Add Unpaid Unscheduled PTO.
					--
    			Set @PTOBalance1 = @PTOBalance1 - @uPTOTaken
  				Set @TempHours = @uPTOTaken * -1
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, 'P', 'UNSCPTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '<', 'nPD UnSch*', @uPTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
					Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
							Set WeeklyUnpaid40Rule = @TempHours,Step = 'nPD UnSch*'
					where RecordID = @AuditRecordID
				END
        -- AutoApprove the UN PAID hours if the original hours were approved.
        --
        if exists (Select 1 from Timehistory..tblTimeHistDetail with (nolock)
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
            and ( (ClockAdjustmentNo = '<') OR (ClockADjustmentNo = 'P' and Hours < 0.00 and UserCode = 'SYW') )
        END  

			END

			IF @PTOTaken > 0 and @PTOBalance1 > 0
			BEGIN
				IF @PTOTaken > @PTOBalance1
				BEGIN
          -- Remove scheduled PTO and Add Unpaid scheduled PTO.
					--
    			Set @PTOTaken = @PTOBalance1
    			Set @PTOBalance1 = 0
  				Set @TempHours = @PTOTaken * -1
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '2', 'PTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '>', 'UnPD PTO*', @PTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
					Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
							Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD PTO*'
					where RecordID = @AuditRecordID
				END
				ELSE
				BEGIN
          -- Remove scheduled PTO and Add Unpaid scheduled PTO.
					--
    			Set @PTOBalance1 = @PTOBalance1 - @PTOTaken
  				Set @TempHours = @PTOTaken * -1
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '2', 'PTO *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '>', 'UnPD PTO*', @PTOTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
					Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
							Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD PTO*'
					where RecordID = @AuditRecordID
				END
        -- AutoApprove the UN PAID hours if the original hours were approved.
        --
        if exists (Select 1 from Timehistory..tblTimeHistDetail with (nolock)
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
            and ( (ClockAdjustmentNo = '>') OR (ClockADjustmentNo = '2' and Hours < 0.00 and UserCode = 'SYW') )
        END  
			END
			IF @EILTaken > 0 and @PTOBalance1 > 0
			BEGIN
				IF @EILTaken > @PTOBalance1
				BEGIN
          -- Remove EIL and Add Unpaid EIL
					--
    			Set @EILTaken = @PTOBalance1
    			Set @PTOBalance1 = 0
  				Set @TempHours = @EILTaken * -1
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '5', 'PdSckTm *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '-', 'UnPD PST*', @EILTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
					Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
							Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD EIL*'
					where RecordID = @AuditRecordID
				END
				ELSE
				BEGIN
          -- Remove EIL and Add Unpaid EIL
					--
    			Set @PTOBalance1 = @PTOBalance1 - @EILTaken
  				Set @TempHours = @EILTaken * -1
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '5', 'PdSckTm *', @TempHours, 0.00, @PPED, @MPD, 'SYW', 'N'
    			EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, 0, 0, '-', 'UnPD PST*', @EILTaken, 0.00, @PPED, @MPD, 'SYW', 'N'
					Update TimeCurrent..tblWork_DAVT_UnpaidPTO_Audit 
							Set WeeklyUnpaid40Rule = @TempHours,Step = 'UnPD EIL*'
					where RecordID = @AuditRecordID
				END
			END


  	END
	END
NEXT_RECORD:
	FETCH NEXT FROM cSSNS INTO @Client, @Groupcode, @SSN, @PPED, @WeekLocked, @Hours
END

CLOSE cSSNS
DEALLOCATE cSSNS

if @ReturnRecs = 'Y'
BEGIN
	--recalc Command.
	--
	select Client = 'DAVT', GroupCode, SSN, PayrollPeriodenddate = PPED, lastname = message, Step
	from [TimeCurrent].[dbo].[tblWork_DAVT_UnpaidPTO_Audit] with (nolock)
	where message like 'Recalc%'
	and GroupCode = @GroupCode
	and isnull(dateadded,'1/1/1970') >= @CalcStart

END	
