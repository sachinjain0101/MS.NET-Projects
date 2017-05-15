USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_WTE_GetUnapprovedTimeEntries]    Script Date: 11/6/2014 10:19:56 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WTE_GetUnapprovedTimeEntries]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_WTE_GetUnapprovedTimeEntries] AS' 
END
GO
/*

exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries '37D9FDD7-F5BE-4E0D-9949-5D9E1B256A84'

exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries_GG10 'A2DC7279-5439-4BC9-81A3-9B5BF76A4FE4'

exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries                 '2F953784-6490-4CB4-A5A4-0C1DE63492BF'  -- PCT trying to reproduce
exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries_MONTHLY_ROLLBACK '7286524A-7DBB-4336-8C22-EAE329FDA300' -- Duplicates on clock for Clark

--Randstad Production clock by dept eow not Sunday issue
exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries                  '840E2F62-A584-4D77-84A0-7B89D014FEAA';
go
exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries_MONTHLY_ROLLBACK 'C034EAE1-2CC6-4B3E-A326-2D141B95518B';

exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries 'C034EAE1-2CC6-4B3E-A326-2D141B95518B'

exec TimeHistory..usp_WTE_GetUnapprovedTimeEntries_GG11 'C034EAE1-2CC6-4B3E-A326-2D141B95518B'
*/
ALTER PROCEDURE [dbo].[usp_WTE_GetUnapprovedTimeEntries] 

	@ApprovalGuid varchar(36)

AS

SET NOCOUNT ON
--SET STATISTICS IO,TIME off
--DECLARE @approvalGUID VARCHAR(36) = 'F029BC7B-66DE-4043-85CB-4490A7980B08'

SET NOCOUNT ON

-- how many weeks should we look back in tblPeriodEndDates
DECLARE @WeeksBack int = 20
DECLARE @XMLStream VARCHAR(2000)
DECLARE @TimeEntryStaffingID VARCHAR(20)
DECLARE @PPED VARCHAR(50)
DECLARE @UserID VARCHAR(20)
DECLARE @Escalation VARCHAR(1)
DECLARE @StartPos INT 
DECLARE @EndPos INT 
DECLARE @Client VARCHAR(4)
DECLARE @GroupCode INT 
DECLARE @PPEDCursor DATETIME 
DECLARE @MethodID INT
DECLARE @ApprovalGuid2 varchar(36)
DECLARE @CutoffDate DATETIME
DECLARE @AssRowsAffected INT
DECLARE @DeptRowsAffected INT 
DECLARE @AE_RecordID INT

SELECT @ApprovalGuid = ISNULL(TimeGuid,GUID)
FROM Scheduler..tblEmailGuid
WHERE GUID = @ApprovalGuid


SELECT @MethodID = RecordID 
FROM timecurrent..tblStaffing_Methods WITH(NOLOCK) 
WHERE MethodCode = 'APBAS'

SET @ApprovalGuid2 = @ApprovalGuid
--SET @CutoffDate =  DATEADD(ww, -4, GETDATE())
SELECT @CutoffDate = DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, ae.PayrollPeriodEndDate) 
		                                                                                                                                                    ELSE DATEADD(dd, -21, ae.PayrollPeriodEndDate) 
									                                                                                       END),
       @AE_RecordID = ae.RecordID
FROM TimeCurrent.dbo.tblApprovalEmail_Schedule aes WITH (NOLOCK)
INNER JOIN TimeCurrent.dbo.tblApprovalEmail ae WITH (NOLOCK)
ON ae.RecordID = aes.ApprovalEmailID
INNER JOIN TimeCurrent.dbo.tblClients c WITH (NOLOCK)
ON c.Client = ae.Client
INNER JOIN TimeCurrent.dbo.tblClientGroups cg WITH (NOLOCK)
ON cg.Client = c.Client
AND cg.GroupCode = ae.GroupCode_FirstAssignment
WHERE aes.GUID = @ApprovalGuid
print @CutoffDate

CREATE TABLE #tmpNew
(
      RecordID  BIGINT   
	  , ApprovalGUID VARCHAR(36)
    , Brand VARCHAR(60)
    , BrandId INT 
    , SiteName VARCHAR(100)
    , DeptName VARCHAR(100)
    , TimeEntryFreqID INT 
    , EmployeeId INT 
    , EmployeeName VARCHAR(100) 
    , Client VARCHAR(4) 
    , GroupCode INT 
    , SSN INT 
    , SiteNo INT 
    , DeptNo INT 
    , TransDate DATETIME 
    , PayrollPeriodEndDate DATETIME 
    , MasterPayrollDate DATETIME 
    , InTime DATETIME 
    , OutTime DATETIME 
    , [Hours] NUMERIC(9, 2)
    , Dollars NUMERIC(9, 2)
    , ClockAdjustmentNo VARCHAR(3)  
    , RegHours NUMERIC(9, 2)
    , OT_Hours NUMERIC(9, 2)
    , DT_Hours NUMERIC(9, 2)
    , UseProjects BIT  
    , RequireProjects BIT  
    , ParentPayrollDate DATETIME 
    , DisputeMode SMALLINT 
    , Comments VARCHAR(4000)
    , PayRate NUMERIC(7, 2)
    , ClientRecordID INT
	, AssignmentNo VARCHAR(50) 
    , query VARCHAR(10)
    , SpreadsheetAssignmentID INT
	, PayRecordsSent DATETIME
	, ApprovalModeBool VARCHAR(1)
	, HasSnapshots BIT DEFAULT(0)
)

CREATE TABLE #tmpAssignments
(
	Client varchar(4),
	GroupCode int,
	SSN int,
	SiteNo int,
	DeptNo int,
	Brand varchar(32),
	BrandID int,
	TimeEntryFreqID int,
	ae_Request_PayrollPeriodEndDate datetime,
	ae_PayrollPeriodEndDate datetime,
	RequestType int,
	ae_RecordID int,
	OpenDepts VARCHAR(1),
	AssignmentNo VARCHAR(50)
)

CREATE TABLE #tmpDepts
(
	Client varchar(4),
	GroupCode int,
	DeptNo int,
	DeptName varchar(50),
	BrandID int,
	GroupDeptsRecordID int,
	ae_Request_PayrollPeriodEndDate datetime,
	ae_PayrollPeriodEndDate datetime,
	RequestType int,
	ae_RecordID int	
)

