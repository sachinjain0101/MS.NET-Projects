Create PROCEDURE [dbo].[usp_APP_PaidBreak_SP]
(
  @MinHoursPerDay NUMERIC(7, 2),
  @PaidMinutes NUMERIC(7,2),
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON

DECLARE @TransDate datetime
DECLARE @MPD DATETIME
DECLARE @SiteNo INT
DECLARE @DeptNo INT
DECLARE @TotHours numeric(9,2)
DECLARE @RecordId BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--



DECLARE cPunch CURSOR
READ_ONLY
FOR 
SELECT thd2.SiteNo,thd2.DeptNo,thd2.TransDate,thd2.MasterPayrollDate
FROM
(
	SELECT TransDate,MasterPayrollDate,SUM(hours) Hours
	FROM TimeHistory..tblTimeHistDetail
	WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND PayrollPeriodEndDate = @PPED
	GROUP BY TransDate,MasterPayrollDate HAVING SUM(hours) > @MinHoursPerDay
) AS thd1
INNER JOIN TimeHistory..tblTimeHistDetail thd2
ON thd1.TransDate = thd2.TransDate
AND thd1.MasterPayrollDate = thd2.MasterPayrollDate
WHERE thd2.Client = @Client
AND thd2.GroupCode = @GroupCode
AND thd2.SSN = @SSN
AND thd2.PayrollPeriodEndDate = @PPED


OPEN cPunch

FETCH NEXT FROM cPunch INTO @SiteNo,@DeptNo,@TransDate,@MPD
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- 
    SELECT  @TotHours = @PaidMinutes / 60
    Set @RecordID = NULL
    Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
                      where client = @Client 
                        and groupcode = @GroupCode
                        and Payrollperiodenddate = @PPED 
                        and SSN = @SSN
                        and Transdate = @TransDate
                        and ClockAdjustmentNo = '1'
                        and AdjustmentName = 'PAIDBREAK'
                        and (Hours = @TotHours or (TransType = 7 and Hours = 0.00))
                        and isnull(UserCode,'') = 'SYS' )


    IF @RecordID IS NULL 
      -- The Adjustment does not exist so add it.
      EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'PAIDBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
    
	END
	FETCH NEXT FROM cPunch INTO @SiteNo,@DeptNo,@TransDate,@MPD
END

CLOSE cPunch
DEALLOCATE cPunch









