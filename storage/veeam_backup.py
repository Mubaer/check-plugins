#!/usr/bin/env python3

# Imports
import argparse, requests, sys, os

# Variables
requests.packages.urllib3.disable_warnings()
checkVersion = '1.3'

# Functions
def parse_command_line():
    parser = argparse.ArgumentParser(description='Parse command line parameters')
    parser.add_argument('--check', type=str, help='backup|jobs|version|repository')
    parser.add_argument('--host', type=str, help='Veeam Host to check')
    parser.add_argument('--username', type=str, help='Veeam Username')
    parser.add_argument('--password', type=str, help='Veeam Password')
    parser.add_argument('--tmpdir', type=str, default='/var/tmp',
                        help='Directory for status file (default: /var/tmp)')
    args = parser.parse_args()
    return args

def login_to_rest_api(hostname, username, password):
    url = 'https://' + hostname + ':9419/api/oauth2/token'
    headers = {'x-api-version': '1.1-rev0'}
    data = {
        'grant_type': 'password',
        'username': username,
        'password': password
    }
    response = requests.post(url, headers=headers, data=data, verify=False, timeout=30)
    
    if response.status_code != 200:
        print('Error: Failed to authenticate. Exiting script.')
        sys.exit(2)
    
    response_json = response.json()
    access_token = response_json.get('access_token')
    
    return access_token

def get_veeam_version(hostname, access_token):
    url = 'https://' + hostname + ':9419/api/v1/serverInfo'
    headers = {
        'x-api-version': '1.1-rev0',
        'Authorization': 'Bearer ' + access_token
    }
    response = requests.get(url, headers=headers, verify=False, timeout=30)
    return response.json()['buildVersion']

def set_api_version(veeam_version):
    if veeam_version == '12.2.0.334':
        return '1.1-rev2'
    elif veeam_version == '12.1.0.2131':
        return '1.1-rev1'
    else:
        return '1.1-rev0'

def get_all_backups(hostname, access_token, api_version):
    url = 'https://' + hostname + ':9419/api/v1/backups?orderColumn=Name'
    headers = {
        'x-api-version': api_version,
        'Authorization': 'Bearer ' + access_token
    }
    response = requests.get(url, headers=headers, verify=False, timeout=30)
    
    if response.status_code != 200:
        print('Error: Failed to get backups. Exiting script.')
        sys.exit(2)
    
    response_json = response.json()
    return response_json['data']

def extract_backup_ids(backups):
    backup_ids = []
    for backup in backups:
        if backup['jobId'] != '00000000-0000-0000-0000-000000000000':
            backup_id = {'name': backup['name'], 'jobId': backup['jobId'], 'platformName': backup['platformName']}
            backup_ids.append(backup_id)
    return backup_ids

def get_all_jobs(hostname, access_token, api_version):
    url = 'https://' + hostname + ':9419/api/v1/jobs?orderColumn=Name'
    headers = {
        'x-api-version': api_version,
        'Authorization': 'Bearer ' + access_token
    }
    response = requests.get(url, headers=headers, verify=False, timeout=30)
    
    if response.status_code != 200:
        print('Error: Failed to get jobs. Exiting script.')
        sys.exit(2)
    
    response_json = response.json()
    return response_json['data']

def get_backup_sessions(hostname, access_token, backup_ids, api_version):
    sessions = []
    for backup_id in backup_ids:
        url = 'https://' + hostname + ':9419/api/v1/sessions?orderColumn=CreationTime&jobIdFilter=' + backup_id['jobId'] + '&Limit=10'
        headers = {
            'x-api-version': api_version,
            'Authorization': 'Bearer ' + access_token
        }
        response = requests.get(url, headers=headers, verify=False, timeout=30)
        
        if response.status_code != 200:
            print('Error: Failed to get sessions for backup ID ' + backup_id['jobId'] + '. Skipping.')
            continue
        
        response_json = response.json()
        sessiondata = {'name': backup_id['name'], 'sessions': response_json['data']}
        sessions.append(sessiondata)
    return sessions

