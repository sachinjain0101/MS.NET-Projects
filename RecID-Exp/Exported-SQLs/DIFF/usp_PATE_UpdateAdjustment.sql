Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_PATE_UpdateAdjustment.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_PATE_UPDATEADJUSTMENT.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_PATE_UpdateAdjustment.sql
    8:    @PPED        datetime,
    9:    @ClockAdjustmentNo  char(1),
   10:    @AdjType     char(1),
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_PATE_UPDATEADJUSTMENT.SQL
    8:    @PPED        datetime,
    9:    @ClockAdjustmentNo  varchar(3), --< Srinsoft 08/28/2015 Changed  @ClockAdjustmentNo  char(1) to varchar(3) >--
   10:    @AdjType     char(1), 
*****

***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_PATE_UpdateAdjustment.sql
   36:  DECLARE @UserCode     varchar(5)
   37:  DECLARE @THDRecordID  int
   38:  DECLARE @DoDelete                       char(1)
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_PATE_UPDATEADJUSTMENT.SQL
   35:  DECLARE @UserCode     varchar(5)
   36:  DECLARE @THDRecordID  BIGINT  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 26Aug2016 >--
   37:  DECLARE @DoDelete                       char(1)
*****

