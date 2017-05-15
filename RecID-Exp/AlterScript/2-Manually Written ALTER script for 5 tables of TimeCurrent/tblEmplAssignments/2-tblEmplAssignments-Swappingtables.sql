USE [TimeCurrent]
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
    IF ( OBJECT_ID('DF__tblEmplAs__SiteN__6F42C185Old') IS NULL
         AND OBJECT_ID('DF__tblEmplAs__SiteN__6F42C185') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF__tblEmplAs__SiteN__6F42C185 ...';
            EXEC dbo.sp_rename 'DF__tblEmplAs__SiteN__6F42C185',
                'DF__tblEmplAs__SiteN__6F42C185Old', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_DeptNoOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_DeptNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_DeptNo ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_DeptNo',
                'DF_tblEmplAssignments_DeptNoOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_FinalTerminationOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_FinalTermination') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_FinalTermination ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_FinalTermination',
                'DF_tblEmplAssignments_FinalTerminationOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_HasBeenUsedOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_HasBeenUsed') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_HasBeenUsed ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_HasBeenUsed',
                'DF_tblEmplAssignments_HasBeenUsedOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_JobOrderNoOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_JobOrderNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_JobOrderNo ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_JobOrderNo',
                'DF_tblEmplAssignments_JobOrderNoOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_JobSkillOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_JobSkill') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_JobSkill ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_JobSkill',
                'DF_tblEmplAssignments_JobSkillOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_PreventWorkedTimeOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_PreventWorkedTime') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_PreventWorkedTime ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_PreventWorkedTime',
                'DF_tblEmplAssignments_PreventWorkedTimeOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_PurchOrderNoOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_PurchOrderNo') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_PurchOrderNo ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_PurchOrderNo',
                'DF_tblEmplAssignments_PurchOrderNoOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_RecordStatusOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_RecordStatus') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_RecordStatus ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_RecordStatus',
                'DF_tblEmplAssignments_RecordStatusOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_SortOrderOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_SortOrder') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_SortOrder ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_SortOrder',
                'DF_tblEmplAssignments_SortOrderOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_TerminatedByPNEOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_TerminatedByPNE') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_TerminatedByPNE ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_TerminatedByPNE',
                'DF_tblEmplAssignments_TerminatedByPNEOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_TermReasonOld') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_TermReason') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_TermReason ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_TermReason',
                'DF_tblEmplAssignments_TermReasonOld', 'OBJECT';
        END;


	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplAssignmentsOld') IS NULL
         AND OBJECT_ID('PK_tblEmplAssignments') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplAssignments ...';
            EXEC dbo.sp_rename 'PK_tblEmplAssignments',
                'PK_tblEmplAssignmentsOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplAssignmentsOld'
                                AND si.object_id = OBJECT_ID('tblEmplAssignments') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplAssignments'
                                AND si.object_id = OBJECT_ID('tblEmplAssignments') )
         AND OBJECT_ID('tblEmplAssignmentsOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplAssignments index ...';
            EXEC dbo.sp_rename 'tblEmplAssignments.PK_tblEmplAssignments',
                'PK_tblEmplAssignmentsOld', 'INDEX';
        END;


	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF__tblEmplAs__SiteN__6F42C185') IS NULL
         AND OBJECT_ID('DF__tblEmplAs__SiteN__6F42C185New') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF__tblEmplAs__SiteN__6F42C185 ...';
            EXEC dbo.sp_rename 'DF__tblEmplAs__SiteN__6F42C185New',
                'DF__tblEmplAs__SiteN__6F42C185', 'OBJECT';
        END;

	 IF ( OBJECT_ID('DF_tblEmplAssignments_DeptNo') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_DeptNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_DeptNo ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_DeptNoNew',
                'DF_tblEmplAssignments_DeptNo', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_FinalTermination') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_FinalTerminationNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_FinalTermination ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_FinalTerminationNew',
                'DF_tblEmplAssignments_FinalTermination', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_HasBeenUsed') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_HasBeenUsedNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_HasBeenUsed ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_HasBeenUsedNew',
                'DF_tblEmplAssignments_HasBeenUsed', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_JobOrderNo') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_JobOrderNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_JobOrderNo ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_JobOrderNoNew',
                'DF_tblEmplAssignments_JobOrderNo', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_JobSkill') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_JobSkillNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_JobSkill ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_JobSkillNew',
                'DF_tblEmplAssignments_JobSkill', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_PreventWorkedTime') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_PreventWorkedTimeNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_PreventWorkedTime ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_PreventWorkedTimeNew',
                'DF_tblEmplAssignments_PreventWorkedTime', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_PurchOrderNo') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_PurchOrderNoNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_PurchOrderNo ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_PurchOrderNoNew',
                'DF_tblEmplAssignments_PurchOrderNo', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_RecordStatus') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_RecordStatusNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_RecordStatus ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_RecordStatusNew',
                'DF_tblEmplAssignments_RecordStatus', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_SortOrder') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_SortOrderNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_SortOrder ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_SortOrderNew',
                'DF_tblEmplAssignments_SortOrder', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_TerminatedByPNE') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_TerminatedByPNENew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_TerminatedByPNE ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_TerminatedByPNENew',
                'DF_tblEmplAssignments_TerminatedByPNE', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblEmplAssignments_TermReason') IS NULL
         AND OBJECT_ID('DF_tblEmplAssignments_TermReasonNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplAssignments_TermReason ...';
            EXEC dbo.sp_rename 'DF_tblEmplAssignments_TermReasonNew',
                'DF_tblEmplAssignments_TermReason', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplAssignments') IS NULL
         AND OBJECT_ID('PK_tblEmplAssignmentsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplAssignments ...';
            EXEC dbo.sp_rename 'PK_tblEmplAssignmentsNew',
                'PK_tblEmplAssignments', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplAssignments'
                                AND si.object_id = OBJECT_ID('tblEmplAssignmentsNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplAssignmentsNew'
                                AND si.object_id = OBJECT_ID('tblEmplAssignmentsNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplAssignments index ...';
            EXEC dbo.sp_rename 'tblEmplAssignmentsNew.PK_tblEmplAssignmentsNew',
                'PK_tblEmplAssignments', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblEmplAssignmentsOld') IS NULL
         AND OBJECT_ID('tblEmplAssignments') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplAssignments ...';
            EXEC dbo.sp_rename 'tblEmplAssignments', 'tblEmplAssignmentsOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblEmplAssignments') IS NULL
         AND OBJECT_ID('tblEmplAssignmentsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplAssignmentsNew ...';
            EXEC dbo.sp_rename 'tblEmplAssignmentsNew', 'tblEmplAssignments',
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