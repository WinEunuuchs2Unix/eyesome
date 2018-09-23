#!/bin/bash

# NAME: eyesome.sh
# PATH: /usr/local/bin
# DESC: Set display brightness and gamma using day/night values, sunrise
#       time, sunset time and transition minutes.

# CALL: Called from /etc/cron.d/start-eyesome on system startup.
#       Called from /usr/local/bin/wake-eyesome.sh during resume which in
#       turn is called from: /lib/systemd/system-sleep/systemd-wake-eyesome
#       and is called from:  /etc/acpi/acpi-lid-eyesome.sh which in turn is
#       is called from: /etc/acpi/events/acpi-lid-event-eyesome
#       Called from eyesome-cfg.sh after 5 second Daytime/Nighttime tests.

# DATE: Feb 17, 2017. Modified: Sep 22, 2018.

# TODO: Support for Wayland

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

export DISPLAY=:0     # For xrandr commands to work.
SpamCount=5
SpamLength=2
SpamContext=""

SleepResetCheck () {

    if [[ $SpamOn -gt 0 ]] ; then
        $(( SpamOn-- ))
        sleep $SpamLength
        if [[ $SpamOn == 1 ]] ; then
            if [[  -f "$EyesomeIsSuspending" ]] ; then
                rm -f "$EyesomeIsSuspending"
                logger "$0: Removed file: $EyesomeIsSuspending"
            fi
        fi
    else
        sleep "$1"
    fi
        
} # SleepResetCheck

CalcTransitionSleep () {

    # Parms $1 = Day = transition from nighttime to full daytime
    #          = Ngt = trannstion from daytime to full nighttime
    #       $2 = total seconds for transition
    #       $3 = number of seconds into transition

    Percent=$( bc <<< "scale=6; ( $3 / $2 )" )

    SetBrightness "$1" "$Percent"
    SleepResetCheck "$UpdateInterval"

} # CalcTransitionSleep

WaitForSignOn () {

    SpamOn=$SpamCount       # Causes 10 iterations of 2 second sleep
    SpamContext="Login"
    TotalWait=0
    [[ ! -f "$CurrentBrightnessFilename" ]] && rm -f \
            "$CurrentBrightnessFilename"

    # Wait for user to sign on then get Xserver access for xrandr calls
    user=""
    while [[ $user == "" ]]; do

        sleep 2
        TotalWait=$(( TotalWait + 2 ))

        # Find the user who is currently logged in on the primary screen.
        user="$(who -u | grep -F '(:0)' | head -n 1 | awk '{print $1}')"
    done

    logger "$0 waited $TotalWait seconds until user: $user to login."

    xhost local:root
    export XAUTHORITY="/home/$user/.Xauthority"

} # WaitForSignOn

CheckForSpam () {

    [[ $SpamOn -gt 0 ]] && return # Spam turned on during signon
    
    # Removed file indicates we are resuming from suspend or
    # laptop lid was opened / closed. Either event can cause external
    # monitors to be reset once or twice and each reset changes 
    # brightnesss and gamma to 1.00.
    if [[ ! -f "$CurrentBrightnessFilename" ]] ; then
        echo "OFF" > "$CurrentBrightnessFilename" # Prevent infinite loop.
        SpamOn=$SpamCount      # Causes 5 iterations of 2 second sleep
        logger "$0: Sleeping $SpamLength seconds $SpamCount times."
    fi

    if [[ -f "EyesomeIsSuspending" ]] ; then
        # Suspending laptop is our reason for spam
        SpamContext="Resuming"
    else
        # SLid Open/Close with external monitor attached is reason for spam
        SpamContext="Lid Open/Close"
    fi
    
} # CheckForSpam

main () {

    WaitForSignOn
    
while true ; do

    CheckForSpam
    
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

     	SleepResetCheck "$SleepUntilDay"
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
     	SleepResetCheck "$SleepUntilNgt"
        continue
    fi

    # Are we between sunrise and full brightness?
    if [[ "$secNow" -gt "$secSunrise" ]] && [[ "$secNow" -lt "$secDayFinal" ]]
    then
    	# Daytime transition from sunrise to Full brightness
    	secPast=$(( secNow - secSunrise ))
        CalcTransitionSleep Day $AfterSunriseSeconds $secPast
        continue
    fi

    # Are we beginning to dim before sunset (full dim)?
    if [[ "$secNow" -gt "$secNgtStart" ]] && [[ "$secNow" -lt "$secSunset" ]]
    then
    	# Nightime transition from Full bright to before Sunset start
    	secBefore=$(( secSunset - secNow ))
        CalcTransitionSleep Ngt $BeforeSunsetSeconds $secBefore
        continue
    fi

    # At this point brightness was set with manual override outside this program
    # or exactly at a testpoint.
    SleepResetCheck "$UpdateInterval"
        
done # End of forever loop

} # main

main "$@"
