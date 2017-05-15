Create PROCEDURE [Reports].[rpt_GetTimecardApprovers_Approver]

	@DetailRecordId BIGINT  --< @DetailRecordID data type is converted from INT to BIGINT by Srinsoft on 28July2016 >--
	, @FrequencyId int = 2

AS

SELECT
	thd.RecordID
	, sn.SiteName
	, gd.DeptName
	, thd.AprvlStatus
	, thd.AprvlStatus_Date
	, thd.AprvlStatus_UserID
	, u.UserID
	, COALESCE(ba.FirstName, u.FirstName, '') AS FirstName
	, COALESCE(ba.LastName, u.LastName, '') AS LastName
	, COALESCE(ba.Email, u.Email, '') AS Email
	, CASE WHEN thd.AprvlStatus_UserID = u2.UserID THEN u2.AltUserID ELSE '' END AS OverrideApproverName

FROM 
	TimeHistory..tblTimeHistDetail thd

	JOIN TimeCurrent..tblUser u 
		ON ISNULL(thd.AprvlStatus_UserID, 0) = u.UserID

	LEFT JOIN TimeCurrent.dbo.tblSiteNames sn 
		ON  sn.Client = thd.Client 
		AND sn.GroupCode = thd.GroupCode	
		AND sn.SiteNo = thd.SiteNo
	
	LEFT JOIN TimeCurrent.dbo.tblGroupDepts gd 
		ON  gd.Client = thd.Client	
		AND gd.GroupCode = thd.GroupCode 
		AND gd.DeptNo = thd.DeptNo
	
	LEFT JOIN tblTimeHistDetail_BackupApproval ba
		ON thd.RecordId = ba.THDRecordId

	LEFT JOIN TimeCurrent..tblUser u2
		ON u2.Client = thd.Client
		AND u2.JobDesc = 'FAXAROO_DEFAULT_APPROVER'

WHERE 
	thd.RecordID = @DetailRecordId
		
	


