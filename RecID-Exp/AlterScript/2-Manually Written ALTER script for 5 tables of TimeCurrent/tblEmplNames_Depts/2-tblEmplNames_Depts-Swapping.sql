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
    


	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplNames_Depts_RecIdOld') IS NULL
         AND OBJECT_ID('PK_tblEmplNames_Depts_RecId') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts_RecId ...';
            EXEC dbo.sp_rename 'PK_tblEmplNames_Depts_RecId',
                'PK_tblEmplNames_Depts_RecIdOld', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_Depts_RecIdOld'
                                AND si.object_id = OBJECT_ID('tblEmplNames_Depts') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_Depts_RecId'
                                AND si.object_id = OBJECT_ID('tblEmplNames_Depts') )
         AND OBJECT_ID('tblEmplNames_DeptsOld') IS NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts_RecId index ...';
            EXEC dbo.sp_rename 'tblEmplNames_Depts.PK_tblEmplNames_Depts_RecId',
                'PK_tblEmplNames_Depts_RecIdOld', 'INDEX';
        END;

	------------------------------------
	-- second rename NEW dependant objects (PK, FKs, Indexes, and Defaults)
	------------------------------------

	------------------------------------
	-- rename Primary Key
	------------------------------------
    IF ( OBJECT_ID('PK_tblEmplNames_Depts_RecId') IS NULL
         AND OBJECT_ID('PK_tblEmplNames_Depts_RecIdNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts_RecId ...';
            EXEC dbo.sp_rename 'PK_tblEmplNames_Depts_RecIdNew',
                'PK_tblEmplNames_Depts_RecId', 'OBJECT';
        END;


    IF ( NOT EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_Depts_RecId'
                                AND si.object_id = OBJECT_ID('tblEmplNames_DeptsNew') )
         AND EXISTS ( SELECT    *
                      FROM      sys.indexes si
                      WHERE     si.name = 'PK_tblEmplNames_Depts_RecIdNew'
                                AND si.object_id = OBJECT_ID('tblEmplNames_DeptsNew') )
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: PK_tblEmplNames_Depts_RecId index ...';
            EXEC dbo.sp_rename 'tblEmplNames_DeptsNew.PK_tblEmplNames_Depts_RecIdNew',
                'PK_tblEmplNames_Depts_RecId', 'INDEX';
        END;

	------------------------------------
	-- Rename current table to OLD and NEW table to current
	------------------------------------

    IF ( OBJECT_ID('tblEmplNames_DeptsOld') IS NULL
         AND OBJECT_ID('tblEmplNames_Depts') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplNames_Depts ...';
            EXEC dbo.sp_rename 'tblEmplNames_Depts', 'tblEmplNames_DeptsOld',
                'OBJECT';
        END;


    IF ( OBJECT_ID('tblEmplNames_Depts') IS NULL
         AND OBJECT_ID('tblEmplNames_DeptsNew') IS NOT NULL
       )
        BEGIN
            PRINT CONVERT(VARCHAR(30), GETDATE(), 121)
                + ' -- Renaming: tblEmplNames_DeptsNew ...';
            EXEC dbo.sp_rename 'tblEmplNames_DeptsNew', 'tblEmplNames_Depts',
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
