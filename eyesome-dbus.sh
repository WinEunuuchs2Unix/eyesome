#!/bin/bash

# NAME: eyesome-dbus.sh
# PATH: /usr/local/bin
# DESC: Watch dbus for monitor color events
# CALL: Automatically started as deamon by eyesome.sh
# DATE: October 8, 2018. Modified October 20, 2018.

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

Type="method_call"
Interface="org.freedesktop.ColorManager"
DirPath="/org/freedesktop/ColorManager"
Member="FindDeviceByProperty"
Watch="type=${Type}, interface=${Interface}, path=${DirPath}, member=${Member}"

# When NewTimeSTamp - OldTimeStamp > 5 seconds a new group of events occurs
# Wake up eyesome.sh to spam monitors
OldTimeStamp=$(printf '%(%s)T')

# Wait for user to sign on then get Xserver access for xrandr calls
UserName=""
iEventCnt=0

OneTimeWakeup () {

    # Wakeup eyesome.sh once for every group of commands
    # If the elapsed time between groups is > 5 seconds we assume a new group
    # of events has begun. Unplugging a monitor can create 5 DBUS events in
    # less than a second and we don't want to wakeup eyesome.sh 5 times.

    NewTimeStamp=$(printf '%(%s)T')
    secElapsed=$(( NewTimeStamp - OldTimeStamp ))
    # log "OneTimeWakeup Elapsed: $secElapsed New Stamp: $NewTimeStamp"
    OldTimeStamp="$NewTimeStamp"
    (( iEventCnt++ ))

    [[ "$secElapsed" -lt 6 ]] && return # If less than 5 seconds get more events
    
    log "Event Count: $iEventCnt over: $secElapsed seconds"
    iEventCnt=0

    # Has user signed on?
    if [[ "$UserName" == "" ]] ; then
        # Check if user has signed in
        UserName="$(who -u | grep -F '(:0)' | head -n 1 | awk '{print $1}')"

        if  [[ "$UserName" == "" ]] ; then
            LastLoginWait="$NewTimeStamp"
            log "Waiting for user to log in, not waking up eyesome"
            return
        else
            # There may not be events after user first logs in with external
            # monitor(s) disconnected. If monitor connected after logging in
            # then we want to wakeup eyesome daemon below.
            LastModificationSeconds=$(date +%s -r "$EyesomeUser")
            sec=$(( NewTimeStamp - LastModificationSeconds ))
            if [[ "$sec" -lt 15 ]] ; then
                log "$UserName logged in $sec seconds, not waking eyesome"
                return
            else
                log "$UserName logged in for $sec seconds, waking eyesome"
            fi
        fi
    fi

    # Wakeup eyesome.sh after dbus searched Xrandr monitor properties
    echo YES > "$EyesomeDbus"
    sync -d "$EyesomeDbus"      # Flush buffer immediately
    $WakeEyesome post eyesome-dbus.sh nosleep &

} # OneTimeWakeup

log "Starting DBUS-Monitor using $Watch"

dbus-monitor --system "${Watch}" | \
(
    while read line; do
       OneTimeWakeup
    done
)

log "Ending DBUS-Monitor" # This should never happen

exit 0
