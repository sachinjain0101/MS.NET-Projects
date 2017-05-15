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
	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblEmplSites_Depts_InLastClkBkpOld') IS NULL
         AND OBJECT_ID('DF_tblEmplSites_Depts_InLastClkBkp') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplSites_Depts_InLastClkBkp ...';
            EXEC dbo.sp_rename 'DF_tblEmplSites_Depts_InLastClkBkp',
                'DF_tblEmplSites_Depts_InLastClkBkpOld', 'OBJECT';
        END;

		------------------------------------
		-- rename Primary Key
		------------------------------------
    IF ( OBJECT_ID('PK_tblEmplSites_RecIdOld') IS NULL
         AND OBJECT_ID('PK_tblEmplSites_RecId') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_RecId ...';
            EXEC dbo.sp_rename 'PK_tblEmplSites_RecId',
                'PK_tblEmplSites_RecIdOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_RecIdOld'
                                AND si.object_id = OBJECT_ID('tblEmplSites_Depts') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_RecId'
                                AND si.object_id = OBJECT_ID('tblEmplSites_Depts') )
         AND OBJECT_ID('tblEmplSites_DeptsOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_RecId index ...';
            EXEC dbo.sp_rename 'tblEmplSites_Depts.PK_tblEmplSites_RecId',
                'PK_tblEmplSites_RecIdOld', 'INDEX';
        END;

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Defaults
	------------------------------------
    IF ( OBJECT_ID('DF_tblEmplSites_Depts_InLastClkBkp') IS NULL
         AND OBJECT_ID('DF_tblEmplSites_Depts_InLastClkBkpNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: DF_tblEmplSites_Depts_InLastClkBkp ...';
            EXEC dbo.sp_rename 'DF_tblEmplSites_Depts_InLastClkBkpNew',
                'DF_tblEmplSites_Depts_InLastClkBkp', 'OBJECT';
        END;

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplSites_RecId') IS NULL
         AND OBJECT_ID('PK_tblEmplSites_RecIdNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_RecId ...';
            EXEC dbo.sp_rename 'PK_tblEmplSites_RecIdNew',
                'PK_tblEmplSites_RecId', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_RecId'
                                AND si.object_id = OBJECT_ID('tblEmplSites_DeptsNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplSites_RecIdNew'
                                AND si.object_id = OBJECT_ID('tblEmplSites_DeptsNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplSites_RecId index ...';
            EXEC dbo.sp_rename 'tblEmplSites_DeptsNew.PK_tblEmplSites_RecIdNew',
                'PK_tblEmplSites_RecId', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblEmplSites_DeptsOld') IS NULL
         AND OBJECT_ID('tblEmplSites_Depts') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplSites_Depts ...';
            EXEC dbo.sp_rename 'tblEmplSites_Depts', 'tblEmplSites_DeptsOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblEmplSites_Depts') IS NULL
         AND OBJECT_ID('tblEmplSites_DeptsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplSites_DeptsNew ...';
            EXEC dbo.sp_rename 'tblEmplSites_DeptsNew', 'tblEmplSites_Depts',
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