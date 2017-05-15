Create PROCEDURE [dbo].[usp_LBR_SrchEmpls]
(
	@JobID int,
	@Client varchar(4),
	@GroupCode int,
	@SiteNo int,
	@MissingpunchThreshold int	
)
AS

DECLARE @empls TABLE
(
	RecordID int not null,
	EmplPIN int null,
	PrimaryDept INT not null,  --< PrimaryDept data type is changed from  SMALLINT to INT by Srinsoft on 25Aug2016 >--
	DeptNo INT not null,  --< DeptNo data type is changed from  SMALLINT to INT by Srinsoft on 25Aug2016 >--
	SSN int not null,
	EmplName varchar(200) null,
	Status char(10) null,
	JobCode varchar(40) null,
	CellCode varchar(20) null
)
DECLARE @recordID int
DECLARE @SSN int
DECLARE @TimeZone varchar(3)
DECLARE @CellCode varchar(20)
DECLARE @JobCode varchar(40)
DECLARE @RowCnt int

	INSERT INTO @empls
	SELECT Empl.RecordID,Empl.EmplPIN, Empl.primaryDept, ' ' as DeptNo, Empl.SSN,
	(Isnull(Empl.LastName,'') + ', ' + Isnull(Empl.FirstName,'')) + ' (' + RIGHT(Empl.SSN,4) +')' as EmplName,' ',' ',' '
	FROM TimeCurrent..tblEmplNames Empl
	
	INNER JOIN TimeCurrent..tblEmplSites EmplSites
	ON Empl.SSN = EmplSites.SSN
	and Empl.Client = EmplSites.Client
	and Empl.GroupCode = EmplSites.GroupCode
	
	INNER JOIN TimeCurrent..tblSiteNames Site
	ON EmplSites.Client = Site.Client
	AND EmplSites.GroupCode = Site.GroupCode
	AND EmplSites.SiteNo = Site.SiteNo

	INNER JOIN TimeCurrent..tblGroupDepts DEPT
	ON EmplSites.Client = DEPT.Client
	AND EmplSites.GroupCode = DEPT.GroupCode
	AND Empl.primaryDept = DEPT.DeptNo


	WHERE Site.Client = @Client
	AND Site.GroupCode = @GroupCode
	AND Site.SiteNo = @SiteNo
	AND Empl.status <> 9
	AND Empl.RecordStatus = 1
	AND EmplSites.RecordStatus = 1
	AND EmplSites.status <> 9
	AND DEPT.MasterDept = 'STD_HN'


DECLARE cEmpls CURSOR STATIC 
FOR SELECT RecordID,SSN 
FROM @empls

OPEN cEmpls
FETCH NEXT FROM cEmpls INTO @recordID,@SSN
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		SELECT @RowCnt = COUNT(*) 
		FROM TimeHistory..tblstdJobCellEmployees
		WHERE Client = @Client
		AND GroupCode = @GroupCode
		AND SiteNo = @SiteNo
		AND SSN = @SSN
		AND JobID = @JobID

		
		
		
		IF @RowCnt > 0  -- Assigned in standard department
	           BEGIN
			UPDATE  @empls
			SET Status = 'A'
			,  JobCode = ' '
			,  CellCode = ' '
			WHERE RecordID = @recordID
		   END
		ELSE		 
		   BEGIN
			UPDATE  @empls
			SET Status = 'NA'
			,  JobCode = ' '
			,  CellCode = ' '
			WHERE RecordID = @recordID
		   END	
	END -- end fetch status <> -2
	FETCH NEXT FROM cEmpls INTO @recordID,@SSN
END -- fetch status <> -1
CLOSE cEmpls
DEALLOCATE cEmpls
SELECT * 
FROM @empls
ORDER BY EmplName









