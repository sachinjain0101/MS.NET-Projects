CREATE       procedure [dbo].[usp_APP_GenericPayrollUpload_GetRecs_TRCS]
(
  @Client varchar(4),
  @Group  int,
  @PayrollPeriodEndDate   datetime,
	@PAYRATEFLAG 	 varchar(4),
	@EMPIDType    varchar(6),
	@REGPAYCODE		varchar(10),
	@OTPAYCODE		varchar(10),
	@DTPAYCODE		varchar(10),
  @PayrollType  varchar(80),
  @IncludeSalary char(1),
  @TestingFlag char(1) = 'N'
)
AS


SET NOCOUNT ON


/*
DECLARE  @Client varchar(4)
DECLARE  @GroupCode  int
DECLARE  @PPED   datetime
DECLARE	@PAYRATEFLAG 	 varchar(4)
DECLARE	@EMPIDType    varchar(6)
DECLARE	@REGPAYCODE		varchar(10)
DECLARE	@OTPAYCODE		varchar(10)
DECLARE	@DTPAYCODE		varchar(10)
DECLARE  @PayrollType  varchar(80)
DECLARE  @IncludeSalary char(1)
DECLARE  @TestingFlag char(1)

SET  @Client = 'STFM'
SET  @GroupCode = 523200
SET  @PPED = '12/23/07'
SET	@PAYRATEFLAG = 'No'
SET	@EMPIDType = 'SSN'
SET	@REGPAYCODE = '001'''
SET	@OTPAYCODE = '002'
SET	@DTPAYCODE = '003'
SET  @PayrollType  = 'Custom'
SET  @IncludeSalary = 'N'
SET  @TestingFlag  = 'Y'

DROP TABLE #tmpUpload
DROP TABLE #tmpUpload2
*/

IF (@PayrollType = 'CORP')
BEGIN
	EXEC usp_APP_GenericPayrollUpload_GetRecs_TRCS_Corp @Client, @Group, @PayrollPeriodEndDate, @PAYRATEFLAG, @EMPIDType,
																											@REGPAYCODE, @OTPAYCODE, @DTPAYCODE, @PayrollType, @IncludeSalary,
																										  @TestingFlag
	RETURN
END

DECLARE @Delim char(1)
DECLARE @Now datetime
DECLARE @GroupCode INT
DECLARE @SiteDeptLevelRates VARCHAR(1)
DECLARE @UseGeneralDept VARCHAR(1) 
DECLARE @PPED DATETIME
DECLARE @RowCount INT 
DECLARE @RecordCount INT
DECLARE @OrigInTime DATETIME 
DECLARE @OrigOutTime DATETIME 
DECLARE @BreakMatchingPunchRecordId INT
DECLARE @BreakRecordId INT
DECLARE @BreakSSN INT
DECLARE @BreakDeptNo INT
DECLARE @BreakStartDate DATETIME
DECLARE @BreakHours NUMERIC(7,2)
DECLARE @BreakGroupCode INT 
DECLARE @LateTimeEntryWeeks INT 
DECLARE @LateTimeCutoff DATETIME 
DECLARE @MA_EmailText VARCHAR(8000)
DECLARE @MA_SSN INT
DECLARE @MA_DeptNo INT
DECLARE @MA_LastName VARCHAR(50)
DECLARE @MA_FirstName VARCHAR(50)
DECLARE @MA_GroupName VARCHAR(100)
DECLARE @MA_Counter INT
DECLARE @crlf CHAR(2)
DECLARE @SendEmailTo VARCHAR(100)
DECLARE @RequestDay INT
DECLARE @FollowupDay INT
DECLARE @EscalateDay INT

SET @Delim = ','
SET @Now = GETDATE()
SET @MA_Counter = 0
SET @crlf = char(13) + char(10)
SET @SendEmailTo = 'john.clifford@trcstaffing.com,karen.bapst@trcstaffing.com,payroll@trcstaffing.com'

