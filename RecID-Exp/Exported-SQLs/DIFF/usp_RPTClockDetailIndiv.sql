Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_RPTClockDetailIndiv.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_RPTCLOCKDETAILINDIV.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_RPTClockDetailIndiv.sql
  301:  rCode ELSE OutSrc.SrcAbrev END), " + @crlf
  302:  SELECT @SelectString = @SelectString +  "OutDay = CASE WHEN THD.OutDay = 10 THEN '0' ELSE THD.OutDay END, " + @crlf
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_RPTCLOCKDETAILINDIV.SQL
  300:  rCode ELSE OutSrc.SrcAbrev END), " + @crlf
  301:  SELECT @SelectString = @SelectString +  "OutDay = CASE WHEN THD.OutDay = 10 THEN '0' ELSE THD.OutDay END, " + @crlf
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_RPTClockDetailIndiv.sql
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_RPTCLOCKDETAILINDIV.SQL
  655:  GO
*****

