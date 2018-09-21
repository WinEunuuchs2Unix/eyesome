#!/bin/bash

# NAME: eyesome.sh
# PATH: /usr/local/bin
# DESC: Set display brightness and gamma using day/night values, sunrise
#       time, sunset time and transition minutes.

# CALL: Called from /etc/cron.d/start-eyesome on system startup.
#       Called from /usr/local/bin/wake-eyesome.sh during resume which in
#       turn is called from /lib/systemd/system-sleep/systemd-wake-eyesome.
#       Called from eyesome-cfg.sh after 5 second Daytime/Nighttime tests.

# DATE: Feb 17, 2017. Modified: Sep 20, 2018.

# TODO: After login Lightdm resets all screens to full brightness. Decipher
#       where / how to invoke eyesome.sh again. Maybe forward 5 second wakeup?

logger "eyesome logger: \$0=$0"

export DISPLAY=:0     # For xrandr commands to work.
logger "$0 waiting for user to login"
user=""
while [[ $user == "" ]]; do

    sleep 1
    logger "$0 waited 1 second for user to login..."

    # Find the user who is currently logged in on the primary screen.
    user="$(who -u | grep -F '(:0)' | head -n 1 | awk '{print $1}')"
done

logger "$0 user found: $user"
xhost local:root
export XAUTHORITY="/home/$user/.Xauthority"
logger "$0 XAUTHORITY: $XAUTHORITY"

# Find the user who is currently logged in on the primary screen.
user="$(who -u | grep -F '(:0)' | head -n 1 | awk '{print $1}')"
logger "$0 user found: $user"

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

ReadConfiguration   # Delete this line when debug stuff is removed.
logger "$0 Getting Work Space"
GetMonitorWorkSpace $CFG_MON1_NDX
logger "$0 Initialize Xrandr Array"
InitXrandrArray
logger "$0 Search Xrandr Array"
SearchXrandrArray $MonXrandrName
logger "$0 Monitor: $MonNumber: $XrandrConnection CRTC: $XrandrCRTC"

# [ "$XDG_SESSION_TYPE" = x11 ] || exit 0
# put above some place, some how.

CalcShortSleep () {

logger "$0 CalcShortSleep"
    # Parms $1 = Day = transition from nighttime to full daytime
    #          = Ngt = trannstion from daytime to full nighttime
    #       $2 = total seconds for transition
    #       $3 = number of seconds into transition

    Percent=$( bc <<< "scale=6; ( $3 / $2 )" )

    SetBrightness "$1" "$Percent"
    sleep "$UpdateInterval"

} # CalcShortSleep

main () {

while true ; do

    # Read hidden configuration file with entries separated by "|" into CfgArr
    # Sunrise and sunset files are also read
    ReadConfiguration

    # Variables starting with sec___ are seconds since Epoch
    secNow=$(date +"%s")
    secSunrise=$(date --date="$sunrise today" +%s)
    secSunset=$(date --date="$sunset today" +%s)

    # Is it night time?
    if [[ $secNow -gt $secSunset ]] || [[ $secNow -lt $secSunrise ]]; then
     	SetBrightness Ngt        # Same function used by eyesome-cfg.sh
        # It's Night; is it after sunset tonight or before sunrise tomorrow?
        if [[ $secNow -gt $secSunrise ]]; then
            # Sleep until sunrise tomorrow
            SleepUntilDay=$(( secSunrise + 86400 - secNow ))
        else
            # Sleep until sunrise today
            SleepUntilDay=$(( secSunrise - secNow ))
        fi

     	sleep "$SleepUntilDay"
    	continue
    fi

    # We're somewhere between sunrise and sunset
    AfterSunriseSeconds=$(( MinAfterSunrise * 60 ))
    BeforeSunsetSeconds=$(( MinBeforeSunset * 60 ))
    secDayFinal=$(( secSunrise + AfterSunriseSeconds ))
    secNgtStart=$(( secSunset  - BeforeSunsetSeconds ))

    # Is it full bright / day time?
    if [[ $secNow -gt $secDayFinal ]] && [[ $secNow -lt $secNgtStart ]]; then
    	# It's Day; after sunrise transition AND before nightime transition
    	# Sleep until Sunset transition time
     	SetBrightness Day        # Same function used by eyesome-cfg.sh
        SleepUntilNgt=$(( secNgtStart - secNow ))
     	sleep "$SleepUntilNgt"
        continue
    fi

    # Are we between sunrise and full brightness?
    if [[ "$secNow" -gt "$secSunrise" ]] && [[ "$secNow" -lt "$secDayFinal" ]]
    then
    	# Daytime transition from sunrise to Full brightness
    	secPast=$(( secNow - secSunrise ))
        CalcShortSleep Day $AfterSunriseSeconds $secPast
        continue
    fi

    # Are we beginning to dim before sunset (full dim)?
    if [[ "$secNow" -gt "$secNgtStart" ]] && [[ "$secNow" -lt "$secSunset" ]]
    then
    	# Nightime transition from Full bright to before Sunset start
    	secBefore=$(( secSunset - secNow ))
        CalcShortSleep Ngt $BeforeSunsetSeconds $secBefore
        continue
    fi

    # At this point brightness was set with manual override outside this program
    # or exactly at a testpoint.
    sleep "$UpdateInterval"
        
done # End of forever loop

} # main

main "$@"
