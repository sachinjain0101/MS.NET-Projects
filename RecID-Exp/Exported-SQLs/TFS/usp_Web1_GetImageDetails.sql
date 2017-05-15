Create PROCEDURE [dbo].[usp_Web1_GetImageDetails]
	-- Add the parameters for the stored procedure here
    ( @PageID INT )
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;
        DECLARE @THD_recordID BIGINT  --< @THD_RecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
        DECLARE @AssociatedExpenseLineItemFaxPageID INT

        SET @AssociatedExpenseLineItemFaxPageID = 0

		--- check if direct hit exists
        IF EXISTS ( SELECT  1
                    FROM    [TimeHistory]..[tblExpenseLineItems] AS TELI WITH ( NOLOCK )
                    WHERE   [TELI].[FaxPageID] = @PageID )
            BEGIN
                SET @AssociatedExpenseLineItemFaxPageID = @PageID
            END
		-- if no direct hit, check if the argument pageID is one of a multipage expense line item
		-- in which case only the TOP fax page row will be tied to the expense line item row
		-- there is a BUG where if u use same multipage image for mulitple expense reports, it wont work.
        ELSE
            BEGIN
                SELECT TOP 1
                        @AssociatedExpenseLineItemFaxPageID = FIP2.RecordId
                FROM    TimeHistory..tblFaxImport_Page AS FIP WITH ( NOLOCK )
                INNER JOIN TimeHistory..tblFaxImport AS FI WITH ( NOLOCK )
                ON      FI.RecordId = FIP.FaxImportId
                INNER JOIN TimeHistory..tblFaxImport_Page AS FIP2 WITH ( NOLOCK )
                ON      FIP2.FaxImportId = FI.RecordId
                INNER JOIN TimeHistory..tblExpenseLineItems AS ELI WITH ( NOLOCK )
                ON      ELI.FaxPageID = FIP2.RecordId
                WHERE   FIP.RecordId = @PageID
                        AND FI.NumPages > 1
            END
       
       -- PRINT @AssociatedExpenseLineItemFaxPageID
        IF @AssociatedExpenseLineItemFaxPageID <> 0
            BEGIN
                --PRINT '1'

                SELECT  'EXPENSES' AS ImageType ,
                        [TEA].[AssignmentNo] ,
                        UPPER([TEN].[LastName]) + ', ' + UPPER([TEN].[FirstName]) AS EmployeeName ,
                        [TimeCurrent].dbo.[fn_GetDateTime]([esd].[PayrollPeriodEndDate], 3) AS Weekending ,
                        [TimeCurrent].dbo.[fn_GetDateTime]([eli].[UpdatedDate], 34) AS DateAdded ,
                        @PageID AS PageID ,
                        er.[RecordId] AS ImageID ,
                        [fax].[SendingFaxNo] ,
                        [fax].[QueueId] ,
                        [q].[QueueName] ,
                        CASE er.Status
                          WHEN 0 THEN 'New'
                          WHEN 1 THEN 'Pending'
                          WHEN 2 THEN 'Approved'
                          WHEN 3 THEN 'Rejected by Client'
                          WHEN 4 THEN 'Cancelled'
                          WHEN 5 THEN 'Sent'
                          WHEN 6 THEN 'Audit'
                          WHEN 7 THEN 'Rejected by Auditor'
                        END AS [Status]
                FROM    [TimeHistory]..[tblFaxImport_Page] AS fp
                INNER JOIN [TimeHistory]..[tblExpenseLineItems] AS eli
                ON      [eli].[FaxPageID] = [fp].[RecordId]
                INNER JOIN [TimeHistory]..[tblExpenseReport] AS er
                ON      [er].[RecordID] = [eli].[ExpenseGroupID]
                INNER JOIN [TimeHistory]..[tblFaxImport] AS fax
                ON      [fax].[RecordId] = [fp].[FaxImportId]
                INNER JOIN [TimeCurrent]..[tblEmplAssignments] AS TEA
                ON      [TEA].[Client] = [er].[Client]
                        AND [TEA].[GroupCode] = [er].[GroupCode]
                        AND [TEA].[SiteNo] = [eli].[SiteNo]
                        AND [TEA].[DeptNo] = [eli].[DeptNo]
                        AND [TEA].[SSN] = [er].[SSN]
                INNER JOIN [TimeHistory]..[tblEmplSites_Depts] AS esd WITH ( NOLOCK )
                ON      [esd].[Client] = [TEA].[Client]
                        AND [esd].[GroupCode] = [TEA].[GroupCode]
                        AND [esd].[SiteNo] = [TEA].[SiteNo]
                        AND [esd].[DeptNo] = [TEA].[DeptNo]
                        AND [esd].[SSN] = [TEA].[SSN]
                        AND [esd].[PayrollPeriodEndDate] = [er].[PayrollPeriodEndDate]
                INNER JOIN [TimeCurrent]..[tblEmplNames] AS TEN
                ON      [TEN].[Client] = [er].[Client]
                        AND [TEN].[GroupCode] = [er].[GroupCode]
                        AND [TEN].[SSN] = [er].[SSN]
                LEFT  JOIN [TimeCurrent]..[tblFaxaroo_Queue] AS q
                ON      [q].[Client] = [fax].[Client]
                        AND [q].[RecordId] = fax.[QueueId]
                WHERE   [fp].[RecordId] = @AssociatedExpenseLineItemFaxPageID
            END
        ELSE
            BEGIN
                SELECT TOP 1
                        @THD_recordID = [thd_fax].[THD_RecordId]
                FROM    [TimeHistory]..[tblTimeHistDetail_Faxaroo] AS thd_fax WITH ( NOLOCK )
                WHERE   [thd_fax].[FaxPageId] = @PageID
                        AND ISNULL([thd_fax].[THD_RecordId], 0) <> 0

                IF ISNULL(@THD_recordID, 0) <> 0
                    BEGIN
                        SELECT  'ASAP' AS ImageType ,
                                [TEA].[AssignmentNo] ,
                                UPPER([TEN].[LastName]) + ', ' + UPPER([TEN].[FirstName]) AS EmployeeName ,
                                [TimeCurrent].dbo.[fn_GetDateTime]([esd].[PayrollPeriodEndDate], 3) AS Weekending ,
                                [TimeCurrent].dbo.[fn_GetDateTime]([fax].[DateAdded], 34) AS DateAdded ,
                                [faxPage].[RecordId] AS PageID ,
                                [fax].[RecordId] AS ImageID ,
                                [fax].[Status] ,
                                [fax].[SendingFaxNo] ,
                                [fax].[QueueId] ,
                                [q].[QueueName]
                        FROM    [TimeHistory]..[tblFaxImport_Page] AS faxPage WITH ( NOLOCK )
                        INNER JOIN [TimeHistory]..[tblFaxImport] AS fax WITH ( NOLOCK )
                        ON      [fax].[RecordId] = [faxPage].[FaxImportId]
                --INNER JOIN [TimeHistory]..[tblTimeHistDetail_Faxaroo] AS thd_fax
                --ON      [thd_fax].[FaxPageId] = [faxPage].[RecordId]
                        INNER JOIN [TimeHistory]..[tblTimeHistDetail] AS thd WITH ( NOLOCK )
                        ON      thd.[RecordID] = @THD_recordID
                        INNER JOIN [TimeHistory]..[tblEmplSites_Depts] AS esd WITH ( NOLOCK )
                        ON      [esd].[Client] = [fax].[Client]
                                AND [esd].[GroupCode] = thd.[GroupCode]
                                AND [esd].[SiteNo] = thd.[SiteNo]
                                AND [esd].[DeptNo] = thd.[DeptNo]
                                AND [esd].[SSN] = thd.[SSN]
                                AND [esd].[PayrollPeriodEndDate] = thd.[PayrollPeriodEndDate]
                        INNER JOIN [TimeCurrent]..[tblEmplAssignments] AS TEA WITH ( NOLOCK )
                        ON      [TEA].[Client] = [esd].[Client]
                                AND [TEA].[GroupCode] = [esd].[GroupCode]
                                AND [TEA].[SiteNo] = [esd].[SiteNo]
                                AND [TEA].[DeptNo] = [esd].[DeptNo]
                                AND [TEA].[SSN] = [esd].[SSN]
                        INNER JOIN [TimeCurrent]..[tblEmplNames] AS TEN WITH ( NOLOCK )
                        ON      [TEN].[Client] = [esd].[Client]
                                AND [TEN].[GroupCode] = [esd].[GroupCode]
                                AND [TEN].[SSN] = [esd].[SSN]
                        INNER  JOIN [TimeCurrent]..[tblFaxaroo_Queue] AS q
                        -- left join as INVC dont have a queueID while PENDING
                                ON
                                [q].[Client] = [fax].[Client]
                                AND q.[RecordId] = fax.[QueueId]
                    --LEFT JOIN [TimeCurrent]..[tblClient_AttachmentTypes] AS cat WITH ( NOLOCK )
                    --ON      [cat].[RecordId] = [fax].[ClientAttachmentTypeID]
                    --LEFT JOIN [TimeCurrent]..[tblAttachmentTypes] AS TAT WITH ( NOLOCK )
                    --ON      [TAT].[RecordId] = [cat].[AttachmentTypeId]
                        WHERE   [faxPage].[RecordId] = @PageID



                    END
                ELSE
                    BEGIN
                        SELECT  CASE [TAT].[Code]
                                  WHEN 'INVC' THEN 'INVOICE'
                                  WHEN 'APPR' THEN 'APPROVAL_ATTACHMENT'
								  WHEN 'TIMECARD_ATTACH' THEN 'TIMECARD_ATTACHMENT'
                                  ELSE 'ASAP'
                                END AS ImageType ,
                                [TEA].[AssignmentNo] ,
                                UPPER([TEN].[LastName]) + ', ' + UPPER([TEN].[FirstName]) AS EmployeeName ,
                                [TimeCurrent].dbo.[fn_GetDateTime]([esd].[PayrollPeriodEndDate], 3) AS Weekending ,
                                [TimeCurrent].dbo.[fn_GetDateTime]([fax].[DateAdded], 34) AS DateAdded ,
                                [pageAssign].[PageId] ,
                                [fax].[RecordId] AS ImageID ,
                                [fax].[Status] ,
                                [fax].[SendingFaxNo] ,
                                [fax].[QueueId] ,
                                [q].[QueueName]
                        FROM    [TimeHistory]..[tblFaxImport_Page] AS faxPage WITH ( NOLOCK )
                        INNER JOIN [TimeHistory]..[tblFaxImport] AS fax WITH ( NOLOCK )
                        ON      [fax].[RecordId] = [faxPage].[FaxImportId]
                        INNER JOIN [TimeHistory]..[tblFaxImport_Page_Assignment] AS pageAssign WITH ( NOLOCK )
                        ON      [pageAssign].[PageId] = [faxPage].[RecordId]
                        INNER JOIN [TimeHistory]..[tblFaxImport_Assignment] AS faxAssign WITH ( NOLOCK )
                        ON      [faxAssign].[RecordId] = [pageAssign].[AssignmentId]
                                AND [faxAssign].[GroupCode] <> 0
                                AND [faxAssign].[SiteNo] <> 0
                                AND [faxAssign].[DeptNo] <> 0
                                AND [faxAssign].[SSN] <> 0
                        INNER JOIN [TimeHistory]..[tblEmplSites_Depts] AS esd WITH ( NOLOCK )
                        ON      [esd].[Client] = [fax].[Client]
                                AND [esd].[GroupCode] = [faxAssign].[GroupCode]
                                AND [esd].[SiteNo] = [faxAssign].[SiteNo]
                                AND [esd].[DeptNo] = [faxAssign].[DeptNo]
                                AND [esd].[SSN] = [faxAssign].[SSN]
                                AND [esd].[PayrollPeriodEndDate] = [faxAssign].[PayrollPeriodEndDate]
                        INNER JOIN [TimeCurrent]..[tblEmplAssignments] AS TEA
                        ON      [TEA].[Client] = [esd].[Client]
                                AND [TEA].[GroupCode] = [esd].[GroupCode]
                                AND [TEA].[SiteNo] = [esd].[SiteNo]
                                AND [TEA].[DeptNo] = [esd].[DeptNo]
                                AND [TEA].[SSN] = [esd].[SSN]
                        INNER JOIN [TimeCurrent]..[tblEmplNames] AS TEN WITH ( NOLOCK )
                        ON      [TEN].[Client] = [esd].[Client]
                                AND [TEN].[GroupCode] = [esd].[GroupCode]
                                AND [TEN].[SSN] = [esd].[SSN]
                        LEFT  JOIN [TimeCurrent]..[tblFaxaroo_Queue] AS q
                        -- left join as INVC dont have a queueID while PENDING
                                ON
                                [q].[Client] = [fax].[Client]
                                AND q.[RecordId] = fax.[QueueId]
                        LEFT JOIN [TimeCurrent]..[tblClient_AttachmentTypes] AS cat WITH ( NOLOCK )
                        ON      [cat].[RecordId] = [fax].[ClientAttachmentTypeID]
                        LEFT JOIN [TimeCurrent]..[tblAttachmentTypes] AS TAT WITH ( NOLOCK )
                        ON      [TAT].[RecordId] = [cat].[AttachmentTypeId]
                        WHERE   [faxPage].[RecordId] = @PageID
                    END

    
        


            END
            
        


    END



