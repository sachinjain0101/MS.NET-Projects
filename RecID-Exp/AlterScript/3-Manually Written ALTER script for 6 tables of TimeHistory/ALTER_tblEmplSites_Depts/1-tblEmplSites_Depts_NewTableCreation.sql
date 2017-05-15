USE [TimeHistory]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblEmplSites_DeptsNew table ...'
	CREATE TABLE [dbo].[tblEmplSites_DeptsNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[PayrollPeriodEndDate] [datetime] NOT NULL,
	[SiteNo] [INT] NOT NULL,
	[SSN] [int] NOT NULL,
	[DeptSeq] [smallint] NULL,
	[DeptNo] [INT] NOT NULL,
	[AssignmentNo] [varchar](32) NULL,
	[JobAssignmentNo] [varchar](7) NULL,
	[PayRate] [numeric](7, 2) NULL,
	[BillRate] [numeric](7, 2) NULL,
	[NewPNE_Entry] [char](1) NULL,
	[AssignmentStartDate] [datetime] NULL,
	[PurchOrderNo] [varchar](30) NULL,
	[RecordStatus] [char](1) NULL,
	[TECommentCategory] [int] NULL DEFAULT (0),
	[TEComment] [varchar](250) NULL DEFAULT (''),
	[TERating] [int] NULL,
	[APPCommentCategory] [int] NULL,
	[APPComment] [varchar](250) NULL,
	[APPRating] [int] NULL,
	[ExcludeFromUpload] [char](1) NULL,
	[ExcludeFromUpload_UserID] [int] NULL,
	[ExcludeFromUpload_DateTime] [datetime] NULL,
	[StaffingApprovalComment] [varchar](4000) NULL,
	[Timesheetimage] [varchar](80) NULL,
	[NonCompliantCode] [int] NULL,
	[NonCompliantReason] [varchar](50) NULL,
	[NonCompliantUserID] [int] NULL,
	[PayRecordsSent] [datetime] NULL,
	[EmplApprovalDate] [datetime] NULL,
	[NoHours] [varchar](1) NULL,
	[AprvlStatus] [varchar](1) NULL,
	[PartialPayRecordsTransDate] [datetime] NULL,
	[PartialPayRecordsSent] [datetime] NULL,
	[PartialPayRecordsFirstWeekTransDate] [date] NULL,
	[PartialPayRecordsLastWeekTransDate] [date] NULL,
	[PartialPayRecordsSentFirst] [datetime] NULL,
	[PartialPayRecordsSentLast] [datetime] NULL,
	[VendorReferenceID] [nvarchar](100) NULL,
	[NoHoursSetBy] [char](1) NULL,
	CONSTRAINT [PK_tblEmplSites_DeptsNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_Depts_ClientGrpPPSiteSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_Depts_ClientGrpPPSiteSSN index ...'
	CREATE UNIQUE CLUSTERED INDEX [IX_tblEmplSites_Depts_ClientGrpPPSiteSSN] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SSN] ASC,
		[SiteNo] ASC,
		[DeptNo] ASC,
		[Client] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeHistory]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblEmplSites_DeptsNew ON
SET NOCOUNT ON

INSERT INTO [dbo].[tblEmplSites_DeptsNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[PayrollPeriodEndDate]
           ,[SiteNo]
           ,[SSN]
           ,[DeptSeq]
           ,[DeptNo]
           ,[AssignmentNo]
           ,[JobAssignmentNo]
           ,[PayRate]
           ,[BillRate]
           ,[NewPNE_Entry]
           ,[AssignmentStartDate]
           ,[PurchOrderNo]
           ,[RecordStatus]
           ,[TECommentCategory]
           ,[TEComment]
           ,[TERating]
           ,[APPCommentCategory]
           ,[APPComment]
           ,[APPRating]
           ,[ExcludeFromUpload]
           ,[ExcludeFromUpload_UserID]
           ,[ExcludeFromUpload_DateTime]
           ,[StaffingApprovalComment]
           ,[Timesheetimage]
           ,[NonCompliantCode]
           ,[NonCompliantReason]
           ,[NonCompliantUserID]
           ,[PayRecordsSent]
           ,[EmplApprovalDate]
           ,[NoHours]
           ,[AprvlStatus]
           ,[PartialPayRecordsTransDate]
           ,[PartialPayRecordsSent]
           ,[PartialPayRecordsFirstWeekTransDate]
           ,[PartialPayRecordsLastWeekTransDate]
           ,[PartialPayRecordsSentFirst]
           ,[PartialPayRecordsSentLast]
           ,[VendorReferenceID]
           ,[NoHoursSetBy])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[PayrollPeriodEndDate]
      ,[SiteNo]
      ,[SSN]
      ,[DeptSeq]
      ,[DeptNo]
      ,[AssignmentNo]
      ,[JobAssignmentNo]
      ,[PayRate]
      ,[BillRate]
      ,[NewPNE_Entry]
      ,[AssignmentStartDate]
      ,[PurchOrderNo]
      ,[RecordStatus]
      ,[TECommentCategory]
      ,[TEComment]
      ,[TERating]
      ,[APPCommentCategory]
      ,[APPComment]
      ,[APPRating]
      ,[ExcludeFromUpload]
      ,[ExcludeFromUpload_UserID]
      ,[ExcludeFromUpload_DateTime]
      ,[StaffingApprovalComment]
      ,[Timesheetimage]
      ,[NonCompliantCode]
      ,[NonCompliantReason]
      ,[NonCompliantUserID]
      ,[PayRecordsSent]
      ,[EmplApprovalDate]
      ,[NoHours]
      ,[AprvlStatus]
      ,[PartialPayRecordsTransDate]
      ,[PartialPayRecordsSent]
      ,[PartialPayRecordsFirstWeekTransDate]
      ,[PartialPayRecordsLastWeekTransDate]
      ,[PartialPayRecordsSentFirst]
      ,[PartialPayRecordsSentLast]
      ,[VendorReferenceID]
      ,[NoHoursSetBy]
  FROM [dbo].[tblEmplSites_Depts]

  USE TimeHistory
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_Depts_ClGrpPPEDSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_Depts_ClGrpPPEDSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_Depts_ClGrpPPEDSite] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[SSN],
		[DeptNo],
		[ExcludeFromUpload],
		[NoHours]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'ix_tblEmplSites_Depts_SiteNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblEmplSites_Depts_SiteNo index ...'
	CREATE NONCLUSTERED INDEX [ix_tblEmplSites_Depts_SiteNo] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblEmplSites_DeptsNew]') AND name = N'IX_tblEmplSites_Depts_ssn')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblEmplSites_Depts_ssn index ...'
	CREATE NONCLUSTERED INDEX [IX_tblEmplSites_Depts_ssn] ON [dbo].[tblEmplSites_DeptsNew]
	(
		[SSN] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO