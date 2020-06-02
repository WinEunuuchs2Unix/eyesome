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
#       Called from wake-eyesome.sh which is called from eyesome-dbus-monitor.

# DATE: Feb 17, 2017. Modified: May 18, 2020.

# UPDT: Nov 09 2018 - Increase Login SpamCount to 10 (20 seconds) because older
#       HDMI TV's not quick enough to repsond with 5 (10 seconds).

#       May 18 2020: Last shutdown some monitors may have been overridden to
#       pause eyesome daemon. If so renable brightness settings on start up.

## ERRORS shellcheck source=/usr/local/bin/eyesome-src.sh
source eyesome-src.sh   # Common code for eyesome___.sh bash scripts

export DISPLAY=:0       # For xrandr commands to work.
SpamOn=0                # > 0 = number of times to spam in loop.
SpamCount=5             # How many times we will spam (perform short sleep)
SpamLength=2            # How long spam lasts (how many seconds to sleep)
SpamContext=""          # Why are we spamming? (Login, Suspend or Lid Event)
                        # Future use: "DPMS Change" ie Monitor on or off.

UnpauseLastSession () {
    # Same code found in eyesome-cfg.sh and similar code in movie.sh
    # Restore any paused monitor status to enabled.
    sed -i "s/|1|Paused|/|1|Enabled|/g" "$ConfigFilename"
    sed -i "s/|2|Paused|/|2|Enabled|/g" "$ConfigFilename"
    sed -i "s/|3|Paused|/|3|Enabled|/g" "$ConfigFilename"

} # UnpauseLastSession

SleepResetCheck () {

    # PARM: $1 sleep interval. If Spam is on then override with short interval
    #       of 2 seconds for 5 iterations as controlled above.

    if [[ $SpamOn -gt 0 ]] ; then
        (( SpamOn-- ))
        sleep $SpamLength
        if [[ $SpamOn == 0 ]] ; then
            log "$SpamContext: Slept $SpamLength seconds x $SpamCount times."
            SpamContext=""
            if [[ -f "$EyesomeIsSuspending" ]] ; then
                # Lid close event can reset external monitors which we need
                # to trap and spam for. Or it can suspend the system which
                # means we did nothing. If file is present after resuming
                # system remove it now so next lid close event isn't broken.
                rm -f "$EyesomeIsSuspending"
                log "Removed file: $EyesomeIsSuspending"
            fi
            if [[ -f "$EyesomeDbus" ]] ; then
                # When monitor is unplugged, plugged in, turned on or turned
                # off about 5 DBUS Monitor events will occur for each active
                # monitor to find Xrandr device property. Remove the file
                # that was created to indicate the events occured.
                rm -f "$EyesomeDbus"
                log "Removed file: $EyesomeDbus"
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
    Percent=$( bc <<< "scale=6; ( $3 / $2 )" ) # WARN: `bc` takes .171 seconds

    SetBrightness "$1" "$Percent"
    SleepResetCheck "$UpdateInterval"

} # CalcTransitionSleep

StartListeners () {

    if [[ "$fUseDbusMonitor" == true ]] ; then
        ("$EyesomeDbusDaemon" &) &  # start deamon as background task
        log "Launching $EyesomeDbusDaemon daemon"
    fi

} # StartListeners

WaitForSignOn () {

    # eyesome daemon is loaded during boot. The user name is required
    # for xrandr external monitor brightness and gamma control. We must
    # wait until user signs on to get .Xauthority file settings.

    SpamOn=10       # Causes 10 iterations of 2 second sleep
    SpamContext="Login"
    TotalWait=0
    [[ ! -f "$CurrentBrightnessFilename" ]] && rm -f \
            "$CurrentBrightnessFilename"

    # Wait for user to sign on then get Xserver access for xrandr calls
    UserName=""
    while [[ $UserName == "" ]]; do

        sleep "$SpamLength"
        TotalWait=$(( TotalWait + SpamLength ))

        # Find UserName currently logged in.
        UserName="$(who -u | grep -F '(:0)' | head -n 1 | awk '{print $1}')"
    done

    log "Waited $TotalWait seconds for $UserName to login."

    xhost local:root
    export XAUTHORITY="/home/$UserName/.Xauthority"

    if [[ "$fUseDbusMonitor" == true ]] ; then
        echo "$UserName" > "$EyesomeUser"
        sync -d "$EyesomeUser"      # Flush buffer immediately
    fi

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
    else
        return # Spamming not needed
    fi
    if [[ -f "$EyesomeIsSuspending" ]] ; then
        # Resuming from Suspend is our reason for spam
        SpamContext="Resuming"
        return
    fi

    if [[ -f "$EyesomeDbus" ]] ; then
        # DBUS Monitor triggered by hotplug or power on/off external monitor
        SpamContext="DBUS"
        return
    fi
    
    # Lid Open/Close is reason for spam
    SpamContext="Lid Open/Close"
    
} # CheckForSpam

LoopForever () {

while true ; do

    # Have listeners told us to spam display settings?
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

} # LoopForever

Main () {

    Unpauselastsession
    ReadConfiguration
    StartListeners
    WaitForSignOn
    LoopForever    

} # Main

Main "$@"
