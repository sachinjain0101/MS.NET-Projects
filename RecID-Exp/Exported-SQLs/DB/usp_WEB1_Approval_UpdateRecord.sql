CREATE PROCEDURE [dbo].[usp_WEB1_Approval_UpdateRecord]
    (
      @Client VARCHAR(4) ,
      @Groupcode INT ,
      @PPED DATETIME ,
      @SSN INT ,
      @ApprovalStatus CHAR(1) ,
      @UserID INT ,
      @RecordID BIGINT ,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 06Sept2016 >--
      @UserName VARCHAR(100)
    )
AS
    
SET NOCOUNT ON

    DECLARE @CurrentStatus CHAR(1)
-- This SP will toggle the status of the selected record from UN-Approved to approved 
-- OR from Approved to UnApproved. A comment will be inserted in the comments, if the record is
-- being un-approved.
--

    IF @ApprovalStatus = 'A' -- note I found that the CFM sends in "A" even if it is an "unapprove" operation.
        BEGIN

            SET @CurrentStatus = (
                                   SELECT   ISNULL(AprvlStatus, '')
                                   FROM     TimeHistory..tblTimeHistDetail
                                   WHERE    RecordID = @RecordID
                                 )

            IF ISNULL(@CurrentStatus, '') <> 'A'
                BEGIN
                    UPDATE  TimeHistory..tblTimeHistDetail
                    SET     AprvlStatus = @ApprovalStatus ,
                            AprvlStatus_UserID = @UserID ,
                            AprvlStatus_Date = GETDATE()
                    WHERE   RecordID = @RecordID
                END
            ELSE
                IF ISNULL(@CurrentStatus, '') = 'A'
                    BEGIN
    -- INSERT Comment indicating the line was un-approved.
    -- 
                        INSERT  INTO [TimeHistory].[dbo].[tblTimeHistDetail_Comments]
                                ( [Client] ,
                                  [GroupCode] ,
                                  [PayrollPeriodEndDate] ,
                                  [SSN] ,
                                  [CreateDate] ,
                                  [Comments] ,
                                  [UserID] ,
                                  [UserName] ,
                                  [ManuallyAdded]
                                )
                                SELECT  Client ,
                                        GroupCode ,
                                        PayrollPeriodEndDate ,
                                        SSN ,
                                        GETDATE() ,
                                        'Transaction for date ' + CONVERT(VARCHAR(12), TransDate, 101) + ' with hours/dollars = ' + LTRIM(STR(Hours, 6, 2))
                                        + '/' + LTRIM(STR(Dollars, 6, 2)) + ' was unapproved.' ,
                                        @UserID ,
                                        @UserName ,
                                        '0'
                                FROM    TimeHistory..tblTimeHistDetail
                                WHERE   RecordID = @RecordID
    
                        UPDATE  TimeHistory..tblTimeHistDetail
                        SET     AprvlStatus = '' ,
                                AprvlStatus_UserID = 0 ,
                                AprvlStatus_Date = GETDATE()
                        WHERE   RecordID = @RecordID
                    END
        END
    ELSE
        BEGIN
            UPDATE  TimeHistory..tblTimeHistDetail
            SET     AprvlStatus = @ApprovalStatus ,
                    AprvlStatus_UserID = @UserID ,
                    AprvlStatus_Date = GETDATE()
            WHERE   RecordID = @RecordID
        END
	SELECT  @@ROWCOUNT AS NoOfRowsUpdated
-- This is not good for performance since it will recalculate status for every THD record.  We need to call this once at the end.
    EXEC TimeHistory.dbo.usp_EmplCalc_SummarizeAprvlStatus
        @Client ,
        @GroupCode ,
        @PPED ,
        @SSN

    -- disputes are deleted in the CFM in EmpDetail_Approval_Post.cfm

