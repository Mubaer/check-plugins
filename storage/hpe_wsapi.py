#!/usr/bin/env python3
#
# Run checks against HPE WSAPI
# (tested with HPE Alletra)
#
program_version=str(0.2)
# Version 0.2
#	added "volumes" and "disks"
#
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
	return jdata['key']

def delSessionKey( host, sessionKey ):

	url="https://{}/api/v1/credentials/{}".format(host, sessionKey)

	jdata, error = apiRequest( url, 'delete', verify=False )

	if error:
		print( plugin_output(
				1,	# return code
				'Could not delete token from cloud. Details below',
				error, # detail text
				None   # perfdata
				)
			)
		sys.exit(3)

	return None

def checkVolumes(host, sessionKey):
	rcode=0
	output=''
	detail=''
	perfdata=''
	# fetch this fields from API
	# interessting fields: name, state, totalUsedMiB, sizeMiB
	url=f'https://{host}/api/v1/volumes'
	header={
		'Accept': 'application/json',
		'X-HP3PAR-WSAPI-SessionKey': sessionKey
		}

	# API-Call
	answer, error = apiRequest( url, 'get', verify=False, header=header)

	if answer.get('members'):
		# Init output table header
		head = [ 'Name', 'State', 'Size (MiB)', '% Used', 'RC' ]
		table = []
		cProblems = 0
		cOK = 0

		# Loop over Volums
		for vol in answer.get('members'):
			# Exclude volumes that start with "." or "admin"
			if vol.get('name').startswith('.') or vol.get('name') == 'admin':
				continue
			cOK += 1
			# set rcode to '3' if status is unknown to us
			vol['rcode'] = _volumeStateEnum( vol.get('state' )).get('icingaState')
			vol['stateDesc'] = _volumeStateEnum( vol.get('state' )).get('desc')

			# Set return code according to system's state
			if vol['rcode'] is None: vol['rcode'] = 3

			# -----------
			# Calculate percent usage and overwrite system's state if greater
			# than "usrSpcAllocWarningPct"
			vol['pctusage'] = int(vol['totalUsedMiB'] / vol['sizeMiB'] * 100 )

			# calculate critical level from warning level
			warnLevel = vol['usrSpcAllocWarningPct']
			critLevel = 100 - (100 - warnLevel) / 2
			# Overwrite status
			if vol['pctusage'] >= critLevel:
				vol['rcode'] = 2
			elif vol['pctusage'] >= warnLevel:
				vol['rcode'] = 1
			# -----------

			# update rcode, count problem Volumes1
			if vol['rcode'] > 0:
				rcode = update_rc(vol['rcode'], rcode)
				cProblems += 1

			# set the corresponding icinga state string
			vol['icingaDetailState'] = rcstring( vol['rcode'] )

			# line fields
			volume_infos = [ vol.get('name'), vol.get('stateDesc'), 
				   '{:,}'.format( vol.get('sizeMiB') ), 
				   str(vol['pctusage']) + '%',
				   vol['icingaDetailState'] ]

			table.append( volume_infos )

			# append perfdata
			perfdata += "{}={}%;{};{};0;100 ".format(
					vol.get('name'), vol['pctusage'], warnLevel, critLevel )

		# Generate ASCII table for details
		detail = tabulate(table, headers = head, 
					colglobalalign='right', colalign = ('left','left') )

		detail += "\n\nNote: Commas ',' in numbers are thousand separators."
		# plugin output (first line)
		output = 'Number of volumes: {}'.format( cOK )
		if cProblems > 0:
			output += ', with problems: {}'.format(cProblems)
		else:
			output += ', all OK'

	else:
		print('No Volumes found.')
		sys.exit(0)

	if error:
		rcode = 3
		output = str(error)

	return rcode, output, detail, perfdata

