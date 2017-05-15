CREATE PROCEDURE  dbo.usp_RPTSavedSubmittedUnapprovedABS
  (   @DateFrom DATETIME
	  , @DateTo DATETIME
    , @Date DATETIME
    , @Client VARCHAR(4)
    , @Group INTEGER
    , @Report VARCHAR(4)
	  , @AreaBranchSelection CHAR(1) 
	  , @UserID int
    , @ClusterID INT = NULL
    )

AS 


--DECLARE   @DateFrom DATETIME =null--'2015-07-01'
--		, @DateTo DATETIME = null--'2015-07-31'
--		, @Date DATETIME ='12/25/2016'
--		, @Client VARCHAR(4) = 'MPOW'
--		, @Group INTEGER = 329
--		, @Report VARCHAR(4) = 'MB16'
--		, @AreaBranchSelection CHAR(1) ='1'
--		, @UserID int = 120088
--		, @ClusterID INT =4

SET NOCOUNT ON ;
DECLARE @tblEmplAssignments TABLE
    (
      RecordID INT
    , Client CHAR(4) COLLATE SQL_Latin1_General_CP437_CI_AS
                     NOT NULL
    , GroupCode INT NOT NULL
    , SiteNo INT NOT NULL
    , DeptNo INT NOT NULL
    , StartDate DATETIME NULL
    , EndDate DATETIME NULL
    , PPED DATETIME NULL
    , SSN INT NOT NULL
    , BranchId VARCHAR(100)
    , GroupName VARCHAR(50)
    , ApprovalMethodID INT NULL
    , State VARCHAR(100) NULL
    , source VARCHAR(100) NULL
    , Comment VARCHAR(100) NULL
    ,Saved VARCHAR(30) null
    , INDEX ix3 NONCLUSTERED ( Client, GroupCode, DeptNo, SiteNo, SSN, PPED )
    );


DECLARE @MaxPPED DATETIME
  , @minPPED DATETIME;

IF @Date IS NOT NULL
    BEGIN	
        SET @MaxPPED = @Date;
         SET @minPPED = DATEADD(DAY,-6,@Date);	
    END; 

ELSE IF @DateFrom IS NOT NULL 
	BEGIN
	   -- get theMonday of the minddate payperiod

	    SET @minPPED = DATEADD(DAY ,- 6,DATEADD(DAY,8 - DATEPART(WEEKDAY,@datefrom)  ,@DateFrom))
	    SET @MaxPPED =DATEADD(DAY,8 - DATEPART(WEEKDAY,@dateto)  ,@Dateto)
	ENd

;WITH  unapproved AS (
				    SELECT DISTINCT --en.FirstName,en.LastName,
						   A.RecordID
						 , A.Client
						 , A.GroupCode
						 , A.SiteNo
						 , A.DeptNo
						 , A.StartDate
						 , A.EndDate
						 , PED.PayrollPeriodEndDate
						 , pped = thd.PayrollPeriodEndDate
						 , A.SSN
						 , A.BranchId
						 , TCG.GroupName
						 , A.ApprovalMethodID
						 , State = convert(varchar(100),'')
						 , source = ''
						 , comment = ''
						 , Saved = THD.AprvlStatus 
				    FROM    TimeCurrent.dbo.tblEmplAssignments A 
				    INNER JOIN TimeCurrent.dbo.tblClientGroups AS TCG WITH ( NOLOCK ) ON TCG.Client = A.Client AND TCG.GroupCode = A.GroupCode				    
		          --INNER JOIN TimeCurrent..tblemplnames en ON en.Client = a.Client AND en.GroupCode = a.GroupCode AND en.SSN = a.SSN
				    INNER JOIN  timehistory.dbo.tblPeriodEndDates ped ON ped.client = A.Client AND ped.GroupCode = A.GroupCode AND PayrollPeriodEndDate  BETWEEN @minPPED AND  @MaxPPED
				    INNER JOIN TimeHistory.dbo.tblEmplSites_Depts esd ON esd.Client = A.Client AND esd.GroupCode = A.GroupCode AND esd.SiteNo = A.SiteNo AND esd.DeptNo = A.DeptNo AND esd.SSN = A.SSN AND esd.PayrollPeriodEndDate = PED.PayrollPeriodEndDate
					LEFT outer JOIN TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK ) ON THD.Client = a.Client AND a.GroupCode = THD.GroupCode AND THD.SSN = a.SSN AND a.SiteNo = THD.SiteNo AND THD.DeptNo = a.DeptNo  AND thd.PayrollPeriodEndDate = ped.PayrollPeriodEndDate
				    WHERE   A.Client = @client AND A.GroupCode >0 AND a.ssn >-1	AND A.AssignmentNo IS NOT null AND A.DeptNo > 0 AND (A.StartDate <= @MaxPPED and A.EndDate >= @minPPED)
					and esd.nohours is null 
				)


