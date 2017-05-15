Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
    8:  SET NOCOUNT ON
   10:  -- how many weeks should we look back in tblPeriodEndDates
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
    7:  SET NOCOUNT ON
    8:  --SET STATISTICS IO,TIME off
    9:  --DECLARE @approvalGUID VARCHAR(36) = 'F029BC7B-66DE-4043-85CB-4490A7980B08'
   11:  SET NOCOUNT ON
   13:  -- how many weeks should we look back in tblPeriodEndDates
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
   59:  (
   60:        RecordID  INT 
   61:            , ApprovalGUID uniqueidentifier
   62:      , Brand VARCHAR(60)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
   62:  (
   63:        RecordID  BIGINT   
   64:            , ApprovalGUID VARCHAR(36)
   65:      , Brand VARCHAR(60)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  113:          ae_RecordID int,
  114:          OpenDepts INT,
  115:          AssignmentNo VARCHAR(50)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  116:          ae_RecordID int,
  117:          OpenDepts VARCHAR(1),
  118:          AssignmentNo VARCHAR(50)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  134:  SELECT ea.Client, ea.GroupCode, ea.SSN, ea.SiteNo, ea.DeptNo, ea.Brand, ae.BrandID, ea.TimeEntryFreqID, ae_request.PayrollPerio
  135:  dEndDate, ae.PayrollPeriodEndDate, aes.RequestType, ae.RecordID, ISNULL(ae_ass.OpenDepts, 0), ea.AssignmentNo
  136:  FROM     
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  137:  SELECT ea.Client, ea.GroupCode, ea.SSN, ea.SiteNo, ea.DeptNo, ea.Brand, ae.BrandID, ea.TimeEntryFreqID, ae_request.PayrollPerio
  138:  dEndDate, ae.PayrollPeriodEndDate, aes.RequestType, ae.RecordID, ISNULL(ae_ass.OpenDepts, '0'), ea.AssignmentNo
  139:  FROM     
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  178:    AND ((CASE
  179:                          WHEN aes2.RequestType IN ('1','2') THEN '1' 
  180:               WHEN aes2.RequestType IN ('3') THEN '3'
  181:              ELSE '4'
  182:                  END =
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  181:    AND ((CASE
  182:                          WHEN aes2.RequestType IN (1,2) THEN 1 
  183:               WHEN aes2.RequestType IN (3) THEN 3
  184:              ELSE 4
  185:                  END =
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  183:                  CASE
  184:                          WHEN aes.RequestType IN ('1','2') THEN '1' 
  185:                               WHEN aes.RequestType IN ('3') THEN '3'
  186:              ELSE '4'
  187:                  END)
  188:                  OR aes.RequestType NOT IN ('1','2','3'))
  190:    INNER JOIN TimeCurrent..tblApprovalEmail_Assignment ae_ass WITH(NOLOCK)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  186:                  CASE
  187:                          WHEN aes.RequestType IN (1,2) THEN 1 
  188:                               WHEN aes.RequestType IN (3) THEN 3
  189:              ELSE 4
  190:                  END)
  191:                  OR aes.RequestType NOT IN (1,2,3))
  193:    INNER JOIN TimeCurrent..tblApprovalEmail_Assignment ae_ass WITH(NOLOCK)
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  193:      AND ae_ass.GroupDeptsRecordID IS NOT NULL
  195:          INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK)
  196:                  ON gd.RecordID = ae_ass.GroupDeptsRecordID
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  196:      AND ae_ass.GroupDeptsRecordID IS NOT NULL
  198:          INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK) --returns deptname and causes a key lookup
  199:                  ON gd.RecordID = ae_ass.GroupDeptsRecordID
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  218:                , sn.SiteName
  219:                , ISNULL(gd.DeptName_Long, '') as DeptName
  220:                , ISNULL(tmpAss.TimeEntryFreqID, 2) AS TimeEntryFreqID
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  221:                , sn.SiteName
  222:                , DeptName =ISNULL(gd.DeptName_long , '')
  223:                , ISNULL(tmpAss.TimeEntryFreqID, 2) AS TimeEntryFreqID
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  240:                ,/* ISNULL(thd.RequireProjects, 0) */ 0 AS RequireProjects
  241:                , CASE ISNULL(tmpAss.TimeEntryFreqID, 2) WHEN 5 THEN CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(thd.TransDate)-1), th
  242:  d.TransDate), 101)
  243:                                                                  ELSE thd.PayrollPeriodEndDate 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  243:                ,/* ISNULL(thd.RequireProjects, 0) */ 0 AS RequireProjects
  244:                , CASE ISNULL(tmpAss.TimeEntryFreqID, 2) WHEN 5 THEN  DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate)
  245:                                                                  ELSE thd.PayrollPeriodEndDate 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  296:                    AND thd.SiteNo = sn.SiteNo 
  298:            INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK)
  299:                    ON thd.Client = gd.Client 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  298:                    AND thd.SiteNo = sn.SiteNo 
  300:            INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK) --added DeptName_long as an included column to the index re
  301:  sulting in an  index seek instead of Key Lookup
  302:                    ON thd.Client = gd.Client 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  311:                  WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
  312:                  AND ((CASE WHEN aes2.RequestType IN ('1','2') THEN '1' 
  313:                             WHEN aes2.RequestType IN ('3') THEN '3'
  314:                             ELSE '4' END =  CASE WHEN tmpAss.RequestType IN ('1','2') THEN '1' 
  315:                                             WHEN tmpAss.RequestType IN ('3') THEN '3'
  316:                                             ELSE '4' END) OR tmpAss.RequestType NOT IN ('1','2','3'))
  317:                )
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  314:                  WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
  315:                  AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
  316:                             WHEN aes2.RequestType IN (3) THEN 3
  317:                             ELSE 4 END =  CASE WHEN tmpAss.RequestType IN (1,2) THEN 1 
  318:                                             WHEN tmpAss.RequestType IN (3) THEN 3
  319:                                             ELSE 4 END) OR tmpAss.RequestType NOT IN (1,2,3))
  320:                )
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  323:                                  END)
  324:            AND tmpAss.OpenDepts = 0
  325:            AND thd.Hours <> 0
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  326:                                  END)
  327:            AND tmpAss.OpenDepts = '0'
  328:            AND thd.Hours <> 0
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  361:                , 0 as RequireProjects
  362:                , CASE ISNULL(tmpAss.TimeEntryFreqID, 2) WHEN 5 THEN CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(thd.TransDate)-1), th
  363:  d.TransDate), 101)
  364:                                                                  ELSE thd.PayrollPeriodEndDate 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  364:                , 0 as RequireProjects
  365:                , CASE ISNULL(tmpAss.TimeEntryFreqID, 2) WHEN 5 THEN  DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate)
  366:                                                                  ELSE thd.PayrollPeriodEndDate 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  424:                  WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
  425:                  AND ((CASE WHEN aes2.RequestType IN ('1','2') THEN '1' 
  426:                             WHEN aes2.RequestType IN ('3') THEN '3'
  427:                             ELSE '4' END =  CASE WHEN tmpAss.RequestType IN ('1','2') THEN '1' 
  428:                                             WHEN tmpAss.RequestType IN ('3') THEN '3'
  429:                                             ELSE '4' END) OR tmpAss.RequestType NOT IN ('1','2','3'))
  430:                )  
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  426:                  WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
  427:                  AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
  428:                             WHEN aes2.RequestType IN (3) THEN 3
  429:                             ELSE 4 END =  CASE WHEN tmpAss.RequestType IN (1,2) THEN 1 
  430:                                             WHEN tmpAss.RequestType IN (3) THEN 3
  431:                                             ELSE 4 END) OR tmpAss.RequestType NOT IN (1,2,3))
  432:                )  
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  436:                                  END)
  437:            AND tmpAss.OpenDepts = 0
  438:            AND thd.Hours <> 0
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  438:                                  END)
  439:            AND tmpAss.OpenDepts = '0'
  440:            AND thd.Hours <> 0
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  475:                , CASE ISNULL(tmpAss.TimeEntryFreqID, 2)
  476:                        WHEN 5 THEN CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate), 101)
  477:                        ELSE thd.PayrollPeriodEndDate 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  477:                , CASE ISNULL(tmpAss.TimeEntryFreqID, 2)
  478:                        WHEN 5 THEN DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate)
  479:                        ELSE thd.PayrollPeriodEndDate 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  541:                  WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
  542:                  AND ((CASE WHEN aes2.RequestType IN ('1','2') THEN '1' 
  543:                             WHEN aes2.RequestType IN ('3') THEN '3'
  544:                             ELSE '4' END =  CASE WHEN tmpAss.RequestType IN ('1','2') THEN '1' 
  545:                                             WHEN tmpAss.RequestType IN ('3') THEN '3'
  546:                                             ELSE '4' END) OR tmpAss.RequestType NOT IN ('1','2','3'))
  547:                )  
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  543:                  WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
  544:                  AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
  545:                             WHEN aes2.RequestType IN (3) THEN 3
  546:                             ELSE 4 END =  CASE WHEN tmpAss.RequestType IN (1,2) THEN 1 
  547:                                             WHEN tmpAss.RequestType IN (3) THEN 3
  548:                                             ELSE 4 END) OR tmpAss.RequestType NOT IN (1,2,3))
  549:                )  
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  553:                                  END)    
  554:            AND tmpAss.OpenDepts = 1
  555:            AND thd.Hours <> 0            
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  555:                                  END)    
  556:            AND tmpAss.OpenDepts = '1'
  557:            AND thd.Hours <> 0            
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  646:                  WHERE aes2.ApprovalEmailID = tmpDepts.ae_RecordID
  647:                  AND ((CASE WHEN aes2.RequestType IN ('1','2') THEN '1' 
  648:                             WHEN aes2.RequestType IN ('3') THEN '3'
  649:                             ELSE '4' END =  CASE WHEN tmpDepts.RequestType IN ('1','2') THEN '1' 
  650:                                             WHEN tmpDepts.RequestType IN ('3') THEN '3'
  651:                                             ELSE '4' END) OR tmpDepts.RequestType NOT IN ('1','2','3'))
  652:                )  
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  648:                  WHERE aes2.ApprovalEmailID = tmpDepts.ae_RecordID
  649:                  AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
  650:                             WHEN aes2.RequestType IN (3) THEN 3
  651:                             ELSE 4 END =  CASE WHEN tmpDepts.RequestType IN (1,2) THEN 1 
  652:                                             WHEN tmpDepts.RequestType IN (3) THEN 3
  653:                                             ELSE 4 END) OR tmpDepts.RequestType NOT IN (1,2,3))
  654:                )  
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  729:                  WHERE mthWeeks.PPED = t.PayrollPeriodEndDate    
  730:                  AND t.TransDate BETWEEN CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(ts.TimesheetEndDate)-1), ts.TimesheetEndDate), 1
  731:  01) AND ts.TimesheetEndDate
  732:                  AND t.TimeEntryFreqID = 5
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  731:                  WHERE mthWeeks.PPED = t.PayrollPeriodEndDate    
  732:                  AND t.TransDate BETWEEN  DATEADD(dd, -(DAY(ts.TimesheetEndDate)-1), ts.TimesheetEndDate) AND ts.TimesheetEndDat
  733:  e
  734:                  AND t.TimeEntryFreqID = 5
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  774:          CROSS APPLY TimeHistory.dbo.fn_GetApprovalBillableFlags(t.Client, t.GroupCode, t.SiteNo, @MethodID, adj.Worked, adj.Bil
  775:  lable, adj.Payable, adj.AdjustmentType) flg
  776:          ORDER BY t.EmployeeName, t.TransDate
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  776:          CROSS APPLY TimeHistory.dbo.fn_GetApprovalBillableFlags(t.Client, t.GroupCode, t.SiteNo, @MethodID, adj.Worked, adj.Bil
  777:  lable, adj.Payable, adj.AdjustmentType) flg --is this used?
  778:          ORDER BY t.EmployeeName, t.TransDate
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  786:                          FirstName         VARCHAR(20),
  787:                          THDRecordID       INT,
  788:                          DeptNo            INT,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  788:                          FirstName         VARCHAR(20),
  789:                          THDRecordID       BIGINT,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Se
  790:  pt2016 >--
  791:                          DeptNo            INT,
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
  810:                          BrandID           INT,
  811:                          ClockAdjustmentNo VARCHAR(3), 
  812:                          PayrollPeriodEndDate DATETIME,
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
  813:                          BrandID           INT,
  814:                          ClockAdjustmentNo VARCHAR(3),  --< Srinsoft 09/09/2015 Changed ClockAdjustmentNo VARCHAR(1) to VARCHAR(
  815:  3) for #tmpTxns >-- 
  816:                          PayrollPeriodEndDate DATETIME,
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_WTE_GetUnapprovedTimeEntries.sql
 1006:        , CASE ISNULL(t.TimeEntryFreqID, 2)
 1007:                  WHEN 5 THEN CONVERT(VARCHAR(25), DATEADD(dd, -(DAY(t.TransDate) -1), t.TransDate), 101)
 1008:                  ELSE t.PayrollPeriodEndDate 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_WTE_GETUNAPPROVEDTIMEENTRIES.SQL
 1010:        , CASE ISNULL(t.TimeEntryFreqID, 2)
 1011:                  WHEN 5 THEN  DATEADD(dd, -(DAY(t.TransDate) -1), t.TransDate)
 1012:                  ELSE t.PayrollPeriodEndDate 
*****

