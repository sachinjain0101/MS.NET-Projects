Create PROCEDURE [dbo].[usp_APP_GenericPayrollUpload_GetRecs_SNES_PCT]
(   
  @Client         char(4),  
  @GroupCode      int,  
  @PPED           DateTime,  
  @PAYRATEFLAG    varchar(4),  
  @EMPIDType      varchar(6),  
  @REGPAYCODE     varchar(10),  
  @OTPAYCODE     varchar(10),  
  @DTPAYCODE     varchar(10),  
  @PayrollType    varchar(32) = '',  
  @IncludeSalary  char(1),  
  @TestingFlag    char(1) = 'N'  
) AS  
SET NOCOUNT ON  

DECLARE
 @RecordType CHAR(1) = LEFT(@PayrollType, 1)
,@PPEDMinus6 DATETIME = DATEADD(dd, -6, @PPED)
,@Now DATETIME = GETDATE()
,@Today DATE = GETDATE()
,@ExcludeSubVendors VARCHAR(1) = '0' -- Exclude SubVendors from all Unapproved pay files
,@Delim CHAR(1) = '|'
,@FaxApprover INT
,@MinAAWeek DATE
,@MaxAAWeek DATE;

SELECT @FaxApprover = UserID   
FROM TimeCurrent.dbo.tblUser WITH(NOLOCK)  
WHERE JobDesc = 'FAXAROO_DEFAULT_APPROVER'   
AND Client = @Client

IF EXISTS
(
	SELECT * FROM tempdb.dbo.sysobjects
	WHERE id = object_id(N'tempdb.dbo.#groupLastPPED')
)
DROP TABLE #groupLastPPED;
CREATE TABLE #groupLastPPED  
(  
  Client					VARCHAR(4),  
  GroupCode					INT,  
  PPED						DATETIME, 
  LateTimeEntryWeeks		INT, 
  LateTimeCutoff			DATETIME,
  RecordType				VARCHAR(1) NOT NULL DEFAULT 'A', -- Default everything to Approved Only
  AdditionalApprovalWeeks	INTEGER
)  

IF EXISTS
(
	SELECT * FROM tempdb.dbo.sysobjects
	WHERE id = object_id(N'tempdb.dbo.#groupPPED')
)
DROP TABLE #groupPPED;
CREATE TABLE #groupPPED  
(  
  Client          VARCHAR(4),  
  GroupCode       INT,  
  PPED            DATETIME,
  RecordType	  VARCHAR(1)
);
CREATE CLUSTERED INDEX CIDX_groupPPED_PK ON #groupPPED
(Client,GroupCode,PPED);

 
INSERT INTO #groupLastPPED(	Client, GroupCode, PPED, LateTimeEntryWeeks, 
							LateTimeCutoff, 
							RecordType, AdditionalApprovalWeeks)  
SELECT	cg.Client, cg.GroupCode, MAX(ped.PayrollPeriodEndDate), cg.LateTimeEntryWeeks,
		LateTimeCutoff = DATEADD(dd, cg.LateTimeEntryWeeks * 7 * -1, MAX(ped.PayrollPeriodEndDate)), 
		@PayrollType, ISNULL(c.AdditionalApprovalWeeks,0)
FROM TimeCurrent.[dbo].tblClientGroups cg WITH(NOLOCK)  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = cg.Client  
AND ped.GroupCode = cg.GroupCode 
AND ped.PayrollPeriodEndDate < @Today
INNER JOIN TimeCurrent.dbo.tblClients c WITH(NOLOCK)  
ON c.Client = cg.Client
WHERE cg.Client = @Client  
AND cg.RecordStatus = '1'  
AND cg.IncludeInUpload = '1'  
AND cg.StaffingSetupType = '1'  
GROUP BY cg.Client, cg.GroupCode, cg.LateTimeEntryWeeks, c.AdditionalApprovalWeeks

--SELECT * FROM #groupLastPPED glp
CREATE INDEX IDX_groupLastPPED_PK ON #groupLastPPED (Client,GroupCode,PPED) INCLUDE (LateTimeCutoff)

-- Close out "Last Week"  
IF (@RecordType = 'F' AND @TestingFlag = 'N')  
BEGIN  
  DECLARE @CloseClient varchar(4)  
  DECLARE @CloseGroupCode int   
  DECLARE @ClosePPED datetime   
    
  -- Close the current week and make it available for Late Time Entry  
  UPDATE ped    
  SET [Status] = 'C',  
      OverrideStatus = '1',  
      WeekClosedDateTime = @Now,  
      MaintUserName = 'System',  
      MaintDateTime = @Now  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate = tmp.PPED  
  WHERE tmp.RecordType = 'F'
  AND (ped.Status <> 'C' OR ISNULL(ped.OverrideStatus, '') <> '1')
      
  -- Let the oldest of the three weeks drop off so that it can't be used anymore on WTE  
  UPDATE ped  
  SET OverrideStatus = '0',  
      MaintUserName = 'System',  
      MaintDateTime = @Now  
  FROM TimeHistory.dbo.tblPeriodEndDates ped  
  INNER JOIN #groupLastPPED tmp  
  ON ped.Client = tmp.Client  
  AND ped.GroupCode = tmp.GroupCode  
  AND ped.PayrollPeriodEndDate <= tmp.PPED  
  AND ped.PayrollPeriodEndDate <= tmp.LateTimeCutoff  
  AND ISNULL(ped.OverrideStatus, '') <> '0'    
  WHERE tmp.RecordType = 'F'
  AND ped.OverrideStatus = '1'
    
  DECLARE closeCursor CURSOR READ_ONLY  
  FOR SELECT Client, GroupCode, PPED  
      FROM #groupLastPPED  
	  WHERE RecordType = 'F'
  
  OPEN closeCursor  
  
  FETCH NEXT FROM closeCursor INTO @CloseClient, @CloseGroupCode, @ClosePPED  
  WHILE (@@fetch_status <> -1)  
  BEGIN  
   IF (@@fetch_status <> -2)  
   BEGIN  
      EXEC TimeHistory.dbo.usp_Web1_PayPeriodClose_AddTrigger @CloseClient, @CloseGroupCode, 0, @ClosePPED, 'ClosedGroupPeriod'  
   END  
   FETCH NEXT FROM closeCursor INTO @CloseClient, @CloseGroupCode, @ClosePPED  
  END  
  CLOSE closeCursor  
  DEALLOCATE closeCursor    
