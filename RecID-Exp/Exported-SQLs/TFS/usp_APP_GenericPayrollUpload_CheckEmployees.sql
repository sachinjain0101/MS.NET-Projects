Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_CheckEmployees] 
( 
  @Client char(4), 
  @GroupCode int, 
  @PPED datetime 
) 
AS
SET NOCOUNT ON

/*
DECLARE @Client char(4)
DECLARE @GroupCode int
DECLARE @PPED Datetime

SELECT @Client = 'GAMB'
SELECT @GroupCode = 401000
SELECT @PPED = '3/29/03'

Drop Table #tmpRecs

*/

IF @Client = 'INSP'
BEGIN
  EXEC TimeHistory..usp_APP_GenericPayrollUpload_GetRecs_INSP_VolHours @Client, @GroupCode, @PPED
END

IF @Client = 'HCPA'
BEGIN
	EXEC TimeHistory.dbo.usp_HCPA_PayFile_CheckEmployees @client, @GroupCode, @PPED
	RETURN
END

DECLARE @PPED1 datetime
DECLARE @PayFreq char(1)

Set @PayFreq = (Select PayrollFreq from Timecurrent..tblClientGroups where Client = @Client and groupcode = @GroupCode)

SET @PPED1 = @PPED
if @PayFreq = 'B'
  SET @PPED1 = dateadd(day, -7, @PPED)

--Check to make sure that all employees got re-calced correctly.
--and do not have a zero shift number.

--
-- Check to see if there are any records for this cycle that have 0 shift numbers.
-- 
Create table #tmpRecs 
(
  Client char(4),
  GroupCode int,
  PPED datetime,
  SSN int,
  ShiftNo int,
  TotHours numeric(9,2),
  TotCalcHrs numeric(9,2),
  AllocatedHrs numeric(9,2) 
)
 

  insert into #tmpRecs(Client, Groupcode, PPED, SSN, ShiftNo, TotHours, TotCalcHrs, AllocatedHrs)
  (Select Client, GroupCode, PPED = PayrollPeriodEndDate, SSN, ShiftNo,
--        TotHours = Sum(CASE WHEN Hours = 0 Then xAdjHours Else Hours End), 
        TotHours = Sum(Hours), 
        TotCalcHrs = Sum(RegHours + OT_Hours + DT_Hours),
        AllocatedHrs = sum(AllocatedRegHours + AllocatedOT_Hours + AllocatedDT_Hours)
  From tblTimeHistDetail
  Where Client = @Client
    and groupCode = @GroupCode
    and PayrollPeriodEnddate IN(@PPED, @PPED1)
  Group By Client, GroupCode, PayrollPeriodEndDate, SSN, ShiftNo )


  insert into #tmpRecs(Client, Groupcode, PPED, SSN, ShiftNo, TotHours, TotCalcHrs, AllocatedHrs)
  select t.Client, t.groupCode, t.PayrollPeriodEndDate, t.ssn, 1, sum(t.reghours), e.basehours, e.basehours
  from tblTimeHistDetail as t
  inner join timecurrent..tblEmplNames as e
    on e.client = t.client
    and e.groupcode = t.groupcode
    and e.ssn = t.ssn
  INNER JOIN timecurrent..tblClientGroups cg
    ON cg.Client = e.Client
    AND cg.GroupCode = e.GroupCode
    AND cg.GenSalaryRecs = '1'
  where t.client = @Client 
    and t.groupcode = @GroupCode 
    and t.payrollperiodenddate IN(@PPED, @PPED1)
    and e.paytype = '1'
  group by t.client, t.groupcode, t.payrollPeriodEndDate, t.ssn, e.basehours

	IF (@Client IN ('AMED','LOCU'))
	BEGIN
		INSERT INTO #tmpRecs(Client, Groupcode, PPED, SSN, ShiftNo, TotHours, TotCalcHrs, AllocatedHrs)
		SELECT thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, thd.ShiftNo,
