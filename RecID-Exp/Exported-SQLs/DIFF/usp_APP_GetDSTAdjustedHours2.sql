Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GetDSTAdjustedHours2.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GETDSTADJUSTEDHOURS2.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_GetDSTAdjustedHours2.sql
  101:          --there is still a problem if txn splits at sometime between 1am and 2am.
  103:      select @DSTAdjustedHours = @numhours
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_GETDSTADJUSTEDHOURS2.SQL
  100:          --there is still a problem if txn splits at sometime between 1am and 2am.
  102:      select @DSTAdjustedHours = @numhours
*****