def get_veeam_repositories_state(hostname, access_token, api_version):
    url = 'https://' + hostname + ':9419/api/v1/backupInfrastructure/repositories/states'
    headers = {
        'x-api-version': api_version,
        'Authorization': 'Bearer ' + access_token
    }
    response = requests.get(url, headers=headers, verify=False, timeout=30)
    if response.status_code != 200:
        print('Error: Failed to get repositories states. Exiting script.')
        sys.exit(2)
    response_json = response.json()
    return response_json['data']


def create_backup_check(backups):
    results = {'total_jobs': 0, 'success': 0, 'warning': 0, 'critical': 0}
    job_results = []
    for backup in backups:
        job_name = backup['name']
        sessions = backup['sessions']
        if len(sessions) < 3:
            continue
        recent_sessions = [session for session in sessions if session['state'] == 'Stopped'][:3]
        session_results = [session['result']['result'] for session in recent_sessions]
        last3results = session_results[0]+', '+session_results[1]+', '+session_results[2]
        if session_results[0] == 'Success':
            job_result = 'OK'
            results['success'] += 1
        elif session_results[0] == 'Failed' and session_results[1] == 'Success':
            job_result = 'Warning'
            results['warning'] += 1
        else:
            job_result = 'Critical'
            results['critical'] += 1
        job_results.append({'jobname': job_name, 'result': job_result, 'last3results': last3results})
        results['total_jobs'] += 1
    return {'job_results': job_results, 'summary_results': results}

def output_backup_check(backup_check):
    print('(OK): '+str(backup_check['summary_results']['success'])+', (WARNING): '+str(backup_check['summary_results']['warning'])+', (CRITICAL): '+str(backup_check['summary_results']['critical'])+', Jobs in Check: '+str(backup_check['summary_results']['total_jobs']))
    print('')
    for job in backup_check['job_results']:
        print('('+job['result'].upper()+') Job: '+job['jobname']+'; Last Results: '+job['last3results'])
    if backup_check['summary_results']['critical'] > 0:
        sys.exit(2)
    elif backup_check['summary_results']['warning'] > 0:
        sys.exit(1)
    else:
        sys.exit(0)

def compare_jobs(backup_ids):
    previous_jobs = []
    current_jobs = []
    removed_jobs = []
    added_jobs = []
    new_file = 0
    statefile=args.tmpdir + '/check_veeam_backup-' + args.host
    for backup_id in backup_ids:
        current_jobs.append(backup_id['name'])
    if os.path.exists(statefile):
        with open(statefile, 'r') as file:
            previous_jobs = file.read().splitlines()
        for job in previous_jobs:
            if job not in current_jobs:
                added_jobs.append(job)
        for job in current_jobs:
            if job not in previous_jobs:
                removed_jobs.append(job)
    else:
        for job in current_jobs:
            added_jobs.append(job)
        new_file = 1
    with open(statefile, 'w') as file:
        for job in current_jobs:
            file.write(job + '\n')
    if new_file == 0:
        return {'current': current_jobs, 'removed': removed_jobs, 'added': added_jobs}
    else:
        return {'current': [], 'removed': removed_jobs, 'added': added_jobs}

def output_job_check(job_check):
    if len(job_check['current']) == 0 and len(job_check['removed']) == 0:
        print('[ Note: First Runtime of Check ]')
        sys.exit(0)
    if len(job_check['current']) > 0:
        exitcode = 0
        if len(job_check['added']) > 0:
            print('(WARNING) Jobs seit letztem Check entfernt: '+', '.join(job_check['added']))
            exitcode = 1
        if len(job_check['removed']) > 0:
            print('(WARNING) Jobs seit letztem Check hinzugefügt: '+', '.join(job_check['removed']))
            exitcode = 1
        if len(job_check['added']) == 0 and len(job_check['removed']) == 0:
            print('(OK) Keine neuen / entfernten Jobs gefunden')
            exitcode = 0
        sys.exit(exitcode)