INSERT  INTO @tblEmplAssignments
        ( RecordID
        , Client
        , GroupCode
        , SiteNo
        , DeptNo
        , StartDate
        , EndDate
        , PPED
        , SSN
        , BranchId
        , GroupName
        , ApprovalMethodID
        , State
        , source
        , Comment
	   , Saved )
        SELECT DISTINCT
                a.RecordID
              , a.Client
              , a.GroupCode
              , a.SiteNo
              , a.DeptNo
              , a.StartDate
              , a.EndDate
              , a.PayrollPeriodEndDate
              , a.SSN
              , a.BranchId
              , a.GroupName
              , a.ApprovalMethodID
              , a.State
              , a.source
              , a.comment
              , a.Saved 
        FROM    unapproved a
	   WHERE ISNULL(saved,'d') IN ('','d')
      

UPDATE a SET State = 'Submitted', Source = CASE WHEN THD.UserCode IN ( 'IVR' ) THEN 'IVR'
                                      WHEN THD.UserCode IN ( '*VMS' ) THEN '*VMS'
                                      WHEN ( THD.UserCode IN ( 'WTE', 'IVS', 'SYS' ) OR THD.InSrc = 'S' ) AND ISNULL(h.Mobile, 0) = 0 AND ISNULL(TCG.StaffingSetupType, '') = '1' THEN 'WTE'
                                      WHEN ISNULL(h.Mobile, 0) = 1 THEN 'MBL'
                                      WHEN THD.UserCode IN ( 'VTC', 'VT2' ) OR THD.OutUserCode IN ( 'VTC', 'VT2' ) OR THD.InSrc IN ( 'C', 'V' ) OR THD.OutSrc IN ( 'C', 'V' ) THEN 'WTC'
                                      WHEN THD.UserCode = 'FAX' THEN 'FAX'
                                      WHEN THD.UserCode = 'EML' THEN 'GTS ' + THD.OutUserCode
                                      WHEN ( THD.UserCode NOT IN ( 'PNE', 'SYS', 'EML', '', 'FAX', 'IVR', 'VTC', 'VT2', 'WTE', '*VMS' ) AND THD.InSrc = '3' AND THD.ClockAdjustmentNo <> '' ) THEN 'MAN'
                                      WHEN ( THD.UserCode NOT IN ( 'PNE', 'SYS', 'EML', '', 'FAX', 'IVR', 'VTC', 'VT2', 'WTE', '*VMS' ) AND THD.InSrc = '3' AND THD.OutSrc = '3' AND THD.ClockAdjustmentNo = '' ) THEN 'MAN'
                                      WHEN ( THD.UserCode = '' AND THD.InSrc = '3' AND THD.ClockAdjustmentNo <> '' ) THEN 'SYS'
                                      WHEN ( THD.InSrc = '0' OR THD.OutSrc = '0' ) THEN 'Clock'
                                      ELSE 'UNK'
                                 END 
                      , Comment =  IIF(THD.UserCode = '*VMS', Timecurrent.dbo.fn_getvmsname_by_Assignment_RecordID(A.RecordID), 'PNETWTE')
