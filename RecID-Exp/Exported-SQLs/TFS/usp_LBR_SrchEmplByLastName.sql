Create PROCEDURE [dbo].[usp_LBR_SrchEmplByLastName]
(
	
	@Client varchar(4),
	@GroupCode int,
	@SiteNo int,
	@LastName varchar(50),
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

	WHERE Site.Client = @Client
	AND Site.GroupCode = @GroupCode
	AND Site.SiteNo = @SiteNo
	AND Empl.status <> 9
	AND Empl.RecordStatus = 1
	AND EmplSites.RecordStatus = 1
	AND EmplSites.status <> 9
	AND Empl.LastName like @LastName


DECLARE cEmpls CURSOR STATIC 
FOR SELECT RecordID,SSN 
FROM @empls

OPEN cEmpls
FETCH NEXT FROM cEmpls INTO @recordID,@SSN
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		SELECT @JobCode = Jobs.JobCode, 
		       @CellCode = JobCellEmpls.cellcode
		FROM timehistory..tblStdJobCellEmployees JobCellEmpls
		INNER JOIN timehistory..tblstdJobs Jobs
		ON JobCellEmpls.JobID = Jobs.JobID
		WHERE EndDateTime IS NULL
		AND EffectiveDateTime between dateadd(mi, @MissingpunchThreshold, TimeCurrent.dbo.TimeConverterFromEST(getdate(), @TimeZone)) and TimeCurrent.dbo.TimeConverterFromEST(getdate(), @TimeZone)
		AND JobCellEmpls.SSN = @SSN
		
		IF @JobCode IS NOT NULL -- Assigned in other standard department
	           BEGIN
			UPDATE  @empls
			SET Status = 'OTHER_STD'
			,  JobCode = @JobCode
			,  CellCode = @CellCode
			WHERE RecordID = @recordID
		   END
		ELSE		 
		   BEGIN
			SELECT @RowCnt = COUNT(*)
			FROM timehistory..tblTimeHistDetail HIST
			INNER JOIN TimeCurrent..tblEmplNames EMPLS2
			ON EMPLS2.Client = HIST.Client
			AND EMPLS2.GroupCode = HIST.GroupCode
			AND EMPLS2.SSN = HIST.SSN
			INNER JOIN TimeCurrent..tblGroupDepts DEPT
			ON EMPLS2.Client = DEPT.Client
			AND EMPLS2.GroupCode = DEPT.GroupCode
			AND EMPLS2.primaryDept = DEPT.DeptNo
			INNER JOIN TimeCurrent..tblGroupDepts DEPT2
			ON HIST.Client = DEPT2.Client
			AND HIST.GroupCode = DEPT2.GroupCode
			AND HIST.DeptNo = DEPT2.DeptNo
			WHERE HIST.client = @Client
			AND HIST.GroupCode = @GroupCode
			AND HIST.siteNo = @SiteNo
			AND HIST.ActualInTime between dateadd(mi, @MissingpunchThreshold, TimeCurrent.dbo.TimeConverterFromEST(getdate(), @TimeZone)) and TimeCurrent.dbo.TimeConverterFromEST(getdate(), @TimeZone)
			AND HIST.ClockAdjustmentNo = ' '
			AND HIST.payrollperiodenddate >= Convert(varchar,getdate(),101)
			AND HIST.ActualInTime is not null
			AND HIST.ActualOutTime is null
			AND ISNULL(DEPT.MasterDept,'') = 'STD_HN'
			AND ISNULL(DEPT2.MasterDept,'') not like 'STD%'
			AND Empls2.SSN = @SSN
			GROUP BY  EMPLS2.SSN, HIST.GroupCode,HIST.deptNo,DEPT2.ClientDeptCode,DEPT2.DeptName, HIST.SSN,HIST.payrollperiodenddate
			HAVING MAX(ActualInTime) >= MAX(Isnull(ActualOutTime,'1899-01-01'))
		   	
			IF @RowCnt > 0  -- Assigned in a off-standard department 
			   BEGIN
				UPDATE  @empls
				SET Status = 'OFF_STD'
				,  JobCode = 'OFF_STD'
				,  CellCode = 'OFF_STD'
				WHERE RecordID = @recordID
			   END
			ELSE
			   BEGIN	
			   	SELECT @RowCnt = COUNT(*)
			   	FROM timehistory..tblTimeHistDetail HIST
			  	INNER JOIN TimeCurrent..tblEmplNames EMPLS2
			   	ON EMPLS2.Client = HIST.Client
			   	AND EMPLS2.GroupCode = HIST.GroupCode
			   	AND EMPLS2.SSN = HIST.SSN
			   	INNER JOIN TimeCurrent..tblGroupDepts DEPT
			   	ON EMPLS2.Client = DEPT.Client
			   	AND EMPLS2.GroupCode = DEPT.GroupCode
			   	AND EMPLS2.primaryDept = DEPT.DeptNo
			   	INNER JOIN TimeCurrent..tblGroupDepts DEPT2
			   	ON HIST.Client = DEPT2.Client
			   	AND HIST.GroupCode = DEPT2.GroupCode
			   	AND HIST.DeptNo = DEPT2.DeptNo
			   	WHERE HIST.client = @Client
			   	AND HIST.GroupCode = @GroupCode
			   	AND HIST.siteNo = @SiteNo
			   	AND HIST.ActualInTime between dateadd(mi, @MissingpunchThreshold, TimeCurrent.dbo.TimeConverterFromEST(getdate(), @TimeZone)) and TimeCurrent.dbo.TimeConverterFromEST(getdate(), @TimeZone)
			   	AND HIST.ClockAdjustmentNo = ' '
			   	AND HIST.payrollperiodenddate >= Convert(varchar,getdate(),101)
			   	AND HIST.ActualInTime is not null
			   	AND HIST.ActualOutTime is null
			   	AND ISNULL(DEPT.MasterDept,'') = 'STD_HN'
			   	AND ISNULL(DEPT2.MasterDept,'') = 'STD_HN'
			   	AND Empls2.SSN = @SSN
			   	GROUP BY  EMPLS2.SSN, HIST.GroupCode,HIST.deptNo,DEPT2.ClientDeptCode,DEPT2.DeptName, HIST.SSN,HIST.payrollperiodenddate
			   	HAVING MAX(ActualInTime) >= MAX(Isnull(ActualOutTime,'1899-01-01'))	   	
		   	   
			   	IF @RowCnt > 0
				   BEGIN
					UPDATE  @empls
					SET Status = 'AIN'
					,  JobCode = 'AIN'
					,  CellCode = 'AIN'
					WHERE RecordID = @recordID	
				   END
			   	ELSE
				   BEGIN
					UPDATE  @empls
					SET Status = 'ANI'
					,  JobCode = 'ANI'
					,  CellCode = 'ANI'
					WHERE RecordID = @recordID
				   END	
    			   END
		     END	
			

		
		
	END -- end fetch status <> -2
	FETCH NEXT FROM cEmpls INTO @recordID,@SSN
END -- fetch status <> -1
CLOSE cEmpls
DEALLOCATE cEmpls
SELECT * 
FROM @empls






