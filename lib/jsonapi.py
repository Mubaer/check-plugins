"""generic API request functions."""

import requests
import logging
from lib.generic_plugin import output_and_exit

requests.urllib3.disable_warnings()

def request_json( url, header=None ):
	result = None

	try:
		resp = requests.get( url, headers=header, verify=False )
	except OSError as e:
		output_and_exit( 3, 'Error occured while running the check' , repr(e), None)
	except Exception as e:
		output_and_exit( 3, 'Exception occured while running the check' , repr(e), None)

	else:
		if resp:
			result = resp.json()
		elif resp.status_code == 401:
			output_and_exit( 3, 'We are not authorized to access the device',
				   resp.text,
				   None)
		else:
			detailed = "Response Header:\n\n{}\nResponse Text\n\n{}".format( \
				resp.headers, resp.text )
			output_and_exit( 3, 'Unexpected answer from device', detailed, None)

	return(result)

def apiRequest( url, method = 'get', verify=True, header=None, data=None ):
	# BE CAREFUL: we always deal with JSON data here. don't use this
	# function for different data playloads
	result = None
	error  = None

	if method == 'post':
		resp = requests.post( url, verify=verify, headers=header, json=data )
	elif method == 'delete':
		resp = requests.delete( url, verify=verify, headers=header, json=data )
	else:
		resp = requests.get( url, verify=verify,  headers=header )

	if resp and (
		'application/json' in resp.headers.get('Content-Type', '')
		):
		result = resp.json()
	else:
		error=resp.text

	return(result, error)

# vim: ts=4:noexpandtab:sw=4:sts=4:ai:smartindent:filetype=python:nofoldenable