--		        TotHours = Sum(CASE WHEN thd.Hours = 0 Then thd.xAdjHours Else thd.Hours End), 
		        TotHours = Sum(thd.Hours), 
		        TotCalcHrs = Sum(thd.RegHours + thd.OT_Hours + thd.DT_Hours),
		        AllocatedHrs = sum(thd.AllocatedRegHours + thd.AllocatedOT_Hours + thd.AllocatedDT_Hours)
		FROM TimeCurrent..tblClientGroups cg WITH(NOLOCK)
		INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)
		ON ped.Client = cg.Client
		AND ped.GroupCode = cg.GroupCode
		AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -2, @PPED) AND DATEADD(dd, 2, @PPED)
		INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd WITH(NOLOCK)
		ON thd.Client = ped.Client
		AND thd.GroupCode = ped.GroupCode
		AND thd.PayrollPeriodEndDate = ped.PayrollPeriodEndDate
		WHERE cg.Client = @Client
		AND cg.RecordStatus = '1'
		AND cg.GroupCode < 999990
		GROUP BY thd.Client, thd.GroupCode, thd.PayrollPeriodEndDate, thd.SSN, thd.ShiftNo
	END

    CREATE TABLE #tmpDupes
	(
		SSN INT,
		SiteNo INT,
		DeptNo INT,
		PPED DATETIME,
		TransDate DATETIME,
		ClockAdjustmentNo VARCHAR(3), --<Srinsoft 08/12/2015 Changed ClockAdjustmentNo CHAR(1) to VARCHAR(3) for #tmpDupes  >--
		Hours NUMERIC(7,2)
	)

  IF @Client = 'STAF'
  BEGIN

    DECLARE @MailSubject VARCHAR(1000)
	DECLARE @MailMessage VARCHAR(8000)
	DECLARE @MailTo VARCHAR(1000)

	SELECT @MailSubject = CAST(GroupCode AS VARCHAR) + ' ' + GroupName + ' timecard correction',
	       @MailTo = 'pat.lynch@peoplenet.com; gary.gordon@peoplenet.com; jimmy.billiter@peoplenet.com'
	FROM TimeCurrent..tblClientGroups
	WHERE Client = @Client
	AND GroupCode = @GroupCode

	SET @MailMessage = 'The following employees had duplicate time card entries that were automatically voided.  Please verify the timecards are correct.' + char(13) + char(10)

	INSERT INTO #tmpDupes( SSN ,SiteNo ,DeptNo ,PPED ,TransDate ,ClockAdjustmentNo ,Hours)
    SELECT SSN,SiteNo,DeptNo,PayrollPeriodEndDate,TransDate,ClockAdjustmentNo,Hours
	FROM TimeHistory..tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND PayrollPeriodEndDate = @PPED
	AND IsNull(ClockAdjustmentNo,'') = '1'
	AND UserCode = 'EML'
	GROUP BY Client,GroupCode,SSN,SiteNo,DeptNo,PayrollPeriodEndDate,TransDate,ClockAdjustmentNo,Hours HAVING COUNT(*) > 1

	DECLARE @SSN INT
	DECLARE @SiteNo INT
	DECLARE @DeptNo INT
	DECLARE @Week DATETIME
	DECLARE @TransDate DATETIME
	DECLARE @ClockAdjustmentNo VARCHAR(3) --< Srinsoft 08/12/2015 Changed @ClockAdjustmentNo CHAR(1) to VARCHAR(3) >--
	DECLARE @Hours NUMERIC(7,2)
	DECLARE @MinRecordId BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 04Aug2016 >--

	DECLARE csrDupes CURSOR READ_ONLY
	FOR SELECT SSN,SiteNo,DeptNo,PPED,TransDate,ClockAdjustmentNo,Hours
	FROM #tmpDupes

	OPEN csrDupes
	FETCH NEXT FROM csrDupes INTO @SSN,@SiteNo,@DeptNo,@Week,@TransDate,@ClockAdjustmentNo,@Hours
	WHILE (@@fetch_status <> -1)
	BEGIN
	  IF (@@fetch_status <> -2)
	  BEGIN
	    IF NOT EXISTS (
			SELECT 1
			FROM TimeHistory..tblTimeHistDetail
			WHERE Client = @Client
			AND GroupCode = @GroupCode
		    AND SSN = @SSN
			AND SiteNo = @SiteNo
			AND DeptNo = @DeptNo
			AND TransDate = @TransDate
			AND PayrollPeriodEndDate = @Week
			AND AprvlStatus = 'L'
		)
		BEGIN

			SELECT @MinRecordId = MIN(RecordID)
			FROM TimeHistory..tblTimeHistDetail
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND SSN = @SSN
			AND SiteNo = @SiteNo
			AND DeptNo = @DeptNo
			AND PayrollPeriodEndDate = @Week
			AND TransDate = @TransDate
			AND ClockAdjustmentNo = @ClockAdjustmentNo
    
			UPDATE TimeHistory..tblTimeHistDetail
			SET Hours = 0, TransType = 7
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND SSN = @SSN
			AND SiteNo = @SiteNo
			AND DeptNo = @DeptNo
			AND PayrollPeriodEndDate = @Week
			AND TransDate = @TransDate
			AND ClockAdjustmentNo = @ClockAdjustmentNo
			AND RecordID <> @MinRecordId
    
			SELECT @MailMessage = @MailMessage + LastName + ', ' + FirstName  + char(13) + char(10)
			FROM TimeCurrent..tblEmplNames
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND SSN = @SSN
		END
	  END
	  FETCH NEXT FROM csrDupes INTO @SSN,@SiteNo,@DeptNo,@Week,@TransDate,@ClockAdjustmentNo,@Hours
	END
	CLOSE csrDupes
	DEALLOCATE csrDupes

	INSERT INTO Scheduler..tblEmail
	        ( Client ,
	          GroupCode ,
	          SiteNo ,
	          TemplateName ,
	          MailTo ,
	          MailFrom ,
	          MailFromDesc ,
	          MailCC ,
	          MailBCC ,
	          MailSubject ,
	          MailMessage ,
	          MailAttachment ,
	          HTML ,
	          Source ,
	          DateAdded ,
	          DateHandled ,
	          ErrorMessage ,
	          Priority ,
	          EmailFileName ,
	          StatusID
	        )
	VALUES  ( @Client,
	          @GroupCode,
	          0 ,
	          '' ,
	          @MailTo ,
	          'DoNotReply@peopelent.com' ,
	          'Peoplenet' ,
	          '' ,
	          '' ,
	          @MailSubject ,
	          @MailMessage ,
	          '' ,
	          0 ,
	          '' ,
	          GETDATE() ,
	          GETDATE() ,
	          '' ,
	          0 ,
	          '' ,
	          0
	        )

  END

  SELECT @Client Client,
         @GroupCode GroupCode,
         PPED ,
         SSN,
         1 ShiftNo,
         1 TotHours,
         1 TotCalcHrs,
         1 AllocatedHrs
  FROM #tmpDupes
  
  UNION
  
  Select * from #tmpRecs
    where (TotHours <> TotCalcHrs and ShiftNo < 10 ) 
          or ShiftNo = 0 
--          or ( abs(TotHours - AllocatedHrs) > 0.05 and ShiftNo < 10)

  drop table #tmpRecs





