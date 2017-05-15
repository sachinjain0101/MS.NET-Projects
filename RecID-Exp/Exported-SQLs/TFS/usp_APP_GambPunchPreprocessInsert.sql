Create PROCEDURE [dbo].[usp_APP_GambPunchPreprocessInsert] (
	@InPunch		DateTime,
	@BA_ID			varchar(32),
	@InSite			varchar(20),
	@OutPunch		DateTime,
	@OutSite		varchar(20),
	@Notes			varchar(100)
)
AS

SET NOCOUNT ON

Declare @DeptNo 		INT  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
Declare @GroupCode 	Int
Declare @SSN 				Int
Declare @PrimarySite int
Declare @InSiteNo	INT  --< @InSiteNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
Declare @PunchType char(1)


set @PunchType = 'M'
IF @Notes = '' 
	SET @Notes = NULL
ELSE
	SET @Notes = '[' + convert(varchar(8), @InPunch, 1) + '] ' + @Notes

SELECT @GroupCode = GroupCode, @InSiteNo = SiteNo FROM TimeCurrent..tblSiteNames WHERE Client = 'GAMB' AND ExportMailBox = @InSite AND RecordStatus = '1'
IF @InSiteNo IS NULL OR @GroupCode IS NULL
BEGIN
	SELECT -1 as ReturnCode --No such site
	RETURN
END

SET @SSN = (SELECT SSN FROM TimeCurrent..tblEmplNames WHERE Client = 'GAMB' AND GroupCode = @GroupCode AND AssignmentNo = @BA_ID AND RecordStatus = '1')
IF @SSN IS NULL
BEGIN
	SELECT -2 as ReturnCode --No such ee
	RETURN
END
SET @DeptNo = (SELECT PrimaryDept FROM TimeCurrent..tblEmplNames WHERE Client = 'GAMB' AND GroupCode = @GroupCode AND SSN = @SSN AND RecordStatus = '1')
IF @DeptNo IS NULL
BEGIN
	SELECT -3 as ReturnCode --No PrimaryDept
	RETURN
END

IF @OutPunch = '01/01/1900'
Begin
	SET @OutPunch = NULL
	SET @PunchType = 'I'
End

IF @InPunch = '01/01/1900'
Begin
	SET @InPunch = NULL
	SET @PunchType = 'O'
End

--check tblemplsites
IF (SELECT COUNT(*) FROM TimeCurrent..tblEmplSites WHERE Client = 'GAMB' AND GroupCode = @GroupCode AND SSN = @SSN AND SiteNo = @InSiteNo AND RecordStatus = '1') = 0
BEGIN
	SET @PrimarySite = (SELECT PrimarySite FROM TimeCurrent..tblEmplNames WHERE Client = 'GAMB' AND GroupCode = @GroupCode AND SSN = @SSN AND RecordStatus = '1')
	--insert into timecurrent
	INSERT INTO TimeCurrent..tblEmplSites
	(Client, GroupCode, SiteNo, SSN, Status, AgencyNo, ShiftClass, ScheduledShift, OpenDepartments, PayType, ScheduledDays, BaseHours, ShiftDiff, Borrowed, NewPNE_Entry, RecordStatus, ShiftDiffClass)
	SELECT Client, GroupCode, @InSiteNo, SSN, Status, AgencyNo, ShiftClass, ScheduledShift, OpenDepartments, PayType, ScheduledDays, BaseHours, ShiftDiff, Borrowed, NewPNE_Entry, RecordStatus, ShiftDiffClass
	FROM TimeCurrent..tblEmplSites
	WHERE Client = 'GAMB'
	AND GroupCode = @GroupCode
	AND SSN = @SSN
	AND SiteNo = @PrimarySite
	AND RecordStatus = '1'

	--insert into timehistory
	DECLARE @openPPED datetime

	DECLARE PPEDCsr CURSOR READ_ONLY
	FOR SELECT PayrollPeriodEndDate FROM timehistory..tblPeriodEndDates
		WHERE Client = 'GAMB'
		and GroupCode = @GroupCode
		and Status IN ('O', 'M')		

	OPEN PPEDCsr

	FETCH NEXT FROM PPEDCsr INTO @openPPED
	WHILE (@@fetch_status = 0)
	BEGIN
		INSERT INTO TimeHistory..tblEmplSites
		(Client, GroupCode, SiteNo, SSN, Status, AgencyNo, ShiftClass, ScheduledShift, OpenDepartments, PayType,BaseHours, RecordStatus, PayrollPeriodEndDate)
		SELECT Client, GroupCode, @InSiteNo, SSN, Status, AgencyNo, ShiftClass, ScheduledShift, OpenDepartments, PayType, BaseHours, RecordStatus, @OpenPPED
		FROM TimeCurrent..tblEmplSites
		WHERE Client = 'GAMB'
		AND GroupCode = @GroupCode
		AND SSN = @SSN
		AND SiteNo = @PrimarySite
		AND RecordStatus = '1'
		FETCH NEXT FROM PPEDCsr INTO @openPPED
	END
	Close PPEDCsr
	Deallocate PPEDCsr
END


INSERT INTO tblPunchImport
(Client, GroupCode, InSite, OutSite, SSN, DeptNo, PunchType, InDateTime, OutDateTime, InDSTStatus, OutDSTStatus, Status, Comment, AddedDateTime)
Values
('GAMB', @GroupCode, @InSiteNo, @InSiteNo, @SSN, @DeptNo, @PunchType, @InPunch, @OutPunch, '0','0','NEW', @Notes, GetDate())

SELECT 0 as ReturnCode
 


--EXEC TimeHistory..usp_APP_SprintPunchPreprocessInsert '2001-02-12 17:28:47',8156, 8, '', 8, '' 















