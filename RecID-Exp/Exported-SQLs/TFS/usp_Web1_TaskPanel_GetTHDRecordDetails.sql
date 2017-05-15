Create PROCEDURE [dbo].[usp_Web1_TaskPanel_GetTHDRecordDetails] 
	-- Add the parameters for the stored procedure here
    @THDRecordID BIGINT = 0 ,  --< @THDRecordId data type is changed from  INT to BIGINT by Srinsoft on 15Sept2016 >--
    @UserID INT
AS 
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON ;
        
        
        IF NOT EXISTS ( SELECT  1
                        FROM    TimeCurrent..tblUser AS U WITH ( NOLOCK )
                        WHERE   U.UserID = @UserID
                                AND U.Client = '****' ) 
            BEGIN
                SELECT TOP 1
                        thd.Client ,
                        thd.GroupCode ,
                        thd.SiteNo ,
                        thd.PayrollPeriodEndDate ,
                        CD.ClusterID ,
                        CN.ClusterName ,
                        thd.SSN
                FROM    TimeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
                INNER JOIN TimeCurrent..tblUserClusterPermission AS UCP
                ON      UCP.UserID = @UserID
                INNER JOIN TimeCurrent..tblClusterDef AS CD WITH ( NOLOCK )
                ON      UCP.ClusterID = CD.ClusterID
                        AND CD.Client = thd.Client
                        AND CD.GroupCode = thd.GroupCode
                        AND CD.Type = 'G'
                INNER JOIN TimeCurrent..tblClusterName AS CN WITH ( NOLOCK )
                ON      CD.Client = CN.Client
                        AND CD.ClusterID = CN.ClusterID
                WHERE   thd.RecordID = @THDRecordID
                        AND CD.RecordStatus = 1
                        AND CN.RecordStatus = 1
                        AND UCP.RecordStatus = 1
            END
        ELSE 
            BEGIN
                SELECT TOP 1
                        thd.Client ,
                        thd.GroupCode ,
                        thd.SiteNo ,
                        thd.PayrollPeriodEndDate ,
                        UCP.ClusterID ,
                        CN.ClusterName ,
                        thd.SSN
                FROM    TimeHistory..tblTimeHistDetail AS thd WITH ( NOLOCK )
                INNER JOIN TimeCurrent..tblUserClusterPermission AS UCP WITH ( NOLOCK )
                ON      UCP.UserID = @UserID
                --INNER JOIN TimeCurrent..tblClusterDef AS CD WITH ( NOLOCK )
                --ON      UCP.ClusterID = CD.ClusterID
                INNER JOIN TimeCurrent..tblClusterName AS CN WITH ( NOLOCK )
                ON      UCP.ClusterID = CN.ClusterID
                WHERE   thd.RecordID = @THDRecordID
                        AND CN.RecordStatus = 1
                        AND UCP.RecordStatus = 1
            END

        
   
    END


