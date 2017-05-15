select * from INFORMATION_SCHEMA.COLUMNS where upper(COLUMN_NAME) like 'RECORDID'

select t.name TableName, i.rows Records
from sysobjects t, sysindexes i
where t.xtype = 'U' and i.id = t.id and i.indid in (0,1)
order by 2 desc;