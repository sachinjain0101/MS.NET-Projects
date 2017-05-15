CREATE PROCEDURE [dbo].[usp_Web1_GetTHDCustomFieldValue] 
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime,
  @SSN int,
  @TransDate datetime,
  @THDRecordId BIGINT,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 09Sept2016 >--
  @FieldId int
)

AS

--*/

DECLARE @OutTimeStamp bigint
Set @OutTimeStamp = (select isnull(outTimestamp,0) from TimeHistory..tblTimeHistDetail with (nolock) where RecordID = @THDRecordId )

IF @OutTimeStamp = 0
  Set @OutTimeStamp = 1

SELECT RecordId,FieldValue
FROM TimeHistory..tblTimeHistDetail_UDF
WHERE THDRecordId = @THDRecordId
AND FieldId = @FieldId
union 
Select RecordID, FieldValue 
FROM TimeHistory..tblTimeHistDetail_UDF
WHERE Client = @Client
and GroupCode = @GroupCode 
and Payrollperiodenddate = @PPED
and SSN = @SSN
and TransDate = @TransDate 
AND FieldId = @FieldId
and isnull(PunchTimeStamp,0) = @OutTimeStamp 



