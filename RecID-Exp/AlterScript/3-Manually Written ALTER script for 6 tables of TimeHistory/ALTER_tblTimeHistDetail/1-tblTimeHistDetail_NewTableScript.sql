--New Script by Hanife
USE [TimeHistory];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND TYPE IN (N'U'))
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblTimeHistDetailNew table ...';
	--Creating new Table
	CREATE TABLE [dbo].[tblTimeHistDetailNew](
	[RecordID] [BIGINT] IDENTITY(1,1) NOT NULL,--<RecordId datatype is changed from INT to BIGINT>--
	[Client] [char](4) NOT NULL,
	[GroupCode] [int] NOT NULL,
	[SSN] [int] NOT NULL,
	[PayrollPeriodEndDate] [datetime] NOT NULL,
	[MasterPayrollDate] [datetime] NOT NULL,
	[SiteNo] [INT] NOT NULL, --<SiteNo datatype is changed from SMALLINT to INT>--
	[DeptNo] [INT] NOT NULL,  --<DeptNo datatype is changed from SMALLINT to INT>--
	[JobID] [BIGINT] NOT NULL CONSTRAINT [DF_tblTimeHistDetail_JobIDNew]  DEFAULT (0),  --<JobId datatype is changed from INT to BIGINT>--
	[TransDate] [datetime] NULL,
	[EmpStatus] [tinyint] NULL CONSTRAINT [DF_tblTimeHistDetail_EmpStatusNew]  DEFAULT (0),
	[BillRate] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_BillRateNew]  DEFAULT (0),
	[BillOTRate] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_BillOTRateNew]  DEFAULT (0),
	[BillOTRateOverride] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_BillOTRateONew]  DEFAULT (0),
	[PayRate] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_PayRateNew]  DEFAULT (0),
	[ShiftNo] [tinyint] NULL CONSTRAINT [DF_tblTimeHistDetail_ShiftNoNew]  DEFAULT (0),
	[InDay] [tinyint] NULL CONSTRAINT [DF_tblTimeHistDetail_InDayNew]  DEFAULT (0),
	[InTime] [datetime] NULL,
	[OutDay] [tinyint] NULL CONSTRAINT [DF_tblTimeHistDetail_OutDayNew]  DEFAULT (0),
	[OutTime] [datetime] NULL,
	[Hours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_HoursNew]  DEFAULT (0),
	[Dollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_DollarsNew]  DEFAULT (0),
	[ClockAdjustmentNo] [varchar](3) NULL,
	[AdjustmentCode] [varchar](3) NULL,
	[AdjustmentName] [varchar](10) NULL,
	[TransType] [tinyint] NULL CONSTRAINT [DF_tblTimeHistDetail_TransTypeNew]  DEFAULT (0),
	[Changed_DeptNo] [char](1) NULL,
	[Changed_InPunch] [char](1) NULL,
	[Changed_OutPunch] [char](1) NULL,
	[AgencyNo] [smallint] NULL CONSTRAINT [DF_tblTimeHistDetail_AgencyNoNew]  DEFAULT (0),
	[InSrc] [char](1) NULL,
	[OutSrc] [char](1) NULL,
	[DaylightSavTime] [char](1) NULL,
	[Holiday] [char](1) NULL,
	[RegHours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_RegHoursNew]  DEFAULT (0),
	[OT_Hours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_OT_HoursNew]  DEFAULT (0),
	[DT_Hours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_DT_HoursNew]  DEFAULT (0),
	[RegDollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_RegDollars_1New]  DEFAULT (0),
	[OT_Dollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_OT_Dollars_1New]  DEFAULT (0),
	[DT_Dollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_DT_Dollars_1New]  DEFAULT (0),
	[RegBillingDollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_RegBillingD_2New]  DEFAULT (0),
	[OTBillingDollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_OTBillingDo_2New]  DEFAULT (0),
	[DTBillingDollars] [numeric](7, 2) NULL CONSTRAINT [DF_tblTimeHist_DTBillingDo_2New]  DEFAULT (0),
	[CountAsOT] [char](1) NULL,
	[RegDollars4] [numeric](9, 4) NULL CONSTRAINT [DF_tblTimeHistDetail_RegDollars1New]  DEFAULT (0),
	[OT_Dollars4] [numeric](9, 4) NULL CONSTRAINT [DF_tblTimeHistDetail_OT_Dollars1New]  DEFAULT (0),
	[DT_Dollars4] [numeric](9, 4) NULL CONSTRAINT [DF_tblTimeHistDetail_DT_Dollars1New]  DEFAULT (0),
	[RegBillingDollars4] [numeric](9, 4) NULL CONSTRAINT [DF_tblTimeHistDetail_RegBillingDollars1New]  DEFAULT (0),
	[OTBillingDollars4] [numeric](9, 4) NULL CONSTRAINT [DF_tblTimeHistDetail_OTBillingDollars1New]  DEFAULT (0),
	[DTBillingDollars4] [numeric](9, 4) NULL CONSTRAINT [DF_tblTimeHistDetail_DTBillingDollars1New]  DEFAULT (0),
	[xAdjHours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_xAdjHoursNew]  DEFAULT (0),
	[AprvlStatus] [char](1) NULL CONSTRAINT [DF_tblTimeHistDetail_AprvlStatusNew]  DEFAULT (' '),
	[AprvlStatus_UserID] [int] NULL CONSTRAINT [DF_tblTimeHistDetail_AprvlStatus_UserID1New]  DEFAULT (0),
	[AprvlStatus_Date] [datetime] NULL,
	[AprvlAdjOrigRecID] [BIGINT] NULL,  --<AprvlAdjOrigRecId datatype is changed from INT to BIGINT>--
	[HandledByImporter] [char](1) NULL CONSTRAINT [DF_tblTimeHistDetail_HandledByImporterNew]  DEFAULT ('0'),
	[AprvlAdjOrigClkAdjNo] [varchar](3) NULL,
	[ClkTransNo] [BIGINT] NULL CONSTRAINT [DF_tblTimeHistDetail_ClkTransNoNew]  DEFAULT (0),  --<ClkTransNo datatype is changed from INT to BIGINT>--
	[ShiftDiffClass] [char](1) NULL CONSTRAINT [DF_tblTimeHistDetail_ShiftDiffClassNew]  DEFAULT (''),
	[AllocatedRegHours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_AllocatedRegHoursNew]  DEFAULT (0),
	[AllocatedOT_Hours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_AllocatedOT_HoursNew]  DEFAULT (0),
	[AllocatedDT_Hours] [numeric](5, 2) NULL CONSTRAINT [DF_tblTimeHistDetail_AllocatedDT_HoursNew]  DEFAULT (0),
	[Borrowed] [char](1) NULL CONSTRAINT [DF_tblTimeHistDetail_BorrowedNew]  DEFAULT (0),
	[UserCode] [varchar](5) NULL CONSTRAINT [DF_tblTimeHistDetail_UserCodeNew]  DEFAULT (''),
	[DivisionID] [BIGINT] NULL,  --<DivisionId datatype is changed from INT to BIGINT>--
	[CostID] [varchar](30) NULL,
	[ShiftDiffAmt] [numeric](5, 2) NULL,
	[OutUserCode] [varchar](5) NULL,
	[ActualInTime] [datetime] NULL,
	[ActualOutTime] [datetime] NULL,
	[InSiteNo] [int] NULL,
	[OutSiteNo] [int] NULL,
	[InVerified] [char](1) NULL,
	[OutVerified] [char](1) NULL,
	[InClass] [char](1) NULL,
	[OutClass] [char](1) NULL,
	[InTimestamp] [bigint] NULL,
	[outTimestamp] [bigint] NULL,
	[CrossoverStatus] [char](1) NULL,
	[CrossoverOtherGroup] [int] NULL,
	[InRoundOFF] [char](1) NULL,
	[OutRoundOFF] [char](1) NULL,
	[AprvlStatus_Mobile] [bit] NULL,
 CONSTRAINT [PK_tblTimeHistDetailNew] PRIMARY KEY NONCLUSTERED 
