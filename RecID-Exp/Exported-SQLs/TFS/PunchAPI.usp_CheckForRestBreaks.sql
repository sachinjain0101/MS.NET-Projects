Create PROCEDURE [PunchAPI].[usp_CheckForRestBreaks]
(
  @Client VARCHAR(4) ,
  @Groupcode INT ,
  @SSN INT ,
  @OutTime DATETIME,
  @thdRecordId BIGINT  --< @thdRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >-- 
)
AS
SET NOCOUNT ON

DECLARE @PPED DATETIME 
DECLARE @TransDate DATETIME
DECLARE @RestBreaks INT
    
SELECT
      @PPED = Payrollperiodenddate ,
      @Transdate = TransDate,
      @RestBreaks = BillOTRate
FROM TImeHistory.dbo.tblTimeHistDetail (NOLOCK)
WHERE
  CLient = @Client
  AND groupcode = @Groupcode
  AND ssn = @SSN
  AND PayrollPeriodEndDate >= DATEADD(DAY,-14,GETDATE())
  AND ActualOutTime = @OutTime
  AND clockadjustmentNo in('',' ')
  AND recordid >= @thdRecordID

SET @RestBreaks = ISNULL(@RestBreaks,0)

SELECT 
RequiredRestBreaks = @RestBreaks
,displayMessage = 'You were required to take ' + LTRIM(STR(@RestBreaks)) + ' rest break' + CASE WHEN @RestBreaks > 1 THEN 's' ELSE '' END 
,displayLabel = 'Enter number of rest breaks missed.'