END  
  
-- Fill out the remaining PPED's that need to be included  
INSERT INTO #groupPPED(Client, GroupCode, PPED, RecordType)  
SELECT ped.Client, ped.GroupCode, ped.PayrollPeriodEndDate, tmp.RecordType  
FROM #groupLastPPED tmp  
INNER JOIN TimeHistory.dbo.tblPeriodEndDates ped WITH(NOLOCK)  
ON ped.Client = tmp.Client  
AND ped.GroupCode = tmp.GroupCode  
AND ped.PayrollPeriodEndDate BETWEEN DATEADD(ww, -1 * ISNULL(tmp.AdditionalApprovalWeeks, 0), DATEADD(dd, -7, tmp.LateTimeCutoff)) AND tmp.PPED   

--SELECT * FROM #groupPPED

CREATE STATISTICS statG_PPED ON #groupPPED
(PPED) WITH FULLSCAN;

SELECT @MaxAAWeek = MAX(PPED),@MinAAWeek = MIN(PPED) FROM #groupPPED;

Create Table #tmpAssSumm  
(   
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    SSN               INT,  
    SiteNo            INT,
    DeptNo            INT, 
    TransCount        INT,   
    ApprovedCount     INT,  
    PayRecordsSent    DATETIME,    
    IVR_Count         INT,   
    WTE_Count         INT,   
    Fax_Count         INT,   
	DLT_Count		  INT,
    FaxApprover_Count INT,    
    EmailClient_Count INT,  
    EmailOther_Count  INT,   
    Dispute_Count     INT,  
    OtherTxns_Count   INT,  
    AssignmentNo      VARCHAR(50),  
    LateApprovals     INT,  
    Client_Count      INT,
    Branch_Count      INT,
    SubVendorAgency_Count INT,
    Interface_Count   INT,
    Mobile_Count      INT,
    Mobile_Approver   INT,
    Web_Approver_Count INT,
    Clock_Count       INT, 
    SnapshotDateTime  DATETIME,  
    JobID             INT,  
    AttachmentName    VARCHAR(20),  
    ApprovalMethodID  INT,  
    WorkState         VARCHAR(2),  
    IsSubVendor       VARCHAR(1),  
    ApproverName      VARCHAR(100),  
    ApproverEmail     VARCHAR(100), 
    ApprovalStatus    CHAR(1),  
    ApprovalDateTime  DATETIME,  
    MaxRecordID       BIGINT,  --< MaxRecordId data type is changed from  INT to BIGINT by Srinsoft on 10Aug2016 >--
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
	VendorReferenceID VARCHAR(100),
	AssignmentTypeID  INT,
	ExcludeFromPayfile	BIT,
	SendAsRegInPayfile	BIT,
	SendAsUnapproved	BIT,
	Brand				VARCHAR(32),
	BillToCode			VARCHAR(50)
)  
  
Create Table #tmpUploadExport  
(  
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    weDate            VARCHAR(10),
    SSN               INT,  
    EmployeeID        VARCHAR(50),
    EmpName           VARCHAR(50),
    SiteNo            INT,
    DeptNo            INT, 
    AssignmentNo      VARCHAR(50),  
    TransDate         DATETIME,
    SnapshotDateTime  DATETIME,  
    AttachmentName    VARCHAR(200),  
    WorkState         VARCHAR(2),  
    ApproverName      VARCHAR(100), 
    ApproverEmail     VARCHAR(100),  
    ApprovalStatus    CHAR(1),  
    ApprovalDateTime  DATETIME,  
    TimeSource        VARCHAR(1), 
    ApprovalSource    VARCHAR(1), 
    PayCode           VARCHAR(50),
    WorkedHours       NUMERIC(7, 2),
    PayAmt            NUMERIC(7, 2),
    BillAmt           NUMERIC(7, 2),
    Line1             VARCHAR(1000),
    LateApprovals     INT,
    FileBreakID       VARCHAR(50),
	RecordType		  VARCHAR(1) DEFAULT 'T'
)

Create Table #tmpUploadUDF 
(  
    Client            VARCHAR(4),  
    GroupCode         INT,  
    PayrollPeriodEndDate DATETIME,   
    SSN               INT,  
    SiteNo            INT,
    DeptNo            INT, 
    TransDate         DATETIME,
    AttachmentName    VARCHAR(20),  
	AssignmentNo	  VARCHAR(50),
    Line1             VARCHAR(1000),
	UDF1			  VARCHAR(100),
	UDF2			  VARCHAR(100),
	UDF3			  VARCHAR(100),
	UDF4			  VARCHAR(100),
	UDF5			  VARCHAR(100),
	EmployeeID		  VARCHAR(50),
	EmpName			  VARCHAR(100),
	PayCode           VARCHAR(50) DEFAULT '',
	RecordType		  VARCHAR(1) DEFAULT 'U'
)
  
