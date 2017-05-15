Create PROCEDURE [dbo].[usp_APP_STFM_SpecialPay_Shift23Diff]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
BEGIN
SET NOCOUNT ON;

-- Zero out all previous Adjustments, but leave record for possible update
--   we will delete any left over at the end
--
UPDATE TimeHistory..tblTimeHistDetail
  SET Dollars = 0.00 , AdjustmentCode = '', AdjustmentName = ''
WHERE client = @CLient and groupcode = @Groupcode and ssn = @SSN
	and PayrollPeriodEndDate = @PPED
	and ClockAdjustmentNo in ('D','O')

DECLARE @MPD datetime,
		@SiteNo INT,   --< @SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
		@DeptNo INT,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 19Aug2016 >--
		@ShiftNo tinyint,
		@TransDate datetime,
		@ClockAdjustmentNo char(1),
		@AdjustmentCode varchar(3),
		@AdjustmentName varchar(50),
		@Hours numeric(5,2)

DECLARE	@Inday int

DECLARE cTHDSum CURSOR
READ_ONLY
FOR 
SELECT *
FROM
	(
		SELECT thd.MasterPayrollDate, thd.SiteNo, thd.DeptNo, thd.ShiftNo, thd.TransDate, ac.ClockAdjustmentNo, ac.AdjustmentCode, ac.AdjustmentName, sum(thd.RegHours) [Hours]
		FROM TimeHistory..tblTimeHistdetail AS thd WITH (nolock)
		INNER JOIN TimeCurrent..tblAdjCodes AS ac 
			ON ac.client = thd.client and ac.groupcode = thd.groupcode 
			AND ac.ClockAdjustmentNo = 'D'
		WHERE thd.client = @Client
		  and thd.groupcode = @GroupCode 
		  and thd.SSN = @SSN
		  and thd.Payrollperiodenddate = @PPED 
		  and thd.ClockAdjustmentNo in ('',' ','1','$','@','8')
		  and thd.ShiftNo in (2,3,8) 
		GROUP BY thd.MasterPayrollDate, thd.SiteNo, thd.DeptNo, thd.ShiftNo, thd.TransDate, ac.ClockAdjustmentNo, ac.AdjustmentCode, ac.AdjustmentName
		HAVING sum(thd.RegHours) <> 0	
		UNION
		SELECT thd.MasterPayrollDate, thd.SiteNo, thd.DeptNo, thd.ShiftNo, thd.TransDate, ac.ClockAdjustmentNo, ac.AdjustmentCode, ac.AdjustmentName, Sum(thd.OT_Hours) [Hours]
		FROM TimeHistory..tblTimeHistdetail AS thd WITH (nolock)
		INNER JOIN TimeCurrent..tblAdjCodes AS ac 
			ON ac.client = thd.client and ac.groupcode = thd.groupcode 
			AND ac.ClockAdjustmentNo = 'O'
		WHERE thd.client = @Client
		  and thd.groupcode = @GroupCode 
		  and thd.SSN = @SSN
		  and thd.Payrollperiodenddate = @PPED 
		  and thd.ClockAdjustmentNo in ('',' ','1','$','@','8')
		  and thd.ShiftNo in (2,3,8)--including shift 8 per US3586
		GROUP BY thd.MasterPayrollDate, thd.SiteNo, thd.DeptNo, thd.ShiftNo, thd.TransDate, ac.ClockAdjustmentNo, ac.AdjustmentCode, ac.AdjustmentName
		HAVING sum(thd.OT_Hours) <> 0
	) dummy
ORDER BY TransDate, ShiftNo, ClockAdjustmentNo

OPEN cTHDSum

FETCH NEXT FROM cTHDSum INTO @MPD, @SiteNo, @DeptNo, @ShiftNo, @TransDate, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, @Hours
WHILE (@@fetch_status = 0)
BEGIN
	IF isnull(@Hours,0) <> 0
	BEGIN
		IF Exists(Select 1 from TimeHistory..tblTimeHistDetail where Client = @Client and GroupCode = @Groupcode and PayrollPeriodEndDate = @PPED and SSN = @SSN
				and ClockAdjustmentNo = @ClockAdjustmentNo and Transdate = @Transdate and MasterPayrollDate = @MPD)
		BEGIN
			UPDATE TimeHistory..tblTimeHistDetail
				SET Dollars = @Hours, AdjustmentCode = @ClockAdjustmentNo, AdjustmentName = @AdjustmentName
			WHERE Client = @Client 
			and GroupCode = @Groupcode 
			and PayrollPeriodEndDate = @PPED 
			and SSN = @SSN
			and ClockAdjustmentNo = @ClockAdjustmentNo 
			and TransDate = @Transdate
			and MasterPayrollDate = @MPD
		END
		ELSE
		BEGIN
			Set @Inday = datepart(weekday, @TransDate)
			INSERT INTO TimeHistory.dbo.tblTimeHistDetail
			(
				 Client,GroupCode,SSN,PayrollPeriodEndDate,MasterPayrollDate,SiteNo,DeptNo  --ALL NOT NULLABLE IN THD
				,ClockAdjustmentNo,AdjustmentCode,AdjustmentName,Dollars,TransDate,InSrc,OutSrc
				,InDay,InTime,OutDay,OutTime,HandledByImporter,ClkTransNo,AgencyNo,ShiftNo
			)
			VALUES
			(
				@Client, @GroupCode, @SSN, @PPED, @MPD, @SiteNo, @DeptNo		
				,@ClockAdjustmentNo, @ClockAdjustmentNo,  @AdjustmentName, @Hours, @TransDate, '3', '3'
				,@Inday, '1899-12-30 00:00:00.000' , @Inday, '1899-12-30 00:00:00.000', 'V', 406, 1, @ShiftNo			
			)			
		END
	END
	FETCH NEXT FROM cTHDSum INTO @MPD, @SiteNo, @DeptNo, @ShiftNo, @TransDate, @ClockAdjustmentNo, @AdjustmentCode, @AdjustmentName, @Hours
END

CLOSE cTHDSum
DEALLOCATE cTHDSum

-- Delete any left over records
DELETE TimeHistory..tblTimeHistDetail
WHERE client = @CLient and groupcode = @Groupcode and ssn = @SSN
	and PayrollPeriodEndDate = @PPED
	and ClockAdjustmentNo in ('D','O')
	and Dollars = 0.00 and AdjustmentCode = ''and AdjustmentName = ''

END

