CREATE PROCEDURE [dbo].[usp_Web1_PreventNegativeLevels_GetTxns_All]
    (
      @Client VARCHAR(4) ,
      @GroupCode INT ,
      @SiteNo INT = NULL ,
      @DeptNo INT = NULL ,
      @ShiftNo INT = NULL ,
      @SSN INT ,
      @PPED DATETIME ,
      @Transdate DATETIME = NULL ,
      @OnlyNegative BIT   
    )
AS 
    
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON ;
        DECLARE @AggregationString VARCHAR(160)        	
        DECLARE @PreventNegativeLevel INT
        
        SELECT  @PreventNegativeLevel = PreventNegativeLevel
        FROM    TimeCurrent..tblClients AS TC
        WHERE   Client = @Client
		
        
        CREATE TABLE #tmpAllForThisAggregation
            (
              thdRecordID BIGINT ,  --< thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
              siteno INT ,
              sitename VARCHAR(60) ,
              deptno INT ,
              deptname VARCHAR(60) ,
              shiftno INT ,
              HOURS NUMERIC(5, 2) ,
			  RegHours NUMERIC(5,2),
			  OT_Hours NUMERIC(5,2),
			  DT_Hours NUMERIC(5,2),
              TransDate DATETIME ,
              AdjustmentName VARCHAR(10)
            )
		
        INSERT  INTO #tmpAllForThisAggregation
                ( thdRecordID ,
                  siteno ,
                  sitename ,
                  deptno ,
                  deptname ,
                  shiftno ,
                  HOURS ,
				  RegHours,
				  OT_Hours,
				  DT_Hours,
                  TransDate ,
                  AdjustmentName
		        )
                SELECT  thd.RecordID ,
                        TSN.SiteNo ,
                        SiteName ,
                        THD.DeptNo ,
                        DeptName_Long ,
                        ISNULL(thd.ShiftNo, 0) ,
                        thd.Hours ,
						thd.RegHours,
						thd.OT_Hours,
						thd.DT_Hours,
                        thd.TransDate ,-- get date as Tuesday 01/15/2013
                        thd.AdjustmentName
                FROM    TimeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
                INNER JOIN TimeCurrent..tblGroupDepts AS GD WITH ( NOLOCK )
                ON      thd.Client = GD.Client
                        AND thd.GroupCode = GD.GroupCode
                        AND thd.DeptNo = GD.DeptNo
                INNER JOIN TimeCurrent..tblSiteNames AS TSN WITH ( NOLOCK )
                ON      THD.Client = TSN.Client
                        AND THD.GroupCode = TSN.GroupCode
                        AND THD.SiteNo = TSN.SiteNo
                WHERE   thd.Client = @Client
                        AND thd.GroupCode = @GroupCode
                        AND thd.SSN = @SSN
                        AND thd.PayrollPeriodEndDate = @PPED
                        --AND ( @SiteNo IS NULL
                        --      OR thd.SiteNo = @SiteNo
                        --    )
                        --AND ( @DeptNo IS NULL
                        --      OR thd.DeptNo = @DeptNo
                        --    )
                        --AND ( @ShiftNo IS NULL
                        --      OR thd.ShiftNo = @ShiftNo
                        --    )
                        --AND ( @Transdate IS NULL
                        --      OR thd.TransDate = @Transdate
                        --    )
                        AND thd.Hours <> 0


        IF ISNULL(@PreventNegativeLevel, 0) NOT IN (1,2,3,4,5)-- these are the only valid non-zero values 
            BEGIN
                SELECT  deptname AS AggregationString ,
                        SUM(HOURS) AS HOURS ,
                        TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36) AS TransDate
                FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                WHERE   1 = 2 -- redundtant for @PreventNegativeLevel=0 but need to do this to catch all non-zero sums
                GROUP BY deptname ,
                        TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36)
                RETURN
            END                  
        
        ELSE 
            IF @PreventNegativeLevel = 1 
                BEGIN
                    SELECT  'Dept: ' + CAST(deptno AS VARCHAR) + ' (' + deptname + ')' AS AggregationString ,
                            SUM(HOURS) AS HOURS ,
                            TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36) AS TransDate
                    FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                    WHERE   ( @DeptNo IS NULL
                              OR tmp.DeptNo = @DeptNo
                            )
                            AND ( @Transdate IS NULL
                                  OR tmp.TransDate = @Transdate
                                )
                    GROUP BY deptname ,
                            deptno ,
                            TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36)
                    HAVING  ( ( @OnlyNegative = 1
                                AND SUM(HOURS) < 0
                              )
                              OR @OnlyNegative = 0
                            )
                    RETURN
                END 
            ELSE 
                IF @PreventNegativeLevel = 2 
                    BEGIN
                        PRINT '2222222'
                        SELECT  'Site:' + CAST(siteno AS VARCHAR) + ' ( ' + sitename + ' )' + ' / Dept: ' + deptname + ' (' + CAST(deptno AS VARCHAR) + ')' AS AggregationString ,
                                SUM(HOURS) AS HOURS ,
                                TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36) AS TransDate
                        FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                        WHERE   ( @DeptNo IS NULL
                                  OR tmp.DeptNo = @DeptNo
                                )
                                AND ( @Transdate IS NULL
                                      OR tmp.TransDate = @Transdate
                                    )
                                AND ( @SiteNo IS NULL
                                      OR tmp.SiteNo = @SiteNo
                                    )
                        GROUP BY deptname ,
                                deptno ,
                                siteno ,
                                sitename ,
                                TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36)
                        HAVING  ( ( @OnlyNegative = 1
                                    AND SUM(HOURS) < 0
                                  )
                                  OR @OnlyNegative = 0
                                )
                        RETURN
                    END 
                ELSE 
                    IF @PreventNegativeLevel = 3 
                        BEGIN
                            SELECT  'Dept: ' + CAST(deptno AS VARCHAR) + ' (' + deptname + ')' + ' / Shift: ' + CAST(shiftno AS VARCHAR) AS AggregationString ,
                                    SUM(HOURS) AS HOURS ,
                                    TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36) AS TransDate
                            FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                            WHERE   ( @DeptNo IS NULL
                                      OR tmp.DeptNo = @DeptNo
                                    )
                                    AND ( @Transdate IS NULL
                                          OR tmp.TransDate = @Transdate
                                        )
                                    AND ( @ShiftNo IS NULL
                                          OR tmp.ShiftNo = @ShiftNo
                                        )
                            GROUP BY deptname ,
                                    deptno ,
                                    shiftno ,
                                    TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36)
                            HAVING  ( ( @OnlyNegative = 1
                                        AND SUM(HOURS) < 0
                                      )
                                      OR @OnlyNegative = 0
                                    )
                            
                            RETURN
                        END 
                    ELSE 
                        IF @PreventNegativeLevel = 4 
                            BEGIN
                                SELECT  'Site:' + CAST(siteno AS VARCHAR) + ' ( ' + sitename + ' )' + ' / Dept: ' + deptname + '( ' + CAST(deptno AS VARCHAR)
                                        + ')' + ' / Shift: ' + CAST(shiftno AS VARCHAR) AS AggregationString ,
                                        SUM(HOURS) AS HOURS, 
                                        TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36) AS TransDate
                                FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                                WHERE   ( @SiteNo IS NULL
                                          OR tmp.SiteNo = @SiteNo
                                        )
                                        AND ( @DeptNo IS NULL
                                              OR tmp.DeptNo = @DeptNo
                                            )
                                        AND ( @ShiftNo IS NULL
                                              OR tmp.ShiftNo = @ShiftNo
                                            )
                                        AND ( @Transdate IS NULL
                                              OR tmp.TransDate = @Transdate
                                            )
                                GROUP BY siteno ,
                                        sitename ,
                                        shiftno ,
                                        deptname ,
                                        deptno ,
                                        TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36)
                                HAVING  ( ( @OnlyNegative = 1
                                            AND SUM(HOURS) < 0
                                          )
                                          OR @OnlyNegative = 0
                                        )
                                RETURN
                            END 
						ELSE
							IF @PreventNegativeLevel = 5 
								BEGIN
									SELECT  'Dept: ' + CAST(deptno AS VARCHAR) + ' (' + deptname + ')' AS AggregationString ,
											Hours = SUM(hours),
											TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36) AS TransDate
									FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
									WHERE   ( @DeptNo IS NULL
											  OR tmp.DeptNo = @DeptNo
											)
											AND ( @Transdate IS NULL
												  OR tmp.TransDate = @Transdate
												)
									GROUP BY deptname ,
											deptno ,
											TimeCurrent.dbo.fn_GetDateTime(tmp.TransDate, 36)
									HAVING  ( ( @OnlyNegative = 1
												AND SUM(RegHours) < 0
											  )
											  OR
											  ( @OnlyNegative = 1
											    AND SUM(OT_Hours) < 0
											  )
											  OR
											  (  @OnlyNegative = 1
											     AND SUM(DT_Hours) < 0
											  )
											  OR @OnlyNegative = 0
											)
									RETURN
								END 

                       

	
        DROP TABLE #tmpAllForThisAggregation
   
    END