--Used to return a list of Groups and PPED's to VB to auto-resolve disputes  
IF (@RecordType = 'D')  
BEGIN  
  INSERT INTO #tmpUploadExport( Client, GroupCode, SSN, PayrollPeriodEndDate, weDate, EmployeeID, EmpName, FileBreakID, Line1, PayCode, SiteNo, DeptNo)  
  SELECT @Client, GroupCode, 1, PPED, CONVERT(VARCHAR(10), PPED, 101), '', '', '', '', '', 0, 0
  FROM #groupPPED  
    
  SELECT *
  FROM #tmpUploadExport  
    
  DROP TABLE #tmpUploadExport  
    
  RETURN         
END 
ELSE IF (@RecordType IN ('A','L','F'))  
BEGIN  
  --PRINT 'Before: INSERT INTO #tmpAssSumm' + CONVERT(VARCHAR, GETDATE(), 121)  
  INSERT INTO #tmpAssSumm  
  (  
        Client  
      , GroupCode  
      , PayrollPeriodEndDate  
      , SSN  
      , SiteNo
      , DeptNo
      , PayRecordsSent  
      , AssignmentNo  
      , TransCount  
      , ApprovedCount  
      , ApprovalDateTime
      , IVR_Count  
      , WTE_Count  
      , Fax_Count  
	  , DLT_Count
      , FaxApprover_Count  
      , EmailClient_Count  
      , EmailOther_Count  
      , Dispute_Count  
      , OtherTxns_Count  
      , LateApprovals  
      , Client_Count 
      , Branch_Count 
      , SubVendorAgency_Count
      , Interface_Count
      , Mobile_Count 
      , Mobile_Approver
      , Web_Approver_Count
      , Clock_Count      
      , SnapshotDateTime  
      , JobID  
      , AttachmentName  
      , ApprovalMethodID  
      , WorkState  
      , IsSubVendor       
      , MaxRecordID  
	  , VendorReferenceID
	  , AssignmentTypeID
	  , Brand
	  , BillToCode
  )	  
  SELECT   
       t.Client  
     , t.GroupCode  
     , t.PayrollPeriodEndDate  
     , t.SSN  
     , t.SiteNo
     , t.DeptNo       
     , PayRecordsSent = th_esds.PayRecordsSent
     , ea.AssignmentNo  
     , TransCount = SUM(1)  
     , ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A', 'L') THEN 1 ELSE 0 END)  
     , ApprovalDateTime = MAX(isnull(t.AprvlStatus_Date, '1/2/1970'))  
     , IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)  
     , WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE', 'VTS') THEN 1 ELSE 0 END)  
     , Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)  
	 , DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1 ELSE 0 END)
     , FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID, 0) = @FaxApprover THEN 1 ELSE 0 END)  
     , EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)  
     , EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA', 'COR', 'AGE')) THEN 1 ELSE 0 END)  
     , Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$', '@') THEN 1 ELSE 0 END)  
     , OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$', '@', '') AND ISNULL(t.UserCode, '') NOT IN ('WTE','COR', 'FAX', 'EML', 'SYS') AND ISNULL(t.OutUserCode, '') NOT in ('CLI', 'BRA', 'COR', 'AGE') THEN 1 ELSE 0 END)  
     , LateApprovals = SUM(CASE WHEN t.AprvlStatus_Date > th_esds.PayRecordsSent THEN 1 ELSE 0 END)  
     , Client_Count = SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
     , Branch_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('BRA')) THEN 1 ELSE 0 END)
     , SubVendorAgency_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('AGE')) THEN 1 ELSE 0 END)
     , Interface_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode IN ('INT')) THEN 1 ELSE 0 END)
     , Mobile_Count = SUM( CASE WHEN ISNULL(th_en.Mobile, 0) = 0 THEN 0 ELSE 1 END )
     , Mobile_Approver = SUM( CASE WHEN ISNULL(t.[AprvlStatus_Mobile],0) = 0 THEN 0 ELSE 1 END )
     , Web_Approver_Count = 0
     , Clock_Count = 0
     , SnapshotDateTime = @Now  
     , JobID = 0  
     , AttachmentName = th_esds.RecordID  
     , ApprovalMethodID = ea.ApprovalMethodID  
     , WorkState = ISNULL(ea.WorkState, '')  
     , IsSubVendor = CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
     , MAX(t.RecordID)
	 , th_esds.VendorReferenceID
	 , ea.AssignmentTypeID
	 , ea.Brand
	 , ea.BilltoCode
  FROM #groupPPED grpped  
  INNER JOIN TimeHistory.dbo.tblTimeHistDetail as t  
  ON t.Client = grpped.Client  
  AND t.Groupcode = grpped.GroupCode  
  AND t.PayrollPeriodEndDate = grpped.PPED  
  INNER JOIN TimeCurrent.dbo.tblEmplAssignments as ea  WITH(NOLOCK) 
  ON  ea.Client = t.Client  
  AND ea.Groupcode = t.Groupcode  
  AND ea.SSN = t.SSN  
  AND ea.SiteNo = t.SiteNo
  AND ea.DeptNo =  t.DeptNo  
  INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  WITH(NOLOCK) 
  ON  th_esds.Client = t.Client  
  AND th_esds.GroupCode = t.GroupCode  
  AND th_esds.SSN = t.SSN  
  AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
  AND th_esds.SiteNo = t.SiteNo  
  AND th_esds.DeptNo = t.DeptNo
  INNER JOIN TimeHistory.dbo.tblEmplNames th_en  WITH(NOLOCK) 
  ON  th_en.Client = t.Client  
  AND th_en.GroupCode = t.GroupCode  
  AND th_en.SSN = t.SSN  
  AND th_en.PayrollPeriodEndDate = t.PayrollPeriodEndDate  
  AND th_en.SecondLevelApprovalDate IS NOT NULL
  LEFT JOIN TimeCurrent.dbo.tblAgencies a WITH(NOLOCK)  
  ON a.client = ea.Client  
  AND a.GroupCode = ea.GroupCode  
  AND a.Agency = ea.AgencyNo          
  WHERE t.Client = @Client
  AND t.PayrollPeriodEndDate >= @MinAAWeek
  AND t.PayrollPeriodEndDate <= @MaxAAWeek
  AND th_esds.PayRecordsSent IS NULL
  AND t.Hours <> 0
  GROUP BY  
        t.Client  
      , t.GroupCode  
      , t.PayrollPeriodEndDate  
      , t.SSN  
      , t.SiteNo
      , t.DeptNo
      , th_esds.PayRecordsSent
      , ea.AssignmentNo  
      , ea.approvalMethodID  
      , th_esds.RecordID  
      , ISNULL(ea.WorkState, '')  
      , CASE WHEN ISNULL(a.ClientAgencyCode, '') <> '' THEN '1' ELSE '0' END  
	  , th_esds.VendorReferenceID
	  , ea.AssignmentTypeID
      , ea.Brand
	  , ea.BilltoCode
  --PRINT 'After: INSERT INTO #tmpAssSumm A, L, F' + CONVERT(VARCHAR, GETDATE(), 121)          

	-- Summarize Assignment Types
	UPDATE ass
	SET ExcludeFromPayfile = cat.ExcludeFromPayfile,
		SendAsRegInPayfile = cat.SendAsRegInPayfile,
		SendAsUnapproved = cat.SendAsUnapprovedInPayfile
	FROM #tmpAssSumm ass
	INNER JOIN TimeCurrent..tblClients_AssignmentType cat
	ON cat.Client = @Client
	AND cat.AssignmentTypeID = ass.AssignmentTypeID

	-- Remove AssignmentTypes that should not be included in pay file
	DELETE FROM #tmpAssSumm
	WHERE ExcludeFromPayfile = '1'

    -- Snelling only want Approved time cards in each pay file run

	DELETE ass
	FROM #tmpAssSumm ass
	INNER JOIN #groupPPED pped
	ON pped.Client = ass.Client
	AND pped.GroupCode = ass.GroupCode
	AND pped.PPED = ass.PayrollPeriodEndDate
	WHERE ass.TransCount <> ass.ApprovedCount  