CREATE TABLE #tmpUpload 
(
	RecordID								INT IDENTITY (1, 1) NOT NULL,
	GroupCode								INT, 
	DeptNo									INT,
	FileNo 									VARCHAR(50),
	EmployeeName 						VARCHAR(100),
	TimeCardID							INT,
	TCSubmitDate						VARCHAR(10),
	SSN											INT,
	AssignmentNo						VARCHAR(50),
	PayrollPeriodEndDate 		DATETIME,
	PayCode									VARCHAR(20),
	StartDate								VARCHAR(10),
	EndDate									VARCHAR(10),
	BreakMins								NUMERIC(7,2),
	InTime									VARCHAR(5),
	OutTime									VARCHAR(5),
	ApproverId							VARCHAR(20),
	ApproverName						VARCHAR(100),
	ApprovalDate						VARCHAR(10),
	TCInternalApprovalID		VARCHAR(20),
	TCInternalApprovalName 	VARCHAR(100),
	TCInternalApprovalDate 	VARCHAR(10),
	Hours										NUMERIC(7,2),
	ClockAdjustmentNo				VARCHAR(10),
	AprvlAdjOrigRecID				BIGINT,  --< AprvlAdjOrigRecID data type is changed from  INT to BIGINT by Srinsoft on 11Aug2016 >--
	ShiftNo						INT
)


DECLARE groupPPEDCursor CURSOR READ_ONLY
FOR SELECT 	cg.GroupCode,
						IsNull(SiteDeptLevelRates, '0') AS SiteDeptLevelRates,
					 	case when isnull(AssignToClockMethod,'0') = '1' then '1' else '0' END AS UseGeneralDept,
						ped.PayrollPeriodEndDate,
						cg.LateTimeEntryWeeks
		FROM TimeCurrent.dbo.tblClientGroups cg
		INNER JOIN TimeHistory..tblPeriodEndDates ped
		ON ped.Client = cg.Client
		AND ped.GroupCode = cg.GroupCode
		AND ((@Now > ped.PayrollPeriodEndDate) OR		
				 (@Now < ped.PayrollPeriodEndDate AND DATEPART(dw, @Now) >= 5))
		AND DATEADD(dd, -30, @Now) < ped.PayrollPeriodEndDate
		AND ((ped.Status <> 'C') OR (ped.OverrideStatus = '1'))
		AND ped.PayrollPeriodEndDate >= '9/20/2009'
		WHERE cg.Client = @Client
		AND cg.GroupCode NOT IN (720501) -- Corp 

OPEN groupPPEDCursor

FETCH NEXT FROM groupPPEDCursor INTO @GroupCode, @SiteDeptLevelRates, @UseGeneralDept, @PPED, @LateTimeEntryWeeks
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		INSERT INTO #tmpUpload
		Select 	t.GroupCode,
						t.DeptNo,
						e.FileNo, 
						e.Lastname + ',' + e.FirstName AS EmployeeName, 
						ISNULL(ed.RecordID, th_en.RecordID) AS TimeCardID,
						ISNULL(CONVERT(VARCHAR(10), th_en.EmplApprovalDate, 101), '') AS TCSubmitDate,
						t.SSN, 
						CASE WHEN @SiteDeptLevelRates = '1' THEN ISNULL(ea.AssignmentNo,'')
						     WHEN ISNULL(t.CostId,'') NOT IN ('', '0') THEN t.CostId
							 ELSE ISNULL(ed.AssignmentNo,'') END AS AssignmentNo,
--						case when @SiteDeptLevelRates = '0' then isnull(ed.AssignmentNo,'') else isnull(ea.AssignmentNo,'') END AS AssignmentNo,
						t.PayrollPeriodEndDate, 
						CASE WHEN t.ClockAdjustmentNo IN ('', ' ') THEN 'W' ELSE ltrim(rtrim(a.ADP_HoursCode)) END AS PayCode,
						CONVERT(VARCHAR(10), t.TransDate, 101) AS StartDate,
						CASE WHEN t.Outday > t.InDay OR t.OutDay = 1 AND t.InDay = 7 THEN CONVERT(VARCHAR(10), DATEADD(dd, 1, t.TransDate), 101) ELSE CONVERT(VARCHAR(10), t.TransDate, 101) END as EndDate,
						0.00 AS BreakMins,
						CASE WHEN ISNULL(t.InTime,'1899-12-30 00:00:00.000') = '1899-12-30 00:00:00.000' AND ISNULL(t.OutTime,'1899-12-30 00:00:00.000') = '1899-12-30 00:00:00.000' THEN '' ELSE CONVERT(VARCHAR(5), t.InTime, 108) END AS InTime,
						CASE WHEN ISNULL(t.InTime,'1899-12-30 00:00:00.000') = '1899-12-30 00:00:00.000' AND ISNULL(t.OutTime,'1899-12-30 00:00:00.000') = '1899-12-30 00:00:00.000' THEN '' ELSE CONVERT(VARCHAR(5), t.OutTime, 108) END AS OutTime,
						CASE WHEN ISNULL(t.AprvlStatus, '') NOT IN ('D','') THEN ISNULL(CAST(t.AprvlStatus_UserID AS VARCHAR), '') ELSE '' END AS ApproverId,
						CASE WHEN ISNULL(t.AprvlStatus, '') NOT IN ('D','') THEN ISNULL(LEFT(usr.LastName + ', ' + usr.FirstName, 30), '') ELSE '' END AS ApproverName,
						CASE WHEN ISNULL(t.AprvlStatus, '') NOT IN ('D','') THEN CONVERT(VARCHAR(10), t.AprvlStatus_Date, 101) ELSE '' END AS ApprovalDate,
