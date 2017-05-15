Create PROCEDURE [dbo].[usp_Web1_doAutoApproval] 
	-- Add the parameters for the stored procedure here
    (
      @client CHAR(4) = '' ,
      @Groupcode INT = 0 ,
      @PPED DATETIME ,
      @SSN INT = 0 ,
      @SiteNo INT = 0 ,
      @DeptNo INT = 0
    )
AS 
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON ;

        DECLARE @Now DATETIME
        DECLARE @THDRecordID BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 07Sept2016 >--
        DECLARE @SystemApproverUserID INT
		
        SET @Now = GETDATE()
		
        SELECT  @SystemApproverUserID = UserID
        FROM    TimeCurrent..tblUser AS TU
        WHERE   LogonName = 'system_approver'		
		
        DECLARE cursorDB CURSOR READ_ONLY
        FOR
            SELECT  DISTINCT
                    thd.RecordID
            FROM    TimeHistory..tblTimeHistDetail AS thd WITH(NOLOCK)
            INNER JOIN TimeCurrent..tblEmplAssignments AS TEA WITH(NOLOCK)
            ON      tea.Client = thd.Client
                    AND tea.GroupCode = thd.GroupCode                    
                    AND tea.SSN = thd.SSN
                    AND tea.SiteNo = thd.SiteNo
                    AND tea.DeptNo = thd.DeptNo
            INNER JOIN TimeCurrent..tblStaffing_Methods AS methods WITH(NOLOCK)
            ON      TEA.ApprovalMethodID = methods.RecordId
            AND methods.MethodCode = 'AUTO'
            INNER JOIN TimeCurrent..tblClients_Staffing_Setup AS setup WITH(NOLOCK)
            ON      TEA.Client = setup.Client
            INNER JOIN TimeCurrent..tblClients_Staffing_Client_To_Methods AS client_methods WITH(NOLOCK)
            ON      setup.RecordID = client_methods.ClientSetup_RecordID
                    AND client_methods.MethodID = methods.RecordID
                    AND client_methods.RecordStatus = 1
            WHERE   thd.Client = @client
                    AND thd.GroupCode = @Groupcode
                    AND thd.PayrollPeriodEndDate = @PPED
                    AND (ISNULL(@SSN, 0) = 0 OR thd.SSN = @SSN)
                    AND (ISNULL(@SiteNo, 0) = 0 OR thd.SiteNo = @SiteNo)
                    AND (ISNULL(@DeptNo, 0) = 0 OR thd.DeptNo = @DeptNo)
                    AND ISNULL(thd.AprvlStatus, '') = ''                    
		           
        OPEN cursorDB
		
        FETCH NEXT FROM cursorDB INTO @THDRecordID
        WHILE ( @@fetch_status <> -1 ) 
            BEGIN
                IF ( @@fetch_status <> -2 ) 
                    BEGIN
                        UPDATE  TimeHistory..tblTimeHistDetail
                        SET     AprvlStatus = 'A' ,
                                AprvlStatus_Date = @Now ,
                                AprvlStatus_UserID = @SystemApproverUserID
                        WHERE   RecordID = @THDRecordID
                    END 
                FETCH NEXT FROM cursorDB INTO @THDRecordID
            END--WHILE (@@fetch_status <> -1)                   
		            
        CLOSE cursorDB
        DEALLOCATE cursorDB
		
        SELECT @client AS client where 1 = 0 
        --,@Groupcode AS groupcode,@PPED AS WeekendingDate,@SSN AS SSN,@SiteNo AS SiteNo,@DeptNo AS DeptNo
   
    END

    EXEC TimeHistory.dbo.usp_EmplCalc_SummarizeAprvlStatus @Client, @GroupCode, @PPED, @SSN
