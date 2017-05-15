USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].usp_Web1_GetUndefinedReasonOnTimeCard    Script Date: 9/15/2015 ******/
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		CIGNIFY\Sajjan Sarkar
-- Create date: 9/15/2015
-- Description:	
-- =============================================
--EXEC TimeHistory..usp_Web1_GetUndefinedReasonOnTimeCard 1217867214
IF NOT EXISTS ( SELECT  *
                FROM    sys.objects
                WHERE   object_id = OBJECT_ID(N'[dbo].[usp_Web1_GetUndefinedReasonOnTimeCard]')
                        AND type IN ( N'P', N'PC' ) )
    BEGIN
        EXEC dbo.sp_executesql
            @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_GetUndefinedReasonOnTimeCard] AS' 
    END
GO
ALTER PROCEDURE [dbo].[usp_Web1_GetUndefinedReasonOnTimeCard] ( @THDRecordID BIGINT )  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 14Sept2016 >--
AS
    BEGIN
        SET NOCOUNT ON
        
        DECLARE @TransDate DATE
        DECLARE @EndDate DATE

        SELECT  @TransDate = THD.TransDate
        FROM    TimeHistory..tblTimeHistDetail AS THD WITH ( NOLOCK )
        WHERE   THD.RecordID = @THDRecordID

        IF NOT EXISTS ( SELECT  1
                        FROM    TimeHistory..tblTimeHistDetail AS THD
                        INNER JOIN TimeCurrent..tblEmplAssignments AS EA
                        ON      EA.Client = THD.Client
                                AND EA.GroupCode = THD.GroupCode
                                AND EA.SiteNo = THD.SiteNo
                                AND EA.DeptNo = THD.DeptNo
                                AND EA.SSN = THD.SSN
                        WHERE   THD.RecordID = @THDRecordID )
            BEGIN 
                SELECT  'Assignment could not be resolved for this transaction. Possible reason is an error in the refresh process.' AS UndefinedReason
                RETURN                
            END
		 
        SELECT  @EndDate = MAX(ISNULL(EA.EndDate, '1/1/2100'))
        FROM    TimeHistory..tblTimeHistDetail AS THD
        INNER JOIN TimeCurrent..tblEmplAssignments AS EA
        ON      EA.Client = THD.Client
                AND EA.GroupCode = THD.GroupCode
                AND EA.SiteNo = THD.SiteNo
                AND EA.DeptNo = THD.DeptNo
                AND EA.SSN = THD.SSN
        WHERE   THD.RecordID = @THDRecordID 
		PRINT @EndDate
        IF @TransDate > @EndDate
            BEGIN
                SELECT  'Assignment for this transaction ended on ' + TimeCurrent.dbo.fn_GetDateTime(@EndDate,3) AS UndefinedReason
            END
        ELSE
            BEGIN
                SELECT  'Unknown Error' AS UndefinedReason
            END
    END