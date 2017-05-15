Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_HSSS_Upload_GetUploadRecs_Diffs.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_HSSS_UPLOAD_GETUPLOADRECS_DIFFS.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_HSSS_Upload_GetUploadRecs_Diffs.sql
  101:      , [EmpName] = ([en].FirstName+' '+[en].LastName)
  102:      , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_HSSS_UPLOAD_GETUPLOADRECS_DIFFS.SQL
  100:      , [EmpName] = ([en].FirstName+' '+[en].LastName)
  101:      , [FileBreakID]= LTRIM(RTRIM(ISNULL([en].PayGroup,'')))
*****

