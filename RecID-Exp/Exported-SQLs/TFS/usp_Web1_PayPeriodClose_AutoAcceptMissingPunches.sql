Create PROCEDURE [dbo].[usp_Web1_PayPeriodClose_AutoAcceptMissingPunches]
(
  @Client varchar(4),
  @Groupcode int,
  @SiteNo INT,
  @PPED datetime
)
AS
SET NOCOUNT ON

DECLARE @MissingPunchAlertId INT
DECLARE @AcceptanceCriteria VARCHAR(100)

CREATE TABLE #tmpMissingPunches
(
    THDRecordId BIGINT,  --< THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 14Sept2016 >--
	SSN INT,
	SiteNo INT,
	DeptNo INT,
	PunchTime DATETIME,
	MissingPunchType VARCHAR(10) 
)
SET @MissingPunchAlertId = 0

SELECT @MissingPunchAlertId = CASE WHEN ISNULL(mpa_client.RecordStatus,'0') = '1' AND mpa_group.RecordId IS NULL THEN mpa_client.RecordId
            WHEN ISNULL(mpa_group.RecordStatus,'0') = '1' THEN mpa_group.RecordId END
FROM TimeCurrent..tblClients c
INNER JOIN TimeCurrent..tblClientGroups cg
ON cg.Client = c.Client
LEFT JOIN TimeCurrent..tblMissingPunchAlert mpa_client
ON c.MissingPunchAlertId = mpa_client.RecordId
LEFT JOIN TimeCurrent..tblMissingPunchAlert mpa_group
ON cg.MissingPunchAlertId = mpa_group.RecordId
WHERE cg.Client = @Client
AND cg.GroupCode = @Groupcode

IF @MissingPunchAlertId <> 0
BEGIN
	SELECT @AcceptanceCriteria = mpac.AcceptanceCriteriaText
	FROM TimeCurrent..tblMissingPunchAcceptanceCriteria mpac
	INNER JOIN TimeCurrent..tblMissingPunchAlert mpa
	ON mpac.RecordId = mpa.AcceptanceCriteriaId
	WHERE mpa.RecordId = @MissingPunchAlertId

	IF @AcceptanceCriteria = 'Auto Accept at Close'
	BEGIN
	    INSERT INTO #tmpMissingPunches
		SELECT thd.RecordID, thd.SSN, thd.SiteNo, thd.DeptNo,
		       CASE WHEN fpbe.InDateTime IS NOT NULL THEN fpbe.InDateTime ELSE fpbe.OutDateTime END,
			   CASE WHEN fpbe.InDateTime IS NOT NULL THEN 'I' ELSE 'O' END
		FROM TimeHistory..tblTimeHistDetail thd
		INNER JOIN TimeHistory..tblFixedPunchByEE fpbe
		ON fpbe.RecordID = thd.RecordID
		WHERE thd.Client = @Client
		AND thd.GroupCode = @Groupcode
		AND thd.PayrollPeriodEndDate = @PPED
		AND (thd.InDay IN (10,11) OR thd.OutDay IN (10,11))
	END
END

SELECT *
FROM #tmpMissingPunches

