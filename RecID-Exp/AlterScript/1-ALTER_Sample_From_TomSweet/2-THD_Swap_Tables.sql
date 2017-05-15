USE [TimeHistory];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO


------------------------------------
-- first rename OLD dependant objects (PK, FKs, Indexes, Triggers, and Defaults)
------------------------------------
BEGIN TRAN;


BEGIN TRY
	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblTimeHistDetail_xAdjHoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_xAdjHours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_xAdjHours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_xAdjHours',
                'DF_tblTimeHistDetail_xAdjHoursOld', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_UserCodeOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_UserCode') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_UserCode ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_UserCode',
                'DF_tblTimeHistDetail_UserCodeOld', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_TransTypeOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_TransType') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_TransType ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_TransType',
                'DF_tblTimeHistDetail_TransTypeOld', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_ShiftNoOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_ShiftNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_ShiftNo ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_ShiftNo',
                'DF_tblTimeHistDetail_ShiftNoOld', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_ShiftDiffClassOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_ShiftDiffClass') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_ShiftDiffClass ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_ShiftDiffClass',
                'DF_tblTimeHistDetail_ShiftDiffClassOld', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_RegHoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_RegHours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_RegHours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_RegHours',
                'DF_tblTimeHistDetail_RegHoursOld', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_RegDollars1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_RegDollars1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_RegDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_RegDollars1',
                'DF_tblTimeHistDetail_RegDollars1Old', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_RegBillingDollars1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_RegBillingDollars1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_RegBillingDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_RegBillingDollars1',
                'DF_tblTimeHistDetail_RegBillingDollars1Old', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_PayRateOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_PayRate') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_PayRate ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_PayRate',
                'DF_tblTimeHistDetail_PayRateOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OutDayOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OutDay') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OutDay ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OutDay',
                'DF_tblTimeHistDetail_OutDayOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OTBillingDollars1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OTBillingDollars1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OTBillingDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OTBillingDollars1',
                'DF_tblTimeHistDetail_OTBillingDollars1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OT_HoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OT_Hours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OT_Hours',
                'DF_tblTimeHistDetail_OT_HoursOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OT_Dollars1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OT_Dollars1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OT_Dollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OT_Dollars1',
                'DF_tblTimeHistDetail_OT_Dollars1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_JobIDOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_JobID') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_JobID ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_JobID',
                'DF_tblTimeHistDetail_JobIDOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_InDayOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_InDay') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_InDay ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_InDay',
                'DF_tblTimeHistDetail_InDayOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_HoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_Hours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_Hours',
                'DF_tblTimeHistDetail_HoursOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_HandledByImporterOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_HandledByImporter') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_HandledByImporter ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_HandledByImporter',
                'DF_tblTimeHistDetail_HandledByImporterOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_EmpStatusOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_EmpStatus') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_EmpStatus ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_EmpStatus',
                'DF_tblTimeHistDetail_EmpStatusOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DTBillingDollars1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DTBillingDollars1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_DTBillingDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DTBillingDollars1',
                'DF_tblTimeHistDetail_DTBillingDollars1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DT_HoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DT_Hours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_DT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DT_Hours',
                'DF_tblTimeHistDetail_DT_HoursOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DT_Dollars1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DT_Dollars1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_DT_Dollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DT_Dollars1',
                'DF_tblTimeHistDetail_DT_Dollars1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DollarsOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_Dollars') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_Dollars ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_Dollars',
                'DF_tblTimeHistDetail_DollarsOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_ClkTransNoOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_ClkTransNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_ClkTransNo ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_ClkTransNo',
                'DF_tblTimeHistDetail_ClkTransNoOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_BorrowedOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_Borrowed') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_Borrowed ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_Borrowed',
                'DF_tblTimeHistDetail_BorrowedOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_BillRateOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_BillRate') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_BillRate ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_BillRate',
                'DF_tblTimeHistDetail_BillRateOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AprvlStatus_UserID1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AprvlStatus_UserID1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AprvlStatus_UserID1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AprvlStatus_UserID1',
                'DF_tblTimeHistDetail_AprvlStatus_UserID1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AprvlStatusOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AprvlStatus') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AprvlStatus ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AprvlStatus',
                'DF_tblTimeHistDetail_AprvlStatusOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AllocatedRegHoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AllocatedRegHours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AllocatedRegHours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AllocatedRegHours',
                'DF_tblTimeHistDetail_AllocatedRegHoursOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AllocatedOT_HoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AllocatedOT_Hours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AllocatedOT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AllocatedOT_Hours',
                'DF_tblTimeHistDetail_AllocatedOT_HoursOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AllocatedDT_HoursOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AllocatedDT_Hours') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AllocatedDT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AllocatedDT_Hours',
                'DF_tblTimeHistDetail_AllocatedDT_HoursOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AgencyNoOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AgencyNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AgencyNo ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AgencyNo',
                'DF_tblTimeHistDetail_AgencyNoOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_RegDollars_1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_RegDollars_1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_RegDollars_1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_RegDollars_1',
                'DF_tblTimeHist_RegDollars_1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_RegBillingD_2Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_RegBillingD_2') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_RegBillingD_2 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_RegBillingD_2',
                'DF_tblTimeHist_RegBillingD_2Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_OTBillingDo_2Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_OTBillingDo_2') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_OTBillingDo_2 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_OTBillingDo_2',
                'DF_tblTimeHist_OTBillingDo_2Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_OT_Dollars_1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_OT_Dollars_1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_OT_Dollars_1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_OT_Dollars_1',
                'DF_tblTimeHist_OT_Dollars_1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_DTBillingDo_2Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_DTBillingDo_2') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_DTBillingDo_2 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_DTBillingDo_2',
                'DF_tblTimeHist_DTBillingDo_2Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_DT_Dollars_1Old') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_DT_Dollars_1') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_DT_Dollars_1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_DT_Dollars_1',
                'DF_tblTimeHist_DT_Dollars_1Old', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_BillOTRateOOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_BillOTRateO') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_BillOTRateO ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_BillOTRateO',
                'DF_tblTimeHist_BillOTRateOOld', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_BillOTRateOld') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_BillOTRate') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_BillOTRate ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_BillOTRate',
                'DF_tblTimeHist_BillOTRateOld', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblTimeHistDetailOld') IS NULL
         AND OBJECT_ID('PK_tblTimeHistDetail') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblTimeHistDetail ...';
            EXEC dbo.sp_rename 'PK_tblTimeHistDetail',
                'PK_tblTimeHistDetailOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblTimeHistDetailOld'
                                AND si.object_id = OBJECT_ID('tblTimeHistDetail') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblTimeHistDetail'
                                AND si.object_id = OBJECT_ID('tblTimeHistDetail') )
         AND OBJECT_ID('tblTimeHistDetailOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblTimeHistDetail index ...';
            EXEC dbo.sp_rename 'tblTimeHistDetail.PK_tblTimeHistDetail',
                'PK_tblTimeHistDetailOld', 'INDEX';
        END;

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblTimeHistDetail_xAdjHours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_xAdjHoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_xAdjHours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_xAdjHoursNew',
                'DF_tblTimeHistDetail_xAdjHours', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_UserCode') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_UserCodeNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_UserCode ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_UserCodeNew',
                'DF_tblTimeHistDetail_UserCode', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_TransType') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_TransTypeNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_TransType ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_TransTypeNew',
                'DF_tblTimeHistDetail_TransType', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_ShiftNo') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_ShiftNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_ShiftNo ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_ShiftNoNew',
                'DF_tblTimeHistDetail_ShiftNo', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_ShiftDiffClass') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_ShiftDiffClassNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_ShiftDiffClass ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_ShiftDiffClassNew',
                'DF_tblTimeHistDetail_ShiftDiffClass', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_RegHours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_RegHoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_RegHours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_RegHoursNew',
                'DF_tblTimeHistDetail_RegHours', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_RegDollars1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_RegDollars1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_RegDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_RegDollars1New',
                'DF_tblTimeHistDetail_RegDollars1', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_RegBillingDollars1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_RegBillingDollars1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_RegBillingDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_RegBillingDollars1New',
                'DF_tblTimeHistDetail_RegBillingDollars1', 'OBJECT';
        END;

    IF ( OBJECT_ID('DF_tblTimeHistDetail_PayRate') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_PayRateNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_PayRate ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_PayRateNew',
                'DF_tblTimeHistDetail_PayRate', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OutDay') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OutDayNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OutDay ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OutDayNew',
                'DF_tblTimeHistDetail_OutDay', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OTBillingDollars1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OTBillingDollars1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OTBillingDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OTBillingDollars1New',
                'DF_tblTimeHistDetail_OTBillingDollars1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OT_Hours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OT_HoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OT_HoursNew',
                'DF_tblTimeHistDetail_OT_Hours', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_OT_Dollars1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_OT_Dollars1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_OT_Dollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_OT_Dollars1New',
                'DF_tblTimeHistDetail_OT_Dollars1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_JobID') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_JobIDNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_JobID ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_JobIDNew',
                'DF_tblTimeHistDetail_JobID', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_InDay') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_InDayNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_InDay ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_InDayNew',
                'DF_tblTimeHistDetail_InDay', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_Hours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_HoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_HoursNew',
                'DF_tblTimeHistDetail_Hours', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_HandledByImporter') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_HandledByImporterNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_HandledByImporter ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_HandledByImporterNew',
                'DF_tblTimeHistDetail_HandledByImporter', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_EmpStatus') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_EmpStatusNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_EmpStatus ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_EmpStatusNew',
                'DF_tblTimeHistDetail_EmpStatus', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DTBillingDollars1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DTBillingDollars1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_DTBillingDollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DTBillingDollars1New',
                'DF_tblTimeHistDetail_DTBillingDollars1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DT_Hours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DT_HoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_DT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DT_HoursNew',
                'DF_tblTimeHistDetail_DT_Hours', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_DT_Dollars1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DT_Dollars1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_DT_Dollars1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DT_Dollars1New',
                'DF_tblTimeHistDetail_DT_Dollars1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_Dollars') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_DollarsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_Dollars ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_DollarsNew',
                'DF_tblTimeHistDetail_Dollars', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_ClkTransNo') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_ClkTransNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_ClkTransNo ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_ClkTransNoNew',
                'DF_tblTimeHistDetail_ClkTransNo', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_Borrowed') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_BorrowedNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_Borrowed ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_BorrowedNew',
                'DF_tblTimeHistDetail_Borrowed', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_BillRate') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_BillRateNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_BillRate ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_BillRateNew',
                'DF_tblTimeHistDetail_BillRate', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AprvlStatus_UserID1') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AprvlStatus_UserID1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AprvlStatus_UserID1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AprvlStatus_UserID1New',
                'DF_tblTimeHistDetail_AprvlStatus_UserID1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AprvlStatus') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AprvlStatusNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AprvlStatus ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AprvlStatusNew',
                'DF_tblTimeHistDetail_AprvlStatus', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AllocatedRegHours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AllocatedRegHoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AllocatedRegHours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AllocatedRegHoursNew',
                'DF_tblTimeHistDetail_AllocatedRegHours', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AllocatedOT_Hours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AllocatedOT_HoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AllocatedOT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AllocatedOT_HoursNew',
                'DF_tblTimeHistDetail_AllocatedOT_Hours', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AllocatedDT_Hours') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AllocatedDT_HoursNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AllocatedDT_Hours ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AllocatedDT_HoursNew',
                'DF_tblTimeHistDetail_AllocatedDT_Hours', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHistDetail_AgencyNo') IS NULL
         AND OBJECT_ID('DF_tblTimeHistDetail_AgencyNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHistDetail_AgencyNo ...';
            EXEC dbo.sp_rename 'DF_tblTimeHistDetail_AgencyNoNew',
                'DF_tblTimeHistDetail_AgencyNo', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_RegDollars_1') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_RegDollars_1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_RegDollars_1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_RegDollars_1New',
                'DF_tblTimeHist_RegDollars_1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_RegBillingD_2') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_RegBillingD_2New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_RegBillingD_2 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_RegBillingD_2New',
                'DF_tblTimeHist_RegBillingD_2', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_OTBillingDo_2') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_OTBillingDo_2New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_OTBillingDo_2 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_OTBillingDo_2New',
                'DF_tblTimeHist_OTBillingDo_2', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_OT_Dollars_1') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_OT_Dollars_1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_OT_Dollars_1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_OT_Dollars_1New',
                'DF_tblTimeHist_OT_Dollars_1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_DTBillingDo_2') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_DTBillingDo_2New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_DTBillingDo_2 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_DTBillingDo_2New',
                'DF_tblTimeHist_DTBillingDo_2', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_DT_Dollars_1') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_DT_Dollars_1New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_DT_Dollars_1 ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_DT_Dollars_1New',
                'DF_tblTimeHist_DT_Dollars_1', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_BillOTRateO') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_BillOTRateONew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_BillOTRateO ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_BillOTRateONew',
                'DF_tblTimeHist_BillOTRateO', 'OBJECT';
        END;


    IF ( OBJECT_ID('DF_tblTimeHist_BillOTRate') IS NULL
         AND OBJECT_ID('DF_tblTimeHist_BillOTRateNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblTimeHist_BillOTRate ...';
            EXEC dbo.sp_rename 'DF_tblTimeHist_BillOTRateNew',
                'DF_tblTimeHist_BillOTRate', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblTimeHistDetail') IS NULL
         AND OBJECT_ID('PK_tblTimeHistDetailNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblTimeHistDetail ...';
            EXEC dbo.sp_rename 'PK_tblTimeHistDetailNew',
                'PK_tblTimeHistDetail', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblTimeHistDetail'
                                AND si.object_id = OBJECT_ID('tblTimeHistDetailNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblTimeHistDetail'
                                AND si.object_id = OBJECT_ID('tblTimeHistDetailNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblTimeHistDetail index ...';
            EXEC dbo.sp_rename 'tblTimeHistDetailNew.PK_tblTimeHistDetailNew',
                'PK_tblTimeHistDetail', 'INDEX';
        END;


	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblTimeHistDetailOld') IS NULL
         AND OBJECT_ID('tblTimeHistDetail') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblTimeHistDetail ...';
            EXEC dbo.sp_rename 'tblTimeHistDetail', 'tblTimeHistDetailOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblTimeHistDetail') IS NULL
         AND OBJECT_ID('tblTimeHistDetailNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblTimeHistDetailNew ...';
            EXEC dbo.sp_rename 'tblTimeHistDetailNew', 'tblTimeHistDetail',
                'OBJECT';
        END;

END TRY
BEGIN CATCH

    IF ( @@TRANCOUNT > 0 )
        BEGIN
            ROLLBACK TRAN;
        END;

    DECLARE @ErrorMessage NVARCHAR(4000);
    SET @ErrorMessage = 'ERROR on Line ' + CONVERT(VARCHAR(20), ERROR_LINE())
        + ': ' + ERROR_MESSAGE();
    RAISERROR(@ErrorMessage, 16, 1);

END CATCH;


IF ( @@TRANCOUNT > 0 )
    BEGIN
        COMMIT TRAN;
    END;
GO


