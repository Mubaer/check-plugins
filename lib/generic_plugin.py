"""common functions for check-plugins"""

def rcstring( rc ):
    rcstring = {
        0: "(OK)",
        1: "(WARNING)",
        2: "(CRITICAL)",
        3: "(UNKNOWN)"
        }
    return(rcstring[rc])

