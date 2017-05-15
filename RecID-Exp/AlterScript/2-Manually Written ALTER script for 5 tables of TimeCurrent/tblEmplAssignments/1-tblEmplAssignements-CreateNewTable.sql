USE [TimeCurrent]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblEmplAssignmentsNew table ...'

	CREATE TABLE [dbo].[tblEmplAssignmentsNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[SSN] [int] NOT NULL,
	[AssignmentNo] [varchar](32) NOT NULL,
	[DeptNo] [INT] NOT NULL CONSTRAINT [DF_tblEmplAssignments_DeptNoNew]  DEFAULT (0),
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[HasBeenUsed] [char](1) NOT NULL CONSTRAINT [DF_tblEmplAssignments_HasBeenUsedNew]  DEFAULT (0),
	[TermDate] [datetime] NULL,
	[TerminatedByPNE] [char](1) NOT NULL CONSTRAINT [DF_tblEmplAssignments_TerminatedByPNENew]  DEFAULT (0),
	[TermReasonCode] [varchar](5) NOT NULL CONSTRAINT [DF_tblEmplAssignments_TermReasonNew]  DEFAULT (''),
	[RecordStatus] [char](1) NOT NULL CONSTRAINT [DF_tblEmplAssignments_RecordStatusNew]  DEFAULT (1),
	[PurchOrderNo] [varchar](15) NOT NULL CONSTRAINT [DF_tblEmplAssignments_PurchOrderNoNew]  DEFAULT (''),
	[JobOrderNo] [varchar](15) NOT NULL CONSTRAINT [DF_tblEmplAssignments_JobOrderNoNew]  DEFAULT (''),
	[JobSkillCode] [varchar](10) NOT NULL CONSTRAINT [DF_tblEmplAssignments_JobSkillNew]  DEFAULT (''),
	[FinalTermination] [char](1) NOT NULL CONSTRAINT [DF_tblEmplAssignments_FinalTerminationNew]  DEFAULT (0),
	[AdditionalInfo] [varchar](32) NULL,
	[EmplID] [varchar](100) NULL,
	[RFR_UniqueID] [varchar](100) NULL,
	[PayRate] [numeric](7, 2) NULL,
	[BillRate] [numeric](7, 2) NULL,
	[SiteNo] [int] NOT NULL DEFAULT (0),
	[Approver_Email1] [varchar](200) NULL,
	[Approver_Email2] [varchar](200) NULL,
	[ApproverUserId1] [int] NULL,
	[ApproverUserId2] [int] NULL,
	[AgencyNo] [int] NULL,
	[Approver_FirstName1] [varchar](50) NULL,
	[Approver_LastName1] [varchar](50) NULL,
	[Approver_FirstName2] [varchar](50) NULL,
	[Approver_LastName2] [varchar](50) NULL,
	[BranchId] [varchar](100) NULL,
	[ClientId] [varchar](100) NULL,
	[GroupingNo] [varchar](100) NULL,
	[ExpenseApprover_Email1] [varchar](200) NULL,
	[ExpenseApprover_Email2] [varchar](200) NULL,
	[ExpenseApproverUserId1] [int] NULL,
	[ExpenseApproverUserId2] [int] NULL,
	[ExpenseApprover_FirstName1] [varchar](50) NULL,
	[ExpenseApprover_LastName1] [varchar](50) NULL,
	[ExpenseApprover_FirstName2] [varchar](50) NULL,
	[ExpenseApprover_LastName2] [varchar](50) NULL,
	[WorkSiteID] [varchar](100) NULL,
	[DateHidden] [smalldatetime] NULL,
	[WorkState] [varchar](2) NULL,
	[Brand] [varchar](32) NULL,
	[AltID] [varchar](100) NULL,
	[ProjectTracking] [varchar](1) NULL,
	[QtrHrRound] [varchar](1) NULL,
	[Schedule410] [varchar](1) NULL,
	[AgencyEmail] [varchar](132) NULL,
	[EstimatedEndDate] [datetime] NULL,
	[BusinessLine] [varchar](3) NULL,
	[BilltoCode] [varchar](20) NULL,
	[InOuts] [varchar](2) NULL,
	[EntryRounding] [int] NULL,
	[ApprovalMethodID] [int] NULL,
	[EligibleForHolidayPay] [varchar](10) NULL,
	[IVR_AssignmentNo] [varchar](32) NULL,
	[PayRuleID] [int] NULL,
	[OTOverrideRuleID] [int] NULL,
	[MealDuration] [numeric](5, 2) NULL,
	[TimeEntryFreqID] [int] NULL,
	[SecondaryRefreshWFCode] [varchar](50) NULL,
	[ConsultantType] [varchar](50) NULL,
	[DisableBreakExceptions] [varchar](1) NULL,
	[BrandID] [int] NULL,
	[PayOnly] [char](1) NULL,
	[BPO] [char](1) NULL,
	[POSITION] [varchar](32) NULL,
	[WorkSiteName] [varchar](32) NULL,
	[JobTitle] [varchar](100) NULL,
	[Expenses] [varchar](1) NULL,
	[OrderID] [varchar](50) NULL,
	[AssignmentTypeID] [int] NULL,
	[DiscountPercent] [numeric](10, 4) NULL,
	[EmployeeCPAFlag] [varchar](1) NULL,
	[ProxyCPAFlag] [varchar](1) NULL,
	[PreventWorkedTime] [varchar](1) NULL CONSTRAINT [DF_tblEmplAssignments_PreventWorkedTimeNew]  DEFAULT ('0'),
	[SortOrder] [tinyint] NULL CONSTRAINT [DF_tblEmplAssignments_SortOrderNew]  DEFAULT ((0)),
	[MinHours] [numeric](5, 2) NULL,
	[NoBill_ExpAprvr_FirstName] [varchar](20) NULL,
	[NoBill_ExpAprvr_LastName] [varchar](20) NULL,
	[NoBill_ExpAprvr_Email] [varchar](132) NULL,
	[NoBill_ExpAprvr_FirstName2] [varchar](20) NULL,
	[NoBill_ExpAprvr_LastName2] [varchar](20) NULL,
	[NoBill_ExpAprvr_Email2] [varchar](132) NULL,
	[NoBill_TS_Aprvr_FirstName] [varchar](50) NULL,
	[NoBill_TS_Aprvr_LastName] [varchar](50) NULL,
	[NoBill_TS_Aprvr_Email] [varchar](200) NULL,
	[NoBill_TS_Aprvr_FirstName2] [varchar](50) NULL,
	[NoBill_TS_Aprvr_LastName2] [varchar](50) NULL,
	[NoBill_TS_Aprvr_Email2] [varchar](200) NULL,
	[NoBill_ExpAprvr_UserId1] [int] NULL,
	[NoBill_ExpAprvr_UserId2] [int] NULL,
	[FoxAssignmentNo] [varchar](32) NULL,
	[AssignmentCostCenter] [varchar](20) NULL,
	[Setting] [varchar](32) NULL,
	CONSTRAINT [PK_tblEmplAssignmentsNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]
END
GO
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_ClientGrpSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_ClientGrpSSN index ...'
	CREATE UNIQUE CLUSTERED INDEX [IX_tblEmplAssignments_ClientGrpSSN] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[AssignmentNo] ASC,
		[DeptNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeCurrent]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplAssignmentsNew ON
SET NOCOUNT ON
INSERT INTO [dbo].[tblEmplAssignmentsNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[SSN]
           ,[AssignmentNo]
           ,[DeptNo]
           ,[StartDate]
           ,[EndDate]
           ,[HasBeenUsed]
           ,[TermDate]
           ,[TerminatedByPNE]
           ,[TermReasonCode]
           ,[RecordStatus]
           ,[PurchOrderNo]
           ,[JobOrderNo]
           ,[JobSkillCode]
           ,[FinalTermination]
           ,[AdditionalInfo]
           ,[EmplID]
           ,[RFR_UniqueID]
           ,[PayRate]
           ,[BillRate]
           ,[SiteNo]
           ,[Approver_Email1]
           ,[Approver_Email2]
           ,[ApproverUserId1]
           ,[ApproverUserId2]
           ,[AgencyNo]
           ,[Approver_FirstName1]
           ,[Approver_LastName1]
           ,[Approver_FirstName2]
           ,[Approver_LastName2]
           ,[BranchId]
           ,[ClientId]
           ,[GroupingNo]
           ,[ExpenseApprover_Email1]
           ,[ExpenseApprover_Email2]
           ,[ExpenseApproverUserId1]
           ,[ExpenseApproverUserId2]
           ,[ExpenseApprover_FirstName1]
           ,[ExpenseApprover_LastName1]
           ,[ExpenseApprover_FirstName2]
           ,[ExpenseApprover_LastName2]
           ,[WorkSiteID]
           ,[DateHidden]
           ,[WorkState]
           ,[Brand]
           ,[AltID]
           ,[ProjectTracking]
           ,[QtrHrRound]
           ,[Schedule410]
           ,[AgencyEmail]
           ,[EstimatedEndDate]
           ,[BusinessLine]
           ,[BilltoCode]
           ,[InOuts]
           ,[EntryRounding]
           ,[ApprovalMethodID]
           ,[EligibleForHolidayPay]
           ,[IVR_AssignmentNo]
           ,[PayRuleID]
           ,[OTOverrideRuleID]
           ,[MealDuration]
           ,[TimeEntryFreqID]
           ,[SecondaryRefreshWFCode]
           ,[ConsultantType]
           ,[DisableBreakExceptions]
           ,[BrandID]
           ,[PayOnly]
           ,[BPO]
           ,[POSITION]
           ,[WorkSiteName]
           ,[JobTitle]
           ,[Expenses]
           ,[OrderID]
           ,[AssignmentTypeID]
           ,[DiscountPercent]
           ,[EmployeeCPAFlag]
           ,[ProxyCPAFlag]
           ,[PreventWorkedTime]
           ,[SortOrder]
           ,[MinHours]
           ,[NoBill_ExpAprvr_FirstName]
           ,[NoBill_ExpAprvr_LastName]
           ,[NoBill_ExpAprvr_Email]
           ,[NoBill_ExpAprvr_FirstName2]
           ,[NoBill_ExpAprvr_LastName2]
           ,[NoBill_ExpAprvr_Email2]
           ,[NoBill_TS_Aprvr_FirstName]
           ,[NoBill_TS_Aprvr_LastName]
           ,[NoBill_TS_Aprvr_Email]
           ,[NoBill_TS_Aprvr_FirstName2]
           ,[NoBill_TS_Aprvr_LastName2]
           ,[NoBill_TS_Aprvr_Email2]
           ,[NoBill_ExpAprvr_UserId1]
           ,[NoBill_ExpAprvr_UserId2]
           ,[FoxAssignmentNo]
           ,[AssignmentCostCenter]
           ,[Setting])

SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[SSN]
      ,[AssignmentNo]
      ,[DeptNo]
      ,[StartDate]
      ,[EndDate]
      ,[HasBeenUsed]
      ,[TermDate]
      ,[TerminatedByPNE]
      ,[TermReasonCode]
      ,[RecordStatus]
      ,[PurchOrderNo]
      ,[JobOrderNo]
      ,[JobSkillCode]
      ,[FinalTermination]
      ,[AdditionalInfo]
      ,[EmplID]
      ,[RFR_UniqueID]
      ,[PayRate]
      ,[BillRate]
      ,[SiteNo]
      ,[Approver_Email1]
      ,[Approver_Email2]
      ,[ApproverUserId1]
      ,[ApproverUserId2]
      ,[AgencyNo]
      ,[Approver_FirstName1]
      ,[Approver_LastName1]
      ,[Approver_FirstName2]
      ,[Approver_LastName2]
      ,[BranchId]
      ,[ClientId]
      ,[GroupingNo]
      ,[ExpenseApprover_Email1]
      ,[ExpenseApprover_Email2]
      ,[ExpenseApproverUserId1]
      ,[ExpenseApproverUserId2]
      ,[ExpenseApprover_FirstName1]
      ,[ExpenseApprover_LastName1]
      ,[ExpenseApprover_FirstName2]
      ,[ExpenseApprover_LastName2]
      ,[WorkSiteID]
      ,[DateHidden]
      ,[WorkState]
      ,[Brand]
      ,[AltID]
      ,[ProjectTracking]
      ,[QtrHrRound]
      ,[Schedule410]
      ,[AgencyEmail]
      ,[EstimatedEndDate]
      ,[BusinessLine]
      ,[BilltoCode]
      ,[InOuts]
      ,[EntryRounding]
      ,[ApprovalMethodID]
      ,[EligibleForHolidayPay]
      ,[IVR_AssignmentNo]
      ,[PayRuleID]
      ,[OTOverrideRuleID]
      ,[MealDuration]
      ,[TimeEntryFreqID]
      ,[SecondaryRefreshWFCode]
      ,[ConsultantType]
      ,[DisableBreakExceptions]
      ,[BrandID]
      ,[PayOnly]
      ,[BPO]
      ,[POSITION]
      ,[WorkSiteName]
      ,[JobTitle]
      ,[Expenses]
      ,[OrderID]
      ,[AssignmentTypeID]
      ,[DiscountPercent]
      ,[EmployeeCPAFlag]
      ,[ProxyCPAFlag]
      ,[PreventWorkedTime]
      ,[SortOrder]
      ,[MinHours]
      ,[NoBill_ExpAprvr_FirstName]
      ,[NoBill_ExpAprvr_LastName]
      ,[NoBill_ExpAprvr_Email]
      ,[NoBill_ExpAprvr_FirstName2]
      ,[NoBill_ExpAprvr_LastName2]
      ,[NoBill_ExpAprvr_Email2]
      ,[NoBill_TS_Aprvr_FirstName]
      ,[NoBill_TS_Aprvr_LastName]
      ,[NoBill_TS_Aprvr_Email]
      ,[NoBill_TS_Aprvr_FirstName2]
      ,[NoBill_TS_Aprvr_LastName2]
      ,[NoBill_TS_Aprvr_Email2]
      ,[NoBill_ExpAprvr_UserId1]
      ,[NoBill_ExpAprvr_UserId2]
      ,[FoxAssignmentNo]
      ,[AssignmentCostCenter]
      ,[Setting]
  FROM [dbo].[tblEmplAssignments]

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IDX_Client_AssignmentNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IDX_Client_AssignmentNo index ...'
	CREATE NONCLUSTERED INDEX [IDX_Client_AssignmentNo] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[AssignmentNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IDX_Client_Branch_ClientID')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IDX_Client_Branch_ClientID index ...'
	CREATE NONCLUSTERED INDEX [IDX_Client_Branch_ClientID] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[BranchId] ASC,
		[ClientId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IDX_ClientSSNGroupDeptSiteClientID')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IDX_ClientSSNGroupDeptSiteClientID index ...'
	CREATE NONCLUSTERED INDEX [IDX_ClientSSNGroupDeptSiteClientID] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[SSN] ASC,
		[GroupCode] ASC,
		[DeptNo] ASC,
		[SiteNo] ASC,
		[ClientId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_BranchCliGrpCdSSNStartDtGroupingAssignEndDt')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_BranchCliGrpCdSSNStartDtGroupingAssignEndDt index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_BranchCliGrpCdSSNStartDtGroupingAssignEndDt] ON [dbo].[tblEmplAssignmentsNew]
	(
		[BranchId] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[StartDate] ASC,
		[GroupingNo] ASC,
		[AssignmentNo] ASC,
		[EndDate] ASC,
		[ClientId] ASC,
		[DeptNo] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_BranchStDtGrpNoAssignEndDtCliGrpCdSSNCliIDDeptSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_BranchStDtGrpNoAssignEndDtCliGrpCdSSNCliIDDeptSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_BranchStDtGrpNoAssignEndDtCliGrpCdSSNCliIDDeptSite] ON [dbo].[tblEmplAssignmentsNew]
	(
		[BranchId] ASC,
		[StartDate] ASC,
		[GroupingNo] ASC,
		[AssignmentNo] ASC,
		[EndDate] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[ClientId] ASC,
		[DeptNo] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliBrandWSBLGrpCdSiteDept')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliBrandWSBLGrpCdSiteDept index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliBrandWSBLGrpCdSiteDept] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[Brand] ASC,
		[WorkState] ASC,
		[BusinessLine] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC,
		[DeptNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliGrpCdRecStatSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliGrpCdRecStatSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliGrpCdRecStatSite] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[RecordStatus] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[SSN],
		[DeptNo],
		[StartDate],
		[EndDate]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliGrpCdSiteNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliGrpCdSiteNo index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliGrpCdSiteNo] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[RecordID],
		[SSN],
		[AssignmentNo],
		[DeptNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliGrpCdSiteSSNDeptAgencyAssignNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliGrpCdSiteSSNDeptAgencyAssignNo index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliGrpCdSiteSSNDeptAgencyAssignNo] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC,
		[SSN] ASC,
		[DeptNo] ASC,
		[AgencyNo] ASC,
		[AssignmentNo] ASC
	)
	INCLUDE ( 	[RecordID],
		[StartDate],
		[EndDate],
		[ApproverUserId1],
		[InOuts],
		[ApprovalMethodID],
		[EligibleForHolidayPay],
		[OTOverrideRuleID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) 
		ON	[PRIMARY]

	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliGrpCdSiteSSNDeptAssignRecID')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliGrpCdSiteSSNDeptAssignRecID index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliGrpCdSiteSSNDeptAssignRecID] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC,
		[SSN] ASC,
		[DeptNo] ASC,
		[AssignmentNo] ASC,
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliGrpCdStartDtEndDtSSNDeptAppMethID')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliGrpCdStartDtEndDtSSNDeptAppMethID index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliGrpCdStartDtEndDtSSNDeptAppMethID] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[StartDate] ASC,
		[EndDate] ASC,
		[SSN] ASC,
		[DeptNo] ASC,
		[ApprovalMethodID] ASC
	)
	INCLUDE ( 	[RecordID],
		[SiteNo],
		[ApproverUserId1],
		[ApproverUserId2]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliIDCLi')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliIDCLi index ...'
	
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliIDCLi] ON [dbo].[tblEmplAssignmentsNew]
	(
		[ClientId] ASC,
		[Client] ASC
	)
	INCLUDE ( 	[GroupCode],
		[SSN],
		[DeptNo],
		[SiteNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_CliWSGrpCdBlBrand')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_CliWSGrpCdBlBrand index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_CliWSGrpCdBlBrand] ON [dbo].[tblEmplAssignmentsNew]
	(
		[Client] ASC,
		[WorkState] ASC,
		[GroupCode] ASC,
		[BusinessLine] ASC,
		[Brand] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_DeptCliGrpCdSSNSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_DeptCliGrpCdSSNSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_DeptCliGrpCdSSNSite] ON [dbo].[tblEmplAssignmentsNew]
	(
		[DeptNo] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[EligibleForHolidayPay]) 
	WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_GrpCdCliWSBrand')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_GrpCdCliWSBrand index ...'
	
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_GrpCdCliWSBrand] ON [dbo].[tblEmplAssignmentsNew]
	(
		[GroupCode] ASC,
		[Client] ASC,
		[WorkState] ASC,
		[Brand] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_RecordID_SSN_Client_AssignmentNo_GroupCode_DeptNo_Brand')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_RecordID_SSN_Client_AssignmentNo_GroupCode_DeptNo_Brand index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplAssignments_RecordID_SSN_Client_AssignmentNo_GroupCode_DeptNo_Brand] ON [dbo].[tblEmplAssignmentsNew]
	(
		[RecordID] ASC,
		[SSN] ASC,
		[Client] ASC,
		[AssignmentNo] ASC,
		[GroupCode] ASC,
		[DeptNo] ASC,
		[Brand] ASC
	)
	INCLUDE ( 	[TimeEntryFreqID],
		[SiteNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplAssignmentsNew]') AND name = N'IX_tblEmplAssignments_SSNDeptNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplAssignments_SSNDeptNo index ...'
	CREATE UNIQUE NONCLUSTERED INDEX [IX_tblEmplAssignments_SSNDeptNo] ON [dbo].[tblEmplAssignmentsNew]
	(
		[SSN] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[AssignmentNo] ASC,
		[DeptNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	
	END
GO