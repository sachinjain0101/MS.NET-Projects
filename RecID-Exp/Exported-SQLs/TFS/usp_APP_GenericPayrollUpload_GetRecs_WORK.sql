Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_WORK]
(
  @Client varchar(4),
  @GroupCode  int,
  @PPED   datetime,
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

DECLARE @CompanyID varchar(25)
DECLARE @PayrollFreq char(1)
DECLARE @PPED2 datetime
DECLARE @AgencyNo smallint
DECLARE @IncludeDeptCode char(1)
DECLARE @IncludeAssignNo char(1)
DECLARE @ClientGroupID1 varchar(100)
DECLARE @OpenDepts varchar(1)
DECLARE @PersonNameType VARCHAR(10)


IF @PayrollType like '%Custom-ZChaos%'
BEGIN

  EXECUTE TimeHIstory..usp_APP_GenericPayrollUpload_GetRecs_WORK_ZC 
     @Client
    ,@GroupCode
    ,@PPED
    ,@PAYRATEFLAG
    ,@EMPIDType
    ,@REGPAYCODE
    ,@OTPAYCODE
    ,@DTPAYCODE
    ,@PayrollType
    ,@IncludeSalary
    ,@TestingFlag

  RETURN
END

Set @IncludeDeptCode = 'N'
set @OpenDepts = '0'
IF charindex('DeptCode', @PayrollType) > 0 
BEGIN
  Set @IncludeDeptCode = 'Y'
END

Set @IncludeAssignNo = 'N'
IF charindex('Assignment', @PayrollType) > 0 
BEGIN
  Set @IncludeAssignNo = 'Y'
  Set @IncludeDeptCode = 'Y'
END

SET @PersonNameType = 'wfl'
IF (@Client = 'DIST' AND @GroupCode = 252201)
BEGIN
  SET @PersonNameType = 'client'
END

Set @PPED2 = @PPED
--
-- First check to see if this is bi-weekly.
-- 
SELECT 
	@PayrollFreq = PayrollFreq, 
	@CompanyID = ADP_CompanyCode,
	@ClientGroupID1 = ClientGroupID1
FROM TimeCurrent..tblClientGroups 
WHERE 
Client = @Client 
AND GroupCode = @GroupCode

IF @ClientGroupID1 like '%UseOpenDepts%'
  Set @OpenDepts = '1'

if @PayrollFreq = 'B' 
BEGIN
  Set @PPED2 = dateadd(day, -7, @PPED)
END

if @TestingFlag = 'N'
BEGIN
  if @PayrollFreq = 'B'
  BEGIN
  	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'Y'
  	if @@error <> 0 
  	   return
  END
  else
  BEGIN
  	Exec usp_APP_PRECHECK_Upload @Client,	@GroupCode, @PPED,'N'
  	if @@error <> 0 
  	   return
  END
END
DECLARE @Delim char(1)
Set @Delim = ','

SELECT 	en.ssn, en.LastName,en.FirstName, 
	en.FileNo as EmployeeID,
	hd.TransDate,
	ShiftNo = 6,
  ExpenseString = d.ClientDeptCode,
  AssignmentNo = case when @OpenDepts = '1' THEN hd.CostID ELSE CASE WHEN isnull(edh.assignmentno,'') = '' then isnull(ed.AssignmentNo,'') else isnull(edh.AssignmentNo,'') END END,
	PayCode = ltrim(ac.ADP_HoursCode), 
	RegHours = SUM(case when ac.ClockadjustmentNo = '1' then hd.RegHours else 0.00 end),
	OT_Hours = SUM(hd.OT_Hours),
  DT_Hours = SUM(hd.DT_Hours),
  OthHours = SUM(case when ac.ClockadjustmentNo <> '1' then hd.RegHours else 0.00 end),
	RecordID = Max(hd.recordID),
	ApprUserID = Max(isnull(hd.AprvlStatus_UserID,0)),
	AppDate = max(isnull(AprvlStatus_Date,'1/1/2000')),
  ApprEmplID = cast('' as varchar(32))
INTO #tmpUpload
FROM 	TimeHistory..tblTimeHistDetail as hd
INNER JOIN TimeCurrent..tblEmplNames as en
ON	en.Client = hd.Client
AND	en.GroupCode = hd.GroupCode
AND	en.SSN = hd.SSN
INNER JOIN TimeCurrent..tblAdjCodes as ac
ON	ac.Client = hd.Client
AND	ac.GroupCode = hd.GroupCode
AND	ac.ClockAdjustmentNo = CASE WHEN IsNull(hd.ClockAdjustmentNo, '') IN ('', '8', '@') then '1' else hd.ClockAdjustmentNo END
INNER JOIN TimeCurrent..tblGroupDepts as d
ON	d.Client = hd.Client
AND	d.GroupCode = hd.GroupCode
AND	d.DeptNo = hd.DeptNo
LEFT JOIN TimeCurrent..tblAgencies as ag
ON	ag.Client = en.Client
AND	ag.GroupCode = en.GroupCode
AND	ag.Agency = en.AgencyNo
Left Join TimeCurrent..tblEmplnames_depts as ed
on ed.Client = hd.client
and ed.groupcode = hd.groupcode
and ed.ssn = hd.ssn
and ed.department = hd.deptno
Left Join TimeHistory..tblEmplnames_depts as edh
on edh.Client = hd.client
and edh.groupcode = hd.groupcode
and edh.ssn = hd.ssn
and edh.department = hd.deptno
and edh.payrollperiodenddate = hd.payrollperiodenddate
WHERE	hd.Client = @Client 
AND hd.GroupCode = @GroupCode 
AND	hd.PayrollPeriodEndDate in(@PPED, @PPED2)
AND isnull(ag.ExcludeFromPayFile,'0') = '0'
group By 
hd.TransDate, --hd.ShiftNo,
en.ssn, en.FileNo, en.lastname, en.firstname, 
ag.ClientAgencyCode, 
ltrim(ac.ADP_hoursCode), 
case when @OpenDepts = '1' THEN hd.CostID ELSE CASE WHEN isnull(edh.assignmentno,'') = '' then isnull(ed.AssignmentNo,'') else isnull(edh.AssignmentNo,'') END END, 
d.ClientDeptCode


DELETE FROM #tmpUpload where RegHours = 0.00 and OthHours = 0.00 and OT_Hours = 0.00 and DT_Hours = 0.00

Update #tmpUpload
  Set #tmpUpload.ApprEmplID = case when isnull(usr.EmployeeNumber,'') = '' then ltrim(str(#tmpUpload.ApprUserID)) else usr.EmployeeNumber end
from #tmpUpload
Inner Join TimeCurrent..tblUser as usr
on usr.Client = @Client
and usr.UserID = #tmpUpload.ApprUserID
where #tmpUpload.ApprUserID > 0

Create Table #tmpOutput
(
	SSN int,
	EmployeeID varchar(20),
	EmplName varchar(80),
	XMLString varchar(7800)
)

--select * from #tmpUpload where ssn = 11881

-- =============================================
-- 
-- =============================================
DECLARE cPayRecs CURSOR
READ_ONLY
FOR 
select SSN, EmployeeID, LastName, FirstName, Transdate, ShiftNo, ExpenseString, AssignmentNo, RegHours, OT_Hours, DT_Hours, RecordID, ApprUserID, ApprEmplID, AppDate  from #tmpUpload order by SSN, AssignmentNo, TransDate, ApprUserID

DECLARE @XMLString varchar(7800)
DECLARE @SSN int
DECLARE @EmployeeID varchar(20)
DECLARE @LastName varchar(50)
DECLARE @FirstName varchar(50)
DECLARE @Transdate datetime
DECLARE @ShiftNo int
DECLARE @DeptCode varchar(50)
DECLARE @DeptCode2 varchar(50)
DECLARE @AssignmentNo varchar(32)
DECLARE @RegHours numeric(9,2)
DECLARE @OT_Hours numeric(9,2)
DECLARE @DT_Hours numeric(9,2)
DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 11Aug2016 >--
DECLARE @ApproverID int
DECLARE @ApprEmplID varchar(32)
DECLARE @AppDate datetime
DECLARE @TempString varchar(1000)
DECLARE @AppLast varchar(50)
DECLARE @AppFirst varchar(50)

DECLARE @savTransDate datetime
DECLARE @savApproverID int
DECLARE @savApprEmplID varchar(32)
DECLARE @savAppDate datetime
DECLARE @savSSN int
DECLARE @savLastName varchar(80)
DECLARE @savFirstName varchar(80)
DECLARE @savEmplID varchar(20)
DECLARE @savAssignmentNo varchar(32)

SET @savTransDate = '1/1/2000'
SET @savSSN = 0
SET @savAssignmentNo = ''

OPEN cPayRecs

FETCH NEXT FROM cPayRecs INTO @SSN, @EmployeeID, @LastName, @FirstName, @TransDAte, @ShiftNo, @deptCode, @AssignmentNo, @RegHours, @OT_Hours, @DT_Hours, @RecordID, @ApproverID, @ApprEmplID, @AppDate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		IF cast(@savSSN as varchar) + @savAssignmentNo <> cast(@SSN as varchar) + @AssignmentNo 
		BEGIN
			IF @savSSN <> 0
			BEGIN
				-- NOTE: @savSSN = 0 means first time thru
				
				-- Finalize Submitter and Approver Information.
				--
				Set @TempString = '</ReportedTime><SubmitterInfo> <Person> <Id> <IdValue name="' + @PersonNameType + '">' + isnull(@savEmplID,'missing') + '</IdValue> </Id> <PersonName>  <FormattedName>' + @savFirstName + ' ' + @savLastName+ '</FormattedName> <GivenName>' + @savFirstName + '</GivenName> <FamilyName>' + @savLastName + '</FamilyName> </PersonName> </Person> <SubmittedDateTime>' + replace(convert(varchar(20),@PPED,120),' ', 'T') + '</SubmittedDateTime> </SubmitterInfo>'
				--Print 'Submitter : '
				--Print @TempString  

				Set @XMLString = @XMLString + @TempString

				Select @AppLast = LastName, 
							 @AppFirst = FirstName
				From TimeCurrent..tblUser where UserID = @savApproverID

				Set @TempString = '<ApprovalInfo> <Person> <Id> <IdValue name="client">' + ltrim(str(@savApprEmplID)) + '</IdValue> </Id> <PersonName> <FormattedName>' + isnull(@AppFirst,'') + ' ' + isNUll(@AppLast,'') + '</FormattedName> <GivenName>' + isnull(@AppFirst,'') + '</GivenName> <FamilyName>' + isnull(@AppLast,'') + '</FamilyName> </PersonName> </Person> <ApprovedDateTime>' + convert(varchar(10),@savAppDate,120) + 'T00:00:00' + '</ApprovedDateTime> </ApprovalInfo>'
				--Print 'Approver : '
				--Print @TempString  
				Set @XMLString = @XMLString + @TempString + '</TimeCard>'

				INSERT INTO #tmpOutput (SSN, EmployeeID, EmplName, XMLString ) Values (@savSSN, @savEmplID, @savLastName + ',' + @savFirstName, @XMLString)
			END
			Set @savTransDate = @TransDate
			Set @savSSN = @SSN
			Set @savApproverID = @ApproverID
			Set @savApprEmplID = @ApprEmplID
			Set @savAppDate = @AppDate
			Set @savLastName = @LastName 
			Set @savFirstName = @FirstName
			Set @savEmplID = @EmployeeID
      Set @savAssignmentNo = @AssignmentNo
  
      --<TimeCards xmlns="http://ns.hr-xml.org/2006-02-28" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://ns.hr-xml.org/2006-02-28 http://ns.hr-xml.org/2_4/HR-XML-2_4/TimeCard/TimeCard.xsd">
			Set @XMLString = '<TimeCard xmlns="http://ns.hr-xml.org/2006-02-28" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://ns.hr-xml.org/2006-02-28 TimeCard.xsd">	<ReportedResource> <Person>	<Id> <IdValue name="' + @PersonNameType + '">' + isnull(@EmployeeID,'missing') + '</IdValue> </Id>	<PersonName> <FormattedName>' + @FirstName + ' ' + @LastName + '</FormattedName> <GivenName>' + @FirstName + '</GivenName> <FamilyName>' + @LastName + '</FamilyName> </PersonName> </Person> </ReportedResource>	'
      Set @XMLString = @XMLString + '<ReportedTime> <PeriodStartDate>' + replace(convert(varchar(20),dateadd(day,-6,@PPED),120),' ', 'T') + '</PeriodStartDate> <PeriodEndDate>' + replace(convert(varchar(20),@PPED,120),' ', 'T') + '</PeriodEndDate> <ReportedPersonAssignment>	<Id>	<IdValue name="wfl">' + isnull(@AssignmentNo,'Missing') + '</IdValue>	</Id>	</ReportedPersonAssignment>'
			--Print @LastName + ',' + @FirstName + ' : ' + @XMLString
		END

    --IF @savAssignmentNo <> @AssignmentNo
    --BEGIN
    --  Set @XMLString = @XMLString + '</ReportedTime> <ReportedTime> <PeriodStartDate>' + replace(convert(varchar(20),dateadd(day,-6,@PPED),120),' ', 'T') + '</PeriodStartDate> <PeriodEndDate>' + replace(convert(varchar(20),@PPED,120),' ', 'T') + '</PeriodEndDate> <ReportedPersonAssignment>	<Id>	<IdValue name="wfl">' + isnull(@AssignmentNo,'Missing') + '</IdValue>	</Id>	</ReportedPersonAssignment>'
    --  Set @savAssignmentNo = @AssignmentNo
    --END

		IF @RegHours <> 0.00
		BEGIN
			Set @XMLString = @XMLString + '<TimeInterval type="Regular" actionCode="Add"> <Id> <IdValue>' + ltrim(str(@RecordID)) + '</IdValue> </Id> <StartDateTime>' + replace(convert(varchar(20),@TransDate,120),' ', 'T') + '</StartDateTime> <Duration>' + ltrim(str(@RegHours,6,2)) + '</Duration>	<PieceWork>	<Piece>	<Id> <IdValue name="GL">' + isnull(@DeptCode,'') + '</IdValue> </Id> <PieceValue></PieceValue> </Piece>	<Quantity>' + ltrim(str(@RegHours,6,2)) + '</Quantity> </PieceWork> <AdditionalData type="Shift">' + ltrim(str(@ShiftNo)) + '</AdditionalData> <AdditionalData type="AdjustmentType">complete</AdditionalData> </TimeInterval>'
			--Print 'Reg Hours: ' + @XMLString
		END
		IF @OT_Hours <> 0.00
		BEGIN
			Set @XMLString = @XMLString + '<TimeInterval type="Overtime" actionCode="Add"><Id><IdValue>' + ltrim(str(@RecordID+1)) + '</IdValue></Id><StartDateTime>' + replace(convert(varchar(20),@TransDate,120),' ', 'T') + '</StartDateTime><Duration>' + ltrim(str(@OT_Hours,6,2)) + '</Duration><PieceWork><Piece><Id><IdValue name="GL">' + isnuLL(@DeptCode,'') + '</IdValue></Id><PieceValue></PieceValue></Piece><Quantity>' + ltrim(str(@OT_Hours,6,2)) + '</Quantity></PieceWork><AdditionalData type="Shift">' + ltrim(str(@ShiftNo)) + '</AdditionalData> <AdditionalData type="AdjustmentType">complete</AdditionalData> </TimeInterval>'
			--Print 'OT Hours: ' + @XMLString
		END
		IF @DT_Hours <> 0.00
		BEGIN
			Set @XMLString = @XMLString + '<TimeInterval type="doubletime" actionCode="Add"><Id><IdValue>' + ltrim(str(@RecordID+2)) + '</IdValue></Id><StartDateTime>' + replace(convert(varchar(20),@TransDate,120),' ', 'T') + '</StartDateTime><Duration>' + ltrim(str(@DT_Hours,6,2)) + '</Duration><PieceWork><Piece><Id><IdValue name="GL">' + isnull(@DeptCode,'') + '</IdValue></Id><PieceValue></PieceValue></Piece><Quantity>' + ltrim(str(@DT_Hours,6,2)) + '</Quantity></PieceWork><AdditionalData type="Shift">' + ltrim(str(@ShiftNo)) + '</AdditionalData> <AdditionalData type="AdjustmentType">complete</AdditionalData> </TimeInterval>'
			--Print 'DT Hours: ' + @XMLString
		END
	END
	FETCH NEXT FROM cPayRecs INTO @SSN, @EmployeeID, @LastName, @FirstName, @TransDAte, @ShiftNo, @deptCode, @AssignmentNo, @RegHours, @OT_Hours, @DT_Hours, @RecordID, @ApproverID, @ApprEmplID, @AppDate
END

CLOSE cPayRecs
DEALLOCATE cPayRecs

-- NOTE: @savSSN = 0 means first time thru

-- Finalize Submitter and Approver Information.
--
Set @TempString = '</ReportedTime><SubmitterInfo> <Person> <Id> <IdValue name="' + @PersonNameType + '">' + isnull(@savEmplID,'missing') + '</IdValue> </Id> <PersonName>  <FormattedName>' + @savFirstName + ' ' + @savLastName+ '</FormattedName> <GivenName>' + @savFirstName + '</GivenName> <FamilyName>' + @savLastName + '</FamilyName> </PersonName> </Person> <SubmittedDateTime>' + replace(convert(varchar(20),@PPED,120),' ', 'T') + '</SubmittedDateTime> </SubmitterInfo>'
--Print 'Submitter : '
--Print @TempString  

Set @XMLString = @XMLString + @TempString

Select @AppLast = LastName, 
			 @AppFirst = FirstName
From TimeCurrent..tblUser where UserID = @savApproverID

Set @TempString = '<ApprovalInfo> <Person> <Id> <IdValue name="client">' + ltrim(str(@savApprEmplID)) + '</IdValue> </Id> <PersonName> <FormattedName>' + isnull(@AppFirst,'') + ' ' + isNUll(@AppLast,'') + '</FormattedName> <GivenName>' + isnull(@AppFirst,'') + '</GivenName> <FamilyName>' + isnull(@AppLast,'') + '</FamilyName> </PersonName> </Person> <ApprovedDateTime>' + convert(varchar(10),@savAppDate,120) +  'T00:00:00' + '</ApprovedDateTime> </ApprovalInfo>'
--Print 'Approver : '
--Print @TempString  
Set @XMLString = @XMLString + @TempString + '</TimeCard>'

INSERT INTO #tmpOutput (SSN, EmployeeID, EmplName, XMLString ) Values (@savSSN, @savEmplID, @savLastName + ',' + @savFirstName, @XMLString)

select SSN, EmployeeID, EmpName = EmplName, Line1 = XMLString
from #tmpOutPut order by SSN

IF @GroupCode = 370004
BEGIN
  -- Add the generic export job to create the Staffmark pay file.
  --
  
  Declare @JobID int

  INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], [GroupCode], [Weekly])
  VALUES('GenericDataExport',getdate(),null,null,null,'WORK', 0,'1')
  Set @JobID = scope_identity()
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'DATE', convert(varchar(12),@PPED,101) )
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'GROUP', '370004')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'CLIENT', 'WORK')
  
    INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
    VALUES(@JobID, 'FILENAME', '37471.csv')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
    VALUES(@JobID, 'FILEPATH', '\\cigfile1\apps\pne\sendreceive\StaffMark\Groups\CLOROX\')
  
  -- Main SP to extract data and load CSV file.
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'REF1', 'EXEC TimeHistory..usp_APP_GenericPayrollUpload_GetRecs_STFM_Clorox ')
  
  -- FTP SP to FTP the file via Batch7 or Batch8
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'REF5', '')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'REF2', '')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'XMAIL', 'david.powell@peoplenet.com')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'REF3', '')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'REF4', '')
  
  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  VALUES(@JobID, 'COPYTO', '')

