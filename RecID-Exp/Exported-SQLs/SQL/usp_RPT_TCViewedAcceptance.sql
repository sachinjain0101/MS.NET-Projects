USE [TimeHistory]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF

GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_RPT_TCViewedAcceptance]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_RPT_TCViewedAcceptance] AS' 
END
GO

/*
select * from timecurrent..tbluser where firstname = 'Dakshesh'

---------- AreaBranch = 1 ----------
EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'RAND', @Group = 4070, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '10/1/2015', 
@Sites = NULL, @AreaBranchSelection = 1, @UserID = NULL, @ClusterID = 4, @Ref1 = 'Employee'

EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'TRCS', @Group = 4070, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '7/1/2015', 
@Sites = NULL, @AreaBranchSelection = 1, @UserID = NULL, @ClusterID = 4, @Ref1 = 'Approver'

---------- AreaBranch = 2 ----------
EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'RAND', @Group = NULL, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '7/1/2015', 
@Sites = NULL, @AreaBranchSelection = 2, @UserID = 547354, @ClusterID = 4, @Ref1 = 'Employee'

EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'RAND', @Group = NULL, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '10/1/2015', 
@Sites = NULL, @AreaBranchSelection = 2, @UserID = 483148, @ClusterID = 4, @Ref1 = 'Employee'

EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'TRCS', @Group = NULL, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '7/1/2015', 
@Sites = NULL, @AreaBranchSelection = 2, @UserID = 547354, @ClusterID = 4, @Ref1 = 'Approver'

---------- AreaBranch = 3 ----------
EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'RAND', @Group = 4070, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '7/1/2015', 
@Sites = NULL, @AreaBranchSelection = 3, @UserID = NULL, @ClusterID = 4, @Ref1 = 'Employee'

EXECUTE Timehistory.dbo.usp_RPT_TCViewedAcceptance @Client = 'RAND', @Group = 4070, @Date = NULL, @DateFrom = '1/1/2015', @DateTo = '7/1/2015', 
@Sites = NULL, @AreaBranchSelection = 3, @UserID = NULL, @ClusterID = 4, @Ref1 = 'Approver'

SELECT TOP 100 AllowAprvl,ClientLevelUser,RoleId,TandCAccepted_Approver,* FROM TimeCurrent..tblUser WHERE LastName='Grier' AND FirstName='Fran' AND Client='TRCS'
*/
 
ALTER PROCEDURE usp_RPT_TCViewedAcceptance(
	  @Client VARCHAR(4)
	, @Group INT
	, @Date DATETIME
	, @DateFrom DATETIME
	, @DateTo DATETIME
	, @Sites VARCHAR(1000)
	, @AreaBranchSelection CHAR(1)
	, @UserID INT
	, @ClusterID INT
	, @Ref1 VARCHAR(20)
	) 
AS
SET NOCOUNT ON

DECLARE @Start DATETIME ,
    @End DATETIME;

IF @DateFrom IS NOT NULL -- Date range is passed
    BEGIN
        SELECT  @Start = @DateFrom ,
                @End = @DateTo;
	 
    END;
IF ISNULL(@Date, '') <> '' -- Week ending is passed
    BEGIN
        SELECT  @Start = DATEADD(DAY, -6, @Date) ,
                @End = DATEADD(SECOND, -1, DATEADD(DAY, 1, @Date)); 
    END;


IF OBJECT_ID('tempdb..#tmpTasks') IS NOT NULL
    DROP TABLE #tmpTasks;

IF @Ref1 = 'Employee'
    BEGIN
        IF OBJECT_ID('tempdb..#MaxEmployee') IS NOT NULL
            DROP TABLE #MaxEmployee;

        IF OBJECT_ID('tempdb..#SavedEmployee') IS NOT NULL
            DROP TABLE #SavedEmployee;

        CREATE TABLE #MaxEmployee
            (
              DataSource VARCHAR(50) ,
              Client VARCHAR(4) ,
              GroupCode INT ,
              EmployeeID INT ,
              SSN INT ,
              LastName VARCHAR(50) ,
              FirstName VARCHAR(50) ,
              ViewedDtm DATETIME ,
              AcceptedDtm DATETIME
            );


        INSERT  INTO #MaxEmployee
                ( DataSource ,
                  Client ,
                  GroupCode ,
                  EmployeeID ,
                  SSN ,
                  LastName ,
                  FirstName ,
                  ViewedDtm ,
                  AcceptedDtm
                )
                SELECT  'Employee - tblEmplNames' ,
                        Client ,
                        GroupCode ,
                        RecordID ,
                        SSN ,
                        LastName ,
                        FirstName ,
                        TandCAccepted ,
                        TandCAccepted
                FROM    TimeCurrent.dbo.tblEmplNames (NOLOCK)
                WHERE   Client = @Client 
				AND Password IS NOT NULL;
               
        UPDATE  #MaxEmployee
        SET     DataSource = 'Employee - tblTermsCondAcceptor' ,
                ViewedDtm = tc.ViewedDtm ,
                AcceptedDtm = tc.AcceptedDtm
        FROM    ( SELECT    tc.EmployeeId ,
                            ViewedDtm = MAX(ViewedDtm) ,
                            AcceptedDtm = MAX(AcceptedDtm)
                  FROM      TimeCurrent.dbo.tblTermsCondAcceptor tc ( NOLOCK )
                  GROUP BY  tc.EmployeeId
                ) tc
                INNER JOIN #MaxEmployee e ( NOLOCK ) ON tc.EmployeeId = e.EmployeeID
        WHERE   e.AcceptedDtm IS NULL;

	----SELECT * FROM #MaxEmployee

        SELECT  *
        INTO    #SavedEmployee
        FROM    #MaxEmployee e
        WHERE   ( ( e.ViewedDtm BETWEEN @Start AND @End )
                  OR ( e.AcceptedDtm BETWEEN @Start AND @End )
                ); 

    --SELECT  * FROM    #SavedEmployee;	

    END;

