USE TimeHistory
GO
/****** Object:  StoredProcedure [dbo].usp_Web1_GetTimeHistDetailFaxaroo    Script Date: 5/5/2016 ******/
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		CIGNIFY\Sajjan Sarkar
-- Create date: 5/5/2016
-- Description:	
-- =============================================
IF NOT EXISTS ( SELECT  *
                FROM    sys.objects
                WHERE   object_id = OBJECT_ID(N'[dbo].[usp_Web1_GetTimeHistDetailFaxaroo]')
                        AND type IN ( N'P', N'PC' ) )
    BEGIN
        EXEC dbo.sp_executesql
            @statement = N'CREATE PROCEDURE [dbo].[usp_Web1_GetTimeHistDetailFaxaroo] AS' 
    END
GO
ALTER PROCEDURE [dbo].[usp_Web1_GetTimeHistDetailFaxaroo] ( @THDRecordID INT )
AS
    BEGIN
        SET NOCOUNT ON
        SELECT  FaxPageId
        FROM    TimeHistory..tblTimeHistDetail_Faxaroo WITH (NOLOCK)
        WHERE   THD_RecordId = @THDRecordID
        
    END

	