--						ISNULL(CAST(usr2.UserId AS VARCHAR), '') AS TCInternalApprovalID,
--						ISNULL(LEFT(usr2.LastName + ', ' + usr2.FirstName, 30), '') AS TCInternalApprovalName,
--						ISNULL(CONVERT(VARCHAR(10), ped.WeekClosedDateTime, 101), '') AS TCInternalApprovalDate,
						'0' AS TCInternalApprovalID,
						'N/A' AS TCInternalApprovalName,
						ISNULL(CONVERT(VARCHAR(10), @Now, 101), '') AS TCInternalApprovalDate,
						t.Hours,
						t.ClockAdjustmentNo,
						t.AprvlAdjOrigRecID,
						ISNULL(t.ShiftNo, 0)
		FROM TimeHistory..tblTimeHistdetail as t
		INNER JOIN timehistory..tblEmplNames th_en
		ON th_en.Client = t.Client
		AND th_en.GroupCode = t.GroupCode
		AND th_en.SSN = t.SSN
		AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate
		AND th_en.PayRecordsSent IS NULL
		AND th_en.SecondLevelApprovalDate IS NOT NULL
		INNER JOIN  TimeCurrent..tblEmplNames as e
		ON e.Client = t.Client
		AND e.GroupCode = t.GroupCode
		AND e.SSN = t.SSN
		INNER JOIN  TimeCurrent..tblSiteNames as s
		ON s.Client = t.Client
		AND s.GroupCode = t.GroupCode
		AND s.SiteNo = t.SiteNo
		LEFT JOIN  TimeCurrent..tblAdjcodes as a
		ON a.Client = t.Client
		AND a.GroupCode = t.GroupCode
		AND a.ClockAdjustmentNo = t.ClockAdjustmentNo
		INNER JOIN TimeHistory..tblPeriodEndDates AS ped
		ON ped.Client = t.Client
		AND ped.GroupCode = t.GroupCode
		AND ped.PayrollPeriodEndDate = t.PayrollPeriodEndDate
		LEFT JOIN TimeHistory..tblEmplNames_Depts as ed
		ON ed.Client = t.Client
		AND ed.Groupcode = t.Groupcode
		AND ed.SSN = t.SSN
		AND ed.Department = t.DeptNo
		AND ed.Payrollperiodenddate = t.Payrollperiodenddate
		AND isnull(ed.ExcludeFromUpload,'0')  <> '1'
		LEFT JOIN TimeHistory..tblEmplSites_Depts as esd
		ON esd.Client = t.Client
		AND esd.Groupcode = t.Groupcode
		AND esd.SSN = t.SSN
		AND esd.DeptNo = t.DeptNo
		AND esd.SiteNo = t.SiteNo
		AND esd.Payrollperiodenddate = t.Payrollperiodenddate
		AND isnull(esd.ExcludeFromUpload,'0') <> '1'
		LEFT JOIN TimeCurrent..tblEmplAssignments as ea
		ON ea.Client = t.Client
		AND ea.Groupcode = t.Groupcode
		AND ea.SSN = t.SSN
		AND ea.DeptNo = t.DeptNo
		AND ea.SiteNo = t.SiteNo
		AND ((@SiteDeptLevelRates = '0' and 1 = 0) or (@SiteDeptLevelRates = '1'))
		LEFT JOIN TimeCurrent..tblAgencies as agy
		ON agy.Client = @Client
		AND agy.Groupcode = @Groupcode
		AND agy.Agency = e.AgencyNo
		INNER JOIN  TimeCurrent..tblGroupDepts as gd
		ON gd.Client = @Client
		AND gd.Groupcode = @Groupcode
		AND gd.DeptNo = t.DeptNo
		LEFT JOIN TimeCurrent..tblUser as Usr
		ON usr.UserID = isnull(t.AprvlStatus_UserID, 0)
