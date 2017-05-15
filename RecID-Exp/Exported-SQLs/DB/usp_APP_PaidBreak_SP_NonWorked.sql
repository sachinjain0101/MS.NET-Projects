CREATE Procedure [dbo].[usp_APP_PaidBreak_SP_NonWorked]
(
  @NonWorkedCode varchar(3),   --< Srinsoft 08/24/2015 Changed @NonWorkedCode char(1) to varchar(3) for clockadjustment >--
  @AdjName varchar(10),
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
DECLARE @BrkRecordId BIGINT  --< @BrkRecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 17Aug2016 >--

-- Get the breaks that have not been processed yet.
-- The Jobid from the 
DECLARE cBreaks CURSOR READ_ONLY STATIC
READ_ONLY
FOR 
	SELECT t.Hours, t.MasterPayrollDate, t.SiteNo, t.DeptNo, t.TransDate, T.RecordID 
	FROM TimeHistory..tblTimeHistDetail as t with(nolock)
  Left JOIN TimeHistory..tblTimeHistDetail t2 with(nolock)
  ON t2.Client = t.Client 
  and t2.Groupcode = t.groupcode
  and t2.PayrollPeriodEndDate = t.PayrollPeriodEndDate 
  and t2.SSN = t.SSN
  and t2.Transdate = t.TransDate
  and t2.ClockAdjustmentNo = @NonWorkedCode
  and t2.JobID = t.RecordID 
  WHERE t.Client = @Client
  AND t.GroupCode = @GroupCode
  AND t.SSN = @SSN
  AND t.PayrollPeriodEndDate = @PPED
  AND t.Clockadjustmentno = '8'
  and t.Hours < 0.00

OPEN cBreaks

FETCH NEXT FROM cBreaks INTO @TotHours, @MPD, @SiteNo, @DeptNo, @TransDate, @BrkRecordID
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    Set @TotHours = @TotHours * -1  --Reverse the amount 
    EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, @NonWorkedCode, @AdjName, @TotHours, 0.00, @TransDate, @MPD, 'SYS'

    -- Need to link these two transactions ( break transactions to the non-worked paid break ).
    Set @RecordID = (select max(recordID) from TimeHistory..tblTimeHistDetail with(nolock) 
                        where client = @Client 
                        and groupcode = @Groupcode 
                        and SSN = @SSN 
                        and payrollperiodenddate = @PPED 
                        and TransDAte = @TransDate 
                        and SiteNo = @SiteNo 
                        and DeptNo = @DeptNo 
                        and ClockAdjustmentNo = @NonWOrkedCode )
    IF isnull(@RecordID,0) <> 0
    BEGIN
      Update TimeHistory..tblTimeHistDetail 
        Set JobID = @BrkRecordID, 
            RegHours = Hours,
            RegDollars = round(Hours * payrate,2),
            RegBillingDollars = Round(Hours * BillRate,2),
            RegDollars4 = round(Hours * payrate,4),
            RegBillingDollars4 = Round(Hours * BillRate,4)
      where recordID = @RecordID
    END

	END
	FETCH NEXT FROM cBreaks INTO @TotHours, @MPD, @SiteNo, @DeptNo, @TransDate, @BrkRecordID
END

CLOSE cBreaks
DEALLOCATE cBreaks