from Timehistory.dbo.tblTimeHistDetail THD WITH (NOLOCK) 
LEFT outer JOIN @tblEmplAssignments A ON A.Client = THD.Client AND A.GroupCode = THD.GroupCode AND A.SiteNo = THD.SiteNo AND A.DeptNo = THD.DeptNo AND A.SSN = THD.SSN AND thd.PayrollPeriodEndDate = a.PPED
INNER JOIN TimeCurrent.dbo.tblClientGroups AS TCG WITH ( NOLOCK ) ON TCG.Client = A.Client AND TCG.GroupCode = A.GroupCode
INNER JOIN TimeHistory.dbo.tblEmplNames AS h WITH ( NOLOCK ) ON h.Client = A.Client AND h.GroupCode = A.GroupCode AND h.SSN = A.SSN AND h.PayrollPeriodEndDate = a.PPED



--saved not submitted
UPDATE A SET state = 'Saved',source= 'WTE'
               FROM     TimeHistory.dbo.tblWTE_Spreadsheet esd WITH ( NOLOCK )
               LEFT OUTER JOIN TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK ) ON THD.Client = esd.Client AND THD.GroupCode = esd.GroupCode AND THD.SiteNo = esd.SiteNo AND THD.DeptNo = esd.DeptNo AND THD.SSN = esd.SSN AND THD.PayrollPeriodEndDate = esd.PayrollPeriodEndDate
               INNER JOIN @tblEmplAssignments A ON A.Client = esd.Client AND A.GroupCode = esd.GroupCode AND A.SiteNo = esd.SiteNo AND A.DeptNo = esd.DeptNo AND A.SSN = esd.SSN AND esd.PayrollPeriodEndDate =a.PPED
               INNER JOIN TimeCurrent.dbo.tblClientGroups AS TCG WITH ( NOLOCK ) ON TCG.Client = esd.Client AND TCG.GroupCode = esd.GroupCode
               WHERE    esd.Client = @client
						AND THD.RecordID IS NULL
						AND esd.PayrollPeriodEndDate = a.PPED
						AND state = ''

UPDATE @tblEmplAssignments SET state = 'Not Entered' WHERE state = ''


--SELECT *FROM @tblEmplAssignments 
SELECT distinct
       BranchId
     , BranchDescription = GroupName
	 , state
	 , Approvaltype = IIF(ApprovalMethodID = 11
							, 'CLNT'
							, IIF(State ='Saved'
									,'Unapproved'					
									,'ELEC'
								 )
						 )
	 , PPED  
	  , TimesheetCount = COUNT(1) OVER (PARTITION BY BranchID,GroupName,IIF(ApprovalMethodID = 11
							, 'CLNT'
							, IIF(State ='Saved'
									,'Unapproved'					
									,'ELEC'
								 )
						 ),state,PPED, Source, comment )
	 
	 , Source 
	 , comment 
	 ,Eass.Saved
	 FROM @tblEmplAssignments Eass
	 INNER JOIN  timehistory.dbo.tblPeriodEndDates ped ON ped.client = eass.Client AND ped.GroupCode = Eass.GroupCode AND PayrollPeriodEndDate  BETWEEN @minPPED AND @MaxPPED
	 WHERE  ( -- only look in this group
                ( @AreaBranchSelection = 1 AND Eass.GroupCode = @Group )
			-- look in all groups for this user
             OR ( @AreaBranchSelection = 2 AND TimeHistory.dbo.fn_GetUserClusterPermission(Eass.GroupCode, NULL, NULL, NULL, NULL, NULL, NULL, @UserID) = 1 )
			-- look in all groups within this cluster
             OR ( @AreaBranchSelection = 3 AND EXISTS ( SELECT ClusterID FROM   TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn(Eass.GroupCode, NULL, NULL, NULL, NULL, NULL, NULL, @ClusterID) ) ) 
			)

