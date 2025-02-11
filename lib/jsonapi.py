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

def apiRequest( url, method = 'get', header = None ):
	result = None
	error  = None

	if method == 'post':
		resp = requests.post( url, headers=header )
	else:
		resp = requests.get( url, headers=header )

	if resp:
		result = resp.json()
	else:
#		logging.error(
#				"something went wrong\n\nRESP_HEADER\n{}\nRESP_TEXT\n{}".format(
#				resp.headers, resp.text ))
		error=resp.text

	return(result, error)