INSERT INTO #tmpAssignments (Client, GroupCode, SSN, SiteNo, DeptNo, Brand, BrandID, TimeEntryFreqID, ae_Request_PayrollPeriodEndDate, ae_PayrollPeriodEndDate, RequestType, ae_RecordID, OpenDepts, AssignmentNo)
SELECT ea.Client, ea.GroupCode, ea.SSN, ea.SiteNo, ea.DeptNo, ea.Brand, ae.BrandID, ea.TimeEntryFreqID, ae_request.PayrollPeriodEndDate, ae.PayrollPeriodEndDate, aes.RequestType, ae.RecordID, ISNULL(ae_ass.OpenDepts, '0'), ea.AssignmentNo
FROM     
  TimeCurrent..tblApprovalEmail_Schedule aes WITH(NOLOCK)
  
  INNER JOIN TimeCurrent..tblApprovalEmail ae_request WITH(NOLOCK)
    ON ae_request.RecordID = aes.ApprovalEmailID
    
  INNER JOIN TimeCurrent..tblApprovalEmail ae WITH(NOLOCK)
    ON ae.UserID = ae_request.UserID
    AND ae.BrandID = ae_request.BrandID    
    AND ae.PayrollPeriodEndDate <= ae_request.PayrollPeriodEndDate
    AND ae.PayrollPeriodEndDate >= @CutoffDate
        
  INNER JOIN TimeCurrent..tblApprovalEmail_Assignment ae_ass WITH(NOLOCK)
    ON ae_ass.ApprovalEmailID = ae.RecordID
    AND ae_ass.AssignmentRecordID IS NOT NULL
    
	INNER JOIN TimeCurrent..tblEmplAssignments AS ea WITH(NOLOCK)
		ON ea.RecordID = ae_ass.AssignmentRecordID
	WHERE aes.GUID = @ApprovalGuid	
SET @AssRowsAffected = @@ROWCOUNT
	--OPTION (FORCE ORDER)

INSERT INTO #tmpDepts(Client, GroupCode, DeptNo, DeptName, BrandID, GroupDeptsRecordID, ae_Request_PayrollPeriodEndDate, ae_PayrollPeriodEndDate, RequestType, ae_RecordID)
SELECT DISTINCT gd.Client, gd.GroupCode, gd.DeptNo, gd.DeptName, ae.BrandID, ae_ass.GroupDeptsRecordID, ae_request.PayrollPeriodEndDate, ae.PayrollPeriodEndDate, aes.RequestType, ae.RecordID
FROM
  TimeCurrent..tblApprovalEmail_Schedule aes WITH(NOLOCK)
  
  INNER JOIN TimeCurrent..tblApprovalEmail ae_request WITH(NOLOCK)
    ON ae_request.RecordID = aes.ApprovalEmailID
    
  INNER JOIN TimeCurrent..tblApprovalEmail ae WITH(NOLOCK)
    ON ae.UserID = ae_request.UserID
    AND ae.BrandID = ae_request.BrandID
    AND ae.PayrollPeriodEndDate <= ae_request.PayrollPeriodEndDate
    AND ae.PayrollPeriodEndDate >= @CutoffDate
    
-- If it's a request, or an escalation then only return "like" requests
-- If it's a manual request, then return everything
  INNER JOIN TimeCurrent..tblApprovalEmail_Schedule aes2 WITH(NOLOCK)
  ON aes2.ApprovalEmailID = ae.RecordID
  AND ((CASE
			WHEN aes2.RequestType IN (1,2) THEN 1 
             WHEN aes2.RequestType IN (3) THEN 3
            ELSE 4
		END =
		CASE
			WHEN aes.RequestType IN (1,2) THEN 1 
                             WHEN aes.RequestType IN (3) THEN 3
            ELSE 4
		END)
		OR aes.RequestType NOT IN (1,2,3))
    
  INNER JOIN TimeCurrent..tblApprovalEmail_Assignment ae_ass WITH(NOLOCK)
    ON ae_ass.ApprovalEmailID = ae.RecordID
    AND ae_ass.AssignmentRecordID IS NULL
    AND ae_ass.GroupDeptsRecordID IS NOT NULL
    
	INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK) --returns deptname and causes a key lookup
		ON gd.RecordID = ae_ass.GroupDeptsRecordID
  WHERE aes.GUID = @ApprovalGuid
SET @DeptRowsAffected = @@ROWCOUNT  

