USE [TimeCurrent];
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
	
	------------------------------------------
	-- rename Triggers of present Table to Old
	-----------------------------------------
	IF ( OBJECT_ID('trg_DeptNames_SyncMultiSupplierOld') IS NULL
         AND OBJECT_ID('trg_DeptNames_SyncMultiSupplier') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: trg_DeptNames_SyncMultiSupplier ...';
            EXEC dbo.sp_rename 'trg_DeptNames_SyncMultiSupplier',
                'trg_DeptNames_SyncMultiSupplierOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('trg_DeptNamesInsUpdOld') IS NULL
         AND OBJECT_ID('trg_DeptNamesInsUpd') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: trg_DeptNamesInsUpd ...';
            EXEC dbo.sp_rename 'trg_DeptNamesInsUpd',
                'trg_DeptNamesInsUpdOld', 'OBJECT';
        END;
	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblDeptNames_AppliesToShiftDiffOld') IS NULL
         AND OBJECT_ID('DF_tblDeptNames_AppliesToShiftDiff') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblDeptNames_AppliesToShiftDiff ...';
            EXEC dbo.sp_rename 'DF_tblDeptNames_AppliesToShiftDiff',
                'DF_tblDeptNames_AppliesToShiftDiffOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblDeptNames_DeptNameOld') IS NULL
         AND OBJECT_ID('DF_tblDeptNames_DeptName') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblDeptNames_DeptName ...';
            EXEC dbo.sp_rename 'DF_tblDeptNames_DeptName',
                'DF_tblDeptNames_DeptNameOld', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblDeptNames_DeptName_LongOld') IS NULL
         AND OBJECT_ID('DF_tblDeptNames_DeptName_Long') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblDeptNames_DeptName_Long ...';
            EXEC dbo.sp_rename 'DF_tblDeptNames_DeptName_Long',
                'DF_tblDeptNames_DeptName_LongOld', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblDeptNamesOld') IS NULL
         AND OBJECT_ID('PK_tblDeptNames') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNames ...';
            EXEC dbo.sp_rename 'PK_tblDeptNames',
                'PK_tblDeptNamesOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNamesOld'
                                AND si.object_id = OBJECT_ID('tblDeptNames') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNames'
                                AND si.object_id = OBJECT_ID('tblDeptNames') )
         AND OBJECT_ID('tblDeptNamesOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNames index ...';
            EXEC dbo.sp_rename 'tblDeptNames.PK_tblDeptNames',
                'PK_tblDeptNamesOld', 'INDEX';
        END;

		

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------------
	-- rename Triggers of New Table to actual Table
	-----------------------------------------
	IF ( OBJECT_ID('trg_DeptNames_SyncMultiSupplier') IS NULL
         AND OBJECT_ID('trg_DeptNames_SyncMultiSupplierNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: trg_DeptNames_SyncMultiSupplierNew ...';
            EXEC dbo.sp_rename 'trg_DeptNames_SyncMultiSupplierNew',
                'trg_DeptNames_SyncMultiSupplier', 'OBJECT';
        END;

	IF ( OBJECT_ID('trg_DeptNamesInsUpd') IS NULL
         AND OBJECT_ID('trg_DeptNamesInsUpdNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: trg_DeptNamesInsUpdNew ...';
            EXEC dbo.sp_rename 'trg_DeptNamesInsUpdNew',
                'trg_DeptNamesInsUpd', 'OBJECT';
        END;

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblDeptNames_AppliesToShiftDiff') IS NULL
         AND OBJECT_ID('DF_tblDeptNames_AppliesToShiftDiffNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblDeptNames_AppliesToShiftDiff ...';
            EXEC dbo.sp_rename 'DF_tblDeptNames_AppliesToShiftDiffNew',
                'DF_tblDeptNames_AppliesToShiftDiff', 'OBJECT';
        END;

	 IF ( OBJECT_ID('DF_tblDeptNames_DeptName') IS NULL
         AND OBJECT_ID('DF_tblDeptNames_DeptNameNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblDeptNames_DeptName ...';
            EXEC dbo.sp_rename 'DF_tblDeptNames_DeptNameNew',
                'DF_tblDeptNames_DeptName', 'OBJECT';
        END;

	IF ( OBJECT_ID('DF_tblDeptNames_DeptName_Long') IS NULL
         AND OBJECT_ID('DF_tblDeptNames_DeptName_LongNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblDeptNames_DeptName_Long ...';
            EXEC dbo.sp_rename 'DF_tblDeptNames_DeptName_LongNew',
                'DF_tblDeptNames_DeptName_Long', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblDeptNames') IS NULL
         AND OBJECT_ID('PK_tblDeptNamesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNames ...';
            EXEC dbo.sp_rename 'PK_tblDeptNamesNew',
                'PK_tblDeptNames', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNames'
                                AND si.object_id = OBJECT_ID('tblDeptNamesNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblDeptNamesNew'
                                AND si.object_id = OBJECT_ID('tblDeptNamesNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblDeptNamesNew index ...';
            EXEC dbo.sp_rename 'tblDeptNamesNew.PK_tblDeptNamesNew',
                'PK_tblDeptNames', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblDeptNamesOld') IS NULL
         AND OBJECT_ID('tblDeptNames') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblDeptNames ...';
            EXEC dbo.sp_rename 'tblDeptNames', 'tblDeptNamesOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblDeptNames') IS NULL
         AND OBJECT_ID('tblDeptNamesNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblDeptNamesNew ...';
            EXEC dbo.sp_rename 'tblDeptNamesNew', 'tblDeptNames',
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