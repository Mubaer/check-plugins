"""common date and time functions for check-plugins"""
import datetime
import time

# Converts a time period in seconds into a human readable format
def sec2hr( secs ):
    return( str(datetime.timedelta(seconds=secs)) )

def hour2hr( h ):
    return( str(datetime.timedelta(hours=h)) )

def delta_unixseconds( unix_seconds ):
    now = time.time()
    return( now - unix_seconds )

