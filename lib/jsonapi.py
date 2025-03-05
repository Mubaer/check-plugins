"""generic API request functions."""

import requests
import logging

requests.urllib3.disable_warnings()

def request_json( url ):
	resp = requests.get( url, verify=False )
	result = None

	if resp:
		result = resp.json()
	else:
		logging.error("something went wrong\n\nRESP_HEADER\n{}\nRESP_TEXT\n{}".format( \
				resp.headers, resp.text ))
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

# vim: ts=4:noexpandtab:sw=4:sts=4:ai:smartindent:filetype=python
