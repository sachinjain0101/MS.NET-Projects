select * from sys.sql_modules sm
join sys.objects s
on (sm.object_id = s.object_id)
WHERE s.type = 'P'
      AND s.name NOT LIKE '%_GG'
      AND s.name NOT LIKE '%_GG1'
      AND s.name NOT LIKE '%_GG2'
      AND s.name NOT LIKE '%_GG3'
      AND s.name NOT LIKE '%_GG4'
      AND s.name NOT LIKE '%_GG5'
      AND s.name NOT LIKE '%_GG6'
      AND s.name NOT LIKE '%_deh'
      AND s.name NOT LIKE '%_deh2'
      AND s.name NOT LIKE '%_jb'
      AND s.name NOT LIKE '%_jlb'
      AND s.name NOT LIKE '%_ss'
      AND s.name NOT LIKE '%_clim'
      AND s.name NOT LIKE '%_mk'
      AND s.name NOT LIKE '%_mk1'
      AND s.name NOT LIKE '%_mk2'
      AND s.name NOT LIKE '%_mk3'
      AND s.name NOT LIKE '%usp_WTE_GetUnapprovedTimeEntries_%';
