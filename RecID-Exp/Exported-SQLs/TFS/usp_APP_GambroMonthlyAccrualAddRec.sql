Create PROCEDURE [dbo].[usp_APP_GambroMonthlyAccrualAddRec] 
(
  @Client char(4),
  @GroupCode int, 
  @SSN int, 
  @MPD varchar(6),
  @Modality char(1),
  @SiteNo int,
  @EmplNo int,
  @PayCode varchar(12),
  @Hours numeric(5,2),
  @Rate numeric(7,4),
  @Dollars numeric(7,2),
  @ChargeToSite int,
  @ChargeToModality char(1),
  @JobCode varchar(10),
  @DeptNo INT,  --< @DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 03Aug2016 >--
  @AgencyNo smallint,
  @GLType char(1)
)
AS

DECLARE @newMPD datetime
Select @NewMPD = substring(@MPD,1,2) + '/' + substring(@MPD,3,2) + '/' + substring(@MPD,5,2)

INSERT INTO [TimeHistory].[dbo].[tblGambroUploads]([Client], [GroupCode], [MasterPayrollDate], [DataClass], 
[Frequency], [SiteWorkedAt], [HomeSite], [HomeGambroDept], 
[SSN], [EmpNo], [PayCode], [Hours], [Rate], [Dollars], [SiteChargedTo], [GambroDeptChargedTo], 
[JobCode], [DeptNo], [AgencyNo])
VALUES(@Client, @GroupCode, @NewMPD, 'MNTHACC '+ @GLType,'M',@SiteNo,@SiteNo,@Modality,@SSN,@EmplNo,substring(@PayCode,1,3),
       @Hours,@Rate, @Dollars, @ChargeToSite, @ChargeToModality, @JobCode, @DeptNo,@AgencyNo)