IF @Ref1 = 'Approver'
    BEGIN

	IF OBJECT_ID('tempdb..#MaxUser') IS NOT NULL
    DROP TABLE #MaxUser;

	IF OBJECT_ID('tempdb..#SavedUser') IS NOT NULL
		DROP TABLE #SavedUser;

	CREATE TABLE #MaxUser
		(
		  DataSource VARCHAR(50) ,
		  UserID INT ,
		  LastName VARCHAR(50) ,
		  FirstName VARCHAR(50) ,
		  ViewedDtm DATETIME ,
		  AcceptedDtm DATETIME
		);
	CREATE NONCLUSTERED INDEX [idx_userid] ON #MaxUser(UserID);


-- Get Users who exist tblUser
        INSERT  INTO #MaxUser
                ( DataSource ,
                  UserID ,
                  LastName ,
                  FirstName ,
                  ViewedDtm ,
                  AcceptedDtm
                )
                SELECT  'User - tblUser' ,
                        UserID ,
                        LastName ,
                        FirstName ,
                        TandCAccepted_Approver ,
                        TandCAccepted_Approver
                FROM    TimeCurrent.dbo.tblUser (NOLOCK)
                WHERE   Client = @Client
				AND Password IS NOT NULL;

--Update existing users with data from tblTermsCondAcceptor
        UPDATE  #MaxUser
        SET     DataSource = 'User - tblTermsCondAcceptor' ,
                ViewedDtm = tc.ViewedDtm ,
                AcceptedDtm = tc.AcceptedDtm
        FROM    ( SELECT    tc.UserId ,
                            ViewedDtm = MAX(ViewedDtm) ,
                            AcceptedDtm = MAX(AcceptedDtm)
                  FROM      TimeCurrent.dbo.tblTermsCondAcceptor tc ( NOLOCK )
                  GROUP BY  tc.UserId
                ) tc
                INNER JOIN #MaxUser u ( NOLOCK ) ON tc.UserId = u.UserID
        WHERE   u.AcceptedDtm IS NULL;

        SELECT  *
        INTO    #SavedUser
        FROM    #MaxUser u
        WHERE   ( ( u.ViewedDtm BETWEEN @Start AND @End )
                  OR ( u.AcceptedDtm BETWEEN @Start AND @End )
                ); 

        --SELECT  * FROM    #SavedUser;	
    END;

CREATE TABLE #tmpTasks
    (
      [DataSource] [VARCHAR](50) NULL ,
      [client] [VARCHAR](4) NULL ,
      [GroupCode] [INT] NULL ,
      [SiteNo] [INT] NULL ,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 31Aug2016 >--
      [DeptNo] [INT] NULL ,  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 31Aug2016 >--
      [SSN] [INT] NULL ,
      [EmployeeID] [INT] NULL ,
      [LastName] [VARCHAR](20) NOT NULL ,
      [FirstName] [VARCHAR](20) NOT NULL ,
      [ViewedDtm] [DATETIME] NOT NULL ,
      [AcceptedDtm] [DATETIME] NULL
    );
 
