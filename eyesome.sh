#!/bin/bash

# NAME: eyesome.sh
# PATH: /usr/local/bin
# DESC: Set display brightness and gamma using day/night values, sunrise
#       time, sunset time and transition minutes.

# CALL: Called from /etc/cron.d/start-eyesome on system startup.
#       Called from /lib/systemd/system-sleep/wake-eyesome.sh during resume.
#       Called from eyesome-cfg.sh after 5 second Daytime/Nighttime tests.

# DATE: Feb 17, 2017. Modified: Sep 18, 2018.

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

CalcShortSleep () {

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

    # Sunrise and sunset files can be updated at any time.
    sunrise=$(cat "$SunriseFilename")
    sunset=$(cat "$SunsetFilename")

    # Read hidden configuration file with entries separated by "|" into CfgArr
    ReadConfiguration

    # Variables starting with sec___ are seconds since Epoch
    secNow=$(date +"%s")
    secSunrise=$(date --date="$sunrise today" +%s)
    secSunset=$(date --date="$sunset today" +%s)

    # Is it night time?
    if [[ $secNow -gt $secSunset ]] || [[ $secNow -lt $secSunrise ]]; then
        # It's Night; after sunset or before sunrise nightime setting
        if [[ $secNow -gt $secSunrise ]]; then
            # Sleep until sunrise tomorrow
            SleepUntilDay=$(( secSunrise + 86400 - secNow ))
        else
            # Sleep until sunrise today
            SleepUntilDay=$(( secSunrise - secNow ))
        fi

     	SetBrightness Ngt        # Same function used by eyesome-cfg.sh
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
        SleepUntilNgt=$(( secNgtStart - secNow ))
     	SetBrightness Day        # Same function used by eyesome-cfg.sh
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