END
  
-- Remove Subvendors from the file  
IF (@ExcludeSubVendors = '1')  
BEGIN  
  DELETE FROM #tmpAssSumm  
  WHERE IsSubVendor = '1'  
END  
--PRINT 'After: ExcludeSubVendors' + CONVERT(VARCHAR, GETDATE(), 121)  
  
CREATE INDEX IDX_tmpSSNs_PK ON #tmpAssSumm(Client, GroupCode, PayrollPeriodEndDate, SSN, AssignmentNo)  
    
--PRINT 'Before: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  
UPDATE tas  
SET ApproverName = CASE  WHEN bkp.RecordId IS NOT NULL   
                         THEN LEFT(bkp.LastName + '; ' + ISNULL(bkp.FirstName,''), 50)  
                         ELSE LEFT(usr.LastName + '; ' + ISNULL(usr.FirstName,''), 50)   
                    END,
    ApproverEmail = CASE WHEN bkp.RecordId IS NOT NULL   
                         THEN LEFT(bkp.Email, 50)
                         ELSE LEFT(usr.Email, 50)   
                         END                      
FROM #tmpAssSumm AS tAS  
INNER JOIN TimeHistory.dbo.tblTimeHistDetail as thd WITH(NOLOCK) 
ON thd.RecordID = tAS.MaxRecordID  
LEFT JOIN TimeHistory.dbo.tblTimeHistDetail_BackupApproval bkp  WITH(NOLOCK) 
ON bkp.THDRecordId = tAS.MaxRecordID  
LEFT JOIN TimeCurrent.dbo.tblUser as Usr  WITH(NOLOCK) 
ON usr.UserID = ISNULL(thd.AprvlStatus_UserID,0)  
--PRINT 'After: Update Approver' + CONVERT(VARCHAR, GETDATE(), 121)  

UPDATE #tmpAssSumm
SET ApproverName = CASE WHEN ApprovedCount = TransCount THEN ApproverName ELSE '' END,
    ApprovalStatus = CASE WHEN ApprovedCount <> TransCount THEN '0'
                          WHEN ApprovedCount = TransCount AND Dispute_Count = 0 THEN '1'
                          WHEN ApprovedCount = TransCount AND Dispute_Count > 0 THEN '2' 
                     END
      
--PRINT 'Before: Source Update' + CONVERT(VARCHAR, GETDATE(), 121)                                                         
UPDATE #tmpAssSumm 
SET TimeSource = CASE  WHEN IVR_Count>0 THEN 'I'
                       WHEN Fax_Count > 0 THEN 'F'
                       WHEN WTE_Count > 0 THEN 'W'
                       WHEN Client_Count > 0 THEN 'L'
                       WHEN Branch_Count > 0 THEN 'B'                                                                                                                           
                       WHEN SubVendorAgency_Count > 0 THEN 'S'
                       WHEN Interface_Count > 0 THEN 'X'
                       WHEN Clock_Count > 0 THEN 'C'
                       WHEN Mobile_Count > 0 THEN 'M'
					   WHEN DLT_Count > 0 THEN 'T'
                       ELSE 'P'  --PeopleNet Dashboard
                  END
  , ApprovalSource = CASE WHEN FAXApprover_Count > 0 THEN 'F'
                          WHEN Mobile_Approver > 0 THEN 'M'
                          WHEN Web_Approver_Count > 0 THEN 'W'
                          ELSE 'P'   --PeopleNet Dashboard
                     END                       
 
