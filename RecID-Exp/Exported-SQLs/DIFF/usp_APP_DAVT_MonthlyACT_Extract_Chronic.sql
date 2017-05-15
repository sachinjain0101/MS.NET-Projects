Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql
   54:  having sum(case when t.Inclass = 'S' then 1 else 0 end )  > 1
   56:  DECLARE @RecordID int
   57:  DECLARE @savClockOutTime datetime
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
   53:  having sum(case when t.Inclass = 'S' then 1 else 0 end )  > 1
   55:  DECLARE @RecordID BIGINT  --< @RecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
   56:  DECLARE @savClockOutTime datetime
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql
   60:  DECLARE @ClockOutTime datetime
   61:  DECLARE @savRecordID int
   62:  DECLARE @DiffMins int
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
   59:  DECLARE @ClockOutTime datetime
   60:  DECLARE @savRecordID BIGINT  --< @savRecordID data type is converted from INT to BIGINT by Srinsoft on 02Aug2016 >--
   61:  DECLARE @DiffMins int
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql
   65:  DECLARE @ShiftSegmentID char(1)
   66:  DECLARE @AdjNo varchar(3)
   67:  DECLARE @BreakMins INT
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
   64:  DECLARE @ShiftSegmentID char(1)
   65:  DECLARE @AdjNo char(1)
   66:  DECLARE @BreakMins INT
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql
  245:  DECLARE @FileName varchar(40)
  247:  --Set @FileName = 'DAVT_MonthlyACTFileChronic_' + LTRIM(str(year(@TransStart))) + '_' + ltrim(str(month(@TransStart))) + '.csv'
  249:  Set @FileName = 'DAVT_MonthlyACTFileChronic.csv'
  251:  --CostCenter,EmplID,Name,PrimaryDept,DeptName_Long,PayWeek,TransDate,   Amount,ShiftID
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
  244:  DECLARE @FileName varchar(40)
  246:  Set @FileName = 'DAVT_MonthlyACTFileChronic_' + LTRIM(str(year(@TransStart))) + '_' + ltrim(str(month(@TransStart))) + '.csv'
  248:  --CostCenter,EmplID,Name,PrimaryDept,DeptName_Long,PayWeek,TransDate,   Amount,ShiftID
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql
  255:  DECLARE @JobID INT
  256:  DECLARE @MessageBody VARCHAR(400)
  258:  SET @MessageBody = 'ACT Chronic Monthly extract for ' + DATENAME(MONTH,@TransStart) + ' ' + str(YEAR(@TransStart)) + ' is attac
  259:  hed.'
  262:  INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], 
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
  252:  DECLARE @JobID int
  254:  INSERT INTO [Scheduler].[dbo].[tblJobs]([ProgramName], [TimeRequested], [TimeQued], [TimeStarted], [TimeCompleted],  [Client], 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_APP_DAVT_MonthlyACT_Extract_Chronic.sql
  293:  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  294:  VALUES(@JobID, 'XMAIL','Alexander.Behzadi@davita.com,Nicole.Delphia@davita.com')
  296:  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  297:  VALUES(@JobID, 'ZIPFILE', '1')
  299:  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  300:  VALUES(@JobID, 'MESSAGEBODY', @MessageBody)
  302:  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  303:  VALUES(@JobID, 'SUBJECTLINE', @MessageBody)
  305:  /*
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_APP_DAVT_MONTHLYACT_EXTRACT_CHRONIC.SQL
  285:  INSERT INTO [Scheduler].[dbo].[tblJobs_Parms]([JobID], [ParmKey], [Parm])
  286:  VALUES(@JobID, 'XMAIL','Alexander.Behzadi@davita.com')
  288:  /*
*****

