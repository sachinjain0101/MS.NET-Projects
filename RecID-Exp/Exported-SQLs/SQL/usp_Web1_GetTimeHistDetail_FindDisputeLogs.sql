USE [TimeHistory]
GO
/****** Object:  StoredProcedure [dbo].[usp_Web1_GetTimeHistDetail_FindDisputeLogs]    Script Date: 10/23/2015 ******/
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author: Jimmy
-- Create date: 2016-05-12 03:53:04.453
-- Description:    
-- =============================================
IF NOT EXISTS ( SELECT  *
                FROM    sys.objects
                WHERE   object_id = OBJECT_ID(N'[dbo].[usp_Web1_GetTimeHistDetail_FindDisputeLogs]')
                        AND type IN ( N'P', N'PC' ) )
    BEGIN
        EXEC dbo.sp_executesql
            @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_FindDisputeLogs] AS' 
    END
GO
ALTER PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_FindDisputeLogs]
    (
      @Client VARCHAR(4) = '' ,
      @GroupCode INT = 0 ,
      @SSN INT = 0 ,
      @PPED DATETIME = '' ,
      @DisputeDetailRecordID BIGINT = 0  --< @DisputeDetailRecordID data type is changed from  INT to BIGINT by Srinsoft on 09Sept2016 >--

    )
AS
    BEGIN
        SET NOCOUNT ON
        SELECT  Disputes.* ,
                Reasons.* ,
                u.FirstName ResolvedFirstName ,
                u.LastName ResolvedLastName
        FROM    TimeHistory..tblTimeHistDetail_Disputes AS Disputes WITH (NOLOCK)
        LEFT JOIN TimeCurrent..tblAdjCodes adj WITH (NOLOCK)
        ON      adj.Client = Disputes.Client
                AND adj.GroupCode = Disputes.GroupCode
                AND adj.ClockAdjustmentNo = Disputes.AdjCode
        INNER JOIN TimeCurrent..tblValidDisputeReasons AS Reasons WITH (NOLOCK)
        ON      Disputes.DisputeReason = Reasons.DisputeReason
        LEFT JOIN TimeCurrent..tblUser AS u WITH (NOLOCK)
        ON      Disputes.ResolvedUserId = u.UserId
        WHERE   Disputes.Client = @Client
                AND Disputes.GroupCode = @GroupCode
                AND Disputes.PayrollPeriodEndDate = @PPED
                AND Disputes.SSN = @SSN
                AND DetailRecordID = @DisputeDetailRecordID
    END
