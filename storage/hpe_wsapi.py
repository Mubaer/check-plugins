#!/usr/bin/env python3
#
# Run checks against HPE WSAPI
# (tested with HPE Alletra)
#
program_version=str(0.1)
# Version 0.1 2025-02-17
#	 test version
#
import os, sys
import argparse
import requests
from tabulate2 import tabulate
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from lib.generic_plugin import *
from lib.jsonapi import *

# parse command line parameters
cli = argparse.ArgumentParser \
	(description='Maintain Aruba Central token')

cli.add_argument('--user', '-u',
		help='API User',required = True)
cli.add_argument('--pass', '-p', dest='pwd',
		help='API Password',required = True)
cli.add_argument('--mode',
		help='check mode: disks | ...', required = True )
cli.add_argument('-H', dest = 'host',
		help='Hostname or IP address', required = True)
cli.add_argument('-d', '--debug', 
		help='enable debugging output', action="store_true")
cli.add_argument('--version', 
		action='version', version='%(prog)s ' + program_version)
args = cli.parse_args()

#### init vars
# check output
rcode=0
out_text=''
detail=''
perfdata=''

# arguments / settings
# Strip trailing /
DEBUG		 = args.debug

if DEBUG:
	import pprint
	pp = pprint.PrettyPrinter(indent=4, compact=True, sort_dicts=True)

#-----------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------

def getSessionKey( host, user, pwd ):

	url="https://{}/api/v1/credentials".format(host)
	data={ 'user': user, 'password': pwd }

	jdata, error = apiRequest( url, 'post', verify=False, data=data )

	if not jdata:
		print( plugin_output(
				3,	# return code
				'Could not get token from cloud. Details below',
				error, # detail text
				None   # perfdata
				)
			)
		sys.exit(3)

	if DEBUG:
		pp.pprint( jdata )

	#return sessionKey
	return None

def delSessionKey( host, user, pwd ):

	url="https://{}/api/v1/credentials".format(host)
	data={ 'user': user, 'password': pwd }

	jdata, error = apiRequest( url, 'get', verify=False )

	if not jdata:
		print( plugin_output(
				3,	# return code
				'Could not get token from cloud. Details below',
				error, # detail text
				None   # perfdata
				)
			)
		sys.exit(3)

	if DEBUG:
		pp.pprint( jdata )

	#return sessionKey
	return None


def checkAPs (baseURL, accessToken):
	rcode=0
	# fetch this fields from API
	fields=','.join( [ 'status', 'firmware_version', 'model', 'site', 'ap_group' ] )
	url=f'{baseURL}/monitoring/v2/aps?fields={fields}'

	# API-Call
	answer, error = apiRequest( url, 'get', { 'Authorization': f'Bearer {accessToken}' } )

	if answer.get('aps'):

		if DEBUG: pp.pprint(answer.get('aps'))

		# Output table header
		head = [ 'Serial', 'STS', 'Name ', 'Firmware', 'Model', 'Site', 'RC' ]
		table = []
		cDown = 0	
		errorMap = { 'Up': 0, 'Down': 2 }

		# Loop over AccessPoints
		for ap in answer.get('aps'):
			# set rcode to '3' if status is unknown to us
			ap['rcode'] = errorMap.get( ap.get('status' ) )
			if ap['rcode'] is None: ap['rcode'] = 3

			ap['icingaStatus'] = rcstring( ap['rcode'] )

			# update rcode, cound down APs
			if ap['rcode'] == 2:
				rcode = update_rc(2, rcode)
				cDown += 1
	
			# line fields
			ap_infos = [ ap.get('serial'), ap.get('status'), ap.get('name'), 
			   ap.get('firmware_version'), ap.get('model'), ap.get('site'), ap['icingaStatus'] ]

			table.append( ap_infos )

		# Generate ASCII table for details
		detail = tabulate(table, headers = head)
		detail += "\n\nSTS == Aruba central status (raw)"
		detail += '\nRC == Return code of check plugin (intrepreted)'

		# plugin output (first line)
		output = 'Number of access points: {}'.format( answer.get('count') )
		if cDown > 0:
			output += ', DOWN: {}'.format(cDown)
		else:
			output += ', all UP'

	else:
		print('No Access Points returned from Aruba Networking Central')
		sys.exit(0)

	if error:
		rcode = 3
		output = str(error)

	return rcode, output, detail




#-----------------------------------------------------------------------
#								  MAIN
#-----------------------------------------------------------------------

#--------------------------- get session key ---------------------------

sessionKey = getSessionKey( args.host, args.user, args.pwd )

if args.mode == 'aps':
	( rcode, out_text, detail) = checkAPs( baseURL, accessToken )

#
#Finally, print check output and exit with rcode
#
print( plugin_output( rcode, out_text, detail, perfdata ) )
sys.exit(rcode)

# vim: ts=4:noexpandtab:sw=4:sts=4:ai:smartindent:filetype=python

