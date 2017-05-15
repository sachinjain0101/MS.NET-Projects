USE Metrics;
GO

DECLARE @waitTime VARCHAR(100)= N'00:00:02';

DECLARE @count INT= 1;

DECLARE @msg VARCHAR(100)= '';

BEGIN
    IF OBJECT_ID(N'Metrics.dbo.yyy',N'U') IS NULL
        BEGIN
            CREATE TABLE Metrics.dbo.yyy (
                         id  INT IDENTITY ,
                         msg NVARCHAR(100)
                             );
        END;
    WHILE @count <= 10
        BEGIN
            SET @msg = CONVERT(VARCHAR , CONVERT(TIME , CURRENT_TIMESTAMP));
            PRINT @msg;
            INSERT INTO yyy (msg)
            VALUES ( @msg
                   );
            EXEC usp_TableIdentityStatsCollector;
            WAITFOR DELAY @waitTIme;
            SET @count = @count + 1;
        END;
END;
GO

SELECT *
FROM Metrics.dbo.yyy;
GO


select * from tbl_TableIdentityStats