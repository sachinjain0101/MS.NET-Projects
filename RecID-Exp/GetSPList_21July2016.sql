																
			--Adding newly identified tables/fields to the SQL Script													
			--USE TimeCurrent													
			USE TimeHistory													
			--Creating the Temp table with Table and Column Names													
				Create table #temp(SlNo int Identity(1,1), ColumnName VARCHAR(500), TableName VARCHAR(500))												
				--Inserting the dependent Table and Column names into temp table												
				insert into #temp(ColumnName,TableName) values('%OrigRecordID%','%tblFixedPunch%')												
				insert into #temp(ColumnName,TableName) values('%OrigRecordID%','%tblFixPunchAudit%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblAdjustments%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblCigTransLog%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblEmplMissingPunchAlert%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblNotificationMessage%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblPATETxn%')												
				insert into #temp(ColumnName,TableName) values('%AprvlAdjOrigRecID%','%tblTimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%RecordId%','%tblTimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblKronosPunchExport%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblKronosPunchExport_Audit%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblStaffingApproval_THD%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblTimeHistDetail_BackupApproval%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblTimeHistDetail_PATE%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblTimeHistDetail_UDF%')												
				insert into #temp(ColumnName,TableName) values('%THDRecordID%','%tblWork_KronosExport%')												
				insert into #temp(ColumnName,TableName) values('%FromRecordID%','%tblTimeHistDetail_Crossover%')												
				insert into #temp(ColumnName,TableName) values('%ToRecordID%','%tblTimeHistDetail_Crossover%')												
				insert into #temp(ColumnName,TableName) values('%DetailRecordID%','%tblTimeHistDetail_Disputes%')												
				insert into #temp(ColumnName,TableName) values('%THD_RecordId%','%tblTimeHistDetail_Faxaroo%')												
				insert into #temp(ColumnName,TableName) values('%AdjustmentRecordID%','%tblTimeHistDetail_Reasons%')												
				insert into #temp(ColumnName,TableName) values('%RecordID%','%tblTimeHistDetail_Partial%')												
				insert into #temp(ColumnName,TableName) values('%AprvlAdjOrigRecID%','%tblTimeHistDetail_Partial%')												
				insert into #temp(ColumnName,TableName) values('%InOutId%','%tblWTE_Spreadsheet_Breaks%')												
				------Newly Identified Table---------------------												
				insert into #temp(ColumnName,TableName) values('%RecordId%','%tblFixedPunchByEE%')												
				-------------------------------------------------												
				-- TimeCurrent %Site%												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDAVT_UploadCodes_Audit%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSaliBudgetHours%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplClass%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%zz_tblEmplNames%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblShiftDiffClasses%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteNames_Messages%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblPayRules%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblAdjustments%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblEmplNames_Audit%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblClusterDef%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteNamesIPRestriction%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSaliBudgetHoursTemp%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteParm_Values%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblMCRequestDetail%')												
				insert into #temp(ColumnName,TableName) values('%OldSiteNo%','%tblFixedPunch%')												
				insert into #temp(ColumnName,TableName) values('%NewSiteNo%','%tblFixedPunch%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblEmplNames_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDeptNames%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Depts_Template%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Template%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplChange%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Depts_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Depts%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTempoDataLoadSnapShot%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblStdJobTemplates%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteNames_GeoLocation%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplChangeSSN%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteNames%')												
				insert into #temp(ColumnName,TableName) values('%UploadAsSiteNo%','%tblSiteNames%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblEmplNames_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDeptShiftChange%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%clim_coas_back%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblClientDeptXref%')												
				insert into #temp(ColumnName,TableName) values('%ActualSiteNo%','%tblClientDeptXref%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%clim_coas_back2%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDAVT_UploadCodes2%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Depts_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDavitaUploadCodes_Parallel%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblWork_Waff%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDAVT_UploadCodes%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%diff_tblEmplSites%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%diff_tblEmplSites_Depts%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblOrderTemplates%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblEmplNames%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Audit%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDavitaUploadCodes%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Depts_Audit%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblEmplNames2%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteNamesPhoneNumbers%')												
				-- TimeHistory %Site%												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%zzJimResearch_TimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplShifts%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeCards_Control_DELETE%')												
				insert into #temp(ColumnName,TableName) values('%SiteWorkedAt%','%tblGambroUploads%')												
				insert into #temp(ColumnName,TableName) values('%HomeSite%','%tblGambroUploads%')												
				insert into #temp(ColumnName,TableName) values('%SiteChargedTo%','%tblGambroUploads%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblAdjustments%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_ZeroSite%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDeptNames%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites_Depts%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplClass%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblWork_TimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblEmplSites%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblWTE_Project_Archive%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%OLSTLegal%')												
				insert into #temp(ColumnName,TableName) values('%InSite%','%tblPunchImport%')												
				insert into #temp(ColumnName,TableName) values('%OutSite%','%tblPunchImport%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblImportLog%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_Orig%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_GeoLocation%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblSiteNames%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_backup%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_COAS_pre%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDataFormStatus%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%VANGlegal%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_Partial%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblDataFormValues%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblWork_TimeHistDetail2%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySite%','%tblEmplNames%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblFixPunchAudit%')												
				insert into #temp(ColumnName,TableName) values('%siteno%','%STFMCompassBank%')												
				insert into #temp(ColumnName,TableName) values('%WorkedSiteNo%','%tblCIAHistory_DAVT%')												
				insert into #temp(ColumnName,TableName) values('%PrimarySiteNo%','%tblCIAHistory_DAVT%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblStdJobs%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblStdJobs_Audit%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_DELETED%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%ADVOlegal%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeCards_DELETE%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblStdJobCellEmployees%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblTimeHistDetail_COAS_post%')												
				insert into #temp(ColumnName,TableName) values('%SiteNo%','%tblExpenseLineItems%')												
				-- TimeCurrent %Dept% %Department%												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShiftDiffs%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tbl_DAVT_GroupDeptsPre802011%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%zz_tblEmplNames%')												
				insert into #temp(ColumnName,TableName) values('%Deptno%','%tblendava%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblGroupDepts%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%tblPayRules%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplAssignments_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblAdjustments%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%tblEmplNames_Audit%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblClusterDef%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblSaliBudgetHoursTemp%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts_Duplicates%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblMCRequestDetail%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShifts_DAVT%')												
				insert into #temp(ColumnName,TableName) values('%OldDeptNo%','%tblFixedPunch%')												
				insert into #temp(ColumnName,TableName) values('%NewDeptNo%','%tblFixedPunch%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblWORK_DeptShiftDiffs%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplAllocation_Session%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts_Template%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%tblEmplNames_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblRedirEmpDepts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptNames%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplSites_Depts_Template%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplSites_Depts_SESSION%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplSites_Depts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblStdJobTemplates%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShiftDiffs_DAVT%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplAssignments%')												
				insert into #temp(ColumnName,TableName) values('%DefaultDeptNo%','%tblSiteNames%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%tblEmplNames_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%clim_coas_back%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblClientDeptXref%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%clim_coas_back2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplSites_Depts_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplAllocation%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShifts_Audit2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShifts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShifts_DAVT2%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%diff_tblEmplNames_Depts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%diff_tblEmplSites_Depts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblOrderTemplates%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplAllocation_WORK%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts_Audit%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%tblEmplNames%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShiftDiffs_DAVT2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplSites_Depts_Audit%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%tblEmplNames2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblJobOrders%')												
				------Newly Identified Table---------------------												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblSaliBudgetHours%')												
				-------------------------------------------------												
				-- TimeHistory %Dept% %Department%												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%zzJimResearch_TimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplShifts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptShifts%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblGambroUploads%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblAdjustments%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_ZeroSite%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblDeptNames%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblEmplSites_Depts%')												
				insert into #temp(ColumnName,TableName) values('%deptno%','%tblCOAS_Screwup%')												
				insert into #temp(ColumnName,TableName) values('%deptno%','%tblCOAS_Screwup2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblWork_TimeHistDetail%')												
				insert into #temp(ColumnName,TableName) values('%Department%','%tblEmplNames_Depts%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%OLSTLegal%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%OLSTLegal%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblPunchImport%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_Orig%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblBudgetData%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_backup%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_COAS_pre%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%VANGlegal%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%VANGlegal%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_Partial%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblWork_TimeHistDetail2%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblFixPunchAudit%')												
				insert into #temp(ColumnName,TableName) values('%deptno%','%STFMCompassBank%')												
				insert into #temp(ColumnName,TableName) values('%newdept%','%STFMCompassBank%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblStdJobs%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblStdJobs_Audit%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_DELETED%')												
				insert into #temp(ColumnName,TableName) values('%PrimaryDept%','%ADVOlegal%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%ADVOlegal%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeHistDetail_COAS_post%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblExpenseLineItems%')												
				------Newly Identified Table---------------------												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeCards_Control_DELETE%')												
				insert into #temp(ColumnName,TableName) values('%DeptNo%','%tblTimeCards_DELETE%')												
				-------------------------------------------------												
			--Createing a temp table to store the SP's list, which uses The mentioned TableName/ColumnName													
			--Create table #output(SlNo int Identity(1,1), StoredProcName VARCHAR(1000))													
			--Declaration of Temp Variables													
			Declare @tableCount int													
			DECLARE @intFlag INT													
			Declare @TableName VARCHAR(500)													
			Declare @ColumnName VARCHAR(500)													
				Set @tableCount =(select COUNT(1) FROM #temp);												
				SET @intFlag = 1												
			--Looping through the Temp table													
			--WHILE (@intFlag <=@tableCount)													
			--	BEGIN												
					--Taking the TableName and Column Name from table by rowwise and appending % to perform Like operation											
					--Set @TableName = '%'+(select TableName FROM #temp WHERE SlNo = @intFlag)+'%'											
					--Set @ColumnName = '%'+(select ColumnName FROM #temp WHERE SlNo = @intFlag)+'%'											
					--Inserting the SP's into Output temp table											
					SELECT DISTINCT s.name,											
									c.text							
					into #TempCode											
					FROM syscomments c 											
					INNER JOIN sysobjects s											
					ON c.id = s.id											
					WHERE s.type='p'											
					AND s.name NOT LIKE '%_GG'											
					AND s.name NOT LIKE '%_GG1'											
					AND s.name NOT LIKE '%_GG2'											
					AND s.name NOT LIKE '%_GG3'											
					AND s.name NOT LIKE '%_GG4'											
					AND s.name NOT LIKE '%_GG5'											
					AND s.name NOT LIKE '%_GG6'											
					AND s.name NOT LIKE '%_deh'											
					AND s.name NOT LIKE '%_deh2'											
					AND s.name NOT LIKE '%_jb'											
					AND s.name NOT LIKE '%_jlb'											
					AND s.name NOT LIKE '%_ss'											
					AND s.name NOT LIKE '%_clim'											
					AND s.name NOT LIKE '%_mk'											
					AND s.name NOT LIKE '%_mk1'											
					AND s.name NOT LIKE '%_mk2'											
					AND s.name NOT LIKE '%_mk3'											
					AND s.name NOT LIKE '%usp_WTE_GetUnapprovedTimeEntries_%'											
					SELECT * FROM #TempCode											
					SELECT * FROM #temp											
					--RETURN											
			        													
					------DataType and Field combinations	Temp Variable Declaration Starts	-----									
					DECLARE @OrigRecIdLike VARCHAR(100) = '%int%OrigRecordID%';											
					DECLARE @OrigRecIdLikeReverse VARCHAR(100) = '%OrigRecordID%int%';											
					DECLARE @THDRecIdLike VARCHAR(100) = '%int%THDRecordID%';											
					DECLARE @THDRecIdLikeReverse VARCHAR(100) = '%THDRecordID%int%';											
					DECLARE @AprvOrigRecIdLike VARCHAR(100) = '%int%AprvlAdjOrigRecID%';											
					DECLARE @AprvOrigRecIdLikeReverse VARCHAR(100) = '%AprvlAdjOrigRecID%int%';											
					DECLARE @FrmRecIdLike VARCHAR(100) = '%int%FromRecordID%';											
					DECLARE @FrmRecIdLikeReverse VARCHAR(100) = '%FromRecordID%int%';											
					DECLARE @ToRecIdLike VARCHAR(100) = '%int%ToRecordID%';											
					DECLARE @ToRecIdLikeReverse VARCHAR(100) = '%ToRecordID%int%';											
					DECLARE @DetRecIdLike VARCHAR(100) = '%int%DetailRecordID%';											
					DECLARE @DetRecIdLikeReverse VARCHAR(100) = '%DetailRecordID%int%';											
					DECLARE @THD_RecIdLike VARCHAR(100) = '%int%THD_RecordId%';											
					DECLARE @THD_RecIdLikeReverse VARCHAR(100) = '%THD_RecordId%int%';											
					DECLARE @AdjRecIdLike VARCHAR(100) = '%int%AdjustmentRecordID%';											
					DECLARE @AdjRecIdLikeReverse VARCHAR(100) = '%AdjustmentRecordID%int%';											
					DECLARE @RecIdLike VARCHAR(100) = '%int%RecordID%';											
					DECLARE @RecIdLikeReverse VARCHAR(100) = '%RecordID%int%';											
					DECLARE @InOutIdLike VARCHAR(100) = '%int%InOutId%';											
					DECLARE @InOutIdLikeReverse VARCHAR(100) = '%InOutId%int%';											
					DECLARE @SiteNoSmlINTLike VARCHAR(100) = '%smallint%site%';											
					DECLARE @SiteNoSmlINTLikeReverse VARCHAR(100) = '%site%smallint%';											
					DECLARE @PrimarySiteSmlINTLike VARCHAR(100) = '%smallint%primarysite%';											
					DECLARE @PrimarySiteSmlINTLikeReverse VARCHAR(100) = '%primarysite%smallint%';											
					DECLARE @DeptnoSmlINTLike VARCHAR(100) = '%smallint%dept%';											
					DECLARE @DeptnoSmlINTLikeReverse VARCHAR(100) = '%dept%smallint%';											
					DECLARE @PrimaryDeptSmlINTLike VARCHAR(100) = '%smallint%primaryDept%';											
					DECLARE @PrimaryDeptSmlINTLikeReverse VARCHAR(100) = '%primaryDept%smallint%';											
					DECLARE @DepartmentSmlINTLike VARCHAR(100) = '%smallint%Department%';											
					DECLARE @DepartmentSmlINTLikeReverse VARCHAR(100) = '%Department%smallint%';											
					DECLARE @DeptnoTinyINTLike VARCHAR(100) = '%tinyint%deptno%';											
					DECLARE @DeptnoTinyINTLikeReverse VARCHAR(100) = '%deptno%tinyint%';											
					------DataType and Field combinations	Ends	-----									
					SELECT DISTINCT c.name,											
							SUM(CASE WHEN (( (c.text like @OrigRecIdLike or c.text like @OrigRecIdLikeReverse) AND (c.text like '%tblFixedPunch%' OR c.text like '%tblFixPunchAudit%')) OR									
					((c.text like @THDRecIdLike or c.text like @THDRecIdLikeReverse) AND (c.text like '%tblAdjustments%' OR c.text like '%tblCigTransLog%' OR c.text like '%tblEmplMissingPunchAlert%' 											
					OR c.text like '%tblNotificationMessage%' OR c.text like '%tblPATETxn%' OR c.text like '%tblKronosPunchExport%' OR c.text like '%tblKronosPunchExport_Audit%' 											
					OR c.text like '%tblStaffingApproval_THD%' OR c.text like '%tblTimeHistDetail_BackupApproval%' OR c.text like '%tblTimeHistDetail_PATE%' OR c.text like '%tblTimeHistDetail_UDF%' 											
					OR c.text like '%tblWork_KronosExport%' )) OR 											
					((c.text like @AprvOrigRecIdLike or c.text like @AprvOrigRecIdLikeReverse) AND(c.text like '%tblTimeHistDetail%' OR c.text like '%tblTimeHistDetail_Partial%')) OR											
					((c.text like @FrmRecIdLike OR c.text like @FrmRecIdLikeReverse or c.text like @ToRecIdLike OR c.text like @ToRecIdLikeReverse) AND (c.text like '%tblTimeHistDetail_Crossover%')) OR											
					((c.text like @DetRecIdLike or c.text like @DetRecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Disputes%') OR											
					((c.text like @THD_RecIdLike or c.text like @THD_RecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Faxaroo%') OR											
					((c.text like @AdjRecIdLike or c.text like @AdjRecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Reasons%') OR											
					((c.text like @RecIdLike or c.text like @RecIdLikeReverse) AND(c.text like '%tblTimeHistDetail_Partial%' OR c.text like '%tblFixedPunchByEE%' or  c.text like '%tblTimeHistDetail%')) OR											
					((c.text like @InOutIdLike or c.text like @InOutIdLikeReverse) AND c.text like '%tblWTE_Spreadsheet_Breaks%') ) THEN 1 ELSE 0 END) AS tblTimeHistDetail_RecordID_Related,											
							SUM(CASE WHEN ((c.text LIKE @SiteNoSmlINTLike or c.text LIKE @SiteNoSmlINTLikeReverse)OR (c.text LIKE @PrimarySiteSmlINTLike or c.text LIKE @PrimarySiteSmlINTLike))									
								 AND c.text LIKE '%smallint%' THEN 1 ELSE 0 END) AS SiteNo_SMALLINT,								
							SUM(CASE WHEN (((c.text LIKE @DeptnoSmlINTLike or c.text LIKE @DeptnoSmlINTLikeReverse)  OR (c.text LIKE @PrimaryDeptSmlINTLike or c.text LIKE @PrimaryDeptSmlINTLikeReverse)  OR									
								 (c.text LIKE @DepartmentSmlINTLike or c.text LIKE @DepartmentSmlINTLikeReverse) OR 								
								 (c.text LIKE @DeptnoTinyINTLike or c.text LIKE @DeptnoTinyINTLikeReverse))) AND (c.text LIKE '%smallint%' or c.text LIKE '%tinyint%') THEN 1 ELSE 0 END) AS DeptNo_SMALLINT								
					into #output											
					FROM #TempCode c											
					INNER JOIN #temp tmp											
					ON c.text LIKE tmp.TableName 											
					AND c.text LIKE tmp.ColumnName											
					GROUP BY c.name											
					UNION											
					SELECT DISTINCT c.name,											
							SUM(CASE WHEN (( (c.text like @OrigRecIdLike or c.text like @OrigRecIdLikeReverse) AND (c.text like '%tblFixedPunch%' OR c.text like '%tblFixPunchAudit%')) OR									
					((c.text like @THDRecIdLike or c.text like @THDRecIdLikeReverse) AND (c.text like '%tblAdjustments%' OR c.text like '%tblCigTransLog%' OR c.text like '%tblEmplMissingPunchAlert%' 											
					OR c.text like '%tblNotificationMessage%' OR c.text like '%tblPATETxn%' OR c.text like '%tblKronosPunchExport%' OR c.text like '%tblKronosPunchExport_Audit%' 											
					OR c.text like '%tblStaffingApproval_THD%' OR c.text like '%tblTimeHistDetail_BackupApproval%' OR c.text like '%tblTimeHistDetail_PATE%' OR c.text like '%tblTimeHistDetail_UDF%' 											
					OR c.text like '%tblWork_KronosExport%' )) OR 											
					((c.text like @AprvOrigRecIdLike or c.text like @AprvOrigRecIdLikeReverse) AND(c.text like '%tblTimeHistDetail%' OR c.text like '%tblTimeHistDetail_Partial%')) OR											
					((c.text like @FrmRecIdLike OR c.text like @FrmRecIdLikeReverse or c.text like @ToRecIdLike OR c.text like @ToRecIdLikeReverse) AND (c.text like '%tblTimeHistDetail_Crossover%')) OR											
					((c.text like @DetRecIdLike or c.text like @DetRecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Disputes%') OR											
					((c.text like @THD_RecIdLike or c.text like @THD_RecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Faxaroo%') OR											
					((c.text like @AdjRecIdLike or c.text like @AdjRecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Reasons%') OR											
					((c.text like @RecIdLike or c.text like @RecIdLikeReverse) AND(c.text like '%tblTimeHistDetail_Partial%' OR c.text like '%tblFixedPunchByEE%'  OR c.text like '%tblTimeHistDetail%')) OR											
					((c.text like @InOutIdLike or c.text like @InOutIdLikeReverse) AND c.text like '%tblWTE_Spreadsheet_Breaks%') ) THEN 1 ELSE 0 END) AS tblTimeHistDetail_RecordID_Related,											
							SUM(CASE WHEN ((c.text LIKE @SiteNoSmlINTLike or c.text LIKE @SiteNoSmlINTLikeReverse)OR (c.text LIKE @PrimarySiteSmlINTLike or c.text LIKE @PrimarySiteSmlINTLike))									
								 AND c.text LIKE '%smallint%' THEN 1 ELSE 0 END) AS SiteNo_SMALLINT,								
							SUM(CASE WHEN (((c.text LIKE @DeptnoSmlINTLike or c.text LIKE @DeptnoSmlINTLikeReverse)  OR (c.text LIKE @PrimaryDeptSmlINTLike or c.text LIKE @PrimaryDeptSmlINTLikeReverse)  OR									
								 (c.text LIKE @DepartmentSmlINTLike or c.text LIKE @DepartmentSmlINTLikeReverse) OR 								
								 (c.text LIKE @DeptnoTinyINTLike or c.text LIKE @DeptnoTinyINTLikeReverse))) AND (c.text LIKE '%smallint%' or c.text LIKE '%tinyint%') THEN 1 ELSE 0 END) AS DeptNo_SMALLINT								
					--into #output											
					FROM #TempCode c											
					INNER JOIN #temp tmp											
					ON 1 = 1											
					WHERE ((((c.text LIKE @SiteNoSmlINTLike or c.text LIKE @SiteNoSmlINTLikeReverse) OR (c.text LIKE @PrimarySiteSmlINTLike or c.text LIKE @PrimarySiteSmlINTLikeReverse)) AND c.text LIKE '%smallint%') OR											
						 ((((c.text LIKE @DeptnoSmlINTLike or c.text LIKE @DeptnoSmlINTLikeReverse)  OR (c.text LIKE @DepartmentSmlINTLike or c.text LIKE @DepartmentSmlINTLikeReverse) 										
							 OR (c.text LIKE @PrimaryDeptSmlINTLike or c.text LIKE @PrimaryDeptSmlINTLikeReverse)  									
								OR 	(c.text LIKE @DeptnoTinyINTLike or c.text LIKE @DeptnoTinyINTLikeReverse))) AND (c.text LIKE '%smallint%' or c.text LIKE '%tinyint%' ))	OR						
							(( (c.text like @OrigRecIdLike or c.text like @OrigRecIdLikeReverse) AND (c.text like '%tblFixedPunch%' OR c.text like '%tblFixPunchAudit%')) 									
								OR	((c.text like @THDRecIdLike or c.text like @THDRecIdLikeReverse) AND 							
									(c.text like '%tblAdjustments%' OR c.text like '%tblCigTransLog%' OR c.text like '%tblEmplMissingPunchAlert%' OR c.text like '%tblNotificationMessage%' 							
										OR c.text like '%tblPATETxn%' OR c.text like '%tblKronosPunchExport%' OR c.text like '%tblKronosPunchExport_Audit%' OR c.text like '%tblStaffingApproval_THD%' 						
										OR c.text like '%tblTimeHistDetail_BackupApproval%' OR c.text like '%tblTimeHistDetail_PATE%' OR c.text like '%tblTimeHistDetail_UDF%' OR c.text like '%tblWork_KronosExport%' ))						OR ((c.text like @AprvOrigRecIdLike or c.text like @AprvOrigRecIdLikeReverse) AND(c.text like '%tblTimeHistDetail%' OR c.text like '%tblTimeHistDetail_Partial%')) 
								OR	((c.text like @FrmRecIdLike OR c.text like @FrmRecIdLikeReverse or c.text like @ToRecIdLike OR c.text like @ToRecIdLikeReverse) AND (c.text like '%tblTimeHistDetail_Crossover%')) 							
								OR	((c.text like @DetRecIdLike or c.text like @DetRecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Disputes%') 							
								OR	((c.text like @THD_RecIdLike or c.text like @THD_RecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Faxaroo%') 							
								OR	((c.text like @AdjRecIdLike or c.text like @AdjRecIdLikeReverse) AND c.text like '%tblTimeHistDetail_Reasons%') 							
								OR	((c.text like @RecIdLike or c.text like @RecIdLikeReverse) AND(c.text like '%tblTimeHistDetail_Partial%' OR c.text like '%tblFixedPunchByEE%' OR c.text							
										 like '%tblTimeHistDetail%')) 						
								OR	((c.text like @InOutIdLike or c.text like @InOutIdLikeReverse) AND c.text like '%tblWTE_Spreadsheet_Breaks%') )							
							)									
					GROUP BY c.name											
					--SET @intFlag = @intFlag + 1											
				--END												
			drop table #temp;													
			DROP TABLE #TempCode;													
			SELECT name,													
				   CASE WHEN tblTimeHistDetail_RecordID_Related > 0 THEN 'Y' ELSE '' END AS tblTimeHistDetail_RecordID_Related,												
				   CASE WHEN SiteNo_SMALLINT > 0 THEN 'Y' ELSE '' END AS SiteNo_SMALLINT,												
				   CASE WHEN DeptNo_SMALLINT > 0 THEN 'Y' ELSE '' END AS DeptNo_SMALLINT												
			FROM (SELECT DISTINCT name, 													
									SUM(tblTimeHistDetail_RecordID_Related) AS tblTimeHistDetail_RecordID_Related,							
									SUM(SiteNo_SMALLINT) AS SiteNo_SMALLINT,							
									SUM(DeptNo_SMALLINT) AS DeptNo_SMALLINT							
					FROM #output											
					GROUP BY name) AS tmp 											
					where tmp.DeptNo_SMALLINT>0 or tmp.SiteNo_SMALLINT>0 or tmp.tblTimeHistDetail_RecordID_Related>0											
			ORDER BY 1													
			--select * from #output													
			drop table #output;													
																
																
