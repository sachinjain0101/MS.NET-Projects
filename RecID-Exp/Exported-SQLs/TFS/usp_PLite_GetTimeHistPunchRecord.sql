Create PROCEDURE [dbo].[usp_PLite_GetTimeHistPunchRecord] (
     @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
)

AS

SELECT *
FROM tblTimeHistDetail
WHERE RecordID = @RecordID