-- REG
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode,
							  WorkedHours, 
							  PayAmt, 
							  BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN @REGPAYCODE ELSE tas.BillToCode END, 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.RegHours ELSE 0.0 END),
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.RegHours ELSE 0.0 END), 
		SUM(CASE WHEN ac.Billable = 'Y' THEN thd.RegHours ELSE 0.0 END)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory..tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', '1', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
WHERE thd.RegHours <> 0 
AND thd.ClockAdjustmentNo IN ('', '1', '8', '$', '@') -- Worked - have to do it like this because of Training
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN @REGPAYCODE ELSE tas.BillToCode END

--OT
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode,
							  WorkedHours, 
							  PayAmt, 
							  BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN @OTPAYCODE ELSE tas.BillToCode END, 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.OT_Hours ELSE 0.0 END), 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.OT_Hours ELSE 0.0 END), 
		SUM(CASE WHEN ac.Billable = 'Y' THEN thd.OT_Hours ELSE 0.0 END)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory..tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', '1', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
WHERE thd.OT_Hours <> 0 
AND thd.ClockAdjustmentNo IN ('', '1', '8', '$', '@') -- Worked - have to do it like this because of Training
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN @OTPAYCODE ELSE tas.BillToCode END

-- DT
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode,
							  WorkedHours, 
							  PayAmt, 
							  BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN @DTPAYCODE ELSE tas.BillToCode END, 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.DT_Hours ELSE 0.0 END), 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.DT_Hours ELSE 0.0 END), 
		SUM(CASE WHEN ac.Billable = 'Y' THEN thd.DT_Hours ELSE 0.0 END)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory..tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', '1', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
WHERE thd.DT_Hours <> 0 
AND thd.ClockAdjustmentNo IN ('', '1', '8', '$', '@') -- Worked - have to do it like this because of Training
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN @DTPAYCODE ELSE tas.BillToCode END

-- Other Hours
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode,
							  WorkedHours, 
							  PayAmt, 
							  BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN ac.ADP_HoursCode ELSE tas.BillToCode END, 
		0.00, 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.Hours ELSE 0.0 END), 
		SUM(CASE WHEN ac.Billable = 'Y' THEN thd.Hours ELSE 0.0 END)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory..tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', '1', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
WHERE thd.Hours <> 0 
AND thd.ClockAdjustmentNo NOT IN ('', '1', '8', '$', '@') -- Worked - have to do it like this because of Training
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN ADP_HoursCode ELSE tas.BillToCode END


-- Dollars
INSERT INTO #tmpUploadExport( Client, GroupCode, PayrollPeriodEndDate, weDate, SSN, SiteNo, DeptNo, AssignmentNo, TransDate, LateApprovals,
                              SnapshotDateTime, AttachmentName, WorkState, ApproverName, ApproverEmail, ApprovalStatus, ApprovalDateTime, TimeSource, ApprovalSource,
                              PayCode,
							  WorkedHours, 
							  PayAmt, 
							  BillAmt)
SELECT  tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN ac.ADP_EarningsCode ELSE tas.BillToCode END, 
		0.00, 
		SUM(CASE WHEN ac.Payable = 'Y' THEN thd.Dollars ELSE 0.0 END), 
		SUM(CASE WHEN ac.Billable = 'Y' THEN thd.Dollars ELSE 0.0 END)
FROM #tmpAssSumm tas
INNER JOIN TimeHistory..tblTimeHistDetail thd
ON thd.Client = tas.Client
AND thd.GroupCode = tas.GroupCode
AND thd.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
AND thd.SSN = tas.SSN
AND thd.SiteNo = tas.SiteNo
AND thd.DeptNo = tas.DeptNo
INNER JOIN TimeCurrent.dbo.tblAdjCodes ac
ON ac.Client = thd.Client
AND ac.GroupCode = thd.GroupCode
AND ac.ClockAdjustmentNo = CASE WHEN thd.ClockAdjustmentNo IN ('', '1', '8') THEN '1' ELSE thd.ClockAdjustmentNo END
WHERE thd.Dollars <> 0 
AND thd.ClockAdjustmentNo NOT IN ('', '1', '8', '$', '@') -- Worked - have to do it like this because of Training
GROUP BY tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, CONVERT(VARCHAR(10), tas.PayrollPeriodEndDate, 101), tas.SSN, tas.SiteNo, tas.DeptNo, tas.AssignmentNo, thd.TransDate, tas.LateApprovals,
        tas.SnapshotDateTime, tas.AttachmentName, tas.WorkState, tas.ApproverName, tas.ApproverEmail, tas.ApprovalStatus, tas.ApprovalDateTime, tas.TimeSource, tas.ApprovalSource,
        CASE WHEN ISNULL(tas.BillToCode, '') = '' THEN ADP_EarningsCode ELSE tas.BillToCode END