--OPTION (FORCE ORDER)
/*
CREATE INDEX IDX_tmpAssignments_C_GC_SSN ON #tmpAssignments(Client, GroupCode, SSN) 
CREATE INDEX IDX_tmpAssignments_C_GC_D ON #tmpAssignments(Client, GroupCode, DeptNo) 

SELECT * FROM #tmpAssignments
SELECT * FROM #tmpDepts
*/
--------------------------------
-- Approval By Assignment - PCT
--------------------------------
IF (@AssRowsAffected > 0)
BEGIN
  INSERT INTO #tmpNew /*Query1*/
  SELECT DISTINCT thd.RecordID
	      , @ApprovalGuid AS ApprovalGUID
		    , tmpAss.Brand
	      , tmpAss.BrandId as BrandId
	      , sn.SiteName
	      , DeptName =ISNULL(gd.DeptName_long , '')
	      , ISNULL(tmpAss.TimeEntryFreqID, 2) AS TimeEntryFreqID
	      , en.RecordID AS EmployeeId
	      , en.LastName + ', ' + en.FirstName AS EmployeeName
	      , thd.Client
	      , thd.GroupCode
	      , thd.SSN
	      , thd.SiteNo
	      , thd.DeptNo
	      , thd.TransDate
	      , thd.PayrollPeriodEndDate
	      , thd.MasterPayrollDate
	      , dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InTime
	      , dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutTime
	      , thd.Hours
	      , thd.Dollars
	      , thd.ClockAdjustmentNo
	      , thd.RegHours
	      , thd.OT_Hours
	      , thd.DT_Hours
	      , /*ISNULL(thd.UseProjects, 0)*/ 0 as UseProjects
	      ,/* ISNULL(thd.RequireProjects, 0) */ 0 AS RequireProjects
	      , CASE ISNULL(tmpAss.TimeEntryFreqID, 2) WHEN 5 THEN  DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate)
		                                                ELSE thd.PayrollPeriodEndDate 
          END AS ParentPayrollDate
	      , ISNULL(cgs.DisputeMode, 0) as DisputeMode
		    , /*IsNULL(thd.Comments, '') */ '' as Comments
		    , thd.PayRate AS PayRate
		    , c.RecordID
			, tmpAss.AssignmentNo
		    , '1'
			, 0
			, NULL
			, cg.ApprovalModeBool
			, 0
  FROM     
    #tmpAssignments as tmpAss
  		
	  INNER JOIN TimeCurrent..tblClients c WITH(NOLOCK)
		  ON c.Client = tmpAss.Client		

	  INNER JOIN TimeCurrent..tblClientGroups cg  WITH(NOLOCK)
		  ON cg.Client = tmpAss.Client		
		  AND cg.GroupCode = tmpAss.GroupCode
		  AND cg.StaffingSetupType = '1'
  		
	  INNER JOIN dbo.tblPeriodEndDates AS ped  WITH(NOLOCK)
		  ON ped.Client = tmpAss.Client 
		  AND ped.GroupCode = tmpAss.GroupCode 
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, ae_request.PayrollPeriodEndDate) AND ae_request.PayrollPeriodEndDate
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpAss.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                                                                           ELSE DATEADD(dd, -21, tmpAss.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                            END)) AND tmpAss.ae_Request_PayrollPeriodEndDate
  		AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, TimeCurrent.dbo.fn_GetNextDaysDate(tmpAss.ae_PayrollPeriodEndDate, 1)) AND TimeCurrent.dbo.fn_GetNextDaysDate(tmpAss.ae_PayrollPeriodEndDate, 1)          
	  INNER JOIN TimeHistory..tblTimeHistDetail AS thd  WITH(NOLOCK)
		  ON thd.Client = tmpAss.Client
		  AND thd.GroupCode = tmpAss.GroupCode
		  AND thd.SSN = tmpAss.SSN
		  AND thd.DeptNo = tmpAss.DeptNo
		  AND thd.PayrollPeriodEndDate = ped.PayrollPeriodEndDate
		  AND thd.AprvlStatus = ''
  		
	  INNER JOIN TimeCurrent..tblEmplNames AS en  WITH(NOLOCK)
		  ON tmpAss.Client = en.Client 
		  AND tmpAss.GroupCode = en.GroupCode 
		  AND tmpAss.SSN = en.SSN 
  	
	  INNER JOIN TimeCurrent..tblSiteNames AS sn  WITH(NOLOCK)
		  ON thd.Client = sn.Client 
		  AND thd.GroupCode = sn.GroupCode 
		  AND thd.SiteNo = sn.SiteNo 
  				  
	  INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK) --added DeptName_long as an included column to the index resulting in an  index seek instead of Key Lookup
		  ON thd.Client = gd.Client 
		  AND thd.GroupCode = gd.GroupCode 
	    AND thd.DeptNo = gd.DeptNo 			  

	  LEFT JOIN TimeCurrent..tblCustomGroupSettings cgs WITH(NOLOCK)
		  ON c.RecordId = cgs.ClientId
		  AND cgs.GroupCode = thd.GroupCode

    WHERE --aes.GUID = @ApprovalGuid
    -- If it's a request, or an escalation then only return "like" requests
    -- If it's a manual request, then return everything
    EXISTS( SELECT 1 FROM TimeCurrent..tblApprovalEmail_Schedule aes2 WITH(NOLOCK)
                WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
                AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
                           WHEN aes2.RequestType IN (3) THEN 3
                           ELSE 4 END =  CASE WHEN tmpAss.RequestType IN (1,2) THEN 1 
                                           WHEN tmpAss.RequestType IN (3) THEN 3
                                           ELSE 4 END) OR tmpAss.RequestType NOT IN (1,2,3))
              )
    AND tmpAss.ae_Request_PayrollPeriodEndDate >= DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpAss.ae_Request_PayrollPeriodEndDate) 
		                                                                                                                                                    ELSE DATEADD(dd, -21, tmpAss.ae_Request_PayrollPeriodEndDate) 
									                                                                                       END)
	  AND tmpAss.OpenDepts = '0'
	  AND thd.Hours <> 0
   --OPTION (FORCE ORDER)
