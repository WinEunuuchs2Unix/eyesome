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

# DATE: Feb 17, 2017. Modified: Oct 1, 2018.

# TODO: Recognize user may have booted with Wayland (no xrandr)

# TODO: Some sort of udev support for monitor hotplugging or physical on/off.
#       Wihtout udev user will need to use `sudo eyesome-cfg.sh` and click the
#       Daytime or Nightime 5 second test button. Or watch dpms on/off.

source eyesome-src.sh   # Common code for eyesome___.sh bash scripts

export DISPLAY=:0       # For xrandr commands to work.
SpamOn=0                # > 0 = number of times to spam in loop.
SpamCount=5             # How many times we will spam (perform short sleep)
SpamLength=2            # How long spam lasts (how many seconds to sleep)
SpamContext=""          # Why are we spamming? (Login, Suspend or Lid Event)
                        # Future use: "DPMS Change" ie Monitor on or off.

SleepResetCheck () {

    # PARM: $1 sleep interval. If Spam is on then override with short interval
    #       of 2 seconds for 5 iterations as controlled above.

    if [[ $SpamOn -gt 0 ]] ; then
        (( SpamOn-- ))
        sleep $SpamLength
        if [[ $SpamOn == 0 ]] ; then
            log "$SpamContext: Slept $SpamLength seconds x $SpamCount times."
            SpamContext=""
            if [[  -f "$EyesomeIsSuspending" ]] ; then
                # Lid close event can reset external monitors which we need
                # to trap and spam for. Or it can suspend the system which
                # means we did nothing. If file is present after resuming
                # system remove it now so next lid close event isn't broken.
                rm -f "$EyesomeIsSuspending"
                log "Removed file: $EyesomeIsSuspending"
            fi
        fi
    else
        sleep "$1"
    fi
        
} # SleepResetCheck

CalcTransitionSleep () {

    # PARM: $1 = Day = transition from nighttime to full daytime
    #          = Ngt = trannstion from daytime to full nighttime
    #       $2 = total seconds for transition
    #       $3 = number of seconds into transition

    # How far are we into transition? 0.999999 is not very far and
    # 0.000001 is nearly at end. Yad uses 6 decimal places so eyesome
    # uses same.
    Percent=$( bc <<< "scale=6; ( $3 / $2 )" )

    SetBrightness "$1" "$Percent"
    SleepResetCheck "$UpdateInterval"

} # CalcTransitionSleep

WaitForSignOn () {

    # eyesome daemon is loaded during boot. The user name is required
    # for xrandr external monitor brightness and gamma control. We must
    # wait until user signs on to get .Xauthority file settings.

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

        # Find user currently logged in.
        user="$(who -u | grep -F '(:0)' | head -n 1 | awk '{print $1}')"
    done

    log "Waited $TotalWait seconds for $user to login."

    xhost local:root
    export XAUTHORITY="/home/$user/.Xauthority"

} # WaitForSignOn

CheckForSpam () {

    [[ $SpamOn -gt 0 ]] && return # Spam already turned on during login
    
    # Removed file indicates we are resuming from suspend or
    # laptop lid was opened / closed. Either event can cause external
    # monitors to be reset once or twice and each reset changes 
    # brightnesss and gamma to 1.00. The reset period lasts many seconds.

    if [[ ! -f "$CurrentBrightnessFilename" ]] ; then
        echo "OFF" > "$CurrentBrightnessFilename" # Prevent infinite loop.
        SpamOn=$SpamCount      # Causes 5 iterations of 2 second sleep
        # This works for kernel 4.13.0-36 because monitors auto reset to 1.00.
        # This doesn't work for 4.4.0-135 because monitors stay black until
        # mouse is moved and user may be slower than 10 seconds.
    fi

    if [[ -f "EyesomeIsSuspending" ]] ; then
        # Resuming from Suspend is our reason for spam
        SpamContext="Suspend Resume"
    else
        # SLid Open/Close (external monitor resets) is reason for spam
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
    	RemainingSeconds=$(( secDayFinal - secNow )) # secPast is Decreasing
        CalcTransitionSleep Day $AfterSunriseSeconds $RemainingSeconds
        continue
    fi

    # Are we beginning to dim before sunset (full dim)?
    if [[ "$secNow" -gt "$secNgtStart" ]] && [[ "$secNow" -lt "$secSunset" ]]
    then
    	# Nightime transition from Full bright to Sunset
    	RemainingSeconds=$(( secSunset - secNow )) # secBefore is decreasing
        CalcTransitionSleep Ngt $BeforeSunsetSeconds $RemainingSeconds
        continue
    fi

    # At this point brightness was set with manual override outside this program
    # or exactly at a testpoint.
    SleepResetCheck "$UpdateInterval"
        
done # End of forever loop

} # main

main "$@"