def output_version_check(veeam_version, checkVersion):
    print('Veeam Version: '+veeam_version+'; Check Version: '+checkVersion)
    exitcode = 0
    sys.exit(exitcode)

def create_repo_state_check(repo_states):
    repos = []
    if len(repo_states) != 0:
        for repo_state in repo_states:
            repos.append({'name': repo_state['name'], 'type': repo_state['type'], 'totalCapacity': repo_state['capacityGB'], 'usedCapacity': repo_state['usedSpaceGB']/repo_state['capacityGB']})
    else:
        print('Error: Could not process Veeam Repository States')
        sys.exit(2)
    return repos

def output_repo_state_check(repos):
    results = {'ok': 0, 'warning': 0, 'critical': 0}
    for repo in repos:
        if repo['usedCapacity'] < 0.8:
            results['ok'] += 1
            print('(OK) Repository: ' + repo['name'] + '; Type: ' + repo['type'] + '; total Capacity: ' + str(int(repo['totalCapacity'])) + ' GB; used Capacity: ' + str(int(100*repo['usedCapacity'])) + ' %')
        elif repo['usedCapacity'] < 0.9:
            results['warning'] += 1
            print('(WARNING) Repository: ' + repo['name'] + '; Type: ' + repo['type'] + '; total Capacity: ' + str(int(repo['totalCapacity'])) + ' GB; used Capacity: ' + str(int(100*repo['usedCapacity'])) + ' %')
        else:
            results['critical'] += 1
            print('(CRITICAL) Repository: ' + repo['name'] + '; Type: ' + repo['type'] + '; total Capacity: ' + str(int(repo['totalCapacity'])) + ' GB; used Capacity: ' + str(int(100*repo['usedCapacity'])) + ' %')
    if results['critical'] > 0:
        exitcode = 2
    elif results['warning'] > 0:
        exitcode = 1
    else:
        exitcode = 0
    sys.exit(exitcode)

# Main
args = parse_command_line()

if args.check == 'backup' and args.host != None and args.username != None and args.password != None:
    access_token = login_to_rest_api(args.host, args.username, args.password)
    veeam_version = get_veeam_version(args.host, access_token)
    api_version = set_api_version(veeam_version)
    backups = get_all_backups(args.host, access_token, api_version)
    backup_ids = extract_backup_ids(backups)
    sessions = get_backup_sessions(args.host, access_token, backup_ids, api_version)
    backup_check = create_backup_check(sessions)
    output_backup_check(backup_check)

elif args.check == 'jobs' and args.host != None and args.username != None and args.password != None:
    access_token = login_to_rest_api(args.host, args.username, args.password)
    veeam_version = get_veeam_version(args.host, access_token)
    api_version = set_api_version(veeam_version)
    backups = get_all_backups(args.host, access_token, api_version)
    backup_ids = extract_backup_ids(backups)
    job_check = compare_jobs(backup_ids)
    output_job_check(job_check)

elif args.check == 'version' and args.host != None and args.username != None and args.password != None:
    access_token = login_to_rest_api(args.host, args.username, args.password)
    veeam_version = get_veeam_version(args.host, access_token)
    output_version_check(veeam_version, checkVersion)

elif args.check == 'repository' and args.host != None and args.username != None and args.password != None:
    access_token = login_to_rest_api(args.host, args.username, args.password)
    veeam_version = get_veeam_version(args.host, access_token)
    api_version = set_api_version(veeam_version)
    repo_states = get_veeam_repositories_state(args.host, access_token, api_version)
    repos = create_repo_state_check(repo_states)
    output_repo_state_check(repos)

if args.check == None:
    print('No check specified')
    sys.exit(2)