IF @AreaBranchSelection = 1
    BEGIN
        IF @Ref1 = 'Employee'
            BEGIN
                SELECT DISTINCT
                        en.Client ,
                        en.GroupCode ,
                        me.EmployeeID ,
                        en.LastName ,
                        en.FirstName ,
                        me.ViewedDtm ,
                        me.AcceptedDtm
                FROM    TimeCurrent.dbo.tblEmplNames en ( NOLOCK )
                        INNER JOIN #SavedEmployee me ON me.EmployeeID = en.RecordID
                        INNER JOIN TimeCurrent.[dbo].[tblEmplSites_Depts] sd ( NOLOCK ) ON sd.Client = en.Client
                                                              AND sd.GroupCode = en.GroupCode
                                                              AND sd.SSN = en.SSN
                WHERE   en.Client = @Client
                        AND en.GroupCode = @Group
                        AND en.RecordStatus = 1
                        AND EXISTS ( SELECT ClusterID
                                     FROM   TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn(sd.GroupCode,
                                                              sd.SiteNo,
                                                              sd.DeptNo, NULL,
                                                              en.SSN, NULL,
                                                              NULL, @ClusterID) )
                ORDER BY en.Client ,
                        en.GroupCode ,
                        en.LastName ,
                        en.FirstName;
            END;

        IF @Ref1 = 'Approver'
        BEGIN

        SELECT DISTINCT
                cd.Client ,
                cd.GroupCode ,
                mu.UserID AS EmployeeID ,
                mu.LastName ,
                mu.FirstName ,
                mu.ViewedDtm ,
                mu.AcceptedDtm
        FROM    #SavedUser mu 
                INNER JOIN TimeCurrent.dbo.tblUserClusterPermission ucp ( NOLOCK ) ON ucp.UserID = mu.UserID
                INNER JOIN TimeCurrent.dbo.tblClusterDef cd ( NOLOCK ) ON cd.ClusterID = ucp.ClusterID
				INNER JOIN TimeCurrent.dbo.tblClusterName cn ( NOLOCK ) ON cn.ClusterID = ucp.ClusterID
        WHERE   cd.Client = @Client
                AND cd.GroupCode = @Group
				AND ucp.RecordStatus  ='1'
				AND cd.RecordStatus = '1'
				AND cn.RecordStatus = '1'
        ORDER BY cd.Client ,
                cd.GroupCode ,
                mu.LastName ,
                mu.FirstName;
        END;
    END;


 -- End of @AreaBranchSelection = 1

IF @AreaBranchSelection IN ( 2, 3 )
    BEGIN
        IF @Ref1 = 'Employee'
            BEGIN
                INSERT  INTO #tmpTasks
                        ( DataSource ,
                          client ,
                          GroupCode ,
                          SiteNo ,
                          DeptNo ,
                          SSN ,
                          EmployeeID ,
                          LastName ,
                          FirstName ,
                          ViewedDtm ,
                          AcceptedDtm	
                        )
                        SELECT DISTINCT
                                me.DataSource ,
                                en.Client ,
                                en.GroupCode ,
                                sd.SiteNo ,
                                sd.DeptNo ,
                                sd.SSN ,
                                me.EmployeeID ,
                                en.LastName ,
                                en.FirstName ,
                                me.ViewedDtm ,
                                me.AcceptedDtm
                        FROM    TimeCurrent.dbo.tblEmplNames en ( NOLOCK )
                                INNER JOIN #SavedEmployee me ON me.EmployeeID = en.RecordID
                                INNER JOIN TimeCurrent.[dbo].[tblEmplSites_Depts] sd ( NOLOCK ) ON sd.Client = en.Client
                                                              AND sd.GroupCode = en.GroupCode
                                                              AND sd.SSN = en.SSN
                        WHERE   en.Client = @Client
                                AND en.RecordStatus = 1;
                               	 
            END;

        IF @Ref1 = 'Approver'
            BEGIN
				INSERT  INTO #tmpTasks
                        ( DataSource ,
                          client ,
                          GroupCode ,
                          SiteNo ,
                          DeptNo ,
                          SSN ,
                          EmployeeID ,
                          LastName ,
                          FirstName ,
                          ViewedDtm ,
                          AcceptedDtm	
                        )
                SELECT DISTINCT
                        mu.DataSource ,
						cd.Client,
						cd.GroupCode,
						cd.SiteNo,
						cd.DeptNo,
						cd.ssn,
                        mu.UserID AS EmployeeID ,
                        mu.LastName ,
                        mu.FirstName ,
                        mu.ViewedDtm ,
                        mu.AcceptedDtm
                FROM    #SavedUser mu 
                INNER JOIN TimeCurrent.dbo.tblUserClusterPermission ucp ( NOLOCK ) ON ucp.UserID = mu.UserID
                INNER JOIN TimeCurrent.dbo.tblClusterDef cd ( NOLOCK ) ON cd.ClusterID = ucp.ClusterID
				INNER JOIN TimeCurrent.dbo.tblClusterName cn ( NOLOCK ) ON cn.ClusterID = ucp.ClusterID
				WHERE   cd.Client = @Client
				AND ucp.RecordStatus  ='1'
				AND cd.RecordStatus = '1'
				AND cn.RecordStatus = '1'
				ORDER BY mu.LastName ,
                        mu.FirstName
            END
    END
 -- End of initial @AreaBranchSelection in (2,3)

IF @AreaBranchSelection = 2
    BEGIN
       SELECT DISTINCT
                DataSource ,
                client ,
                EmployeeID ,
                LastName ,
                FirstName ,
                ViewedDtm ,
                AcceptedDtm
        FROM    #tmpTasks
        ORDER BY LastName ,
                FirstName;
   END

IF @AreaBranchSelection = 3
    BEGIN	
        DELETE  #tmpTasks
        WHERE   NOT EXISTS ( SELECT 1 FROM   [dbo].[tvf_GetTimeHistoryClusterDefAsFn](GroupCode, SiteNo, NULL, 0,SSN, 0, 0,@ClusterID) );
		
        SELECT DISTINCT
                DataSource ,
                client ,
                EmployeeID ,
                LastName ,
                FirstName ,
                ViewedDtm ,
                AcceptedDtm
        FROM    #tmpTasks
        ORDER BY LastName ,
                FirstName;
    END;

GO
