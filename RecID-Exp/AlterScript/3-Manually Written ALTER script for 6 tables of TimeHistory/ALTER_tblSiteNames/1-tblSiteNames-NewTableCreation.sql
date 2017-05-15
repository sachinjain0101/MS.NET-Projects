use TimeHistory
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tblSiteNamesNew]') AND type in (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblSiteNamesNew table ...'
	CREATE TABLE [dbo].[tblSiteNamesNew](
	[RecordID] [int] IDENTITY(1,1) NOT NULL,
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL CONSTRAINT [DF_tblSiteNames_GroupCodeNew]  DEFAULT (0),
	[PayrollPeriodEndDate] [datetime] NOT NULL,
	[SiteNo] [smallint] NOT NULL CONSTRAINT [DF_tblSiteNames_SiteNoNew]  DEFAULT (0),
	[SiteName] [varchar](60) NULL,
	[SiteAddr1] [varchar](50) NULL,
	[SiteAddr2] [varchar](50) NULL,
	[SiteCity] [varchar](30) NULL,
	[SiteState] [char](2) NULL,
	[SiteZip] [varchar](10) NULL,
	[SitePhone] [varchar](20) NULL,
	[SiteContact] [varchar](50) NULL,
	[ExportMailBox] [varchar](20) NULL,
	[DateLastUploadCreated] [datetime] NULL,
	[NotInLatestUpload] [char](1) NULL,
	[ClientFacility] [varchar](100) NULL,
	[PayrollUploadCode] [varchar](12) NULL,
	[CloseHour] [int] NULL,
	[CloseDay] [tinyint] NULL,
	[WeekClosed] [char](1) NOT NULL CONSTRAINT [DF_tblSiteNames_WeekClosedNew]  DEFAULT ('O'),
	[WeekClosedDateTime] [datetime] NULL,
	[ClockVersion] [varchar](10) NULL,
	[BackupPhoneNo] [varchar](30) NULL,
	[DefaultShift] [smallint] NULL CONSTRAINT [DF_tblSiteNames_ShiftClassificationOnNew]  DEFAULT (0),
	[OldGroup] [int] NULL,
	[SemiMoPayrollClosed] [char](1) NOT NULL CONSTRAINT [DF_tblSiteNames_SemiMoPayrollClosedNew]  DEFAULT (0),
	[SemiMoPayrollClosedDateTime] [datetime] NULL,
	[WeekClosedUserName] [varchar](50) NOT NULL CONSTRAINT [DF_tblSiteNames_WeekClosedUserNameNew]  DEFAULT (''),
	[WeekClosedUserID] [int] NOT NULL CONSTRAINT [DF_tblSiteNames_WeekClosedUserIDNew]  DEFAULT (0),
	[ExcludeFromUpload] [char](1) NOT NULL CONSTRAINT [DF_tblSiteNames_ExcludeFromUploadNew]  DEFAULT ('0'),
	[MaintUserName] [varchar](20) NULL,
	[MaintDateTime] [datetime] NULL,
	CONSTRAINT [PK_tblSiteNamesNew] PRIMARY KEY NONCLUSTERED 
	(
		[RecordID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY],
	 CONSTRAINT [IX_tblSiteNames_UCNew] UNIQUE NONCLUSTERED 
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]


	END
GO
SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblSiteNamesNew]') AND name = N'IX_tblSiteNames_ClientGrpCdPPEndDateSiteNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblSiteNames_ClientGrpCdPPEndDateSiteNo index ...'
	CREATE CLUSTERED INDEX [IX_tblSiteNames_ClientGrpCdPPEndDateSiteNo] ON [dbo].[tblSiteNamesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC,
		[WeekClosed] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90)
	END
GO

SET ANSI_PADDING ON
GO
USE [TimeHistory]
GO
SET QUOTED_IDENTIFIER ON
SET IDENTITY_INSERT dbo.tblSiteNamesNew ON
SET NOCOUNT ON

INSERT INTO [dbo].[tblSiteNamesNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[PayrollPeriodEndDate]
           ,[SiteNo]
           ,[SiteName]
           ,[SiteAddr1]
           ,[SiteAddr2]
           ,[SiteCity]
           ,[SiteState]
           ,[SiteZip]
           ,[SitePhone]
           ,[SiteContact]
           ,[ExportMailBox]
           ,[DateLastUploadCreated]
           ,[NotInLatestUpload]
           ,[ClientFacility]
           ,[PayrollUploadCode]
           ,[CloseHour]
           ,[CloseDay]
           ,[WeekClosed]
           ,[WeekClosedDateTime]
           ,[ClockVersion]
           ,[BackupPhoneNo]
           ,[DefaultShift]
           ,[OldGroup]
           ,[SemiMoPayrollClosed]
           ,[SemiMoPayrollClosedDateTime]
           ,[WeekClosedUserName]
           ,[WeekClosedUserID]
           ,[ExcludeFromUpload]
           ,[MaintUserName]
           ,[MaintDateTime])
SELECT [RecordID]
      ,[Client]
      ,[GroupCode]
      ,[PayrollPeriodEndDate]
      ,[SiteNo]
      ,[SiteName]
      ,[SiteAddr1]
      ,[SiteAddr2]
      ,[SiteCity]
      ,[SiteState]
      ,[SiteZip]
      ,[SitePhone]
      ,[SiteContact]
      ,[ExportMailBox]
      ,[DateLastUploadCreated]
      ,[NotInLatestUpload]
      ,[ClientFacility]
      ,[PayrollUploadCode]
      ,[CloseHour]
      ,[CloseDay]
      ,[WeekClosed]
      ,[WeekClosedDateTime]
      ,[ClockVersion]
      ,[BackupPhoneNo]
      ,[DefaultShift]
      ,[OldGroup]
      ,[SemiMoPayrollClosed]
      ,[SemiMoPayrollClosedDateTime]
      ,[WeekClosedUserName]
      ,[WeekClosedUserID]
      ,[ExcludeFromUpload]
      ,[MaintUserName]
      ,[MaintDateTime]
  FROM [dbo].[tblSiteNames]

  IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblSiteNamesNew]') AND name = N'IX_tblSiteNames_CliGrpCdPPEDSite')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblSiteNames_CliGrpCdPPEDSite index ...'
	CREATE NONCLUSTERED INDEX [IX_tblSiteNames_CliGrpCdPPEDSite] ON [dbo].[tblSiteNamesNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[DateLastUploadCreated],
		[NotInLatestUpload],
		[WeekClosed]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblSiteNamesNew]') AND name = N'IX_tblSiteNames_GrpCdPPEDCliSiteWeekClosed')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblSiteNames_GrpCdPPEDCliSiteWeekClosed index ...'
	CREATE NONCLUSTERED INDEX [IX_tblSiteNames_GrpCdPPEDCliSiteWeekClosed] ON [dbo].[tblSiteNamesNew]
	(
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[Client] ASC,
		[SiteNo] ASC,
		[WeekClosed] ASC
	)
	INCLUDE ( 	[DateLastUploadCreated],
		[NotInLatestUpload]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) 
		ON [PRIMARY]
	END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[tblSiteNamesNew]') AND name = N'IX_tblSiteNames_PPEndDate')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblSiteNames_PPEndDate index ...'
	CREATE NONCLUSTERED INDEX [IX_tblSiteNames_PPEndDate] ON [dbo].[tblSiteNamesNew]
	(
		[PayrollPeriodEndDate] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
