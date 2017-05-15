Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_ADVO.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_ADVO.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GenericPayrollUpload_GetRecs_ADVO.sql
  101:          BEGIN
  102:      Set @Rate = (Select DiffRate from TimeCurrent..tblDeptShiftDiffs where client = @Client
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GENERICPAYROLLUPLOAD_GETRECS_ADVO.SQL
  100:          BEGIN
  101:      Set @Rate = (Select DiffRate from TimeCurrent..tblDeptShiftDiffs where client = @Client
*****

