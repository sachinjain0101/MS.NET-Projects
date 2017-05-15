Create PROCEDURE [dbo].[usp_Web1_GetTimeHistDetail_FindDisputeLogs]
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
