Create PROCEDURE [dbo].[usp_APP_TRCS_LunchRounding_SP]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int
)
AS
SET NOCOUNT ON

/*
DECLARE @Client varchar(4)
DECLARE @GroupCode int
DECLARE @PPED datetime
DECLARE @SSN int
set @Client = 'TRCS'
Set @GroupCode = 720100
Set @PPED = '11/11/2007'
Set @SSN =  83592

select o.ActualOutTime, o.RecordID, i.ActualInTime, i.RecordID, i.InTime, i.TransDate, i.MasterPayrollDate,
DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
and i.SSN = o.SSN
and i.InClass = o.OutClass  
and datediff(minute, isnull(o.ActualOutTime,dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime)), isnull(i.ActualInTime,dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) ) between 1 and 97
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn
and o.Outclass in('L','2')
return
*/

IF EXISTS (
SELECT 1
    FROM TimeHistory..tblTimeHistDetail thd
    INNER JOIN TimeHistory..tblTimeHistDetail thd2
    ON thd.Client = thd2.Client
    AND thd.GroupCode = thd2.GroupCode
    AND thd.SSN = thd2.SSN
    AND thd.SiteNo = thd2.SiteNo
    AND thd.DeptNo = thd2.DeptNo
    AND thd.PayrollPeriodEndDate = thd2.PayrollPeriodEndDate
    AND thd.TransDate = thd2.TransDate
    AND thd.ActualOutTime < thd2.ActualInTime
    AND thd.ClockAdjustmentNo IN ('',' ')
    AND thd2.ClockAdjustmentNo IN ('',' ')
    AND thd.Hours <> 0
    AND thd2.Hours <> 0
    AND thd.OutClass IN ('','S')
    AND thd2.InClass IN ('','S')
    WHERE thd.Client = @Client
    AND thd.GroupCode = @GroupCode
    AND thd.SSN = @SSN
    AND thd.PayrollPeriodEndDate = @PPED
)
BEGIN
  -- Sometimes CigTrans doesn't recognize punches as lunch out/in.  Run this to fix them if necessary.
  EXEC TimeHistory..usp_APP_FixLunchClass @Client, @GroupCode, @PPED, @SSN
END

DECLARE cPunch CURSOR
READ_ONLY
FOR 
select o.ActualOutTime, o.RecordID, i.ActualInTime, i.OutTime, i.SiteNo, i.DeptNo, i.RecordID, i.TransDate, i.MasterPayrollDate,
DiffInMinutes = datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime) )
from TimeHistory..tblTimeHistDetail as o
Inner Join TimeHistory..tblTimeHistDetail as i
on i.Client = o.Client
and i.Groupcode = o.GroupCode
and i.PayrollPeriodEndDate = o.PayrollPeriodEndDate
and i.SSN = o.SSN
and i.InClass = o.OutClass  
and datediff(minute, dbo.PunchDateTime2(o.TransDate, o.OutDay, o.OutTime), dbo.PunchDateTime2(i.TransDate, i.InDay, i.InTime)) between 1 and 97
where o.Client = @Client
and o.Groupcode = @GroupCode
and o.Payrollperiodenddate = @PPED
and o.SSN = @ssn
--and o.Outclass in('L','2')

DECLARE @OutTime datetime
DECLARE @iOutTime datetime
DECLARE @InTime DateTime
DECLARE @NewInTime DateTime
DECLARE @NewInDay int
DECLARE @TransDate datetime
DECLARE @Minutes int
DECLARE @MPD datetime
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @oRecordID BIGINT  --< @oRecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @iRecordID BIGINT  --< @iRecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
DECLARE @SiteNo int
DECLARE @DeptNo int
DECLARE @TotHours numeric(9,2)

OPEN cPunch

FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno,  @iRecordID, @TransDate, @MPD, @Minutes
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
    -- If the Lunch Break is 15 or less then add in an addition 15 minutes for lunch break.
    IF @Minutes <= 15 
    BEGIN
      Set @TotHours = -0.25
      Set @RecordID = NULL
      Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
                        where client = @Client 
                          and groupcode = @GroupCode
                          and Payrollperiodenddate = @PPED 
                          and SSN = @SSN
                          and Transdate = @TransDate
                          and ClockAdjustmentNo = '1'
                          and AdjustmentName = 'LUNCHBREAK'
                          and (Hours = @TotHours or (TransType = 7 and Hours = 0.00))
                          and InSrc = '3'
                          and isnull(UserCode,'') = 'SYS' )


      IF isNULL(@RecordID,0) = 0 
      BEGIN
				-- Make Sure User didn't add a Break Adjustment.
	      Set @RecordID = NULL
	      Set @RecordID = (Select TOP 1 RecordID from TimeHistory..tblTimeHistDetail
	                        where client = @Client 
	                          and groupcode = @GroupCode
	                          and Payrollperiodenddate = @PPED 
	                          and SSN = @SSN
	                          and Transdate = @TransDate
	                          and ClockAdjustmentNo = '8'
	                          and AdjustmentName = 'BREAK'
	                          and Hours = @TotHours
	                          and InSrc = '3'
	                          and isnull(UserCode,'') <> 'SYS' )
	
	      IF isNULL(@RecordID,0) = 0 
				BEGIN
	        -- The Adjustment does not exist so add it.
	        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'LUNCHBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
	        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
	      END
      END
    END
    
    IF @Minutes >= 45
    BEGIN
      Set @TotHours = 0.25
      Set @RecordID = NULL
      Set @RecordID = (Select  TOP 1 RecordID from TimeHistory..tblTimeHistDetail
                        where client = @Client 
                          and groupcode = @GroupCode
                          and Payrollperiodenddate = @PPED 
                          and SSN = @SSN
                          and Transdate = @TransDate
                          and ClockAdjustmentNo = '1'
                          and AdjustmentName = 'LUNCHBREAK'
                          and (Hours = @TotHours or (TransType = 7 and Hours = 0.00))
                          and InSrc = '3'
                          and isnull(UserCode,'') = 'SYS' )


      IF isNULL(@RecordID,0) = 0 
      BEGIN
				-- Make Sure User didn't add a Break Adjustment.
	      Set @RecordID = NULL
	      Set @RecordID = (Select  TOP 1 RecordID from TimeHistory..tblTimeHistDetail
	                        where client = @Client 
	                          and groupcode = @GroupCode
	                          and Payrollperiodenddate = @PPED 
	                          and SSN = @SSN
	                          and Transdate = @TransDate
	                          and ClockAdjustmentNo = '8'
	                          and AdjustmentName = 'BREAK'
	                          and Hours = @TotHours
	                          and InSrc = '3'
	                          and isnull(UserCode,'') <> 'SYS' )
	
	      IF isNULL(@RecordID,0) = 0 
				BEGIN
	        -- The Adjustment does not exist so add it.
	        EXEC [TimeHistory].[dbo].[usp_APP_XLSImport_Adjustment_Insert_THD] @Client, @GroupCode, @PPED, @SSN, @SiteNo, @DeptNo, '1', 'LUNCHBREAK', @TotHours, 0.00, @TransDate, @MPD, 'SYS'
	        --Print 'About to insert transaction for ' + convert(varchar(12), @TransDate,101) + ' - ' + str(@MinutesHH, 6,2) + ' hours '
	      END
      END
    END
	END
	FETCH NEXT FROM cPunch INTO @OutTime, @oRecordID, @InTime, @iOutTime, @SiteNo, @Deptno, @iRecordID, @TransDate, @MPD, @Minutes
END

CLOSE cPunch
DEALLOCATE cPunch







