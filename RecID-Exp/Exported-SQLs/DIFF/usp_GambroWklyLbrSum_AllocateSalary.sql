Comparing files C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_GambroWklyLbrSum_AllocateSalary.sql and C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_GAMBROWKLYLBRSUM_ALLOCATESALARY.SQL
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\DB\usp_GambroWklyLbrSum_AllocateSalary.sql
  101:    and thd.SSN IN(       select Distinct a.SSN 
  102:                  from timecurrent..tblEmplAllocation as a
***** C:\PROJECTS\RECID-EXP\EXPORTED-SQLS\TFS\USP_GAMBROWKLYLBRSUM_ALLOCATESALARY.SQL
  100:    and thd.SSN IN(       select Distinct a.SSN 
  101:                  from timecurrent..tblEmplAllocation as a
*****

