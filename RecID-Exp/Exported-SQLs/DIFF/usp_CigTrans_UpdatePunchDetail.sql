Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_CigTrans_UpdatePunchDetail.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_CIGTRANS_UPDATEPUNCHDETAIL.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_CigTrans_UpdatePunchDetail.sql
  101:  SET @PayType = (select isnull(paytype,0) as paytype from timecurrent..tblemplnames where client = @client and groupcode = @grou
  102:  pcode and ssn = @ssn and recordstatus = '1')
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_CIGTRANS_UPDATEPUNCHDETAIL.SQL
  100:  SET @PayType = (select isnull(paytype,0) as paytype from timecurrent..tblemplnames where client = @client and groupcode = @grou
  101:  pcode and ssn = @ssn and recordstatus = '1')
*****

