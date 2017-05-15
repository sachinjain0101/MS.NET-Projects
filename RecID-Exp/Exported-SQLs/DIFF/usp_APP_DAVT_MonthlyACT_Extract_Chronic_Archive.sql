Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic_Archive.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC_ARCHIVE.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic_Archive.sql
   54:  having sum(case when t.Inclass = 'S' then 1 else 0 end )  > 1
   56:  DECLARE @RecordID int
   57:  DECLARE @savClockOutTime datetime
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC_ARCHIVE.SQL
   53:  having sum(case when t.Inclass = 'S' then 1 else 0 end )  > 1
   55:  DECLARE @RecordID BIGINT  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >--
   56:  DECLARE @savClockOutTime datetime
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic_Archive.sql
   60:  DECLARE @ClockOutTime datetime
   61:  DECLARE @savRecordID int
   62:  DECLARE @DiffMins int
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC_ARCHIVE.SQL
   59:  DECLARE @ClockOutTime datetime
   60:  DECLARE @savRecordID BIGINT  --< @savRecordId data type is changed from  INT to BIGINT by Srinsoft on 25Nov2016 >--
   61:  DECLARE @DiffMins int
*****

