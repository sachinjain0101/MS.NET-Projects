CREATE            Procedure [dbo].[usp_PLite_SynchPunch] (
	@Client char(4),
	@GroupCode int,
	@SiteNo int,
	@SSN int
)

AS

--*/
SET NOCOUNT ON

/*
DECLARE @Client		char(4)
DECLARE @GroupCode	int
DECLARE @SiteNo		int
DECLARE @SSN		int

SELECT @Client = 'HYPE'
SELECT @GroupCode = 100100
SELECT @SiteNo = 1
SELECT @SSN = 999999933
*/

DECLARE csrPunches CURSOR
READ_ONLY
FOR 
SELECT work.PayrollPeriodEndDate, work.TransDate, work.Dept, work.InSrc, work.InDay, 
	work.InTime, work.OutSrc, work.OutDay, work.OutTime,
	empls.Status, depts.BillRate, depts.PayRate
FROM tblWork_PLite_Punches as work
INNER JOIN TimeCurrent..tblEmplNames as empls
ON empls.Client = work.Client
	AND empls.GroupCode = work.GroupCode
	AND empls.SSN = work.SSN
INNER JOIN TimeCurrent..tblEmplSites_Depts as depts
ON depts.Client = work.Client
	AND depts.GroupCode = work.GroupCode
	AND depts.SiteNo = work.SiteNo
	AND depts.DeptNo = work.Dept
	AND depts.SSN = work.SSN
WHERE work.Client = @Client
	AND work.GroupCode = @GroupCode
	AND work.SiteNo = @SiteNo
	AND work.SSN = @SSN

DECLARE @tmpPPED		datetime
DECLARE @tmpTransDate	datetime
DECLARE @tmpDept		char(3)
DECLARE @tmpInSrc		char(1)
DECLARE @tmpInDay		tinyint
DECLARE @tmpInTime		datetime
DECLARE @tmpOutSrc		char(1)
DECLARE @tmpOutDay		tinyint
DECLARE @tmpOutTime		datetime
DECLARE @tmpEmpStatus	tinyint
DECLARE @tmpBillRate	numeric(7,2)
DECLARE @tmpPayRate		numeric(7,2)

DECLARE @RecordID		BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
DECLARE @PeriodStatus	char(1)
DECLARE @InSrc			char(1)
DECLARE @OutSrc			char(1)


OPEN csrPunches
FETCH NEXT FROM csrPunches INTO @tmpPPED, @tmpTransDate, @tmpDept, @tmpInSrc, @tmpInDay, @tmpInTime, @tmpOutSrc, @tmpOutDay, @tmpOutTime, @tmpEmpStatus, @tmpBillRate, @tmpPayRate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		SELECT @PeriodStatus = NULL
		SELECT @PeriodStatus = WeekClosed 
		FROM tblSiteNames 
		WHERE Client = @Client 
			AND GroupCode = @GroupCode 
			AND SiteNo = @SiteNo
			AND PayrollPeriodEndDate = @tmpPPED

		IF (@PeriodStatus <> 'C') OR (@PeriodStatus IS NULL)
		BEGIN
			SELECT @RecordID = NULL
			SELECT @RecordID = thd.RecordID, @InSrc = thd.InSrc, @OutSrc = thd.OutSrc
			FROM tblTimeHistDetail as thd
			LEFT JOIN TimeCurrent..tblFixedPunch as fixed
			ON thd.RecordID = fixed.OrigRecordID
			WHERE thd.Client = @Client
				AND thd.GroupCode = @GroupCode
				AND thd.SiteNo = @SiteNo
				AND thd.SSN = @SSN
				AND thd.PayrollPeriodEndDate = @tmpPPED
				AND thd.TransDate = @tmpTransDate
				AND (((thd.DeptNo = @tmpDept) AND ((CASE WHEN thd.Changed_DeptNo IS NULL THEN '0' ELSE thd.Changed_DeptNo END) <> '1')) OR ((thd.Changed_DeptNo = '1') AND (fixed.OldDeptNo = @tmpDept)))
				AND (((thd.InDay = @tmpInDay) AND (thd.InTime = @tmpInTime) AND (thd.InDay <> 10)) OR ((thd.OutDay = @tmpOutDay) AND (thd.OutTime = @tmpOutTime) AND (thd.OutDay <> 10)))

			IF @RecordID IS NULL
			BEGIN
				INSERT INTO tblTimeHistDetail (Client, GroupCode, SSN, PayrollPeriodEndDate, MasterPayrollDate, JobID, TransDate, SiteNo, DeptNo, InSrc, InDay, InTime, OutSrc, OutDay, OutTime, EmpStatus, BillRate, PayRate, ClockAdjustmentNo, DaylightSavTime, Holiday)
				VALUES (@Client, @GroupCode, @SSN, @tmpPPED, @tmpPPED, 0, @tmpTransDate, @SiteNo, @tmpDept, @tmpInSrc, @tmpInDay, @tmpInTime, @tmpOutSrc, @tmpOutDay, @tmpOutTime, @tmpEmpStatus, @tmpBillRate, @tmpPayRate, '', '0', '0')
			END
			ELSE
			BEGIN
				IF (@InSrc = 0)
				BEGIN
					UPDATE tblTimeHistDetail 
					SET InDay = @tmpInDay, InTime = @tmpInTime
					WHERE RecordID = @RecordID
				END
				IF (@OutSrc = 0)
				BEGIN
					UPDATE tblTimeHistDetail 
					SET OutDay = @tmpOutDay, OutTime = @tmpOutTime 
					WHERE RecordID = @RecordID
				END
			END
		END
	END
	FETCH NEXT FROM csrPunches INTO @tmpPPED, @tmpTransDate, @tmpDept, @tmpInSrc, @tmpInDay, @tmpInTime, @tmpOutSrc, @tmpOutDay, @tmpOutTime, @tmpEmpStatus, @tmpBillRate, @tmpPayRate
END

CLOSE csrPunches
DEALLOCATE csrPunches

UPDATE tblTimeHistDetail
SET Hours = CAST(DateDiff(minute, 
	DateAdd(day, InDay - DatePart(weekday, PayrollPeriodEndDate) - (CASE WHEN InDay > PayrollPeriodEndDate THEN 7 ELSE 0 END), PayrollPeriodEndDate) + InTime, 
	DateAdd(day, OutDay - DatePart(weekday, PayrollPeriodEndDate) - (CASE WHEN OutDay > PayrollPeriodEndDate THEN 7 ELSE 0 END), PayrollPeriodEndDate) + OutTime
) as numeric) / 60
WHERE Client = @Client
	AND GroupCode = @GroupCode
	AND SiteNo = @SiteNo
	AND SSN = @SSN
	AND InDay <> 10
	AND OutDay <> 10
	AND ((LTrim(ClockAdjustmentNo) = '') OR (ClockAdjustmentNo IS NULL))

EXEC usp_PLite_FlagMissingPunches @Client, @GroupCode, @SiteNo, @SSN