-- "DELETE" out any blank UDF entries
UPDATE udf
SET Client = 'SNE1', SpreadsheetAssignmentID = SpreadsheetAssignmentID * -1
FROM timehistory..tblTimeHistDetail_UDF udf
INNER JOIN (SELECT DISTINCT udf.client, udf.groupcode, udf.ssn, udf.Payrollperiodenddate, udf.siteno, udf.deptno, udf.transdate
			FROM #tmpAssSumm tas
			INNER JOIN timehistory..tblTimeHistDetail_UDF udf
			ON udf.client = tas.Client
			AND udf.groupcode = tas.GroupCode
			AND udf.ssn = tas.SSN
			AND udf.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
			AND udf.SiteNo = tas.SiteNo
			AND udf.DeptNo = tas.DeptNo
			INNER JOIN timecurrent..tblUDF_FieldDefs fd
			ON fd.FieldID = udf.FieldID
			INNER JOIN timecurrent..tblUDF_Templates t
			ON t.TemplateID = fd.TemplateID			
			AND udf.FieldID = t.ValidationFieldId
			AND ISNULL(udf.FieldValue, '') in ('','Nan')) AS tmp
ON udf.Client = tmp.Client
AND udf.GroupCode = tmp.GroupCode
AND udf.Payrollperiodenddate = tmp.Payrollperiodenddate
AND udf.SSN = tmp.SSN
AND udf.SiteNo = tmp.SiteNo
AND udf.DeptNo = tmp.DeptNo
AND udf.TransDate = tmp.TransDate

-- Insert UDF's
INSERT INTO #tmpUploadUDF( Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, TransDate, AssignmentNo, AttachmentName,
                           UDF1,
                           UDF2,
                           UDF3,
                           UDF4,
                           UDF5)
SELECT  Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo, TransDate, AssignmentNo, AttachmentName, 
        ISNULL(Value0, ''),
        ISNULL(Value1, ''),
        ISNULL(Value2, ''),
        ISNULL(Value3, ''),
        ISNULL(Value4, '')
FROM (                              
      SELECT tmp.Client, tmp.GroupCode, tmp.PayrollPeriodEndDate, tmp.SSN, tmp.SiteNo, tmp.DeptNo, tmp.TransDate, tmp.AssignmentNo, tmp.AttachmentName, 
             MAX(CASE WHEN rownum = 1 THEN FieldName END) AS name0,
             MAX(CASE WHEN rownum = 1 THEN FieldValue END) AS value0,
             SUM(CASE WHEN rownum = 1 THEN HoursFieldIndicator END) AS HrsInd0,
             MAX(CASE WHEN rownum = 2 THEN FieldName END) AS Name1,
             MAX(CASE WHEN rownum = 2 THEN FieldValue END) AS Value1,    
             SUM(CASE WHEN rownum = 2 THEN HoursFieldIndicator END) AS HrsInd1,
             MAX(CASE WHEN rownum = 3 THEN FieldName END) AS Name2,
             MAX(CASE WHEN rownum = 3 THEN FieldValue END) AS Value2,
             SUM(CASE WHEN rownum = 3 THEN HoursFieldIndicator END) AS HrsInd2,
             MAX(CASE WHEN rownum = 4 THEN FieldName END) AS Name3,
             MAX(CASE WHEN rownum = 4 THEN FieldValue END) AS Value3,
             SUM(CASE WHEN rownum = 4 THEN HoursFieldIndicator END) AS HrsInd3,
             MAX(CASE WHEN rownum = 5 THEN FieldName END) AS Name4,
             MAX(CASE WHEN rownum = 5 THEN FieldValue END) AS Value4,       
             SUM(CASE WHEN rownum = 5 THEN HoursFieldIndicator END) AS HrsInd4
      FROM (SELECT tas.Client, tas.GroupCode, tas.PayrollPeriodEndDate, tas.SSN, tas.SiteNo, tas.DeptNo, udf.TransDate, 
                   tas.AttachmentName, tas.AssignmentNo, udf.Position, fd.FieldName, udf.FieldValue, 
                   CASE WHEN fd.FieldID = t.ValidationFieldId THEN 1 ELSE 0 END AS HoursFieldIndicator,
                   rownum = ROW_NUMBER() OVER(PARTITION BY udf.client, udf.groupcode, udf.ssn, udf.siteno, udf.deptno, udf.Payrollperiodenddate, udf.transdate, udf.Position ORDER BY CASE WHEN fd.FieldID = t.ValidationFieldId THEN 0 ELSE 1 END, fd.DisplaySeq)
            FROM #tmpAssSumm tas
            INNER JOIN TimeHistory.dbo.tblTimeHistDetail_UDF udf
            ON udf.Client = tas.Client
            AND udf.GroupCode = tas.GroupCode
            AND udf.Payrollperiodenddate = tas.PayrollPeriodEndDate
            AND udf.SSN = tas.SSN
            AND udf.SiteNo = tas.SiteNo
            AND udf.DeptNo = tas.DeptNo
            INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs fd
            ON fd.FieldID = udf.FieldID
            INNER JOIN TimeCurrent.dbo.tblUDF_Templates t
            ON t.TemplateId = fd.TemplateID
            WHERE  tas.PayRecordsSent IS NULL
			AND EXISTS (SELECT 1
						FROM #tmpUploadExport tue
						WHERE tue.Client = tas.Client
						AND tue.GroupCode = tas.GroupCode
						AND tue.SSN = tas.SSN
						AND tue.PayrollPeriodEndDate = tas.PayrollPeriodEndDate
						AND tue.SiteNo = tas.SiteNo
						AND tue.DeptNo = tas.DeptNo)) AS tmp            
      GROUP BY  tmp.Client, tmp.GroupCode, tmp.PayrollPeriodEndDate, tmp.SSN, tmp.SiteNo, tmp.DeptNo, tmp.TransDate, 
                tmp.AttachmentName, tmp.AssignmentNo, tmp.Position
      ) AS tmp2