END
------------------------------------------------------
-- Clock Approval by assignment  - No Open Departments
------------------------------------------------------
IF (@AssRowsAffected > 0)
BEGIN
  INSERT INTO #tmpNew /*Query2*/
  SELECT DISTINCT thd.RecordID
	      , @ApprovalGuid AS ApprovalGUID
		    , tmpAss.Brand
	      , tmpAss.BrandId as BrandId
	      , cg.GroupName AS SiteName
	      , ISNULL(gd.DeptName, '') as DeptName
	      , ISNULL(tmpAss.TimeEntryFreqID, 2) AS TimeEntryFreqID
	      , en.RecordID AS EmployeeId
	      , en.LastName + ', ' + en.FirstName AS EmployeeName
	      , thd.Client
	      , thd.GroupCode
	      , thd.SSN
  --	    , thd.SiteNo
        , tmpAss.SiteNo
	      , thd.DeptNo
	      , thd.TransDate
	      , thd.PayrollPeriodEndDate
	      , thd.MasterPayrollDate
	      , dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InTime
	      , dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutTime
	      , thd.Hours
	      , thd.Dollars
	      , thd.ClockAdjustmentNo
	      , thd.RegHours
	      , thd.OT_Hours
	      , thd.DT_Hours
	      , 0 as UseProjects
	      , 0 as RequireProjects
	      , CASE ISNULL(tmpAss.TimeEntryFreqID, 2) WHEN 5 THEN  DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate)
		                                                ELSE thd.PayrollPeriodEndDate 
          END AS ParentPayrollDate
	      , 0 as DisputeMode
		    , '' as Comments
		    , thd.PayRate AS PayRate
		    , c.RecordID
			, tmpAss.AssignmentNo
		    , '2'
			, 0
			, NULL
			, cg.ApprovalModeBool
			, 0
  FROM     
    #tmpAssignments as tmpAss
  		
	  INNER JOIN TimeCurrent..tblClients c WITH(NOLOCK)
		  ON c.Client = tmpAss.Client		

	  INNER JOIN TimeCurrent..tblClientGroups cg  WITH(NOLOCK)
		  ON cg.Client = tmpAss.Client		
		  AND cg.GroupCode = tmpAss.GroupCode
		  AND cg.StaffingSetupType <> '1'
  		
	  INNER JOIN dbo.tblPeriodEndDates AS ped  WITH(NOLOCK)
		  ON ped.Client = tmpAss.Client 
		  AND ped.GroupCode = tmpAss.GroupCode 
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, ae_request.PayrollPeriodEndDate) AND ae_request.PayrollPeriodEndDate
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpAss.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                                                                           ELSE DATEADD(dd, -21, tmpAss.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                            END)) AND tmpAss.ae_Request_PayrollPeriodEndDate
		  AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, TimeCurrent.dbo.fn_GetNextDaysDate(tmpAss.ae_PayrollPeriodEndDate, 1)) AND TimeCurrent.dbo.fn_GetNextDaysDate(tmpAss.ae_PayrollPeriodEndDate, 1)          
  		  
	  INNER JOIN TimeHistory..tblTimeHistDetail AS thd  WITH(NOLOCK)
		  ON thd.Client = tmpAss.Client
		  AND thd.GroupCode = tmpAss.GroupCode
		  AND thd.SSN = tmpAss.SSN
		  AND thd.DeptNo = tmpAss.DeptNo
		  AND thd.PayrollPeriodEndDate = ped.PayrollPeriodEndDate
		  AND thd.AprvlStatus = ''
  		
	  INNER JOIN TimeCurrent..tblEmplNames AS en  WITH(NOLOCK)
		  ON tmpAss.Client = en.Client 
		  AND tmpAss.GroupCode = en.GroupCode 
		  AND tmpAss.SSN = en.SSN 
  				  
	  INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK)
		  ON thd.Client = gd.Client 
		  AND thd.GroupCode = gd.GroupCode 
		  AND thd.DeptNo = gd.DeptNo 		

    WHERE --aes.GUID = @ApprovalGuid
    -- If it's a request, or an escalation then only return "like" requests
    -- If it's a manual request, then return everything
    EXISTS( SELECT 1 FROM TimeCurrent..tblApprovalEmail_Schedule aes2 WITH(NOLOCK)
                WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
                AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
                           WHEN aes2.RequestType IN (3) THEN 3
                           ELSE 4 END =  CASE WHEN tmpAss.RequestType IN (1,2) THEN 1 
                                           WHEN tmpAss.RequestType IN (3) THEN 3
                                           ELSE 4 END) OR tmpAss.RequestType NOT IN (1,2,3))
              )  
    AND tmpAss.ae_Request_PayrollPeriodEndDate >= DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpAss.ae_Request_PayrollPeriodEndDate) 
		                                                                                                                                                    ELSE DATEADD(dd, -21, tmpAss.ae_Request_PayrollPeriodEndDate) 
									                                                                                       END)
	  AND tmpAss.OpenDepts = '0'
 	  AND thd.Hours <> 0
	  --OPTION (FORCE ORDER)
END

-------------------------------------------------------------------------------
-- Approval By Assignment (clock - can't happen with PCT) with Open Departments
-------------------------------------------------------------------------------
IF (@AssRowsAffected > 0)
BEGIN
  INSERT INTO #tmpNew /*Query3*/
  SELECT DISTINCT thd.RecordID
	      , @ApprovalGuid AS ApprovalGUID
			  , tmpAss.Brand
	      , tmpAss.BrandId as BrandId
	      , cg.GroupName AS SiteName
	      , ISNULL(gd.DeptName, '') as DeptName
	      , ISNULL(tmpAss.TimeEntryFreqID, 2) AS TimeEntryFreqID
	      , en.RecordID AS EmployeeId
	      , en.LastName + ', ' + en.FirstName AS EmployeeName
	      , thd.Client
	      , thd.GroupCode
	      , thd.SSN
	      , tmpAss.SiteNo
	      , thd.DeptNo
	      , thd.TransDate
	      , thd.PayrollPeriodEndDate
	      , thd.MasterPayrollDate
	      , dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InTime
	      , dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutTime
	      , thd.Hours
	      , thd.Dollars
	      , thd.ClockAdjustmentNo
	      , thd.RegHours
	      , thd.OT_Hours
	      , thd.DT_Hours
	      , 0 as UseProjects
	      , 0 as RequireProjects
	      , CASE ISNULL(tmpAss.TimeEntryFreqID, 2)
		      WHEN 5 THEN DATEADD(dd, -(DAY(thd.TransDate)-1), thd.TransDate)
		      ELSE thd.PayrollPeriodEndDate 
	        END AS ParentPayrollDate
	      , ISNULL(cgs.DisputeMode, 0) as DisputeMode
		    , '' as Comments
		    , thd.PayRate AS PayRate
		    , c.RecordID
			, tmpAss.AssignmentNo
		    , '3'
			, 0
			, NULL
			, cg.ApprovalModeBool
			, 0
  FROM     
    #tmpAssignments as tmpAss
    
	  INNER JOIN TimeCurrent..tblClients c WITH(NOLOCK)
		  ON c.Client = tmpAss.Client		

	  INNER JOIN TimeCurrent..tblClientGroups cg  WITH(NOLOCK)
		  ON cg.Client = tmpAss.Client		
		  AND cg.GroupCode = tmpAss.GroupCode
		  AND cg.StaffingSetupType <> '1'
  		  
	  INNER JOIN dbo.tblPeriodEndDates AS ped  WITH(NOLOCK)
		  ON ped.Client = tmpAss.Client 
		  AND ped.GroupCode = tmpAss.GroupCode 
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, ae_request.PayrollPeriodEndDate) AND ae_request.PayrollPeriodEndDate 
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpAss.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                                                                           ELSE DATEADD(dd, -21, tmpAss.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                            END)) AND tmpAss.ae_Request_PayrollPeriodEndDate
      AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, TimeCurrent.dbo.fn_GetNextDaysDate(tmpAss.ae_PayrollPeriodEndDate, 1)) AND TimeCurrent.dbo.fn_GetNextDaysDate(tmpAss.ae_PayrollPeriodEndDate, 1)          		  
  		  
	  INNER JOIN TimeHistory..tblTimeHistDetail AS thd  WITH(NOLOCK)
		  ON thd.Client = tmpAss.Client
		  AND thd.GroupCode = tmpAss.GroupCode
		  AND thd.SSN = tmpAss.SSN
		  --AND thd.DeptNo = ea.DeptNo  -- to handle Open Departments
		  AND thd.PayrollPeriodEndDate = ped.PayrollPeriodEndDate
		  AND thd.AprvlStatus = ''
  		
	  INNER JOIN TimeCurrent..tblEmplNames AS en  WITH(NOLOCK)
		  ON tmpAss.Client = en.Client 
		  AND tmpAss.GroupCode = en.GroupCode 
		  AND tmpAss.SSN = en.SSN 
  				  
	  INNER JOIN TimeCurrent..tblGroupDepts AS gd  WITH(NOLOCK)
		  ON thd.Client = gd.Client 
		  AND thd.GroupCode = gd.GroupCode 
		  AND thd.DeptNo = gd.DeptNo 

	  LEFT JOIN TimeCurrent..tblCustomGroupSettings cgs WITH(NOLOCK)
		  ON c.RecordId = cgs.ClientId
		  AND cgs.GroupCode = thd.GroupCode
    
    WHERE --aes.GUID = @ApprovalGuid
    -- If it's a request, or an escalation then only return "like" requests
    -- If it's a manual request, then return everything
    EXISTS( SELECT 1 FROM TimeCurrent..tblApprovalEmail_Schedule aes2 WITH(NOLOCK)
                WHERE aes2.ApprovalEmailID = tmpAss.ae_RecordID
                AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
                           WHEN aes2.RequestType IN (3) THEN 3
                           ELSE 4 END =  CASE WHEN tmpAss.RequestType IN (1,2) THEN 1 
                                           WHEN tmpAss.RequestType IN (3) THEN 3
                                           ELSE 4 END) OR tmpAss.RequestType NOT IN (1,2,3))
              )  
    AND tmpAss.ae_Request_PayrollPeriodEndDate >= DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpAss.ae_Request_PayrollPeriodEndDate) 
		                                                                                                                                                    ELSE DATEADD(dd, -21, tmpAss.ae_Request_PayrollPeriodEndDate) 
									                                                                                       END)    
	  AND tmpAss.OpenDepts = '1'
	  AND thd.Hours <> 0	        
    OPTION (FORCE ORDER)
