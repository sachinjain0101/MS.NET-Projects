Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_CigTrans_UpdatePunchDetail2.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_CIGTRANS_UPDATEPUNCHDETAIL2.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_CigTrans_UpdatePunchDetail2.sql
  101:  DECLARE @PayType int
  103:  SET @PayType = (select isnull(paytype,0) as paytype from timecurrent..tblemplnames where client = @client and groupcode = @grou
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_CIGTRANS_UPDATEPUNCHDETAIL2.SQL
  100:  DECLARE @PayType int
  102:  SET @PayType = (select isnull(paytype,0) as paytype from timecurrent..tblemplnames where client = @client and groupcode = @grou
*****

