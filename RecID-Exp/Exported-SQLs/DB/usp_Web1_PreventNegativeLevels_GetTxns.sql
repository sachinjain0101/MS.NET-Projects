CREATE PROCEDURE [dbo].[usp_Web1_PreventNegativeLevels_GetTxns] 
	-- Add the parameters for the stored procedure here
    @THDRecordID BIGINT = 0  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
AS 
    
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON ;

    -- Insert statements for procedure here
		
		
        DECLARE @PreventNegativeLevel INT
        DECLARE @HoursSumExcludingCurrentTxn NUMERIC(15, 2)
        DECLARE @AggregationString VARCHAR(160)
		
        SELECT  @PreventNegativeLevel = PreventNegativeLevel
        FROM    TimeHistory..tblTimeHistDetail AS thd
        INNER JOIN TimeCurrent..tblClients AS TC
        ON      thd.Client = TC.Client
        WHERE   thd.RecordID = @THDRecordID
		
		
        CREATE TABLE #tmpAllForThisAggregation
            (
              thdRecordID BIGINT ,  --< thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
              siteno INT ,
              sitename VARCHAR(60) ,
              deptno INT ,
              deptname VARCHAR(60) ,
              shiftno INT ,
              HOURS NUMERIC(15, 2) ,
              TransDate VARCHAR(50),
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
                  TransDate,
                  AdjustmentName
		        )
                SELECT  thd.RecordID ,
                        TSN.SiteNo ,
                        SiteName ,
                        THD.DeptNo ,
                        DeptName_Long ,
                        ISNULL(thd.ShiftNo, 0) ,
                        thd.Hours ,
                        TimeCurrent.dbo.fn_GetDateTime(curr_txn.TransDate, 36),-- get date as Tuesday 01/15/2013
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
                INNER JOIN (
                             SELECT *
                             FROM   TimeHistory..tblTimeHistDetail AS thd2
                             WHERE  RecordID = @THDRecordID
                           ) AS curr_txn
                ON      thd.Client = curr_txn.Client
                        AND thd.GroupCode = curr_txn.GroupCode
                        AND thd.PayrollPeriodEndDate = curr_txn.PayrollPeriodEndDate
                        AND thd.SSN = curr_txn.SSN
                        AND thd.TransDate = curr_txn.TransDate
                        AND thd.Hours<>0
                        AND ( ( @PreventNegativeLevel = 0
                                AND 1 = 2
                              )
                              OR ( @PreventNegativeLevel = 1
                                   AND curr_txn.DeptNo = thd.DeptNo
                                 )
                              OR ( @PreventNegativeLevel = 2
                                   AND curr_txn.SiteNo = thd.SiteNo
                                   AND curr_txn.DeptNo = thd.DeptNo
                                 )
                              OR ( @PreventNegativeLevel = 3
                                   AND curr_txn.DeptNo = thd.DeptNo
                                   AND curr_txn.ShiftNo = thd.ShiftNo
                                 )
                              OR ( @PreventNegativeLevel = 4
                                   AND curr_txn.SiteNo = thd.SiteNo
                                   AND curr_txn.ShiftNo = thd.ShiftNo
                                   AND curr_txn.DeptNo = thd.DeptNo
                                 )
                            )
                WHERE   thd.RecordID <> @THDRecordID
                            
        --SELECT * FROM #tmpAllForThisAggregation AS TAFTA          
        SET @HoursSumExcludingCurrentTxn = 0
                            
        SELECT  @HoursSumExcludingCurrentTxn = SUM(HOURS)
        FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )	             
                            
        IF @PreventNegativeLevel = 0
            OR @HoursSumExcludingCurrentTxn >= 0 
            BEGIN
                SELECT  *
                FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                WHERE   1 = 2 -- redundtant for @PreventNegativeLevel=0 but need to do this to catch all non-zero sums
                
                RETURN
            END                  
        
        ELSE 
            IF @PreventNegativeLevel = 1
                AND @HoursSumExcludingCurrentTxn < 0 
                BEGIN
                    SELECT TOP 1
                            @AggregationString = 'Dept: ' + CAST(deptno AS VARCHAR) + ' (' + deptname + ')'
                    FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                    GROUP BY deptname ,
                            deptno
				
                END 
            ELSE 
                IF @PreventNegativeLevel = 2
                    AND @HoursSumExcludingCurrentTxn < 0 
                    BEGIN
                        SELECT TOP 1
                                @AggregationString = 'Site:' + CAST(siteno AS VARCHAR) + ' ( ' + sitename + ' )' + ' / Dept: ' + deptname + ' ('
                                + CAST(deptno AS VARCHAR) + ')'
                        FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                        GROUP BY deptname ,
                                deptno ,
                                siteno ,
                                sitename
				
                    END 
                ELSE 
                    IF @PreventNegativeLevel = 3
                        AND @HoursSumExcludingCurrentTxn < 0 
                        BEGIN
                            SELECT TOP 1
                                    @AggregationString = 'Dept: ' + CAST(deptno AS VARCHAR) + ' (' + deptname + ')' + ' / Shift: ' + CAST(shiftno AS VARCHAR)
                            FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                            GROUP BY deptname ,
                                    deptno ,
                                    shiftno
                            
				
                        END 
                    ELSE 
                        IF @PreventNegativeLevel = 4
                            AND @HoursSumExcludingCurrentTxn < 0 
                            BEGIN
                                SELECT TOP 1
                                        @AggregationString = 'Site:' + CAST(siteno AS VARCHAR) + ' ( ' + sitename + ' )' + ' / Dept: ' + deptname + '( '
                                        + CAST(deptno AS VARCHAR) + ')' + ' / Shift: ' + CAST(shiftno AS VARCHAR)
                                FROM    #tmpAllForThisAggregation AS tmp WITH ( NOLOCK )
                                GROUP BY siteno ,
                                        sitename ,
                                        shiftno ,
                                        deptname ,
                                        deptno
				
                            END                  
                      
        
        
        SELECT  @AggregationString AS AggregationString ,
                *
        FROM    #tmpAllForThisAggregation
        WHERE hours < 0
        
                            
        DROP TABLE #tmpAllForThisAggregation                            
    END




