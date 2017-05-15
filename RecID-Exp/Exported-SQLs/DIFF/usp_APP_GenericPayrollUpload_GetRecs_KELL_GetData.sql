Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
   20:  ,@FaxApprover INT
   21:  ,@XXPAYCODE VARCHAR(10) = '_XX_XX_XX_';
   23:  SELECT @FaxApprover = UserID 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
   19:  ,@FaxApprover INT
   20:  ,@XXPAYCODE VARCHAR(10) = '_XX_XX_XX_'
   21:  ,@AdditionalCPAWks int;
   23:  SELECT @FaxApprover = UserID 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
   26:  AND Client = @Client;
   28:  CREATE TABLE #tmpGroupCodeDates (Client CHAR(4),GroupCode INT,PPED DATE,isVMS TINYINT);
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
   26:  AND Client = @Client;
   28:  IF @PayrollType IN ('C', 'S')
   29:  BEGIN
   30:      SELECT  @AdditionalCPAWks = AdditionalCPAWeeks
   31:      FROM    TimeCurrent..tblClients
   32:      WHERE   Client = @Client
   33:  END
   35:  CREATE TABLE #tmpGroupCodeDates (Client CHAR(4),GroupCode INT,PPED DATE,isVMS TINYINT);
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
   46:  ;WITH  vmsweeks AS (
   47:   SELECT DISTINCT a.client,a.GroupCode,cat.AdditionalLateTimeEntryWks
   48:   FROM TimeCurrent..tblEmplAssignments a
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
   53:  ;WITH  vmsweeks AS (
   54:   SELECT DISTINCT a.client,a.GroupCode,CASE WHEN @PayrollType NOT IN ('C', 'S') THEN cat.AdditionalLateTimeEntryWks ELSE @Additi
   55:  onalCPAWks END AS AdditionalLateTimeEntryWks
   56:   FROM TimeCurrent..tblEmplAssignments a
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
  287:    AND cat.Client = ea.Client
  288:    WHERE
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
  294:    AND cat.Client = ea.Client
  295:    LEFT JOIN TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
  296:    ON t.Client = cpa.Client
  297:    AND t.GroupCode = cpa.GroupCode
  298:    AND t.PayrollPeriodEndDate = cpa.PayrollPeriodEndDate
  299:    AND t.SSN = cpa.SSN
  300:    AND t.SiteNo = cpa.SiteNo
  301:    AND t.DeptNo = cpa.DeptNo 
  302:    AND cpa.Status <> '4'  
  303:    WHERE
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
  291:    AND (t.isVMS = 0 OR (t.isVMS = 1 AND cat.AdditionalLateTimeEntryWks > 0))
  292:    GROUP BY
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
  306:    AND (t.isVMS = 0 OR (t.isVMS = 1 AND cat.AdditionalLateTimeEntryWks > 0))
  307:    AND cpa.RecordID IS NULL
  308:    GROUP BY
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
  312:    HAVING
  313:      ((CASE @PayrollType
  314:        WHEN 'A' THEN SUM(1)
  315:        ELSE SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
  328:    HAVING
  329:      ((CASE WHEN @PayrollType IN ('A', 'C') THEN SUM(1)
  330:        ELSE SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
*****

Resync Failed.  Files are too different.
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_KELL_GetData.sql
  319:  END
  320:  ELSE
  321:    BEGIN
  322:      RETURN;
  323:    END
  325:  UPDATE ass
  326:  SET ExcludeFromPayfile = cat.ExcludeFromPayfile,
  327:          SendAsRegInPayfile = cat.SendAsRegInPayfile,
  328:          SendAsUnapproved = cat.SendAsUnapprovedInPayfile
  329:  FROM #tmpAssignments ass
  330:  INNER JOIN TimeCurrent..tblClients_AssignmentType cat
  331:  ON cat.Client = @Client
  332:  AND cat.AssignmentTypeID = ass.AssignmentTypeID
  334:  DELETE FROM #tmpAssignments
  335:  WHERE ExcludeFromPayfile = '1'
  337:  DELETE ass
  338:  FROM #tmpAssignments ass
  339:  WHERE ass.TransCount <> ass.ApprovedCount  
  340:  AND @PayrollType ='A' --IN ('A', 'L')
  341:  AND ISNULL(ass.SendAsUnapproved, '0') = '0'
  343:  ;WITH DoesOTOEXists AS
  344:  (
  345:    SELECT DISTINCT sa.SSN,sa.GroupCode,PPED = ts.TimesheetEndDate
  346:    FROM TimeHistory.dbo.tblWTE_Timesheets ts WITH(NOLOCK)
  347:    INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Assignments sa WITH(NOLOCK)
  348:    ON ts.RecordId = sa.TimesheetId
  349:    INNER JOIN (SELECT DISTINCT Client,GroupCode FROM #tmpGroupCodeDates) gcd
  350:    ON gcd.Client = sa.Client
  351:    AND gcd.GroupCode = sa.GroupCode
  352:    WHERE EXISTS
  353:    (
  354:      SELECT 1 FROM TimeHistory.dbo.tblWTE_Spreadsheet_OTOverrides
  355:      WHERE SpreadsheetAssignmentId = sa.RecordId
  356:    )
  357:  )
  358:  UPDATE T SET
  359:  OTOverride = 1
  360:  FROM #tmpAssignments T
  361:  LEFT JOIN DoesOTOEXists D
  362:  ON D.SSN = T.SSN
  363:  AND D.GroupCode = T.GroupCode
  364:  AND D.PPED = T.PPED
  365:  WHERE D.SSN IS NOT NULL
  366:  OR T.AgencyName <> ''
  367:  OR (T.BranchID IN ('35C3','3547') AND T.ClientID = '01327464')
  368:  OR T.SiteState = 'PR';
  370:  CREATE TABLE #tmpBaseData
  371:  (
  372:     RecordID BIGINT  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 09Aug2016 >--
  373:    ,TransDate DATE
  374:    ,[Hours] NUMERIC(5,2)
  375:    ,RegHours NUMERIC(5,2)
  376:    ,OT_Hours NUMERIC(5,2)
  377:    ,DT_Hours NUMERIC(5,2)
  378:    ,AprvlStatus VARCHAR(1)
  379:    ,AprvlStatus_Date DATE
  380:    ,AprvlStatus_UserID INT
  381:    ,ClockAdjustmentNo VARCHAR(3) --> Srinsoft Changed ClockAdjustmentNo VARCHAR(1) VARCHAR(3) for #tmpTHD on 02/17/2016--<
  382:    ,OTOverride TINYINT
  383:    ,SSN INT
  384:    ,EmployeeID VARCHAR(100)
  385:    ,EmpName VARCHAR(100)
  386:    ,FileBreakID VARCHAR(20)
  387:    ,weDate VARCHAR(10)
  388:    ,AssignmentNo VARCHAR(100)
  389:    ,Last4SSN VARCHAR(10)
  390:    ,CollectFrmt VARCHAR(20)
  391:    ,ReportingInt VARCHAR(10)
  392:    ,BranchID VARCHAR(100)
  393:    ,GroupID VARCHAR(100)
  394:    ,TimesheetDate VARCHAR(10)
  395:    ,TimeType VARCHAR(10)
  396:    ,Confirmation VARCHAR(10)
  397:    ,TransType VARCHAR(1)
  398:    ,Individual VARCHAR(1)
  399:    ,[Timestamp] VARCHAR(20)
  400:    ,ExpenseMiles VARCHAR(10)
  401:    ,ExpenseDollars VARCHAR(10)
  402:    ,[Status] VARCHAR(3)
  403:    ,Optional1 VARCHAR(100)
  404:    ,Optional2 VARCHAR(100)
  405:    ,Optional3 VARCHAR(100)
  406:    ,Optional4 VARCHAR(100)
  407:    ,Optional5 VARCHAR(100)
  408:    ,Optional6 VARCHAR(100)
  409:    ,Optional7 VARCHAR(100)
  410:    ,Optional8 VARCHAR(100)
  411:    ,Optional9 VARCHAR(100)
  412:    ,AuthTimeStamp DATETIME
  413:    ,ApprovalUserID INT 
  414:    ,AuthEmail VARCHAR(100)
  415:    ,AuthConfirmNo VARCHAR(6)
  416:    ,AuthComments VARCHAR(255)
  417:    ,WorkRules VARCHAR(4)
  418:    ,Rounding VARCHAR(1)
  419:    ,WeekEndDay VARCHAR(1)
  420:    ,IVR_Count TINYINT
  421:    ,WTE_Count TINYINT
  422:    ,SiteNo INT
  423:    ,DeptNo INT
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_KELL_GETDATA.SQL
  333:  END
  334:  ELSE IF (@PayrollType IN ('C', 'S'))
  335:  BEGIN
  336:    INSERT INTO #tmpAssignments
  337:    (
  338:     SSN
  339:    ,SiteNo
  340:    ,DeptNo
  341:    ,PayRecordsSent
  342:    ,TransCount
  343:    ,ApprovedCount
  344:    ,AprvlStatus_Date
  345:    ,IVR_Count
  346:    ,WTE_Count
  347:    ,Fax_Count
  348:    ,DLT_Count
  349:    ,FaxApprover_Count
  350:    ,EmailClient_Count
  351:    ,EmailOther_Count
  352:    ,Dispute_Count
  353:    ,OtherTxns_Count
  354:    ,LateApprovals
  355:    ,JobID
  356:    ,AttachmentName
  357:    ,ApprovalMethodID
  358:    ,OTOverride
  359:    ,Last5SSN
  360:    ,AgencyName
  361:    ,SiteState        
  362:    ,BranchID
  363:    ,ClientID
  364:    ,EntryRounding
  365:    ,AssignmentNo
  366:    ,BillingRate
  367:    ,WorkState
  368:    ,PayOnly
  369:    ,BPO
  370:    ,GroupCode
  371:    ,PPED
  372:    ,AssignmentTypeID
  373:    )
  374:    SELECT 
  375:     t.SSN
  376:    ,t.SiteNo
  377:    ,t.DeptNo
  378:    ,PayRecordsSent = ISNULL(th_esds.PayRecordsSent,'19700101')
  379:    ,TransCount = SUM(1)
  380:    ,ApprovedCount = SUM(CASE WHEN t.AprvlStatus IN ('A','L') THEN 1 ELSE 0 END)
  381:    ,AprvlStatus_Date = MAX(ISNULL(t.AprvlStatus_Date,'19700102'))
  382:    ,IVR_Count = SUM(CASE WHEN t.UserCode = 'IVR' THEN 1 ELSE 0 END)
  383:    ,WTE_Count = SUM(CASE WHEN t.UserCode IN ('WTE','VTS') THEN 1 ELSE 0 END)
  384:    ,Fax_Count =  SUM(CASE WHEN t.UserCode = 'FAX' THEN 1 ELSE 0 END)
  385:    ,DLT_Count = SUM(CASE WHEN t.UserCode = '*VMS' THEN 1 ELSE 0 END)
  386:    ,FaxApprover_Count =  SUM(CASE WHEN ISNULL(t.AprvlStatus_UserID,0) = @FaxApprover THEN 1 ELSE 0 END)
  387:    ,EmailClient_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode = 'CLI') THEN 1 ELSE 0 END)
  388:    ,EmailOther_Count =  SUM(CASE WHEN (t.UserCode <> t.OutUserCode AND t.OutUserCode in ('BRA','COR','AGE')) THEN 1 ELSE 0 END)
  389:    ,Dispute_Count = SUM(CASE WHEN t.ClockAdjustmentNo IN ('$','@') THEN 1 ELSE 0 END)
  390:    ,OtherTxns_Count = SUM(CASE WHEN t.ClockAdjustmentNo NOT IN ('$','@','') AND ISNULL(t.UserCode,'') NOT IN ('WTE','COR','FAX',
  391:  'EML','SYS') AND ISNULL(t.OutUserCode,'') NOT in ('CLI','BRA','COR','AGE') THEN 1 ELSE 0 END)
  392:    ,LateApprovals = 0
  393:    ,JobID = 0
  394:    ,AttachmentName = th_esds.RecordID
  395:    ,ApprovalMethodID = ea.ApprovalMethodID
  396:    ,OTOverride = 0
  397:    ,LastSSN = (SELECT TOP 1 SSN FROM TimeCurrent.dbo.tblRFR_Empls rfr WITH(NOLOCK) WHERE rfr.Client = @Client AND rfr.RFR_GroupI
  398:  D = tc_cg.RFR_UniqueID AND rfr.RFR_UniqueID = tc_en.FileNo)
  399:    ,AgencyName = ISNULL(ag.ClientAgencyCode,'')
  400:    ,SiteState = ea.WorkState           
  401:    ,BranchID = ea.BranchId
  402:    ,ClientID = ea.ClientID
  403:    ,ea.EntryRounding
  404:    ,AssignmentNo = SUBSTRING(ea.AssignmentNo,CHARINDEX('-',ea.AssignmentNo) + 1,LEN(ea.AssignmentNo))
  405:    ,BillingRate = CAST(ISNULL(th_esds.BillRate,0) AS VARCHAR) -- BILLING-RATE
  406:    ,WorkState = ISNULL(ea.WorkState,'') -- WORK-STATE
  407:    ,PayOnly = CASE WHEN ISNULL(ea.PayOnly,'N') = '' THEN 'N' ELSE ISNULL(ea.PayOnly,'N') END
  408:    ,BPO = CASE WHEN ISNULL(ea.BPO,'N') = '' THEN 'N' ELSE ISNULL(ea.BPO,'N') END
  409:    ,t.GroupCode
  410:    ,PPED = t.PayrollPeriodEndDate
  411:    ,AssignmentTypeID = ea.AssignmentTypeID
  412:    FROM #tmpTHD t
  413:    INNER JOIN TimeCurrent.dbo.tblClientGroups tc_cg WITH(NOLOCK)
  414:    ON  tc_cg.Client = t.Client 
  415:    AND tc_cg.GroupCode = t.GroupCode     
  416:    INNER JOIN TimeCurrent.dbo.tblEmplNames tc_en WITH(NOLOCK)
  417:    ON  tc_en.Client = t.Client 
  418:    AND tc_en.GroupCode = t.GroupCode 
  419:    AND tc_en.SSN = t.SSN    
  420:    INNER JOIN TimeCurrent.dbo.tblEmplAssignments ea WITH(NOLOCK)
  421:    ON  ea.Client = t.Client
  422:    AND ea.Groupcode = t.Groupcode
  423:    AND ea.SSN = t.SSN
  424:    AND ea.DeptNo =  t.DeptNo
  425:    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts th_esds WITH(NOLOCK)
  426:    ON  th_esds.Client = t.Client
  427:    AND th_esds.GroupCode = t.GroupCode
  428:    AND th_esds.PayrollPeriodEndDate = t.PayrollPeriodEndDate
  429:    AND th_esds.SSN = t.SSN
  430:    AND th_esds.SiteNo = t.SiteNo
  431:    AND th_esds.DeptNo = t.DeptNo
  432:    INNER JOIN TimeCurrent.dbo.tblAdjCodes ac WITH(NOLOCK)
*****

