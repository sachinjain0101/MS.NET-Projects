CREATE  Procedure [dbo].[usp_APP_ShiftDiff_GetTHD]
(
  @RecordID BIGINT,  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 18Aug2016 >--
  @UseEmplLevelRates char(1)
)
as


if @UseEmplLevelRates = '1'
Begin
  select thd.*,
  enPayRate = CASE WHEN en.PayRate > 0 THEN en.PayRate
              ELSE ISNULL(gd.PayRate,0.00) END
  from tblTimeHistDetail as thd
  INNER JOIN TimeCurrent..tblGroupDepts gd
  ON thd.Client = gd.Client
  AND thd.GroupCode = gd.GroupCode
  AND thd.DeptNo = gd.DeptNo
  Inner Join TimeCurrent..tblEmplNames as en
    on en.Client = thd.Client
    and en.Groupcode = thd.GroupCode
    and en.SSN = thd.SSN
    and en.RecordStatus = '1'
  where thd.RecordID = @RecordID
End
Else
Begin
  select thd.*, 
  enPayRate = CASE WHEN hed.PayRate > 0 THEN hed.PayRate
                   WHEN ed.PayRate > 0 THEN ed.PayRate
                   ELSE ISNULL(gd.PayRate,0.00) END
--  enPayRate = (CASE WHEN hed.PayRate = 0 THEN isnull(ed.PayRate,0.00) Else isNull(hed.PayRate,0.00) End)
  from tblTimeHistDetail as thd
  INNER JOIN TimeCurrent..tblGroupDepts gd
  ON thd.Client = gd.Client
  AND thd.GroupCode = gd.GroupCode
  AND thd.DeptNo = gd.DeptNo
  Left Join tblEmplNames_Depts as hed
  on hed.Client = thd.Client
  and hed.Groupcode = thd.GroupCode
  and hed.Department = thd.DeptNo
  and hed.SSN = thd.SSN
  and hed.PayrollperiodEndDate = thd.Payrollperiodenddate
  Left Join TimeCurrent..tblEmplNames_Depts as ed
  on ed.Client = thd.Client
  and ed.Groupcode = thd.GroupCode
  and ed.Department = thd.DeptNo
  and ed.SSN = thd.SSN
  and ed.RecordStatus = '1'
  where thd.RecordID = @RecordID
End













