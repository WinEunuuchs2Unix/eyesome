#!/bin/bash

# NAME: eyesome-sun.sh
# PATH: /usr/local/bin
# DESC: Get today's sunrise and sunset times from internet.
# CALL: /etc/cron.daily/daily-eyesome-sun
# DATE: Feb 17, 2017. Modified: August 12, 2020.

# PARM: $1 if "nosleep" and internet fails then return with exit status 1
#       If not then keep retrying doubling sleep times between attempts.

# NOTE: eyesome.sh daemon starts during boot and will not see todays new
#       Sunrise / Sunset time until it wakes up. Call wake-eyesome.sh to
#       force immediate wake after new sun times are obtained.

# UPDT: August 12, 2020 - Website returning extra string:
#           $ cat /usr/local/bin/.eyesome-sunrise
#           6:09 amspan class="comp
#           $ cat /usr/local/bin/.eyesome-sunset
#           9:07 pmspan class="comp

source eyesome-src.sh   # Common code for eyesome___.sh bash scripts
fCron=true              # Turn off xrandr requests to prevent email error msg.
ReadConfiguration       # Get $SunCity (also calls xrandr for monitor list)

sleep 120               # Give user 2 minutes to sign-on. We don't want our
                        # wakeup to clash with eyesome-dbus.sh, acpi-lid-
                        # eyesome.sh or login activity. All who spam.

retry_sleep=60          # 1 minutes first time, then doubling each loop

log "$SunHoursAddress."

while true; do

    ### "-q"= quiet, "-O-" pipe output
    wget -q -O- "$SunHoursAddress" \
        | grep -oE 'Sunrise Today.{35}' | awk -F\> '{print $3}' | \
        tr --delete "<" > /tmp/eyesome-sunrise
    wget -q -O- "$SunHoursAddress" \
        | grep -oE 'Sunset Today.{35}' | awk -F\> '{print $3}' | \
        tr --delete "<" > /tmp/eyesome-sunset

    ## August 12, 2020 - Remove extra after am/pm
    sed -i 's/m.*/m/' /tmp/eyesome-sunrise
    sed -i 's/m.*/m/' /tmp/eyesome-sunset

    ## If network is down files will have one byte size
    size1=$(wc -c < /tmp/eyesome-sunrise)
    size2=$(wc -c < /tmp/eyesome-sunset)

    if [[ $size1 -gt 1 ]] && [[ $size2 -gt 1 ]] ; then
        cp /tmp/eyesome-sunrise "$SunriseFilename"
        cp /tmp/eyesome-sunset  "$SunsetFilename"
        chmod 666 "$SunriseFilename"
        chmod 666 "$SunsetFilename"
        rm /tmp/eyesome-sunrise
        rm /tmp/eyesome-sunset
        # Can't wake eyesome because cron doesn't have display interface
        # $WakeEyesome post eyesome-sun.sh nosleep # $4 remaining sec not used
        exit 0
    fi

    if [[ "$1" == "nosleep" ]] ; then
        exit 1
    fi

    log "Network is down. Waiting $retry_sleep seconds to try again."
    sleep $retry_sleep
    retry_sleep=$(( retry_sleep * 2 )) #double time 2m, 4m, 8m, 16m, etc.

    # After 8 hour work day, simply give up
    if [[ $retry_sleep -gt 28800 ]] ; then
        log "Giving up on waiting $retry_sleep seconds (> 8 hours)."
        exit 1
    fi

done
