USE TimeHistory;  
GO  
EXEC sp_depends @objname = N'dbo.tblTimeHistDetail' ; 

select top 10 * from tblTimeHistDetail 