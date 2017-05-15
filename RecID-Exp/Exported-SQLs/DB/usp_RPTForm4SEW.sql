CREATE     procedure [dbo].[usp_RPTForm4SEW]
(
  @DateFrom datetime,
  @DateTo datetime,
  @Date datetime,
  @Client varchar(8),
  @Group integer,
  @Report varchar(4),
  @Ref1 varchar(16), 
  @Sites varchar(1024)
)
AS



SET NOCOUNT ON

DECLARE @RC int
DECLARE @FDate datetime
DECLARE @strDateFrom varchar(24)
DECLARE @strDateTo varchar(24)
DECLARE @vStartDate datetime
DECLARE @vEndDate datetime


--Temporary table to store weekly data
create table #temp1 (
	siteNo INT primary key,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
	Shift1 numeric(18,2),
	Shift2 numeric(18,2),
	Shift3 numeric(18,2),
	Gross numeric(18,2),
	SalesTax numeric(18,2),
	Net numeric(18,2),
	TotOper numeric(18,2),
	FoodPdOuts numeric(18,2),
	NetIssues numeric(18,2),
	TotFoodCost numeric(18,2),
	TotFoodAndOp numeric(18,2),
	TotFoodDiv numeric(18,2),
	CashCommPurch numeric(18,2),
	FoodDivComm numeric(18,2),
	BankDeposit numeric(18,2),
	Gratuities numeric(18,2),
	Overrings numeric(18,2),
	InvOverShort numeric(18,2),
	EndInv numeric(18,2),
	DepNet numeric(18,2),
	CashNet numeric(18,2),
	CommShortage numeric(18,2),
	CommOverage numeric(18,2),
	CCTips numeric(18,2),
	CCSls numeric(18,2),
	NoDays smallint)

--Temporary table to store since start of acct period data
create table #temp2 (
	siteNo INT primary key,  --< SiteNo data type is changed from  SMALLINT to INT by Srinsoft on 01Sept2016 >--
	Shift1 numeric(18,2),
	Shift2 numeric(18,2),
	Shift3 numeric(18,2),
	Gross numeric(18,2),
	SalesTax numeric(18,2),
	Net numeric(18,2),
	TotOper numeric(18,2),
	FoodPdOuts numeric(18,2),
	NetIssues numeric(18,2),
	TotFoodCost numeric(18,2),
	TotFoodAndOp numeric(18,2),
	TotFoodDiv numeric(18,2),
	CashCommPurch numeric(18,2),
	FoodDivComm numeric(18,2),
	BankDeposit numeric(18,2),
	Gratuities numeric(18,2),
	Overrings numeric(18,2),
	InvOverShort numeric(18,2),
	EndInv numeric(18,2),
	DepNet numeric(18,2),
	CashNet numeric(18,2),
	CommShortage numeric(18,2),
	CommOverage numeric(18,2),
	CCTips numeric(18,2),
	CCSls numeric(18,2),
	NoDays smallint)

 
select @FDate = DATEADD(dd,-6,@Date)
-- Get data for the week
insert into #temp1
exec [TimeHistory].[dbo].[usp_RPTForm4DailySales] @FDate, @Date, @Date, @Client, @Group, @Report, NULL, @Sites, @Date

-- If @Ref1 is null 
-- then get the correct period date

if @Ref1 is null or @Ref1 = 'XX/XXXX'
BEGIN

	IF @Date < '4/29/2004'
		SET @Ref1 = Replace(str(Floor((datediff(d, '06/01/2000', @Date) % (13 * 28)) / 28) + 1, 2) + '/' + str(2001 + floor(datediff(d, '06/01/2000', @Date) / (13 * 28)), 4), ' ', '0')
	ELSE IF @Date between '4/29/2004' and '6/02/2004'
		SET @Ref1 = '13/2004'
	ELSE
		SET @Ref1 = Replace(str(Floor((datediff(d, '06/03/2004', @Date) % (13 * 28)) / 28) + 1, 2) + '/' + str(2005 + floor(datediff(d, '06/03/2004', @Date) / (13 * 28)), 4), ' ', '0')

END

-- Get data for the fiscal period
insert into #temp2

exec [TimeHistory].[dbo].[usp_RPTForm4DailySales] null, null, NULL, @Client, @Group, @Report, @Ref1, @Sites, @Date

-- Get POS Void Data. 
--
-- If we have a Ref1 field ( Waffle House Period ) then convert 
-- the Period into From and To Dates that can be used in the query
EXEC usp_RPTGetWafflePeriodDates @Ref1, @strDateFrom OUTPUT, @strDateTo OUTPUT
IF @Date is NOT NULL
  Select @strDateTo =  convert(varchar(12), @Date  , 101)

Set @vStartDate = @strDateFrom
Set @vEndDate = @strDateTo

/*
select s.SiteNo, 
  wkVoids = Sum(case when v.TransDate >= @FDate and v.TransDate <= @Date then v.VoidAmount else 0.00 end),
  perVoids = Sum(case when v.TransDate >= @vStartDate and v.TransDate <= @vEndDate then v.VoidAmount else 0.00 end)
into #tmp3
from timecurrent..tblSiteNames as s
Inner Join Waffdb1.POS.dbo.tblStats as v
  on v.Client = s.Client
  and v.groupcode = s.groupcode
  and v.siteno = s.siteno
where
  s.client = @Client
  and s.groupcode = @Group
  and s.recordstatus = '1'
  and v.TransDate >= @vStartDate
  and v.TransDate <= @vEndDate 
group by s.siteno
*/

select
	a.siteNo,
	a.Shift1,
	a.Shift2,
	a.Shift3,
	a.Gross ,
	a.SalesTax,
	a.Net ,
	a.TotOper,
	a.FoodPdOuts,
	a.NetIssues ,
	a.TotFoodCost ,
	a.TotFoodAndOp,
	a.TotFoodDiv ,
	a.CashCommPurch ,
	a.FoodDivComm ,
	a.BankDeposit ,
	a.Gratuities ,
	a.Overrings ,
	a.InvOverShort ,
	a.EndInv ,
	a.DepNet ,
	a.CashNet ,
	a.CommShortage ,
	a.CommOverage ,
	a.NoDays,
	b.CashNet as CummCashNet,
	b.commShortage as CummCommShortage,
	b.CommOverage as CummCommOverage,
	b.Overrings as CummOverrings,
  b.CCSls,b.Gross, CCPerc = Case when b.Gross <> 0 then round( b.CCSls / b.Gross, 4) * 100 else 0.00 end
  
--  wkVoids = 0.00, --isnull(c.wkVoids,0.00),
--  perVoids = 0.00 --isNULL(c.perVoids,0.00)

from #temp1 as a
inner join #temp2 as b
on a.siteno = b.siteno
--left join #tmp3 as c
--on c.siteno = a.siteno
Inner Join TimeCurrent..tblSiteNames as s
on s.Client = @Client
and s.GroupCode = @Group
and s.SiteNo = a.SiteNo
and s.RecordStatus = '1'

drop table #temp1
drop table #temp2
--drop table #tmp3