--		LEFT JOIN TimeCurrent..tblUser as Usr2
--		ON usr2.LogonName = ped.MaintUserName
		WHERE t.Client = @Client
		AND t.GroupCode = @GroupCode
		AND t.Payrollperiodenddate = @PPED
		AND (t.RegHours <> 0 OR t.OT_Hours <> 0 OR t.DT_Hours <> 0)
		AND isnull(agy.ExcludeFromPayFile, '0') = '0'
		AND ((isnull(a.Worked, 'Y') = 'Y') OR (t.ClockAdjustmentNo = '@'))
		AND t.SSN NOT IN (SELECT DISTINCT SSN
											FROM TimeHistory.dbo.tblTimeHistDetail AS thd
											WHERE Client = @Client
											AND GroupCode = @GroupCode
											AND PayrollPeriodEndDate = @PPED
											AND Hours <> 0
											AND ( InDay = 10 OR		
														OutDay = 10 OR
														AprvlStatus NOT IN ('A','L')))

		DECLARE MissingAssignmentCursor CURSOR READ_ONLY
		FOR SELECT DISTINCT t.SSN, t.DeptNo, en.LastName, en.FirstName, cg.GroupName
				FROM #tmpUpload t
				INNER JOIN TimeCurrent.dbo.tblEmplNames en
				ON en.Client = @Client
				AND en.GroupCode = @GroupCode
				AND en.SSN = t.SSN
				INNER JOIN TimeCurrent.dbo.tblClientGroups cg
				ON cg.Client = en.Client
				AND cg.GroupCode = en.GroupCode		
				WHERE t.GroupCode = @GroupCode
				AND t.PayrollPeriodEndDate = @PPED
				AND ISNULL(t.AssignmentNo, '') IN ('', '0')
		
		OPEN MissingAssignmentCursor
		
		FETCH NEXT FROM MissingAssignmentCursor INTO @MA_SSN, @MA_DeptNo, @MA_LastName, @MA_FirstName, @MA_GroupName
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN

				IF (@MA_Counter = 0)
				BEGIN
					SET @MA_EmailText = '<html><b>The following Time Sheets have missing assignment numbers:</b>' + '<br><br>'
				END
				
				SET @MA_EmailText = @MA_EmailText + @MA_GroupName + '(' + CAST(@GroupCode as VARCHAR) + ')' + ' - ' + @MA_LastName + ', ' + @MA_FirstName + ' - Dept: ' + CAST(@MA_DeptNo as VARCHAR) + ' for week ' + CONVERT(VARCHAR, @PPED, 101) + '<br>'
				SET @MA_Counter = @MA_Counter + 1

				DELETE FROM #tmpUpload
				WHERE GroupCode = @GroupCode
				AND PayrollPeriodEndDate = @PPED
				AND SSN = @MA_SSN
			END
			FETCH NEXT FROM MissingAssignmentCursor INTO @MA_SSN, @MA_DeptNo, @MA_LastName, @MA_FirstName, @MA_GroupName
		END
		CLOSE MissingAssignmentCursor
		DEALLOCATE MissingAssignmentCursor

		
		---- Detect zero shift
		DECLARE ZeroShiftCursor CURSOR READ_ONLY
		FOR SELECT DISTINCT t.SSN, t.DeptNo, en.LastName, en.FirstName, cg.GroupName
				FROM #tmpUpload t
				INNER JOIN TimeCurrent.dbo.tblEmplNames en
				ON en.Client = @Client
				AND en.GroupCode = @GroupCode
				AND en.SSN = t.SSN
				INNER JOIN TimeCurrent.dbo.tblClientGroups cg
				ON cg.Client = en.Client
				AND cg.GroupCode = en.GroupCode		
				WHERE t.GroupCode = @GroupCode
				AND t.PayrollPeriodEndDate = @PPED
				AND t.ShiftNo = 0
		
		OPEN ZeroShiftCursor
		
		FETCH NEXT FROM ZeroShiftCursor INTO @MA_SSN, @MA_DeptNo, @MA_LastName, @MA_FirstName, @MA_GroupName
		WHILE (@@fetch_status <> -1)
		BEGIN
			IF (@@fetch_status <> -2)
			BEGIN

				IF (@MA_Counter = 0)
				BEGIN
					SET @MA_EmailText = '<html><b>The following Time Sheets have zero Shift:</b>' + '<br><br>'
				END
				ELSE
				BEGIN
					SET @MA_EmailText = @MA_EmailText +  '<br><b>The following Time Sheets have zero Shift:</b>' + '<br><br>'
				END
				
				SET @MA_EmailText = @MA_EmailText + @MA_GroupName + '(' + CAST(@GroupCode as VARCHAR) + ')' + ' - ' + @MA_LastName + ', ' + @MA_FirstName + ' - Dept: ' + CAST(@MA_DeptNo as VARCHAR) + ' for week ' + CONVERT(VARCHAR, @PPED, 101) + '<br>'
				SET @MA_Counter = @MA_Counter + 1

				DELETE FROM #tmpUpload
				WHERE GroupCode = @GroupCode
				AND PayrollPeriodEndDate = @PPED
				AND SSN = @MA_SSN
			END
			FETCH NEXT FROM ZeroShiftCursor INTO @MA_SSN, @MA_DeptNo, @MA_LastName, @MA_FirstName, @MA_GroupName
		END
		CLOSE ZeroShiftCursor
		DEALLOCATE ZeroShiftCursor
				

		-- Lock the employees timecard so it can't be edited
		UPDATE TimeHistory..tblEmplNames
		SET PayRecordsSent = @Now,
				WeekLocked = '1'
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate = @PPED
		AND SSN IN (SELECT DISTINCT SSN
								FROM #tmpUpload
								WHERE Client = @Client
								AND GroupCode = @GroupCode
								AND PayrollPeriodEndDate = @PPED)
		SELECT @RowCount = @@ROWCOUNT
		

		-- Set status to 'C' for the PPED when all employees are paid
		-- Update only if the datetime for the last email request for the week has passed
		IF TimeCurrent.dbo.fn_LatestWeeklyEmailRequest(@Client,@GroupCode,@PPED,DATEADD(dd,-1,GETDATE())) < GETDATE()
		BEGIN
			UPDATE TimeHistory.dbo.tblPeriodEndDates
			SET Status = 'C',
					OverrideStatus = '1',
					WeekClosedDateTime = GETDATE(),
					MaintUserName = 'Payfile'
			WHERE Client = @Client
			AND GroupCode = @GroupCode
			AND PayrollPeriodEndDate = @PPED
			AND @Now > PayrollPeriodEndDate
			AND Status <> 'C'
			AND NOT EXISTS(	SELECT 1
											FROM TimeHistory.dbo.tblEmplNames th_en
											INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
											ON thd.Client = th_en.Client
											AND thd.GroupCode = th_en.GroupCode
											AND thd.PayrollPeriodEndDate = th_en.PayrollPeriodEndDate
											AND thd.SSN = th_en.SSN
											WHERE th_en.Client = @Client
											AND th_en.GroupCode = @GroupCode
											AND th_en.PayrollPeriodEndDate = @PPED
											AND th_en.PayRecordsSent IS NULL)
			SELECT @RowCount = @@ROWCOUNT
			
			IF (@RowCount > 0)
			BEGIN
				SELECT @LateTimeCutoff = DATEADD(dd, @LateTimeEntryWeeks * 7 * -1, @PPED)
				
				-- Let the oldest of the late time entry drop off so that it can't be used anymore on WTE
				UPDATE TimeHistory..tblPeriodEndDates
				SET OverrideStatus = '0',
						MaintUserName = 'System',
						MaintDateTime = GETDATE()
				WHERE Client = @Client
				AND GroupCode = @GroupCode
				AND PayrollPeriodEndDate <= @LateTimeCutoff	
				AND ISNULL(OverrideStatus, '') <> '0'			
			END
		END
	END
	FETCH NEXT FROM groupPPEDCursor INTO @GroupCode, @SiteDeptLevelRates, @UseGeneralDept, @PPED, @LateTimeEntryWeeks
