Create PROCEDURE [dbo].[usp_APP_TandemDailyExtract_GetRecs]
(
  @Client varchar(4),
  @GroupCode int,
  @PPED datetime
)
AS
Set NOCOUNT ON

Create Table #tmpReport
(
  RecordID BIGINT,  --< RecordId data type is changed from  INT to BIGINT by Srinsoft on 19Aug2016 >--
  AccountID varchar(80),
  FileNo varchar(20),
  EmplName varchar(80),
  DeptCode varchar(20),
  BillRate numeric(7,2),
  PayRate numeric(7,2),
  ShiftCode int,
  TransType char(1),
  TransDate datetime,
  InSrc varchar(3),
  InDay varchar(3),
  InTime datetime,
  OutSrc varchar(3),
  OutDay varchar(3),
  OutTime datetime,
  AdjCode varchar(3), --< Srinsoft Changed AdjCode char(1) to varchar(3) for clockadjustmentno >--
  AdjName varchar(20),
  TotHours numeric(7,2)
)

DECLARE @CoCode varchar(32)

Set @Client = 'TAND'

-- =============================================
-- Get a list of Groups and PPEDs
-- =============================================
DECLARE cGroups CURSOR
READ_ONLY
FOR 
Select p.GroupCode, p.PayrollPeriodenddate, g.ADP_CompanyCode 
from TimeHistory..tblPeriodenddates as p
inner join TimeCurrent..tblClientGroups as g
on g.Client = p.Client
and g.GroupCode = p.GroupCode
where p.client = @Client
and p.Payrollperiodenddate >= dateadd(day, -16, getdate())
and p.Status <> 'C'

OPEN cGroups

FETCH NEXT FROM cGroups INTO @GroupCode, @PPED, @CoCode
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    Insert into #tmpReport(RecordID,AccountID,FileNo,EmplName,DeptCode,BillRate,PayRate,ShiftCode,TransType,TransDate,InSrc,InDay,InTime,OutSrc,OutDay,OutTime,AdjCode,AdjName,TotHours)
    (Select t.RecordID, s.PayrollUploadCode + '_' + @CoCode + isnull(s.ClientFacility,''),
        en.FileNo, en.LastName + ',' + en.FirstName,
        dept.ClientDeptCode,
        t.BillRate, t.PayRate, t.ShiftNo, 
        TransType = case when t.ClockAdjustmentNo = '' then 'P' else 'A' end,
        t.TransDate,
        case when t.InSrc = '3' then case when isnull(UserCode,'PNE') = '' then 'PNE' else isnull(UserCode,'PNE') end else isnull(src1.srcabrev,'PNE') end, 
        isnull(nDay.DayAbrev,'UNK'), TimeHistory.dbo.PunchDateTime2(t.TransDate, t.InDay, t.InTime),
        case when t.OutSrc = '3' then isnull(OutUserCode,'PNE') else isnull(src2.srcabrev,'') end, 
        isnull(oDay.DayAbrev,'UNK'), TimeHistory.dbo.PunchDateTime2(t.TransDate, t.OutDay, t.OutTime),        
        t.ClockAdjustmentNo, t.AdjustmentName,
        t.Hours
     from TimeHistory..tblTimeHistDetail as t
     Inner Join TimeCurrent..tblEmplnames as en
      on en.Client = t.Client
      and en.groupcode = t.GroupCode
      and en.ssn = t.SSN
     Inner Join TimeCurrent..tblSiteNames as s
      on s.Client = t.Client
      and s.groupcode = t.GroupCode
      and s.SiteNo = t.SiteNo
     Inner Join TimeCurrent..tblGroupDepts as dept
      on dept.Client = t.Client
      and dept.groupcode = t.GroupCode
      and dept.DeptNo = t.DeptNo
     Left Join TimeCurrent..tblInOutSrc as Src1
      on src1.Src = t.InSrc
     Left Join TimeCurrent..tblInOutSrc as Src2
      on src2.Src = t.OutSrc
     Left Join TimeCurrent..tblDayDef as nDay
      on nDay.DayNo = t.InDay
     Left Join TimeCurrent..tblDayDef as oDay
      on oDay.DayNo = t.OutDay
     Where t.Client = @Client
      and t.GroupCode = @GroupCode
      and t.Payrollperiodenddate = @PPED )
  
	END
	FETCH NEXT FROM cGroups INTO @GroupCode, @PPED, @CoCode
END

CLOSE cGroups
DEALLOCATE cGroups

DECLARE @Delim char(1)
Set @Delim = char(9)
 
select 
LineOut = ltrim(str(RecordID)) + @Delim +
  AccountID + @Delim +
  FileNo + @Delim +
  EmplName + @Delim +
  DeptCode + @Delim +
  ltrim(str(BillRate,7,2)) + @Delim +
  ltrim(str(PayRate,7,2)) + @Delim +
  ltrim(str(ShiftCode)) + @Delim +
  TransType + @Delim +
  convert(varchar(8),TransDate, 112) + @Delim +
  ltrim(InSrc) + @Delim +
  ltrim(InDay) + @Delim +
  Case when AdjCode = '' then case when isnull(intime,'') = '' then '190001010000' else convert(varchar(8),InTime, 112) + replace(convert(varchar(5),InTime, 108),':','') end
       Else '' End + @Delim +
  Case when AdjCode = '' then ltrim(OutSrc) else '' end + @Delim +
  Case when AdjCode = '' then ltrim(OutDay) else '' end + @Delim +
  Case when AdjCode = '' then case when isnull(outtime,'') = '' then '190001010000' else convert(varchar(8),OutTime, 112) + replace(convert(varchar(5),OutTime, 108),':','') end
       Else '' End + @Delim +
  AdjCode + @Delim +
  AdjName + @Delim +
  ltrim(str(TotHours,7,2))
from #tmpReport
--Order by FileNo, TransDate, InTime

Drop Table #tmpReport



