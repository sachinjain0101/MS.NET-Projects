Create PROCEDURE [dbo].[usp_RPT_EmployeeBreakExceptionDetail]
    (
      @Date DATETIME
    , @Client CHAR(4)
    , @Group INT
    , @Report CHAR(4)
    , @UserId INT
    , @DateFrom DATETIME = NULL
    , @DateTo DATETIME = NULL 
    )
AS
    SET NOCOUNT ON;
    DECLARE @TransDateStart DATETIME
      , @TransDateEnd DATETIME
      , @PPEDStart DATETIME
      , @PPEDEnd DATETIME
      , @PeopleNetEmployee VARCHAR(1) = '0'
      , @StaffingSetupType CHAR(1)
      , @BreakExceptions CHAR(1)
      , @GroupName VARCHAR(50);

    IF @DateFrom IS NULL
        BEGIN
            SELECT  @TransDateStart = DATEADD(DAY, -9, @Date)
                  , @TransDateEnd = DATEADD(DAY, 3, @Date)
                  , @PPEDStart = DATEADD(DAY, -3, @Date)
                  , @PPEDEnd = DATEADD(DAY, 3, @Date);
        END;
    ELSE
        BEGIN
            SELECT  @TransDateStart = @DateFrom
                  , @TransDateEnd = @DateTo
                  , @PPEDStart = @DateFrom
                  , @PPEDEnd = DATEADD(DAY, 6, @DateTo);
        END;

    CREATE TABLE #tempBreakExceptionSSNS ( SSN INT );

    INSERT  INTO #tempBreakExceptionSSNS
            SELECT DISTINCT
                    wsb2.SSN
            FROM    TimeHistory.dbo.tblWTE_Spreadsheet_Breaks wsb2
                    LEFT JOIN TimeHistory.dbo.tblWTE_BreakCodes bc2 ON bc2.RecordId = wsb2.BreakCode AND bc2.BreakErrorFieldName NOT IN ( 'MSR', 'WE' ) -- 'Meets state requirements','Ate while working'
																																 AND bc2.BreakType <> 'NA' --  'Ignore' 
            WHERE   wsb2.Client = @Client
                    AND wsb2.PayrollPeriodEndDate BETWEEN @PPEDStart
                                                  AND     @PPEDEnd;

    CREATE TABLE #tmpTHD
        (
          Client CHAR(4)
        , GroupCode VARCHAR(10)
        , PayrollPeriodEndDate DATE
        , SSN INT
        , SiteNo INT  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
        , DeptNo INT  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 30Aug2016 >--
        , TransDate DATE
        , OutDay TINYINT
        , InTime DATETIME
        , OutTime DATETIME
        , [Hours] NUMERIC(5, 2)
        , StaffingSetupType CHAR(1)
        , GroupName VARCHAR(50)
        , BranchID VARCHAR(32)
		,actualintime datetime
        );
    CREATE CLUSTERED INDEX cidxTTHD_CGSS
    ON #tmpTHD
    (Client,GroupCode,SiteNo,SSN);
    CREATE NONCLUSTERED INDEX ncidxTTHD_S
    ON #tmpTHD
    (StaffingSetupType);

    IF EXISTS ( SELECT  1
                FROM    TimeCurrent.dbo.tblUserClusterPermission
                WHERE   UserID = @UserId
                        AND ClusterID = 4 )
        BEGIN
            INSERT  INTO #tmpTHD
                    SELECT DISTINCT
                            THD.Client
                          , THD.GroupCode
                          , THD.PayrollPeriodEndDate
                          , THD.SSN
                          , THD.SiteNo
                          , THD.DeptNo
                          , THD.TransDate
                          , THD.OutDay
                          , TimeHistory.dbo.PunchDateTime2(thd.TransDate,thd.InDay,THD.InTime)
                          , TimeHistory.dbo.PunchDateTime2(thd.TransDate,thd.OutDay,THD.OutTime)
                          , THD.[Hours]
                          , CG.StaffingSetupType
                          , CG.GroupName
                          , CG.BranchID
						  ,THD.actualintime
                    FROM    TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK )
                            INNER JOIN TimeCurrent.dbo.tblClientGroups CG WITH ( NOLOCK ) ON CG.Client = THD.Client AND CG.GroupCode = THD.GroupCode
                    WHERE   THD.Client = @Client
                            AND THD.GroupCode IN (
													SELECT DISTINCT
															GroupCode
													FROM    TimeCurrent.dbo.tblClientGroups WITH ( NOLOCK )
													WHERE   Client = @Client 
												 )
                            AND THD.PayrollPeriodEndDate BETWEEN @PPEDStart AND  @PPEDEnd
                            AND EXISTS ( SELECT *
                                         FROM   #tempBreakExceptionSSNS T
                                         WHERE  T.SSN = THD.SSN );
        END;
    ELSE
        BEGIN
            INSERT  INTO #tmpTHD
                    SELECT DISTINCT
                            THD.Client
                          , THD.GroupCode
                          , THD.PayrollPeriodEndDate
                          , THD.SSN
                          , THD.SiteNo
                          , THD.DeptNo
                          , THD.TransDate
                          , THD.OutDay
                          , TimeHistory.dbo.PunchDateTime2(thd.TransDate,thd.InDay,THD.InTime)
                          , TimeHistory.dbo.PunchDateTime2(thd.TransDate,thd.OutDay,THD.OutTime)
                          , THD.[Hours]
                          , CG.StaffingSetupType
                          , CG.GroupName
                          , CG.BranchID
						  ,THD.actualintime
                    FROM    TimeHistory.dbo.tblTimeHistDetail THD WITH ( NOLOCK )
                            INNER JOIN TimeCurrent.dbo.tblClientGroups CG WITH ( NOLOCK ) ON CG.Client = THD.Client AND CG.GroupCode = THD.GroupCode
                    WHERE   THD.Client = @Client
                            AND THD.GroupCode IN (
													SELECT DISTINCT
															cd.GroupCode
													FROM    TimeCurrent.dbo.tblUserClusterPermission ucp WITH ( NOLOCK )
															INNER JOIN TimeCurrent.dbo.tblClusterDef cd WITH ( NOLOCK ) ON cd.ClusterID = ucp.ClusterID AND cd.RecordStatus = '1' AND cd.Type = 'G'
													WHERE   ucp.UserID = @UserId AND ucp.RecordStatus = '1'
												 )
                            AND THD.PayrollPeriodEndDate BETWEEN @PPEDStart AND  @PPEDEnd
                            AND EXISTS ( SELECT *
                                         FROM   #tempBreakExceptionSSNS T
                                         WHERE  T.SSN = THD.SSN );
        END;

    SELECT BranchId =	 IIF(thd.StaffingSetupType='1',ea1.BranchId, IIF( @Client = 'STFM', thd.BranchID, thd.GroupCode))
          , BranchName = IIF(thd.StaffingSetupType ='1', rhb.BranchName, thd.GroupName)
          , SiteName = IIF(sn.RFR_UniqueID IS NOT NULL,sn.RFR_UniqueID + ' - ' + sn.SiteName, sn.SiteName)
          , thd.SSN
          , EmployeeFirstName = en.FirstName
          , EmployeeLastName = en.LastName
          , en.FileNo
          , AssignmentNo =  IIF(thd.StaffingSetupType =  '1',ea1.AssignmentNo, ISNULL(ea2.AssignmentNo, ed.AssignmentNo))
          , EmployeeEmail = en.EmpEmail
          , EmployeePhone = en.CellPhoneNumber
          , BreakName = ISNULL(bc.BreakName, '')
          , thd.TransDate
          , thd.InTime
          , thd.OutTime
          , thd.[Hours]
          , ApproverFirstName = u.FirstName
          , ApproverLastName = u.LastName
          , ApproverEmail = u.Email
          , ApproverPhone = u.CellPhone
		  ,Agency = A.AgencyName
    FROM    #tmpTHD thd
            INNER JOIN TimeCurrent.dbo.tblEmplNames en WITH ( NOLOCK ) ON en.Client = thd.Client AND en.GroupCode = thd.GroupCode AND en.SSN = thd.SSN
            INNER JOIN TimeCurrent.dbo.tblSiteNames sn WITH ( NOLOCK ) ON sn.Client = thd.Client AND sn.GroupCode = thd.GroupCode AND sn.SiteNo = thd.SiteNo
            LEFT JOIN TimeCurrent.dbo.tblEmplNames_Depts ed WITH ( NOLOCK ) ON ed.Client = thd.Client AND ed.GroupCode = thd.GroupCode AND ed.SSN = thd.SSN AND ed.Department = thd.DeptNo
            LEFT JOIN TimeCurrent.dbo.tblEmplAssignments ea1 WITH ( NOLOCK ) ON ea1.Client = thd.Client AND ea1.GroupCode = thd.GroupCode AND ea1.SiteNo = thd.SiteNo AND ea1.SSN = thd.SSN AND ea1.DeptNo = thd.DeptNo AND thd.StaffingSetupType = 1
            LEFT JOIN TimeCurrent.dbo.tblEmplAssignments ea2 WITH ( NOLOCK ) ON ea2.Client = thd.Client AND ea2.GroupCode = thd.GroupCode AND ea2.SSN = thd.SSN AND ea2.DeptNo = thd.DeptNo AND ea2.AssignmentNo = ed.AssignmentNo
            LEFT JOIN TimeCurrent.dbo.tblRFR_Hierarchy_Branch rhb WITH ( NOLOCK ) ON rhb.Client = thd.Client AND rhb.BranchId = ea1.BranchId
            LEFT JOIN TimeCurrent.dbo.tblUser u WITH ( NOLOCK ) ON u.UserID = CASE thd.StaffingSetupType WHEN '1' THEN ea1.ApproverUserId1 ELSE ea2.ApproverUserId1  END
            LEFT JOIN TimeHistory.dbo.tblWTE_Spreadsheet_Breaks wsb WITH ( NOLOCK ) ON wsb.Client = thd.Client AND wsb.GroupCode = thd.GroupCode AND wsb.SSN = thd.SSN AND wsb.SiteNo = thd.SiteNo AND wsb.TransDate = thd.TransDate AND CONVERT(DATE,wsb.[IN]) = CONVERT(DATE,THD.actualintime)
            LEFT JOIN TimeHistory.dbo.tblWTE_BreakCodes bc WITH ( NOLOCK ) ON bc.RecordId = wsb.BreakCode
			LEFT JOIN Timecurrent..tblAgencies A ON A.Client = en.Client AND A.GroupCode = en.GroupCode AND a.Agency = en.AgencyNo
	WHERE   thd.TransDate BETWEEN @TransDateStart AND @TransDateEnd AND bc.BreakErrorFieldName NOT IN ( 'MSR', 'WE' ) AND bc.BreakType <> 'NA'
    ORDER BY BranchId
          , BranchName
          , sn.SiteName
          , EmployeeFirstName
          , EmployeeLastName
          , TransDate
          , InTime;

    DROP TABLE #tempBreakExceptionSSNS;
    DROP TABLE #tmpTHD;
