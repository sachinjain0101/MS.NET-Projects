Create PROCEDURE [dbo].[usp_APP_DaviClose_EmpsSalMissPunches]
(
	@Client 	VARCHAR(4),
	@GroupCode 	INT,
	@PPED		datetime )

AS
--*/
/* Debugging

DECLARE @Client VARCHAR(8)
DECLARE @GroupCode INT
DECLARE @PPED datetime

SELECT @Client = 'DAVI'
SELECT @GroupCode = 308500
SELECT @PPED = '1/26/02'

*/

SET NOCOUNT ON

DECLARE @PPED1 datetime
DECLARE @SSN int
DECLARE @PayrollPeriodEndDate datetime
DECLARE @InDay int
DECLARE @OutDay int
DECLARE @THDRecordId BIGINT  --< @thdRecordID data type is converted from INT to BIGINT by Srinsoft on 01Aug2016 >--
SELECT @PPED1 = dateadd(day, -7, @PPED)

-- First of all, see if we can flip some of them to regular missing punches
DECLARE empCursor CURSOR READ_ONLY
FOR SELECT 	SSN,	
						PayrollPeriodEndDate,
						InDay,
						OutDay,
						RecordId
		FROM TimeHistory..tblTimeHistDetail
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate IN (@PPED, @PPED1)
		AND (InDay = 11 OR OutDay = 11)
OPEN empCursor

FETCH NEXT FROM empCursor INTO @SSN, @PayrollPeriodEndDate, @InDay, @OutDay, @THDRecordId
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		IF (@InDay = 11)
		BEGIN
			UPDATE TimeHistory.dbo.tblTimeHistDetail
			SET InDay = 10
			WHERE Recordid = @THDRecordId
		END	
		ELSE IF (@OutDay = 11)
		BEGIN
			UPDATE TimeHistory.dbo.tblTimeHistDetail
			SET OutDay = 10
			WHERE Recordid = @THDRecordId
		END
		
		UPDATE TimeHistory.dbo.tblEmplNames
		SET MissingPunch = '1'
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND PayrollPeriodEndDate = @PayrollPeriodEndDate
		AND SSN = @SSN
		AND MissingPunch <> '1'

	END
	FETCH NEXT FROM empCursor INTO @SSN, @PayrollPeriodEndDate, @InDay, @OutDay, @THDRecordId
END
CLOSE empCursor
DEALLOCATE empCursor


-- Check to see if there are any remaining, there shouldn't be
SELECT DISTINCT e.SSN, 
								e.firstName + ',' + e.lastName empName, 
								e.payrollperiodenddate
FROM TimeHistory..tblTimeHistDetail as th
INNER JOIN TimeHistory..tblEmplNames as e
ON e.client = th.client
AND e.groupcode = th.groupcode
AND e.ssn = th.ssn
AND e.PayrollPeriodEndDate = th.PayrollPeriodEndDate
WHERE th.Client = @Client
AND th.GroupCode = @GroupCode
AND th.PayrollperiodEndDate IN (@PPED, @PPED1)
AND (th.Inday = 11 OR th.Outday = 11 )


