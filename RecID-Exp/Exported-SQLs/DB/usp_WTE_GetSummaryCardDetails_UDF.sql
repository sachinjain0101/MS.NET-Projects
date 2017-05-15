CREATE PROCEDURE [dbo].[usp_WTE_GetSummaryCardDetails_UDF] (
  @THDRecordID  BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 16Sept2016 >--
)
AS

--*/

/*
DECLARE  @THDRecordID  int

SET @THDRecordID  = 319838501
*/

SELECT thd.FieldID, thd.FieldValue, defs.FieldDescription, defs.ControlType,
  CASE defs.DropDownMethod WHEN 'Custom' THEN options.OptionDesc WHEN 'PreDef' THEN lookup.LookupDescription END AS OptionDesc
FROM TimeHistory.dbo.tblTimeHistDetail_UDF thd
INNER JOIN TimeCurrent.dbo.tblUDF_FieldDefs defs
ON defs.FieldID = thd.FieldID
LEFT JOIN TimeCurrent.dbo.tblUDF_FieldOptions options
ON options.FieldID = defs.FieldID
  AND options.OptionValue = thd.FieldValue
  AND defs.DropDownMethod = 'Custom'
LEFT JOIN TimeCurrent.dbo.tblValidLookup lookup
ON lookup.LookupType = defs.LookupType
  AND lookup.LookupValue = thd.FieldValue
  AND defs.DropDownMethod = 'PreDef'
WHERE THDRecordID = @THDRecordID
ORDER BY defs.DisplaySeq


