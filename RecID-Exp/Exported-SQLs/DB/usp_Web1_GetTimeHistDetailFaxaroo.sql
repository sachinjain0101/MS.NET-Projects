CREATE PROCEDURE [dbo].[usp_Web1_GetTimeHistDetailFaxaroo] ( @THDRecordID INT )
AS
    
BEGIN
        SET NOCOUNT ON
        SELECT  FaxPageId
        FROM    TimeHistory..tblTimeHistDetail_Faxaroo WITH (NOLOCK)
        WHERE   THD_RecordId = @THDRecordID
        
    END

	