END
/*
DECLARE @XMLStart varchar(2000)
DECLARE @crlf char(2)
DECLARE @XMLEnd varchar(2000)

Set @crlf = char(13) + char(10)

Select 
'<TimeCard xmlns="http://ns.hr-xml.org/2006-02-28" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://ns.hr-xml.org/2006-02-28 http://ns.hr-xml.org/2_4/HR-XML-2_4/TimeCard/TimeCard.xsd">
	<ReportedResource>
		<Person>
			<Id>
				<IdValue name="client|wfl|SSN">' + EmployeeID + '</IdValue>
			</Id>
			<PersonName>
				<FormattedName>' + FirstName + ' ' + LastName + '</FormattedName>
				<GivenName>' + FirstName + '</GivenName>
				<FamilyName>' + LastName + '</FamilyName>
			</PersonName>
		</Person>
	</ReportedResource>
	<ReportedTime>
		<PeriodStartDate>' + replace(convert(varchar(20),dateadd(day,-6,@PPED),120),' ', 'T') + '</PeriodStartDate>
		<PeriodEndDate>' + replace(convert(varchar(20),@PPED,120),' ', 'T') + '</PeriodEndDate>
		<ReportedPersonAssignment>
			<Id>
				<IdValue name="wfl">' + AssignmentNo + '</IdValue>
			</Id>
		</ReportedPersonAssignment>		
		<!--Timecard -->	
		<TimeInterval type="'+ PayCode + '" actionCode="Add">
			<Id>
				<IdValue>' + RecordID + '</IdValue>
			</Id>
			<StartDateTime>' + replace(convert(varchar(20),TransDate,120),' ', 'T') + '</StartDateTime>
			<Duration>' + ltrim(str(TransHours,6,2)) + '</Duration>
			<PieceWork>
				<Piece>
					<Id>
						<IdValue name="wfl">' + ClientDeptCode2 + '</IdValue>
					</Id>
					<PieceValue></PieceValue>
				</Piece>
				<Quantity>' + ltrim(str(Hours,6,2)) + '</Quantity>
			</PieceWork>
			<AdditionalData type="Shift">' + ltrim(str(ShiftNo)) + '</AdditionalData>		
		</TimeInterval>
		<!--Timecard Adjustment-->
		<TimeInterval type="Regular" actionCode="Change">
			<Id>
				<IdValue>' + @CompanyID + '</IdValue>
			</Id>
			<StartDateTime>2006-11-03T00:00:00</StartDateTime>
			<Duration>8</Duration>
			<PieceWork>
				<Piece>
					<Id>
						<IdValue name="client|wfl|gl">Project ID</IdValue>
					</Id>
					<PieceValue>Project Title</PieceValue>
				</Piece>
				<Quantity>8</Quantity>
			</PieceWork>			
			<AdditionalData type="AdjustmentType">Complete|Delta</AdditionalData>
			<AdditionalData type="Shift">1|2|3|5|6</AdditionalData>			
		</TimeInterval>
	</ReportedTime>
	<SubmitterInfo>
		<Person>
			<Id>
				<IdValue name="client|wfl">Submitter ID</IdValue>
			</Id>
			<PersonName>
				<FormattedName>Molly Carpenter</FormattedName>
				<GivenName>Molly</GivenName>
				<FamilyName>Carpenter</FamilyName>
			</PersonName>
		</Person>
		<SubmittedDateTime>2006-10-30T00:00:00</SubmittedDateTime>
	</SubmitterInfo>
	<ApprovalInfo>
		<Person>
			<Id>
				<IdValue name="client|wfl">Approver ID</IdValue>
			</Id>
			<PersonName>
				<FormattedName>Raelyn Mondzak</FormattedName>
				<GivenName>Raelyn</GivenName>
				<FamilyName>Mondzak</FamilyName>
			</PersonName>
		</Person>
		<ApprovedDateTime>2006-11-06T00:00:00</ApprovedDateTime>
	</ApprovalInfo>	
</TimeCard>


Select SSN,
  EmployeeID,
  EmpName,
  PPED = convert(varchar(12),@PPED,101),
  Line1 = 
          ltrim(str(RegHours, 8,2)) + @Delim + 
          ltrim(str(OT_Hours, 8,2)) + @Delim + 
          ltrim(str(DT_Hours, 8,2)) + @Delim +
          '"' + EmpName + '"' + @Delim +
          right('000000000' + ltrim(str(SSN)),9) + @Delim +  
          case when @IncludeDeptCode = 'N' then '' else 
           (case when @IncludeAssignNo = 'Y' then AssignmentNo
             Else ClientDeptCode end) end
FROM #tmpUpload
UNION ALL
Select SSN = 1, EmployeeID = '1', EmpName = '', PPED = convert(varchar(12),@PPED,101),
	Line1 = 'Hours,OTHours,DTHours,Name,ID,Job'
order by EmpName

DROP TABLE #tmpUpload
*/


















