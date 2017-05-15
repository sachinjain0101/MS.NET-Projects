CREATE PROCEDURE [dbo].[usp_WEB1_Approval_UpdateAllEmployeesTimeCard_Clustered]
    (
      @Client VARCHAR(4) = '' ,
      @Groupcode INT = 0 ,
      @payrollPeriodEndDate DATETIME ,
      @ClusterID INT ,
      @userID INT ,
      @PayBill CHAR(1) ,
      @NewStatus VARCHAR(1)
    )
AS
    
BEGIN
        SET NOCOUNT ON
        DECLARE @SSN INT

        CREATE TABLE #tmp
            (
              SSN INT ,
              thdrecordid BIGINT  --< thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
            )

        INSERT  INTO #tmp
                ( SSN ,
                  thdrecordid
		        )
                SELECT  THD.SSN ,
                        THD.RecordID
                FROM    TimeHistory..tblTimeHistDetail AS THD WITH ( NOLOCK )
        --LEFT JOIN TimeCurrent..tblAdjCodes AS AC WITH ( NOLOCK )
        --ON      AC.Client = THD.Client
        --        AND AC.GroupCode = THD.GroupCode
        --        AND AC.ClockAdjustmentNo = THD.ClockAdjustmentNo
                WHERE   THD.Client = @Client
                        AND THD.GroupCode = @Groupcode
                        AND THD.PayrollPeriodEndDate = @payrollPeriodEndDate
                        AND THD.InDay <> 10
                        AND THD.OutDay <> 10
                        AND THD.AprvlStatus <> 'L'
                        AND THD.AprvlStatus <> 'D'
						AND thd.AprvlStatus <>@NewStatus
						/**** this stored proc was written to improve the performance issue caused by its predecessor (usp_Web1_GetTimeHistSum_Approve_All) ,
								that stored procedure was not using the users view pay/bill permissions during the approval.
								Using the pay/bill flag is the correct way, but since we didnt want to change the way the system 
								behaved, we're not using the pay bill flag for now.

								Some day when we decide to make the approval process consistent, uncomment the @paybill references.
						 **/
              /*  AND ( ( @PayBill = 'B'
                        AND ISNULL(AC.Billable, 'Y') <> 'N'
                      )
                      OR ( @PayBill = 'P'
                           AND ISNULL(AC.Payable, 'Y') <> 'N'
                         )
                    )*/
                        AND EXISTS ( SELECT 1
                                     FROM   TimeHistory.dbo.tvf_GetTimeHistoryClusterDefAsFn(THD.GroupCode, THD.SiteNo, THD.DeptNo, THD.AgencyNo, THD.SSN,
                                                                                             THD.DivisionID, THD.ShiftNo, @ClusterID) AS isInCluster )

        UPDATE  TimeHistory..tblTimeHistDetail
        SET     AprvlStatus = @NewStatus ,
                AprvlStatus_Date = GETDATE() ,
                AprvlStatus_UserID = @userID
        FROM    TimeHistory..tblTimeHistDetail AS THD WITH ( NOLOCK )
        INNER JOIN #tmp AS T
        ON      T.thdrecordid = THD.RecordID

        
        DECLARE cursorDB CURSOR READ_ONLY
        FOR
            SELECT DISTINCT
                    T.SSN
            FROM    #tmp AS T
		           
        OPEN cursorDB
		
        FETCH NEXT FROM cursorDB INTO @SSN
        WHILE ( @@fetch_status <> -1 )
            BEGIN
                IF ( @@fetch_status <> -2 )
                    BEGIN
                        EXEC TimeHistory..usp_EmplCalc_SummarizeAprvlStatus
                            @Client , -- varchar(4)
                            @GroupCode , -- int
                            @payrollPeriodEndDate , -- datetime
                            @SSN  -- int
                    END 
                FETCH NEXT FROM cursorDB INTO @SSN
            END--WHILE (@@fetch_status <> -1)                   
		            
        CLOSE cursorDB
        DEALLOCATE cursorDB


        
		
        SELECT  COUNT(*) AS NoOfRowsUpdated
        FROM    #tmp AS T

        DROP TABLE #tmp


        
    END

	