END  
--------------------
-- APPROVAL BY DEPT
--------------------
IF (@DeptRowsAffected > 0)
BEGIN
  INSERT INTO #tmpNew /*Query4*/
  SELECT DISTINCT thd.RecordID
	      , @ApprovalGuid AS ApprovalGUID
		    , '' AS Brand
	      , tmpDepts.BrandId as BrandId
	      , cg.GroupName AS SiteName
	      , ISNULL(tmpDepts.DeptName, '') as DeptName
	      , 2 AS TimeEntryFreqID
	      , en.RecordID AS EmployeeId
	      , en.LastName + ', ' + en.FirstName AS EmployeeName
	      , thd.Client
	      , thd.GroupCode
	      , thd.SSN
	      , thd.SiteNo
	      , thd.DeptNo
	      , thd.TransDate
	      , thd.PayrollPeriodEndDate
	      , thd.MasterPayrollDate
	      , dbo.PunchDateTime2(thd.TransDate, thd.InDay, thd.InTime) AS InTime
	      , dbo.PunchDateTime2(thd.TransDate, thd.OutDay, thd.OutTime) AS OutTime
	      , thd.Hours
	      , thd.Dollars
	      , thd.ClockAdjustmentNo
	      , thd.RegHours
	      , thd.OT_Hours
	      , thd.DT_Hours
	      , 0 as UseProjects
	      , 0 as RequireProjects
	      , thd.PayrollPeriodEndDate AS ParentPayrollDate
	      , ISNULL(cgs.DisputeMode, 0) as DisputeMode
		    , '' as Comments
		    , thd.PayRate AS PayRate
		    , c.RecordID
			, '' AS AssignmentNo
		    , '4'		     
			, 0
			, NULL
			, cg.ApprovalModeBool
			, 0
  FROM     
    #tmpDepts AS tmpDepts

    INNER JOIN TimeCurrent..tblClients c WITH(NOLOCK)
		  ON c.Client = tmpDepts.Client
  				
    INNER JOIN TimeCurrent..tblClientGroups cg WITH(NOLOCK)
      ON cg.Client = tmpDepts.Client
      AND cg.GroupCode = tmpDepts.GroupCode    
      AND cg.StaffingSetupType <> '1'
      
	  INNER JOIN dbo.tblPeriodEndDates AS ped  WITH(NOLOCK)
		  ON ped.Client = tmpDepts.Client 
		  AND ped.GroupCode = tmpDepts.GroupCode 
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, ae_request.PayrollPeriodEndDate) AND ae_request.PayrollPeriodEndDate 
		  AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, TimeCurrent.dbo.fn_GetNextDaysDate(tmpDepts.ae_PayrollPeriodEndDate, 1)) AND TimeCurrent.dbo.fn_GetNextDaysDate(tmpDepts.ae_PayrollPeriodEndDate, 1)          
		  --AND ped.PayrollPeriodEndDate BETWEEN DATEADD(dd, -6, DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpDepts.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                                                                          ELSE DATEADD(dd, -21, tmpDepts.ae_Request_PayrollPeriodEndDate) 
		  --                                                                                            END)) AND tmpDepts.ae_Request_PayrollPeriodEndDate	 
  		                                                                                            	                                                                                            				  
	  INNER JOIN TimeHistory..tblTimeHistDetail AS thd  WITH(NOLOCK)
		  ON thd.Client = tmpDepts.Client
		  AND thd.GroupCode = tmpDepts.GroupCode
		  --AND thd.SSN = hen.SSN
		  AND thd.DeptNo = tmpDepts.DeptNo  -- to handle Open Departments
		  AND thd.PayrollPeriodEndDate = ped.PayrollPeriodEndDate
		  AND thd.AprvlStatus = ''
  		
	  INNER JOIN TimeCurrent..tblEmplNames AS en  WITH(NOLOCK)
		  ON thd.Client = en.Client 
		  AND thd.GroupCode = en.GroupCode 
		  AND thd.SSN = en.SSN 		 

	  LEFT JOIN TimeCurrent..tblCustomGroupSettings cgs WITH(NOLOCK)
		  ON c.RecordId = cgs.ClientId
		  AND cgs.GroupCode = thd.GroupCode
    WHERE EXISTS( SELECT 1 FROM TimeCurrent..tblApprovalEmail_Schedule aes2 WITH(NOLOCK)
                WHERE aes2.ApprovalEmailID = tmpDepts.ae_RecordID
                AND ((CASE WHEN aes2.RequestType IN (1,2) THEN 1 
                           WHEN aes2.RequestType IN (3) THEN 3
                           ELSE 4 END =  CASE WHEN tmpDepts.RequestType IN (1,2) THEN 1 
                                           WHEN tmpDepts.RequestType IN (3) THEN 3
                                           ELSE 4 END) OR tmpDepts.RequestType NOT IN (1,2,3))
              )  
    AND tmpDepts.ae_Request_PayrollPeriodEndDate >= DATEADD(ww, -1 * ISNULL(c.AdditionalApprovalWeeks, 0), CASE WHEN ISNULL(cg.LateTimeEntryWeeks, 0) > 4 THEN DATEADD(dd, cg.LateTimeEntryWeeks * -7, tmpDepts.ae_Request_PayrollPeriodEndDate) 
		                                                                                                                                                    ELSE DATEADD(dd, -21, tmpDepts.ae_Request_PayrollPeriodEndDate) 
									                                                                                       END)  				
	  AND thd.Hours <> 0
    OPTION (FORCE ORDER)