END
CLOSE groupPPEDCursor
DEALLOCATE groupPPEDCursor

UPDATE #tmpUpload
SET #tmpUpload.InTime = CONVERT(VARCHAR(5), thd.InTime, 108),
		#tmpUpload.OutTime = CONVERT(VARCHAR(5), thd.OutTime, 108)
FROM #tmpUpload tmp
INNER JOIN TimeHistory.dbo.tblTimeHistDetail thd
ON thd.RecordID = tmp.AprvlAdjOrigRecID
WHERE tmp.ClockAdjustmentNo = '@'

DECLARE breakCursor CURSOR READ_ONLY
FOR SELECT RecordId, GroupCode, SSN, DeptNo, StartDate, Hours
		FROM #tmpUpload
		WHERE ClockAdjustmentNo = '8'

OPEN breakCursor

FETCH NEXT FROM breakCursor INTO @BreakRecordId, @BreakGroupCode, @BreakSSN, @BreakDeptNo, @BreakStartDate, @BreakHours
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		SELECT TOP 1 @BreakMatchingPunchRecordId = RecordID
		FROM #tmpUpload
		WHERE GroupCode = @BreakGroupCode
		AND SSN = @BreakSSN
		AND ClockAdjustmentNo <> '8'
		ORDER BY  CASE WHEN StartDate = @BreakStartDate THEN 0 ELSE 1 END,
						  CASE WHEN DeptNo = @BreakDeptNo THEN 0 ELSE 1 END,
						  CASE WHEN ClockAdjustmentNo = '' THEN 0 ELSE 1 END,
							Hours DESC

		UPDATE #tmpUpload
		SET BreakMins = BreakMins + (@BreakHours * -1 * 60),
				Hours = Hours - (@BreakHours * -1)
		WHERE RecordID = @BreakMatchingPunchRecordId

		DELETE FROM #tmpUpload
		WHERE RecordId = @BreakRecordId

	END
	FETCH NEXT FROM breakCursor INTO @BreakRecordId, @BreakGroupCode, @BreakSSN, @BreakDeptNo, @BreakStartDate, @BreakHours
