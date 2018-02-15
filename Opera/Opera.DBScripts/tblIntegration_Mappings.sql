USE TimeCurrent

CREATE TABLE TimeCurrent.dbo.tblIntegration_Mappings(
RecordID INT IDENTITY
,MapName VARCHAR(20) NOT NULL
,Attribute VARCHAR(20) NOT NULL
,Expression VARCHAR(500) 
,Version INT NOT NULL
,CreatedBy VARCHAR(100)
,CreateDateTime DATETIME
);

CREATE INDEX idxIntegration_Mappings ON TimeCurrent.dbo.tblIntegration_Mappings(MapName,Version);


