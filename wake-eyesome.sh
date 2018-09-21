#!/bin/bash

# NAME: wake-eyesome.sh
# PATH: /lib/systemd/system-sleep/
# DESC: Instantly adjust display brightness when resuming from suspend.
# CALL: systemd calls this script during syspend/resume cycles.
#       Called from command line for testing/debugging.
#       Called by /usr/local/bin/eyesome-cfg.sh when Test button clicked.

# DATE: August 2017. Modified: Sepetmber 19, 2018.

# PARM: $1 = systemd State = "pre" or "post" for function
#       $2 = systemd Function = "suspend" or "hibernate"
#       $3 = "nosleep" skip sleep time for on-line testing
#       $4 = Optional debug. "remain" to display seconds remaining only,
#            don't kill the sleep command.

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

if [[ $3 == "" && $4 == "" ]] ; then
    logger "eyesome logger: \$0=$0, \$1=$1, \$2=$2"
fi

case $1/$2 in
  pre/*)
    echo "$0: Going to $2..."
    ;;
  post/*)
    # March 28, 2018 On AW17R3 this script runs too soon after suspend resume.
    [[ $3 != nosleep ]] && sleep 1.5

    [[ $4 != remain ]] && echo "$0: Resuming from $2..."

    # Find running tree processes containing "eyesome.sh" AND "sleep"
    ProgramTree=$(pstree -g -p | grep "${EyesomeDaemon##*/}" | grep sleep)

    # Extract sleep program ID in $ProgramTree, we want "16621" below:
    # |-cron(1198,1198)---cron(1257,1198)---sh(1308,1308)--- \
    #                   eyesome.sh(1321,1308)---sleep(16621,1308)

    pID=${ProgramTree##*sleep(} # cut everything up to & incl "sleep("
    pID=${pID%,*}               # cut everything after & incl ","

    # Are we just getting time remaining and not waking up?
    if [[ "$4" == "remain" ]] ; then
        if [[ $pID != "" ]]; then
            # Warning returned value can be negative:
            # https://unix.stackexchange.com/questions/314512/how-to-determine-the-amount-of-time-left-in-a-sleep#comment786223_314777
            ps -o etime= -o args= -p "$pID" | perl -MPOSIX -lane '
                %map = qw(d 86400 h 3600 m 60 s 1);
                $F[0] =~ /(\d+-)?(\d+:)?(\d+):(\d+)/;
                $t = -($4+60*($3+60*($2+24*$1)));
                for (@F[2..$#F]) {
                    s/\?//g;
                    ($n, $p) = strtod($_);
                    $n *= $map{substr($_, -$p)} if $p;
                    $t += $n
                }
                print $t'
        else
            printf "0"  # Was not sleeping when checked, 0 time remaining
        fi
        exit 0
    fi

    [[ $pID == "" ]] && exit 0  # eyesome.sh not running or it wasn't sleeping
    
    # We are waking up eyesome.sh by killing it's sleep command
    kill $pID  # kill sleep command forcing eyesome.sh to wakeup now.
    echo "$0: sleep pID: '$pID' has been killed."

    ;;
esac

exit 0
