Create PROCEDURE [dbo].[usp_Web1_GetPunchLocationsAtSite]
    (
      @Client VARCHAR(4) = '' ,
      @Groupcode INT = 0 ,
      @SiteNo INT ,
      @DeptNo INT = 0 ,
      @DateRangeStart DATETIME = '1/1/1970' ,
      @DateRangeEnd DATETIME = '1/1/1970' ,
      @TimeRangeStart TIME = '00:00' ,
      @TimeRangeEnd TIME = '00:00' ,
      @EmployeeQuery VARCHAR(1000) = '' ,
      @PunchType INT = 0  -- 0 - all mobile punches, 1 - Punches with location only, 2 - Punches without location only
    )
AS
    BEGIN
        SET NOCOUNT ON

        DECLARE @isFileNoSearch INT
        DECLARE @isTimeRangeSpecified BIT
        DECLARE @FirstName VARCHAR(500)
        DECLARE @LastName VARCHAR(500);
        DECLARE @IsOverNightTimeRange BIT
        
        

		-- if @EmployeeQuery is a number then assume its file no
        SELECT  @isFileNoSearch = ISNUMERIC(@EmployeeQuery) 

		-- else get the first name and last name components from @EmployeeQuery
		-- note: ParseVarcharCSV trims the ends before returning.
        IF @isFileNoSearch = 0
            BEGIN
                WITH    cteNameParts
                          AS (
                               SELECT   S.position ,
                                        S.id
                               FROM     TimeCurrent.dbo.ParseVarcharCSV(@EmployeeQuery, ',') AS S
                             )
                    SELECT  @LastName = cteNameParts.id
                    FROM    cteNameParts
                    WHERE   cteNameParts.position = 1;

        ;
                WITH    cteNameParts
                          AS (
                               SELECT   S.position ,
                                        S.id
                               FROM     TimeCurrent.dbo.ParseVarcharCSV(@EmployeeQuery, ',') AS S
                             )
                    SELECT  @FirstName = cteNameParts.id
                    FROM    cteNameParts
                    WHERE   cteNameParts.position = 2
            END
        
        SET @isTimeRangeSpecified = CASE WHEN ISNULL(@TimeRangeStart, '00:00') = '00:00'
                                              AND ISNULL(@TimeRangeEnd, '00:00') = '00:00' THEN 0
                                         ELSE 1
                                    END
        SET @IsOverNightTimeRange = CASE WHEN ISNULL(@TimeRangeEnd, '00:00') < ISNULL(@TimeRangeStart, '00:00') THEN 1
                                         ELSE 0
                                    END
		
		-- create temp table of ppeds in the search range for performance
        CREATE TABLE #tmpPPEDs
            (
              Client VARCHAR(4) ,
              GroupCode INT ,
              PayrollPeriodEndDate DATETIME
            )
		
        IF ISNULL(@DateRangeStart, '1/1/1970') = '1/1/1970'
            BEGIN
                SET @DateRangeStart = DATEADD(DAY, -6, @DateRangeEnd)
            END

        SET @DateRangeStart = @DateRangeStart 
        SET @DateRangeEnd = @DateRangeEnd
        PRINT ' range start:' + TimeCurrent.dbo.fn_GetDateTime(@DateRangeStart, 34)
        PRINT ' range end:' + TimeCurrent.dbo.fn_GetDateTime(@DateRangeEnd, 34)
        PRINT ' apply time range:' + CASE @isTimeRangeSpecified
                                       WHEN 1 THEN 'yes'
                                       ELSE 'no'
                                     END
        INSERT  INTO #tmpPPEDs
                ( Client ,
                  GroupCode ,
                  PayrollPeriodEndDate
		        )
                SELECT  PED.Client ,
                        PED.GroupCode ,
                        PED.PayrollPeriodEndDate
                FROM    TimeHistory.dbo.tblPeriodEndDates AS PED WITH ( NOLOCK )
                WHERE   PED.Client = @Client
                        AND PED.GroupCode = @Groupcode
                        AND PED.PayrollPeriodEndDate BETWEEN @DateRangeStart AND @DateRangeEnd
		--- create temp table of sites to look for (to handle master/slave)
        CREATE TABLE #tmpSites ( SiteNo INT )

        INSERT  INTO #tmpSites
                ( SiteNo
                )
                SELECT  sites.SiteNo
                FROM    TimeCurrent.dbo.tvf_GetMasterAndSlaveSites(@Client, @Groupcode, @SiteNo) AS sites
                WHERE   sites.RecordStatus = 1

		-- temp table with starting set of punches,depending on filters passed in, we delete from this and then finally return it.

        CREATE TABLE #tmpCandidatePunches
            (
              [Client] [CHAR](4) NOT NULL ,
              [GroupCode] [INT] NOT NULL ,
              [DeptNo] [INT] NOT NULL ,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 08Sept2016 >--
              [LastName] [VARCHAR](20) NULL ,
              [FirstName] [VARCHAR](20) NULL ,
              [PayrollPeriodEndDate] [VARCHAR](50) NULL ,
              [TransDate] [VARCHAR](50) NULL ,
              [InTime] [VARCHAR](50) NULL ,
              [OutTime] [VARCHAR](50) NULL ,
              [PUNCHDIRECTION] [VARCHAR](4) NULL ,
              [Latitude] [DECIMAL](9, 6) NULL ,
              [Longitude] [DECIMAL](9, 6) NULL ,
              [PunchTimeStamp] [BIGINT] NULL ,
              [DeptName] [VARCHAR](50) NOT NULL ,
              [THDRecordID] [BIGINT] NOT NULL ,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
              [Hours] [NUMERIC](5, 2) NOT NULL ,
              [FileNo] [VARCHAR](100) NOT NULL ,
              [punchrecordid] [INT] NOT NULL ,
              [PunchSiteNo] [INT] NOT NULL ,  --< PunchSiteNo data type is changed from  SMALLINT to INT by Srinsoft on 08Sept2016 >--
              [InSiteNo] [INT] NULL ,
              [SiteNo] [INT] NOT NULL  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 08Sept2016 >--
            ) 
        
        INSERT  INTO #tmpCandidatePunches
                ( Client ,
                  GroupCode ,
                  DeptNo ,
                  LastName ,
                  FirstName ,
                  PayrollPeriodEndDate ,
                  TransDate ,
                  InTime ,
                  OutTime ,
                  PUNCHDIRECTION ,
                  Latitude ,
                  Longitude ,
                  PunchTimeStamp ,
                  DeptName ,
                  THDRecordID ,
                  Hours ,
                  FileNo ,
                  punchrecordid ,
                  PunchSiteNo ,
                  InSiteNo ,
                  SiteNo
		        )
                SELECT  THD.Client ,
                        THD.GroupCode ,
                        THD.DeptNo ,
                        UPPER(EN.LastName) ,
                        UPPER(EN.FirstName) ,
                        TimeCurrent.dbo.fn_GetDateTime(THD.PayrollPeriodEndDate, 3) ,
                        TimeCurrent.dbo.fn_GetDateTime(THD.TransDate, 2) , --only date part
                        TimeCurrent.dbo.fn_GetDateTime(THD.ActualInTime, 33) , -- only time part
                        TimeCurrent.dbo.fn_GetDateTime(THD.ActualOutTime, 33) ,-- only time part
                        LTRIM(RTRIM(THDGL.PunchDirection)) ,
                        ISNULL(THDGL.Latitude, 0) ,
                        ISNULL(THDGL.Longitude, 0) ,
                        THDGL.PunchLocationTime ,
                        GD.DeptName_Long ,
                        THD.RecordID ,
                        ISNULL(THD.Hours, 0) ,
                        ISNULL(EN.FileNo, '0') ,
                        THDGL.RecordID ,
                        THDGL.SiteNo ,
                        THD.InSiteNo ,
                        THD.SiteNo
                FROM    TimeHistory..tblTimeHistDetail AS THD WITH ( NOLOCK )
                INNER JOIN #tmpPPEDs AS ppeds
                ON      ppeds.Client = THD.Client
                        AND ppeds.GroupCode = THD.GroupCode
                        AND ppeds.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
                INNER JOIN TimeHistory..tblTimeHistDetail_GeoLocation AS THDGL WITH ( NOLOCK )
                ON      THDGL.Client = THD.Client
                        AND THDGL.GroupCode = THD.GroupCode
                        AND THDGL.PayrollPeriodEndDate = THD.PayrollPeriodEndDate
                        AND THDGL.SSN = THD.SSN
                        AND ( THDGL.PunchLocationTime = ISNULL(THD.InTimestamp, 0)
                              OR THDGL.PunchLocationTime = ISNULL(THD.outTimestamp, 0)
                            )
                INNER JOIN #tmpSites AS tmpSites
                ON      tmpSites.SiteNo = THDGL.SiteNo
                INNER JOIN TimeCurrent..tblEmplNames AS EN WITH ( NOLOCK )
                ON      EN.Client = THDGL.Client
                        AND EN.GroupCode = THDGL.GroupCode
                        AND EN.SSN = THDGL.SSN
                INNER JOIN TimeCurrent..tblGroupDepts AS GD WITH ( NOLOCK )
                ON      GD.Client = THD.Client
                        AND GD.GroupCode = THD.GroupCode
                        AND GD.DeptNo = THD.DeptNo
                WHERE   THD.Client = @Client
                        AND THD.GroupCode = @Groupcode
                        AND ISNULL(THD.ClockAdjustmentNo, '') = ''
                        AND ( ( THD.InTimestamp IS NOT NULL
                                AND THD.InTimestamp <> 0
                                AND THD.OutDay <> 10
                              )
                              OR ( THD.outTimestamp IS NOT NULL
                                   AND THD.outTimestamp <> 0
                                   AND THD.InDay <> 10
                                 )
                            )

	
		--- apply filters

		-- department filter
        IF ISNULL(@DeptNo, 0) <> 0
            DELETE  FROM #tmpCandidatePunches
            WHERE   DeptNo <> @DeptNo

		-- time filter filter
        IF ISNULL(@isTimeRangeSpecified, 0) = 1
            IF @IsOverNightTimeRange = 0
                BEGIN
                    DELETE  FROM #tmpCandidatePunches
                    WHERE   ( CAST(InTime AS TIME) NOT BETWEEN @TimeRangeStart AND @TimeRangeEnd
                              AND CAST(OutTime AS TIME) NOT  BETWEEN @TimeRangeStart AND @TimeRangeEnd
                            )	
                END
            ELSE
                BEGIN
                    /**
					Example: 
					Filter:
					+------------+-------+------+
					| time range | start | end  |
					+------------+-------+------+
					|            | 23:00 | 2:00 |
					+------------+-------+------+
					Sample Punches:
					+-------+-------+-----------------+
					|  In   |  Out  | Will be removed |
					+-------+-------+-----------------+
					| 20:00 | 22:00 | yes             |
					| 20:00 | 1:00  | no              |
					| 23:30 | 3:00  | no              |
					| 23:30 | 1:00  | no              |
					| 3:00  | 9:00  | yes             |
					+-------+-------+-----------------+
					
					
					*/	
                    DELETE  FROM #tmpCandidatePunches
                    WHERE   CAST(InTime AS TIME) NOT BETWEEN @TimeRangeStart AND '23:59'
                            AND CAST(InTime AS TIME) NOT BETWEEN '00:00' AND @TimeRangeEnd
                            AND CAST(OutTime AS TIME) NOT BETWEEN @TimeRangeStart AND '23:59'
                            AND CAST(OutTime AS TIME) NOT BETWEEN '00:00' AND @TimeRangeEnd
                                
				
                END
		-- file no filter
        IF @isFileNoSearch = 1
            DELETE  FROM #tmpCandidatePunches
            WHERE   FileNo <> @EmployeeQuery
        ELSE
		-- employee name filter
            BEGIN
                IF ISNULL(@LastName, '') <> ''
                    DELETE  FROM #tmpCandidatePunches
                    WHERE   LastName NOT LIKE @LastName + '%'
                IF ISNULL(@FirstName, '') <> ''
                    DELETE  FROM #tmpCandidatePunches
                    WHERE   FirstName NOT LIKE @FirstName + '%'
            END
		
        IF @PunchType = 1--Punches With Location Only
            BEGIN
                DELETE  FROM #tmpCandidatePunches
                WHERE   THDRecordID IN ( SELECT DISTINCT
                                                TCP.THDRecordID
                                         FROM   #tmpCandidatePunches AS TCP
                                         WHERE  TCP.Longitude = 0
                                                AND TCP.Latitude = 0 )
            END
        IF @PunchType = 2--Punches Without Location Only
            BEGIN
                DELETE  FROM #tmpCandidatePunches
                WHERE   THDRecordID NOT  IN ( SELECT DISTINCT
                                                        TCP.THDRecordID
                                              FROM      #tmpCandidatePunches AS TCP
                                              WHERE     TCP.Longitude = 0
                                                        AND TCP.Latitude = 0 )
            END


        SELECT  *
        FROM    #tmpCandidatePunches AS TCP           
        DROP TABLE #tmpPPEDs
        DROP TABLE #tmpSites
        DROP TABLE #tmpCandidatePunches
    END