END
   
IF (EXISTS(SELECT 1 FROM #tmpNew))
BEGIN

  -- When Harmony can do approval only, need to fix option 2 coming from tblClientGroups
  /*
  Harmony
  -------
  0 = Approve/Dispute
  1 = Reject Only
  2 = Approve/Reject/Dispute

  TMC
  ---
  0 = No Approval
  1 = Approve/Dispute
  2 = Approve Only
  3 = Approve/Dispute/Reject
  4 = Approve/Reject
  */
  UPDATE t
  SET DisputeMode = CASE WHEN t.ApprovalModeBool = '3' THEN 2 WHEN t.ApprovalModeBool = '4' THEN 1 ELSE 0 END
  FROM #tmpNew t

  UPDATE t
  SET DisputeMode = ISNULL(cgs.DisputeMode, 0)
  FROM #tmpNew t
  INNER JOIN TimeCurrent..tblCustomGroupSettings cgs
	ON cgs.ClientId = t.ClientRecordId 
	AND cgs.GroupCode = t.GroupCode
	
	-- Weekly
  UPDATE t
  SET UseProjects = ISNULL(sa.UseProjects, 0),
      RequireProjects = ISNULL(sa.RequireProjects, 0),
      Comments = sa.Comments,
      SpreadsheetAssignmentID = sa.RecordId
  FROM #tmpNew t	
  INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Assignments sa WITH(NOLOCK)
	ON  sa.Client = t.Client
	AND sa.GroupCode = t.GroupCode
	AND sa.SSN = t.SSN
	AND sa.SiteNo = t.SiteNo
	AND sa.DeptNo = t.DeptNo	
	INNER JOIN TimeHistory..tblWTE_Timesheets AS ts WITH(NOLOCK)
	ON ts.RecordId = sa.TimesheetId	
	AND ts.TimesheetEndDate = t.PayrollPeriodEndDate
	WHERE t.TimeEntryFreqID = 2

  -- Monthly	
	IF EXISTS(SELECT 1 FROM #tmpNew WHERE TimeEntryFreqID = 5)
	BEGIN
	  UPDATE t
	  SET UseProjects = ISNULL(sa.UseProjects, 0),
		  RequireProjects = ISNULL(sa.RequireProjects, 0),
		  Comments = sa.Comments,
		  SpreadsheetAssignmentID = sa.RecordId
	  FROM #tmpNew t	
	  INNER JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Assignments sa WITH(NOLOCK)
		ON  sa.Client = t.Client
		AND sa.GroupCode = t.GroupCode
		AND sa.SSN = t.SSN
		AND sa.SiteNo = t.SiteNo
		AND sa.DeptNo = t.DeptNo	
		INNER JOIN TimeHistory..tblWTE_Timesheets AS ts WITH(NOLOCK)
		ON ts.RecordId = sa.TimesheetId	
		CROSS APPLY TimeCurrent.dbo.fn_GetTimesheetAssignmentEndDates(sa.TimeSheetID, sa.RecordID) mthWeeks	
		WHERE mthWeeks.PPED = t.PayrollPeriodEndDate	
		AND t.TransDate BETWEEN  DATEADD(dd, -(DAY(ts.TimesheetEndDate)-1), ts.TimesheetEndDate) AND ts.TimesheetEndDate
		AND t.TimeEntryFreqID = 5
	END

	IF EXISTS(SELECT 1 FROM #tmpNew WHERE DisputeMode IN (1, 2))
	BEGIN
		UPDATE tn
		SET PayRecordsSent = esd.PayRecordsSent
		FROM #tmpNew tn
		INNER JOIN TimeHistory.dbo.tblEmplSites_Depts esd
		ON esd.Client = tn.Client
		AND esd.GroupCode = tn.GroupCode
		AND esd.SSN = tn.SSN
		AND esd.SiteNo = tn.SiteNo
		AND esd.DeptNo = tn.DeptNo
		AND esd.PayrollPeriodEndDate = tn.PayrollPeriodEndDate
		WHERE tn.DisputeMode IN (1, 2)
	END

	--Update the HasSnapshots flag
	UPDATE t
	SET HasSnapshots = 1
	FROM
		#tmpNew t
	WHERE
		EXISTS (
			SELECT *
			FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
			WHERE
				cpa.SpreadsheetAssignmentId = t.SpreadsheetAssignmentID
		);

  SELECT  t.*
	        , CASE WHEN t.ClockAdjustmentNo IN ('1', '8') THEN '' 
			           ELSE IsNULL(adj.AdjustmentDescription, adj.AdjustmentName) END AS AdjustmentName 
	        , CASE t.TimeEntryFreqId WHEN 5 THEN  DATEADD(MM, DATEDIFF(MM, -1, t.TransDate), 0) - 1 ELSE t.PayrollPeriodEndDate END AS TimesheetEndDate 
	        , WhereDidItComeFrom = 'New'
  FROM #tmpNew t
  LEFT JOIN TimeCurrent..tblAdjCodes adj
	ON adj.Client = t.Client
	AND adj.GroupCode = t.GroupCode
	AND adj.ClockAdjustmentNo = CASE WHEN t.ClockAdjustmentNo IN ('', ' ', '8') THEN '1' ELSE t.ClockAdjustmentNo END
	CROSS APPLY TimeHistory.dbo.fn_GetApprovalBillableFlags(t.Client, t.GroupCode, t.SiteNo, @MethodID, adj.Worked, adj.Billable, adj.Payable, adj.AdjustmentType) flg --is this used?
	ORDER BY t.EmployeeName, t.TransDate
END
ELSE
BEGIN

	CREATE TABLE #tmpTxns  
	(  
			ENRecordID        INT,
			SSN               INT,
			LastName          VARCHAR(20),
			FirstName         VARCHAR(20),
			THDRecordID       BIGINT,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
			DeptNo            INT,
			DeptName          VARCHAR(200),
			SiteNo            INT,
			SiteName          VARCHAR(200),
			TransDate         DATETIME,
			InDay             SMALLINT,
			OutDay            SMALLINT,
			Dollars           NUMERIC(9, 2),
			AdditionalDollars NUMERIC(9, 2),
			AdjustmentName    VARCHAR(100),
			[Hours]           NUMERIC(7, 2),
			RegHours          NUMERIC(7, 2),
			OT_Hours          NUMERIC(7, 2),
			DT_Hours          NUMERIC(7, 2),
			InTime            DATETIME,
			OutTime           DATETIME,
			ProjectHours      NUMERIC(7, 2),
			WTE_TimeEntry     VARCHAR(10),
			Client            VARCHAR(4),
			GroupCode         INT,
			TimeEntryFreqID   INT,
			Brand             VARCHAR(20), 
			BrandID           INT,
			ClockAdjustmentNo VARCHAR(3),  --< Srinsoft 09/09/2015 Changed ClockAdjustmentNo VARCHAR(1) to VARCHAR(3) for #tmpTxns >-- 
			PayrollPeriodEndDate DATETIME,
			UseProjects       BIT,
			RequireProjects   BIT,
			ParentPayrollDate DATETIME,
			DisputeMode       INT,
			Comments          VARCHAR(MAX),
			PayRate           NUMERIC(7, 2), 
			AssignmentNo	VARCHAR(50),
			SpreadsheetAssignmentID INT,
			HasSnapshots      BIT DEFAULT(0)
	)  

  IF (@AE_RecordID IS NULL)
  BEGIN
	  SELECT @XMLStream = XMLStream
    FROM Websession..tblSessionData_1
    WHERE GUID = @ApprovalGuid
    
    IF (@XMLStream IS NULL)
    BEGIN
      SELECT @XMLStream = XMLStream
      FROM Websession..tblSessionData_2
      WHERE GUID = @ApprovalGuid
    END

    SET @StartPos = CHARINDEX('TH_CLIENT', @XMLStream)
    SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
    SET @Client = SUBSTRING(@XMLStream, @StartPos + 19, @EndPos - (@StartPos + 19))
    PRINT @Client

    SET @StartPos = CHARINDEX('TH_GROUP', @XMLStream)
  --  SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
    SET @EndPos = CHARINDEX('</number>', @XMLStream, @StartPos)
    IF @EndPos = 0
    BEGIN
		  SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
    END

    DECLARE @strGroupCode NUMERIC(8,2)
    
    SET @strGroupCode = SUBSTRING(@XMLStream, @StartPos + 18, @EndPos - (@StartPos + 18))
    PRINT @strGroupCode
    SET @GroupCode = CAST(@strGroupCode AS INT)
    PRINT @GroupCode
    
    
    SET @StartPos = CHARINDEX('TimeEntryStaffingId', @XMLStream)
    SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
    SET @TimeEntryStaffingID = SUBSTRING(@XMLStream, @StartPos + 29, @EndPos - (@StartPos + 29))
    PRINT @TimeEntryStaffingID

    SET @StartPos = CHARINDEX('TH_Date', @XMLStream)
    SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
    SET @PPED = SUBSTRING(@XMLStream, @StartPos + 17, @EndPos - (@StartPos + 17))
    PRINT @PPED

    SET @StartPos = CHARINDEX('UserId', @XMLStream)
    SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
    SET @UserId = SUBSTRING(@XMLStream, @StartPos + 16, @EndPos - (@StartPos + 16))
    PRINT @UserId

    SET @StartPos = CHARINDEX('Escalation', @XMLStream)
    IF (@StartPos > 0)
    BEGIN
      SET @EndPos = CHARINDEX('</string>', @XMLStream, @StartPos)
      SET @Escalation = SUBSTRING(@XMLStream, @StartPos + 20, @EndPos - (@StartPos + 20))
    END
    ELSE
    BEGIN
      SET @Escalation = '0'
    END
   
    
    DECLARE @LateWeeks int, @AdditionalWeeks int, @BeginWeek datetime

    SELECT @LateWeeks = cg.LateTimeEntryWeeks, @AdditionalWeeks = c.AdditionalApprovalWeeks
    FROM TimeCurrent..tblClientGroups cg WITH(NOLOCK)
           JOIN TimeCurrent..tblClients c
                  ON cg.Client = c.Client
    WHERE cg.Client = @Client
    AND cg.GroupCode = @GroupCode
    
    IF ISNULL(@LateWeeks,0) > 4
    BEGIN
           SET @BeginWeek = DATEADD(dd,@LateWeeks * -7,@PPED) 
    END
    ELSE
    BEGIN
           -- Go back 3 weeks from the current week
           SET @BeginWeek = DATEADD(dd,-21,@PPED)
    END

    SET @BeginWeek = DATEADD(ww, -1 * ISNULL(@additionalWeeks, 0), @BeginWeek)
    
    --PRINT 'Begin Week: ' + CAST(@BeginWeek AS VARCHAR)
    
    DECLARE ppedCursor CURSOR FOR
    SELECT PayrollPeriodEndDate
    FROM TimeHistory..tblPeriodEndDates
    WHERE Client = @Client
    AND GroupCode = @GroupCode
    AND PayrollPeriodEndDate BETWEEN @BeginWeek AND @PPED
    AND Client <> 'RDRM'
    ORDER BY PayrollPeriodEndDate DESC
         
    OPEN ppedCursor

    FETCH NEXT FROM ppedCursor
    INTO @PPEDCursor

    WHILE @@FETCH_STATUS = 0
    BEGIN	
      --PRINT @PPEDCursor
      INSERT INTO #tmpTxns(ENRecordID, SSN, LastName, FirstName, THDRecordID, DeptNo, DeptName, SiteNo, SiteName,
                            TransDate, InDay, OutDay, Dollars, AdditionalDollars, AdjustmentName, [Hours], RegHours, OT_Hours, DT_Hours,
                            InTime, OutTime, ProjectHours, WTE_TimeEntry, Client, GroupCode, TimeEntryFreqID, Brand, BrandID, ClockAdjustmentNo, PayrollPeriodEndDate, PayRate)    
      EXEC TimeHistory..usp_Web1_GetUnapprovedHours_Daily_Details @TimeEntryStaffingId,  
                                                                  @PPEDCursor,  
                                                                  @UserId,  
                                                                  @Escalation
	    FETCH NEXT FROM ppedCursor
	    INTO @PPEDCursor
    END
    CLOSE ppedCursor
    DEALLOCATE ppedCursor	  

    UPDATE t
    SET DisputeMode = ISNULL(cgs.DisputeMode, 0)
    FROM #tmpTxns t
    INNER JOIN TimeCurrent..tblClients c
    ON c.Client = t.Client
    LEFT JOIN TimeCurrent..tblCustomGroupSettings cgs
	  ON cgs.ClientId = c.RecordId 
	  AND cgs.GroupCode = t.GroupCode
  	
    UPDATE t
    SET UseProjects = ISNULL(sa.UseProjects, 0),
        RequireProjects = ISNULL(sa.RequireProjects, 0),
        Comments = sa.Comments,
		SpreadsheetAssignmentID = sa.RecordId
    FROM #tmpTxns t	
    LEFT JOIN TimeHistory..tblWTE_Spreadsheet_Assignments sa
	  ON t.Client = sa.Client
	  AND t.GroupCode = sa.GroupCode
	  AND t.SSN = sa.SSN
	  AND t.SiteNo = sa.SiteNo
	  AND t.DeptNo = sa.DeptNo
	  INNER JOIN TimeHistory.dbo.tblWTE_Timesheets eow
	  ON eow.RecordId = sa.TimesheetId
	  AND eow.TimesheetEndDate = t.PayrollPeriodEndDate 
  END
  
  --Update the HasSnapshots flag
  UPDATE t
  SET HasSnapshots = 1
  FROM
	#tmpTxns t
  WHERE
	EXISTS (
		SELECT *
		FROM TimeHistory..tblWTE_Spreadsheet_ClosedPeriodAdjustment cpa WITH(NOLOCK)
		WHERE
			cpa.SpreadsheetAssignmentId = t.SpreadsheetAssignmentID
	);

  SELECT t.THDRecordID AS RecordID
      , @ApprovalGuid AS ApprovalGUID
	    , t.Brand
      , t.BrandId
      , t.SiteName
      , ISNULL(t.DeptName, '') as DeptName
      , ISNULL(t.TimeEntryFreqID, 2) AS TimeEntryFreqID 
      , t.ENRecordID AS EmployeeId
      , t.LastName + ', ' + t.FirstName AS EmployeeName
      , t.Client
      , t.GroupCode
      , t.SSN
      , t.SiteNo
      , t.DeptNo
      , t.TransDate
      , t.PayrollPeriodEndDate
      , t.PayrollPeriodEndDate AS MasterPayrollDate
      , dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime) AS InTime
      , dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime) AS OutTime
      , t.Hours
      , 0 AS Dollars
      , t.ClockAdjustmentNo 
      , t.RegHours
      , t.OT_Hours
      , t.DT_Hours
      , CAST(ISNULL(t.UseProjects, 0) AS BIT) as UseProjects
      , CAST(ISNULL(t.RequireProjects, 0) AS BIT) as RequireProjects
      , CASE ISNULL(t.TimeEntryFreqID, 2)
	        WHEN 5 THEN  DATEADD(dd, -(DAY(t.TransDate) -1), t.TransDate)
	        ELSE t.PayrollPeriodEndDate 
        END AS ParentPayrollDate
      , ISNULL(t.DisputeMode, 0) as DisputeMode
	    , IsNULL(t.Comments, '') as Comments
	    , t.PayRate
	    , CASE 
			WHEN t.ClockAdjustmentNo IN ('1', '8') THEN '' 
			ELSE IsNULL(adj.AdjustmentDescription, t.AdjustmentName)
			END AS AdjustmentName 
	    , CASE t.TimeEntryFreqId WHEN 5 THEN  DATEADD(MM, DATEDIFF(MM, -1, t.TransDate), 0) - 1 ELSE t.PayrollPeriodEndDate END AS TimesheetEndDate 
	    , WhereDidItComeFrom = 'Old'
		, t.SpreadsheetAssignmentID
		, t.HasSnapshots
  FROM #tmpTxns t
  LEFT JOIN TimeCurrent..tblAdjCodes adj
	ON t.Client = adj.Client
	AND t.GroupCode = adj.GroupCode
	AND t.ClockAdjustmentNo = adj.ClockAdjustmentNo
  ORDER BY t.THDRecordID DESC 

	IF OBJECT_ID('tempdb..#tmpTxns') IS NOT NULL
		DROP TABLE #tmpTxns
END

DROP TABLE #tmpNew
DROP TABLE #tmpAssignments
DROP TABLE #tmpDepts
