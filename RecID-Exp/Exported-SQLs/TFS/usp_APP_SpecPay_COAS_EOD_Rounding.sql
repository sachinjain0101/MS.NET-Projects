Create PROCEDURE [dbo].[usp_APP_SpecPay_COAS_EOD_Rounding]
(
	@Client varchar(4),
	@GroupCode int,
	@PPED datetime,
	@SSN int
)
AS 
SET NOCOUNT ON

IF exists(
		select 1
		from TimeHistory..tblTimeHistDetail as t with(nolock) 
		where t.client = @Client
		and t.groupcode = @GroupCode
		and t.payrollperiodenddate = @PPED
		and t.ssn = @SSN
		and t.intime >= '12/30/1899 22:15'
		and t.OutTime = '12/30/1899 23:00'
		and t.hours <> 0
		--AND t.JobID = 0
		and t.inday = datepart(weekday,t.Transdate)  )
BEGIN

	DECLARE @JobIDStamp BIGINT  --< @JobIdStamp data type is changed from  INT to BIGINT by Srinsoft on 29Sept2016 >--
	Set @JobIDStamp = convert(varchar(6),getdate(),12) + ltrim(str(datepart(hour,getdate())))

	Update TimeHistory..tblTimeHistDetail
		Set Transdate = dateadd(day,1,Transdate),
				Jobid = @JobIDStamp,
				Payrollperiodenddate = case when dateadd(day,1,Transdate) > PayrollPeriodenddate then dateadd(day,7,payrollperiodenddate) else PayrollPeriodEndDate end
	where client = @Client
	and groupcode = @Groupcode
	and payrollperiodenddate = @PPED
	and ssn = @SSN
	and intime >= '12/30/1899 22:15'
	and OutTime = '12/30/1899 23:00'
	and hours <> 0
	and inday = datepart(weekday,Transdate)


END

EXEC usp_APP_COAS_Borrowed_Empl_Move_Trans @Client,@GroupCode,@PPED,@SSN


IF @Client = 'COAS' AND @GroupCode IN (431523,431553)
BEGIN
	IF EXISTS (
		SELECT 1
		FROM TimeCurrent..tblEmplNames
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SSN = @SSN
		AND SubStatus3 = 'Y' -- Union employee
	)
	BEGIN
		EXEC TimeHistory..usp_APP_COAS_UnSplit_TransDate @Client,@GroupCode,@PPED,@SSN
	END
END

EXEC TimeHistory..usp_EmplCalc_OT_AutoClockOut_AT_Midnight @Client,@GroupCode,@PPED,@SSN




