Create PROCEDURE [dbo].[usp_Web1_GetPunchDetails] ( @recordID BIGINT )  --< @RecordId data type is changed from  INT to BIGINT by Srinsoft on 08Sept2016 >--
AS 
    SELECT  RecordID ,
            PayrollPeriodEndDate ,
            ISNULL(Hours, 0) AS Hours ,
            ActualInTime ,
            ActualOutTime ,
            InTime ,
            InDay ,
            OutTime ,
            OutDay ,
            SiteNo ,
            DeptNo ,
            TimeHistory.dbo.PunchDateTime2(TransDate, InDay, InTime) AS PunchStart ,
            TimeHistory.dbo.PunchDateTime2(TransDate, OutDay, OutTime) AS PunchEnd
    FROM    TimeHistory..tblTimeHistDetail AS TTHD
    WHERE   RecordID = @recordID











