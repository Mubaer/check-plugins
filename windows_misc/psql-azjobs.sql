SELECT * FROM public."backup.model.jobsessions" where (Job_type = '15001')
ORDER BY creation_time DESC LIMIT 100

SELECT DISTINCT ON (Job_Name) * FROM public."backup.model.backups" where (Job_target_type = '15001' or Job_target_type = '0')

SELECT * FROM public."backup.model.backups"
ORDER BY id ASC LIMIT 100

SELECT * FROM public."backup.model.backups"  where (Job_target_type = '15000')