UPDATE tue
  SET Line1 = /*'"T"' + @Delim
			+ '"' + ISNULL(en.FirstName, '') + '"' + @Delim 
            + '"' + ISNULL(en.LastName, '') + '"' + @Delim
            + '"' + ISNULL(en.FileNo, '') + '"' + @Delim
            + '"' + ISNULL(tue.AssignmentNo, '') + '"' + @Delim
            + ISNULL(CONVERT(VARCHAR(10),ISNULL(tue.PayrollPeriodEndDate, ' '), 101), '') + @Delim
            + CONVERT(VARCHAR(10),ISNULL(tue.TransDate, ' '), 101) + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.WorkedHours), ' ')  + @Delim
            + '"' + ISNULL(Paycode, ' ') + '"' + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.PayAmt), ' ')  + @Delim
            + ISNULL(CONVERT (VARCHAR(8), tue.BillAmt), ' ') + @Delim
            + ''  + @Delim -- Project Code            
            + '"' + ISNULL(ApproverName, '') + '"' + @Delim
            + '"' + ISNULL(ApproverEmail, '')+ '"' + @Delim
            + ISNULL(CONVERT(VARCHAR(10), tue.ApprovalDateTime, 101), '') + ' ' + ISNULL(CONVERT(VARCHAR(12), tue.ApprovalDateTime, 108), '') + RIGHT(ISNULL(CONVERT(VARCHAR, tue.ApprovalDateTime, 109), ''), 2) + @Delim
            + '"' + ISNULL(en.PayGroup, '') + '"' + @Delim
            + '"' + ISNULL(TimeSource, '') + '"' + @Delim
            + '"' + ISNULL(ApprovalSource, '') + '"' + @Delim
            + ISNULL(AttachmentName, '') + @Delim
            + ISNULL(ApprovalStatus, '') + @Delim
			+ '', -- Department (clocks only)*/
			TimeHistory.dbo.fn_PadVarchar('T', 1) + 
			TimeHistory.dbo.fn_PadVarchar(ISNULL(en.FirstName, ''), 20) +  
            TimeHistory.dbo.fn_PadVarchar(ISNULL(en.LastName, ''), 20) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(en.FileNo, ''), 20) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(tue.AssignmentNo, ''), 32) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT(VARCHAR(10), ISNULL(tue.PayrollPeriodEndDate, ' '), 101), ''), 10) + 
            TimeHistory.dbo.fn_PadVarchar(CONVERT(VARCHAR(10), ISNULL(tue.TransDate, ' '), 101), 10) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT (VARCHAR(8), tue.WorkedHours), ''), 8) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(Paycode, ''), 10) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT (VARCHAR(8), tue.PayAmt), ' '), 8) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT (VARCHAR(8), tue.BillAmt), ' '), 8) + 
            TimeHistory.dbo.fn_PadVarchar('', 32)  +  -- Project Code            
            TimeHistory.dbo.fn_PadVarchar(ISNULL(ApproverName, ''), 40) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(ApproverEmail, ''), 132) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT(VARCHAR(10), tue.ApprovalDateTime, 101), '') + ' ' + ISNULL(CONVERT(VARCHAR(12), tue.ApprovalDateTime, 108), '') + RIGHT(ISNULL(CONVERT(VARCHAR, tue.ApprovalDateTime, 109), ''), 2), 21) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(en.PayGroup, ''), 10) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(TimeSource, ''), 1) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(ApprovalSource, ''), 1) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(AttachmentName, ''), 12) + 
            TimeHistory.dbo.fn_PadVarchar(ISNULL(ApprovalStatus, ''), 1) + 
			TimeHistory.dbo.fn_PadVarchar('', 100), -- Department (clocks only)
     EmployeeID = en.FileNo,
     EmpName = en.LastName + ',' + en.FirstName
FROM #tmpUploadExport tue
INNER JOIN TimeCurrent..tblEmplNames en (NOLOCK)
ON en.Client = tue.Client
AND en.GroupCode = tue.GroupCode
AND en.SSN = tue.SSN

UPDATE udf
  SET /*Line1 = '"U"' + @Delim
			+ '"' + ISNULL(en.FirstName, '') + '"' + @Delim 
            + '"' + ISNULL(en.LastName, '') + '"' + @Delim
            + '"' + ISNULL(en.FileNo, '') + '"' + @Delim
            + '"' + ISNULL(udf.AssignmentNo, '') + '"' + @Delim
            + ISNULL(CONVERT(VARCHAR(10),ISNULL(udf.PayrollPeriodEndDate, ' '), 101), '') + @Delim
            + CONVERT(VARCHAR(10),ISNULL(udf.TransDate, ' '), 101) + @Delim
			+ '"' + ISNULL(udf.UDF1, '') + '"' + @Delim
			+ '"' + ISNULL(udf.UDF2, '') + '"' + @Delim
			+ '"' + ISNULL(udf.UDF3, '') + '"' + @Delim
			+ '"' + ISNULL(udf.UDF4, '') + '"' + @Delim
			+ '"' + ISNULL(udf.UDF5, '') + '"' + @Delim
			+ ISNULL(udf.AttachmentName, '')*/
	   Line1 = TimeHistory.dbo.fn_PadVarchar('U', 1) + 
			+ TimeHistory.dbo.fn_PadVarchar(en.FirstName, 20) + 
            + TimeHistory.dbo.fn_PadVarchar(en.LastName, 20) + 
            + TimeHistory.dbo.fn_PadVarchar(en.FileNo, 20) + 
            + TimeHistory.dbo.fn_PadVarchar(udf.AssignmentNo, 32) + 
            + TimeHistory.dbo.fn_PadVarchar(ISNULL(CONVERT(VARCHAR(10),ISNULL(udf.PayrollPeriodEndDate, ' '), 101), ''), 10) + 
            + TimeHistory.dbo.fn_PadVarchar(CONVERT(VARCHAR(10),ISNULL(udf.TransDate, ' '), 101), 10) + 
			+ TimeHistory.dbo.fn_PadVarchar(udf.UDF1, 50) + 
			+ TimeHistory.dbo.fn_PadVarchar(udf.UDF2, 50) + 
			+ TimeHistory.dbo.fn_PadVarchar(udf.UDF3, 50) + 
			+ TimeHistory.dbo.fn_PadVarchar(udf.UDF4, 50) + 
			+ TimeHistory.dbo.fn_PadVarchar(udf.UDF5, 50) + 
			+ TimeHistory.dbo.fn_PadVarchar(ISNULL(udf.AttachmentName, ''), 12),
     EmployeeID = en.FileNo,
     EmpName = en.LastName + ',' + en.FirstName