(
	[RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY];

	END;
GO

SET ANSI_PADDING ON;
GO

--Creating the Clustered Indexers
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'tblTimeHistDetail_ClientGrpPPSSNEtc')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create tblTimeHistDetail_ClientGrpPPSSNEtc index ...';
	CREATE CLUSTERED INDEX [tblTimeHistDetail_ClientGrpPPSSNEtc] ON [dbo].[tblTimeHistDetailNew]
	(
	[Client] ASC,
	[GroupCode] ASC,
	[PayrollPeriodEndDate] ASC,
	[SSN] ASC,
	[SiteNo] ASC,
	[DeptNo] ASC,
	[JobID] ASC,
	[ClockAdjustmentNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY];

	END;
GO

SET ANSI_PADDING ON;
GO

--Insert the data from tblTimeHistDetail to new table
USE [TimeHistory];
GO

SET QUOTED_IDENTIFIER ON;
SET IDENTITY_INSERT dbo.tblTimeHistDetailNew ON;
SET NOCOUNT ON;

INSERT INTO [dbo].[tblTimeHistDetailNew]
           ([RecordID]
		   ,[Client]
           ,[GroupCode]
           ,[SSN]
           ,[PayrollPeriodEndDate]
           ,[MasterPayrollDate]
           ,[SiteNo]
           ,[DeptNo]
           ,[JobID]
           ,[TransDate]
           ,[EmpStatus]
           ,[BillRate]
           ,[BillOTRate]
           ,[BillOTRateOverride]
           ,[PayRate]
           ,[ShiftNo]
           ,[InDay]
           ,[InTime]
           ,[OutDay]
           ,[OutTime]
           ,[Hours]
           ,[Dollars]
           ,[ClockAdjustmentNo]
           ,[AdjustmentCode]
           ,[AdjustmentName]
           ,[TransType]
           ,[Changed_DeptNo]
           ,[Changed_InPunch]
           ,[Changed_OutPunch]
           ,[AgencyNo]
           ,[InSrc]
           ,[OutSrc]
           ,[DaylightSavTime]
           ,[Holiday]
           ,[RegHours]
           ,[OT_Hours]
           ,[DT_Hours]
           ,[RegDollars]
           ,[OT_Dollars]
           ,[DT_Dollars]
           ,[RegBillingDollars]
           ,[OTBillingDollars]
           ,[DTBillingDollars]
           ,[CountAsOT]
           ,[RegDollars4]
           ,[OT_Dollars4]
           ,[DT_Dollars4]
           ,[RegBillingDollars4]
           ,[OTBillingDollars4]
           ,[DTBillingDollars4]
           ,[xAdjHours]
           ,[AprvlStatus]
           ,[AprvlStatus_UserID]
           ,[AprvlStatus_Date]
           ,[AprvlAdjOrigRecID]
           ,[HandledByImporter]
           ,[AprvlAdjOrigClkAdjNo]
           ,[ClkTransNo]
           ,[ShiftDiffClass]
           ,[AllocatedRegHours]
           ,[AllocatedOT_Hours]
           ,[AllocatedDT_Hours]
           ,[Borrowed]
           ,[UserCode]
           ,[DivisionID]
           ,[CostID]
           ,[ShiftDiffAmt]
           ,[OutUserCode]
           ,[ActualInTime]
           ,[ActualOutTime]
           ,[InSiteNo]
           ,[OutSiteNo]
           ,[InVerified]
           ,[OutVerified]
           ,[InClass]
           ,[OutClass]
           ,[InTimestamp]
           ,[outTimestamp]
           ,[CrossoverStatus]
           ,[CrossoverOtherGroup]
           ,[InRoundOFF]
           ,[OutRoundOFF]
           ,[AprvlStatus_Mobile])
		SELECT  [RecordID]
				,[Client]
				,[GroupCode]
				,[SSN]
				,[PayrollPeriodEndDate]
				,[MasterPayrollDate]
				,[SiteNo]
				,[DeptNo]
				,[JobID]
				,[TransDate]
				,[EmpStatus]
				,[BillRate]
				,[BillOTRate]
				,[BillOTRateOverride]
				,[PayRate]
				,[ShiftNo]
				,[InDay]
				,[InTime]
				,[OutDay]
				,[OutTime]
				,[Hours]
				,[Dollars]
				,[ClockAdjustmentNo]
				,[AdjustmentCode]
				,[AdjustmentName]
				,[TransType]
				,[Changed_DeptNo]
				,[Changed_InPunch]
				,[Changed_OutPunch]
				,[AgencyNo]
				,[InSrc]
				,[OutSrc]
				,[DaylightSavTime]
				,[Holiday]
				,[RegHours]
				,[OT_Hours]
				,[DT_Hours]
				,[RegDollars]
				,[OT_Dollars]
				,[DT_Dollars]
				,[RegBillingDollars]
				,[OTBillingDollars]
				,[DTBillingDollars]
				,[CountAsOT]
				,[RegDollars4]
				,[OT_Dollars4]
				,[DT_Dollars4]
				,[RegBillingDollars4]
				,[OTBillingDollars4]
				,[DTBillingDollars4]
				,[xAdjHours]
				,[AprvlStatus]
				,[AprvlStatus_UserID]
				,[AprvlStatus_Date]
				,[AprvlAdjOrigRecID]
				,[HandledByImporter]
				,[AprvlAdjOrigClkAdjNo]
				,[ClkTransNo]
				,[ShiftDiffClass]
				,[AllocatedRegHours]
				,[AllocatedOT_Hours]
				,[AllocatedDT_Hours]
				,[Borrowed]
				,[UserCode]
				,[DivisionID]
				,[CostID]
				,[ShiftDiffAmt]
				,[OutUserCode]
				,[ActualInTime]
				,[ActualOutTime]
				,[InSiteNo]
				,[OutSiteNo]
				,[InVerified]
				,[OutVerified]
				,[InClass]
				,[OutClass]
				,[InTimestamp]
				,[outTimestamp]
				,[CrossoverStatus]
				,[CrossoverOtherGroup]
				,[InRoundOFF]
				,[OutRoundOFF]
				,[AprvlStatus_Mobile]
		FROM [dbo].[tblTimeHistDetail]

USE TimeHistory
go

--NonClustered Index Creation

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IdxTimeHistDetailPPED')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IdxTimeHistDetailPPED index ...';
	CREATE NONCLUSTERED INDEX [IdxTimeHistDetailPPED] ON [dbo].[tblTimeHistDetailNew]
	(
		[PayrollPeriodEndDate] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[SiteNo] ASC,
		[DeptNo] ASC
	)
	INCLUDE ( 	[SSN],
		[Hours],
		[ClockAdjustmentNo],
		[RegBillingDollars],
		[OTBillingDollars],
		[DTBillingDollars],
		[AprvlStatus],
		[RecordID],
		[UserCode]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [primary]
	END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail] ON [dbo].[tblTimeHistDetailNew]
	(
		[MasterPayrollDate] ASC,
		[SSN] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_AprStatPPEDCliGrpHrsSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_AprStatPPEDCliGrpHrsSSN index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_AprStatPPEDCliGrpHrsSSN] ON [dbo].[tblTimeHistDetailNew]
	(
		[AprvlStatus] ASC,
		[PayrollPeriodEndDate] ASC,
		[Client] ASC,
		[GroupCode] ASC,
		[Hours] ASC,
		[SSN] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_CliGrpCdSSNPPEDSiteDept')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_CliGrpCdSSNPPEDSiteDept index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_CliGrpCdSSNPPEDSiteDept] ON [dbo].[tblTimeHistDetailNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[SSN] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC,
		[DeptNo] ASC
	)
	INCLUDE ( 	[RecordID],
		[Hours],
		[ClockAdjustmentNo],
		[TransType],
		[AprvlStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_CliGrpPPEDSSN')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_CliGrpPPEDSSN index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_CliGrpPPEDSSN] ON [dbo].[tblTimeHistDetailNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SSN] ASC
	)
	INCLUDE ( 	[Hours]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_Grp_PPED_Site')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_Grp_PPED_Site index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_Grp_PPED_Site] ON [dbo].[tblTimeHistDetailNew]
	(
		[SiteNo] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO
SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_Grp_Transdate')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_Grp_Transdate index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_Grp_Transdate] ON [dbo].[tblTimeHistDetailNew]
	(
		[TransDate] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_GrpCdCliOutDayPPED')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_GrpCdCliOutDayPPED index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_GrpCdCliOutDayPPED] ON [dbo].[tblTimeHistDetailNew]
	(
		[GroupCode] ASC,
		[Client] ASC,
		[OutDay] ASC,
		[PayrollPeriodEndDate] ASC
	)
	INCLUDE ( 	[SSN],
		[SiteNo],
		[DeptNo],
		[JobID],
		[TransDate],
		[InDay],
		[InTime],
		[ClockAdjustmentNo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON			[PRIMARY]
	END
GO

SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetail_SSNGrpCliPPEDSiteRecIDClkAdj')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetail_SSNGrpCliPPEDSiteRecIDClkAdj index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetail_SSNGrpCliPPEDSiteRecIDClkAdj] ON [dbo].[tblTimeHistDetailNew]
	(
		[SSN] ASC,
		[GroupCode] ASC,
		[Client] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC,
		[RecordID] ASC,
		[ClockAdjustmentNo] ASC
	)
	INCLUDE ( 	[DeptNo],
		[JobID],
		[Hours],
		[RegBillingDollars],
		[OTBillingDollars],
		[DTBillingDollars],
		[AprvlStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'ix_tblTimeHistDetail_SSNPPED')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create ix_tblTimeHistDetail_SSNPPED index ...';
	CREATE NONCLUSTERED INDEX [ix_tblTimeHistDetail_SSNPPED] ON [dbo].[tblTimeHistDetailNew]
	(
		[SSN] ASC,
		[PayrollPeriodEndDate] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	END
GO

SET ANSI_PADDING ON
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[tblTimeHistDetailNew]') AND name = N'IX_tblTimeHistDetailClientSiteNo')
	BEGIN
	PRINT CONVERT(VARCHAR(30), GETDATE(), 121) + ' -- Create IX_tblTimeHistDetailClientSiteNo index ...';
	CREATE NONCLUSTERED INDEX [IX_tblTimeHistDetailClientSiteNo] ON [dbo].[tblTimeHistDetailNew]
	(
		[Client] ASC,
		[GroupCode] ASC,
		[PayrollPeriodEndDate] ASC,
		[SiteNo] ASC
	)
	INCLUDE ( 	[RecordID],
		[SSN],
		[DeptNo],
		[TransDate],
		[Hours],
		[ClockAdjustmentNo],
		[RegBillingDollars],
		[OTBillingDollars],
		[DTBillingDollars],
		[AprvlStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	END
GO

