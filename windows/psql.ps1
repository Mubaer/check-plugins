Set-Location 'C:\Program Files\PostgreSQL\15\bin\';
$env:PGPASSWORD = 'test';
$cmd = "SELECT job_name, job_type, job_id, creation_time, end_time, result FROM public.\""backup.model.jobsessions\"" where (job_name like 'LINUX') ORDER BY creation_time DESC LIMIT 3;"
$result = @(.\psql  -U postgres -w -d VeeamBackup -c "$cmd")
$result