def checkDisks(host, sessionKey):
	rcode=0
	output=''
	detail=''
	perfdata=''
	# fetch this fields from API
	# interessting fields: name, state, totalUsedMiB, sizeMiB
	url=f'https://{host}/api/v1/disks'
	header={
		'Accept': 'application/json',
		'X-HP3PAR-WSAPI-SessionKey': sessionKey
		}

	# API-Call
	answer, error = apiRequest( url, 'get', verify=False, header=header)

	if answer.get('members'):
		# Output table header
		head = [ 'ID', 'Pos.', 'State ', 'Size (MiB)', 'Used', 'RC' ]
		table = []
		cProblems = 0

		# Loop over Volums
		for disk in answer.get('members'):
			# set rcode to '3' if status is unknown to us
			disk['rcode'] = _diskStateEnum( disk.get('state' )).get('icingaState')
			disk['stateDesc'] = _diskStateEnum( disk.get('state' )).get('desc')

			if disk['rcode'] is None: disk['rcode'] = 3

			# set the corresponding icinga state string
			disk['icingaDetailState'] = rcstring( disk['rcode'] )

			# calculate percent used
			disk['pctusage'] = int( 
						(disk['totalSizeMiB'] - disk['freeSizeMiB'] ) / 
						 disk['totalSizeMiB'] * 100 )
			# update rcode, count disks with problems
			if disk['rcode'] > 0:
				rcode = update_rc(disk['rcode'], rcode)
				cProblems += 1

			# line fields
			disk_infos = [ disk.get('id'), disk.get('position'),
					disk.get('stateDesc'),
				   '{:,}'.format( disk.get('totalSizeMiB') ),
					str( disk.get('pctusage') ) + '%',
					 disk['icingaDetailState'] ]

			table.append( disk_infos )

			# append perfdata
			perfdata += "{}={}% ".format( disk.get('name'), disk['pctusage'] )

		# Generate ASCII table for details
		detail = tabulate(table, headers = head)
		detail += "\n\nNote: Commas ',' in numbers are thousand separators."

		# plugin output (first line)
		output = 'Number of disks: {}'.format( answer.get('total') )
		if cProblems > 0:
			output += ', with problems: {}'.format(cProblems)
		else:
			output += ', all OK'
	else:
		print('No Disks found.')
		sys.exit(0)

	if error:
		rcode = 3
		output = str(error)

	return rcode, output, detail, perfdata

def systemInfo( host, sessionKey):
	rcode=0
	output=''
	detail=''
	# fetch this fields from API
	# interessting fields: name, systemVersion, model, serialNumber, totalNodes
	url=f'https://{host}/api/v1/system'
	header={
		'Accept': 'application/json',
		'X-HP3PAR-WSAPI-SessionKey': sessionKey
		}


	map_field2output = {
			'name': 'Name', 
			'model': 'Model',
			'systemVersion': 'System Version',
			'serialNumber': 'Serial Number', 'totalNodes': 'Number of Nodes' 
			}
	# API-Call
	answer, error = apiRequest( url, 'get', verify=False, header=header)


	# check for valid answer
	table=[]
	if answer.get('id'):
		for field in map_field2output.keys():
			infos=[ map_field2output[field], answer.get(field) ]
			table.append( infos )

		detail = tabulate(table)
	else:
		print('could not get system information')

	return 0, 'test', detail

def _volumeStateEnum( num ):
	volStates = {
			1:	{ 'desc': 'normal', 'icingaState': 0 },
			2:	{ 'desc': 'degraded', 'icingaState': 1 },
			3:	{ 'desc': 'failed', 'icingaState': 2 },
			4:	{ 'desc': 'unknown', 'icingaState': 3 }
			}
	if not volStates.get( num ):
		message = 'internal error: unknown volume state "{}"'.format(num)
		print( plugin_output( 3, message, '', '' ) )
		sys.exit(3)

	return volStates.get( num )

def _diskStateEnum( num ):
	volStates = {
			1:	{ 'desc': 'normal',   'icingaState': 0 },
			2:	{ 'desc': 'degraded', 'icingaState': 1 },
			3:	{ 'desc': 'new',      'icingaState': 0 },
			4:	{ 'desc': 'failed',   'icingaState': 2 },
			99:	{ 'desc': 'unknown',  'icingaState': 3 }
			}
	if not volStates.get( num ):
		message = 'internal error: unknown volume state "{}"'.format(num)
		print( plugin_output( 3, message, '', '' ) )
		sys.exit(3)

	return volStates.get( num )


#-----------------------------------------------------------------------
#								  MAIN
#-----------------------------------------------------------------------

#--------------------------- get session key ---------------------------

# get a session key
sessionKey = getSessionKey( args.host, args.user, args.pwd )

if args.mode == 'info':
	( rcode, out_text, detail) = systemInfo( args.host, sessionKey )
if args.mode == 'volumes':
	( rcode, out_text, detail, perfdata) = checkVolumes( args.host, sessionKey )
if args.mode == 'disks':
	( rcode, out_text, detail, perfdata) = checkDisks( args.host, sessionKey )
if args.mode == 'capacity':
	( rcode, out_text, detail) = checkCapacity( args.host, sessionKey )

# delete the session key
delSessionKey( args.host, sessionKey )

#
#Finally, print check output and exit with rcode
#
print( plugin_output( rcode, out_text, detail, perfdata ) )
sys.exit(rcode)

# vim: ts=4:noexpandtab:sw=4:sts=4:ai:smartindent:filetype=python

