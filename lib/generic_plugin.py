"""common functions for check-plugins"""

def rcstring( rc, b='(' ):
    brace = {
            '(': [ '(', ')' ],
            '[': [ '[', ']' ],
            '{': [ '{', '}' ]
            }

    rcstring = {
        0: f"{brace[b][0]}OK{brace[b][1]}",
        1: f"{brace[b][0]}WARNING{brace[b][1]}",
        2: f"{brace[b][0]}CRITICAL{brace[b][1]}",
        3: f"{brace[b][0]}UNKNOWN{brace[b][1]}"
        }
    return(rcstring[rc])


def check_threshold( metric, warn_thres, crit_thres, method='gt' ):
    rc_return=0
    if method == 'gt':
        if  crit_thres  != None and metric > crit_thres :
            rc_return = 2
        elif warn_thres != None and metric > warn_thres :
            rc_return = 1
        else:
            rc_return = 0

    elif method == 'lt':
        if crit_thres   != None and metric < crit_thres :
            rc_return = 2
        elif warn_thres != None and metric < warn_thres :
            rc_return = 1
        else:
            rc_return = 0
    else:
        True

    return( rc_return )

def update_rc( new, old ):
    if new > old:
        return( new )
    else:
        return( old )