FROM #tmpUploadUDF udf
INNER JOIN TimeCurrent..tblEmplNames en (NOLOCK)
ON en.Client = udf.Client
AND en.GroupCode = udf.GroupCode
AND en.SSN = udf.SSN

/*  
The order of these final 3 steps is VERY IMPORTANT  
1. Update Pay Records Sent  
2. Remove Negatives  
3. Return recordset to VB  
*/  
  
--PRINT 'Before: IDX_tmpUploadExport_PK' + CONVERT(VARCHAR, GETDATE(), 121)  
CREATE INDEX IDX_tmpUploadExport_PK ON #tmpUploadExport(Client, GroupCode, PayrollPeriodEndDate, SSN, SiteNo, DeptNo)  
--PRINT 'After: IDX_tmpUploadExport_PK' + CONVERT(VARCHAR, GETDATE(), 121)  

-- 1. Update Pay Records Sent  
IF (@RecordType <> 'D' AND @TestingFlag IN ('N', '0') )  
BEGIN  
    UPDATE TimeHistory.dbo.tblEmplSites_Depts  
    SET TimeHistory.dbo.tblEmplSites_Depts.PayRecordsSent = u.SnapshotDateTime  
    FROM #tmpUploadExport as u  
    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds  
    ON th_esds.Client = u.Client  
    AND th_esds.GroupCode = u.GroupCode  
    AND th_esds.PayrollPeriodenddate = u.PayrollPeriodEndDate  
    AND th_esds.SSN = u.SSN  
    AND th_esds.SiteNo = u.SiteNo  
    AND th_esds.DeptNo = u.DeptNo   
    --AND ((th_esds.PayRecordsSent IS NULL) OR (u.LateApprovals = '1'))   Manpower not using Late Approvals
  
    Update TimeCurrent.dbo.tblClosedPeriodAdjs  
    Set TimeCurrent.dbo.tblClosedPeriodAdjs.DateTimeProcessed = ouw.SnapshotDateTime  
    from #tmpUploadExport as ouw  
    Inner Join TimeCurrent.dbo.tblClosedPeriodAdjs cpa  
    on cpa.Client = ouw.Client  
    AND cpa.GroupCode = ouw.Groupcode  
    AND cpa.PayrollPeriodEndDate = ouw.PayrollPeriodEndDate  
    and cpa.SSN = ouw.SSN  
    and cpa.DateTimeProcessed IS NULL             
    --PRINT 'After: PayRecordsSent' + CONVERT(VARCHAR, GETDATE(), 121)      
END  

-- 3. Return recordset to VB
SELECT  RecordType,
		GroupCode,  
		PayrollPeriodEndDate,   
		SSN,  
		SiteNo,
		DeptNo, 
		TransDate,
		AssignmentNo,		
		EmployeeID,
		EmpName,
		Paycode,
		Line1,
		CASE WHEN Paycode = @REGPAYCODE THEN 1 WHEN Paycode = @OTPAYCODE THEN 2 WHEN Paycode = @DTPayCode THEN 3 ELSE 5 END
FROM #tmpUploadExport
UNION ALL
SELECT  RecordType,
		GroupCode,  
		PayrollPeriodEndDate,   
		SSN,  
		SiteNo,
		DeptNo, 
		TransDate,
		AssignmentNo,		
		EmployeeID,
		EmpName,
		Paycode,
		Line1,
		CASE WHEN Paycode = @REGPAYCODE THEN 1 WHEN Paycode = @OTPAYCODE THEN 2 WHEN Paycode = @DTPayCode THEN 3 ELSE 5 END
FROM #tmpUploadUDF
ORDER BY GroupCode
		,EmployeeID
		,AssignmentNo
		,PayrollPeriodEndDate
		,RecordType
		,TransDate
		,CASE WHEN Paycode = @REGPAYCODE THEN 1 WHEN Paycode = @OTPAYCODE THEN 2 WHEN Paycode = @DTPayCode THEN 3 ELSE 5 END
          
--PRINT 'After: Final Select' + CONVERT(VARCHAR, GETDATE(), 121)         
         
DROP TABLE #tmpAssSumm  
DROP TABLE #tmpUploadExport  
DROP TABLE #tmpUploadUDF
   
--PRINT 'DONE' + CONVERT(VARCHAR, GETDATE(), 121)  
  
RETURN