END
CLOSE breakCursor
DEALLOCATE breakCursor

SELECT @RecordCount = COUNT(*) FROM #tmpUpload

IF (@RecordCount > 0)
begin
	select 	GroupCode,
					SSN, 
					EmployeeID = FileNo, 
					EmployeeName AS EmpName, 
					PayrollPeriodEndDate AS PPED,
					AssignmentNo,
					Line1 = '"' + FileNo + '","' +   -- FileNo
									case when isnull(AssignmentNo,'') = '' then '0000000' else AssignmentNo End + '","' +  -- AssignmentNo
									ISNULL(CAST(TimeCardID AS VARCHAR), '') + '","' + -- TimeCard ID
									PayCode + '","' + -- Pay Code
									InTime + '","' + -- In Time
									OutTime + '",' + -- Out Time
									CAST(BreakMins AS VARCHAR) + ',' + -- Break Length
									CAST(Hours AS VARCHAR) + ',"' + -- Num hours
									StartDate + '","' + -- StartDate
									CONVERT(VARCHAR(10), PayrollPeriodEndDate, 101) + '","' + -- End Date
									StartDate + '","' + -- Worked Date
									cast(ApproverID AS varchar) + '","' + -- Approver ID
									ApproverName + '","' + -- Approver ID
									ApprovalDate + '","' + -- Approval Date
									TCInternalApprovalID + '","' + -- Internal Approver ID
									TCInternalApprovalName + '","' + -- Internal Approver Name
									TCInternalApprovalDate + '","' + -- Internal Approval Date
									FileNo + '","' + -- Candidate Sbm ID
									LEFT(EmployeeName, 30) + '","' + -- Candidate Sbm Name
									'' + '"' -- Candidate Sbm Date
	from #tmpUpload
	order by 	GroupCode,
						PPED,
						FileNo, 
						AssignmentNo, 
						StartDate,
						PayCode
END
ELSE
BEGIN
	select 	@GroupCode AS GroupCode,
					0 AS SSN, 
					'1234' AS EmployeeID, 
					'N/A' AS EmpName, 
					'1/1/1900' AS PPED,
					'1234' AS AssignmentNo,
					'No records found' AS Line1
END

DROP TABLE #tmpUpload

IF (@MA_EmailText <> '')
BEGIN
	SET @MA_EmailText = @MA_EmailText + '</html>'
	EXEC Scheduler.dbo.usp_Email_SendDirect @Client, 0, 0, @SendEmailTo, 'support@peoplenet.com', 'PeopleNet Support',
																			 '', '', 'Time Card File Export Error', @MA_EmailText, '', 1, '', 1	
END



