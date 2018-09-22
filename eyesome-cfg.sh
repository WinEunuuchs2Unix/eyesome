#!/bin/bash

# NAME: eyesome-cfg.sh
# PATH: /usr/local/bin
# DESC: Configuration for eyessome.sh's min/max values, sun rise/set time
#       and transition minutes.
# CALL: Called from terminal with `sudo` permissions.
# DATE: Feb 17, 2017. Modified: Sep 21, 2018.

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

if [[ $(id -u) != 0 ]]; then # root powers needed to call this script
    echo >&2 $0 must be called with sudo powers
    exit 1
fi

# Must have the yad package.
command -v yad >/dev/null 2>&1 || { echo >&2 \
        "yad package required but it is not installed.  Aborting."; \
        exit 2; }

# $TERM variable may be missing when called via desktop shortcut
CurrentTERM=$(env | grep TERM)
if [[ $CurrentTERM == "" ]] ; then
    notify-send --urgency=critical \
    "$0 cannot be run from GUI without TERM environment variable."
    exit 1
fi

# Read configuration and create if it doesn't exist.
ReadConfiguration

KEY="23255"     # Key for tying Notebook pages (tabs) together
                # multi-timer is KEY="12345", don't duplicate
# Temporary files for Notebook output
res1=$(mktemp --tmpdir iface1.XXXXXXXX) # Notebook Overview Page (Tab 1)
res2=$(mktemp --tmpdir iface2.XXXXXXXX) # Notebook Monitor 1 Page (Tab 2)
res3=$(mktemp --tmpdir iface3.XXXXXXXX) # Notebook Monitor 2 Page (Tab 3)
res4=$(mktemp --tmpdir iface4.XXXXXXXX) # Notebook Monitor 3 Page (Tab 4)

Cleanup () {
    # Remove temporary files
    rm -f "$res1" "$res2" "$res3" "$res4"
    IFS=$OLD_IFS;                       # Restore Input File Separator
} # Cleanup

BuildMonitorPage () {
    # Move configuration array monitor 1-3 to Working Screen fields
    # $1 = CfgArr Starting Index Number

    aMonPage=()
    i="$1"
    aMonPage+=("--field=Monitor Number::RO")
    aMonPage+=("${CfgArr[$((i++))]}")

    aMonPage+=("--field=Monitor Status::CB")
    Status=("${CfgArr[$((i++))]}")
    cbStatus="Enabled!Disabled"
    cbStatus="${cbStatus/$Status/\^$Status}"
    aMonPage+=("$cbStatus")

    aMonPage+=("--field=Monitor Type::CB")
    Type=("${CfgArr[$((i++))]}")
    cbType="Hardware!Software"
    cbType="${cbType/$Type/\^$Type}"
    aMonPage+=("$cbType")

    aMonPage+=("--field=Monitor Name:")
    aMonPage+=("${CfgArr[$((i++))]}")
    aMonPage+=("--field=Internal Name:")
    aMonPage+=("${CfgArr[$((i++))]}")
    aMonPage+=("--field=Xrandr Name:")
    aMonPage+=("${CfgArr[$((i++))]}")
    aMonPage+=("--field=Daytime Brightness::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..9999!.01!2)
    aMonPage+=("--field=Daytime Red::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..2.0!.01!2)
    aMonPage+=("--field=Daytime Green::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..2.0!.01!2)
    aMonPage+=("--field=Daytime Blue::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..2.0!.01!2)
    aMonPage+=("--field=Nighttime Brightness::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..9999!.01!2)
    aMonPage+=("--field=Nighttime Red::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..2.0!.01!2)
    aMonPage+=("--field=Nighttime Green::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..2.0!.01!2)
    aMonPage+=("--field=Nighttime Blue::NUM")
    aMonPage+=("${CfgArr[$((i++))]}"!0.1..2.0!.01!2)
    aMonPage+=("--field=Current Brightness::RO")
    aMonPage+=("${CfgArr[$((i++))]}")
    aMonPage+=("--field=Current Gamma::RO")
    aMonPage+=("${CfgArr[$((i++))]}")
    
} # BuildMonitorPage

AddEmptyFields () {

    # Add empty fields to Configuration File
    # Allows fields for future use without having to modify configuration file
    # $1 = Number of fields to add

    for ((i=1; i<="$1"; i++)); do
        printf " |" >> "$ConfigFilename"
    done

} # AddEmptyFields

EditConfiguration () {

    # General notebook page
    yad --plug=$KEY --tabnum=1 --form \
        --field="
The web page with sunrise/sunset hours must begin with
https://www.timeanddate.com/sun/ and followed by your
country/city name.

For well-known cities it might only contain your city
name or even just a number.  Normally the correct web
address is found automatically.  If not, navigate to
www.timeanddate.com and search for your city name. 
Then copy the browser's web address and paste it below:\n:TXT" \
        "${CfgArr[CFG_SUNCITY_NDX]}" \
        --field="
The brightness update interval is entered in seconds.
A longer update interval saves computer resources.  An 
interval too long will give noticable brightness and
gamma adjustments that can be distracting.:

Set internval between 5 and 300 seconds (5 minutes).
15 to 60 seconds should provide the best results.
:NUM" \
        "${CfgArr[CFG_SLEEP_NDX]}"!5..300!1!0 \
        --field="Transition minutes after sunrise to full brightness::NUM" \
        "${CfgArr[CFG_AFTER_SUNRISE_NDX]}"!0..180!1!0 \
        --field="Transition minutes before sunset to begin dimming::NUM" \
        "${CfgArr[CFG_BEFORE_SUNSET_NDX]}"!0..180!1!0 \
        --field="
Monitor test button duration in seconds. You can enter
5 to 20 seconds. The test may be interupted by eyesome
transition if testing after sunrise and before sunset.:
:NUM" \
        "${CfgArr[CFG_TEST_SECONDS_NDX]}"!5..20!1!0 \
         > "$res1" &

    # Monitor 1 notebook page
    BuildMonitorPage "$CFG_MON1_NDX"
    yad --plug=$KEY --tabnum=2 --form \
        "${aMonPage[@]}" > "$res2" &

    # Monitor 2 notebook page
    BuildMonitorPage "$CFG_MON2_NDX"
    yad --plug=$KEY --tabnum=3 --form \
        "${aMonPage[@]}" > "$res3" &

    # Monitor 3 notebook page
    BuildMonitorPage "$CFG_MON3_NDX"
    yad --plug=$KEY --tabnum=4 --form \
        "${aMonPage[@]}" > "$res4" &

    # run main dialog
    #  --image=gnome-calculator
    if yad --notebook --key=$KEY --tab="General" --tab="Monitor 1" \
        --tab="Monitor 2" --tab="Monitor 3" --active-tab="Monitor 2" \
        --image=sleep --image-on-top \
        --title="eyesome setup" --width=400 \
        --text="<big><b>eyesome</b></big> - edit configuration" 2>/dev/null
    then
        :
    else
        return
    fi

    # Save configuration
    truncate -s -1 "$res1"  # Remove new line at EOF
    cat "$res1" >  "$ConfigFilename"
    AddEmptyFields 5        # Extra fields for future use
    truncate -s -1 "$res2"  # Remove new line at EOF
    cat "$res2" >>  "$ConfigFilename"
    AddEmptyFields 4        # Extra fields for future use
    truncate -s -1 "$res3"  # Remove new line at EOF
    cat "$res3" >>  "$ConfigFilename"
    AddEmptyFields 4
    truncate -s -1 "$res4"
    cat "$res4" >> "$ConfigFilename"
    AddEmptyFields 4
    echo "" >> "$ConfigFilename" # Add EOF (new line) marker

} # EditConfiguration

MainMenu () {

    ReadConfiguration
    
    SecondsToUpdate=$("$WakeEyesome" post eyesome-cfg.sh nosleep remain)

    # Blowout protection blank, 0 or negative (bug)
    [[ $SecondsToUpdate == "" ]] || [[ $SecondsToUpdate == 0 ]] \
        || [[ $SecondsToUpdate == -* ]] \
        && SecondsToUpdate="${CfgArr[$CFG_SLEEP_NDX]%.*}"

    NextDate=$(date --date="$SecondsToUpdate seconds") # Sleep seconds Epoch
    NextCheckTime=$(date --date="$NextDate" +'%I:%M:%S %p') # Now + Sleep
    LastCheckTime=$(date +'%I:%M:%S %p') # Now

    Dummy=$(yad  --form \
        --image=preferences-desktop-screensaver \
        --window-icon=preferences-desktop-screensaver \
        --margins=10 \
        --title="eyesome setup" \
        --text="<big><b>eyesome</b></big> - main menu" \
        --timeout="$SecondsToUpdate" --timeout-indicator=top \
        --field="Eyesome daemon time remaining queried at::RO" \
        --field="Seconds until eyesome daemon wakes up::RO" \
        --field="Brightness will be set again at::RO" \
        --field="

This window will auto refresh when the brightness level
is checked on your monitor(s).

Click the <b><i>Refresh</i></b> button below to refresh how many seconds
remain until the next auto refresh.

Click the <b><i>Edit</i></b> button below to change the brighness and/or
gamma monitor levels for Daytime and Nighttime. There you
can also change your city name used to obtain sunrise and
sunset times daily from the internet.

After using <b><i>Edit</i></b>, tests are done to ensure sunrise time was
recently updated. Also to ensure eyesome daemon is running.

Click the <b><i>Daytime</i></b> button below for a $TestSeconds second test of what
the monitors will look like in daytime. The same $TestSeconds second
test can be used for nighttime using the <b><i>Nighttime</i></b> button.

Click the <b><i>Quit</i></b> button to close this program.

:LBL" \
        --button="_Refresh:$ButnView" \
        --button="_Edit:$ButnEdit" \
        --button="_Daytime:$ButnDay"  \
        --button="_Nighttime:$ButnNight" \
        --button="_Quit:$ButnQuit" \
        "$LastCheckTime" "$SecondsToUpdate" "$NextCheckTime" 2>/dev/null)

    Retn="$?"
    
} # MainMenu

TestBrightness () {

    # $1 = Day or Ngt

    SetBrightness "$1"      # Same function used by eyesome.sh

    eol=$'\n'
    line="${aAllMon[*]}"    # Convert array to string
    line="${line//|/$eol}"  # Search "|" replace with "\n" (new line).

    [[ $TestSeconds == "" ]] || [[ $TestSeconds == 0 ]] && TestSeconds=5
    SleepSec=$(bc <<< "scale=6; $TestSeconds/100")

    for (( i=0; i<100; i++ )) ; do      # 100 interations of sleep .xxx
        echo $i                         # Percent complete for progress bar
        [[ $i == 1 ]] && echo "$line"   # dump aAllMon[*] array to progess log
        [[ $i -gt 100 ]] && break
        sleep "$SleepSec"

    done | yad --progress       --auto-close \
        --title="eyesome Monitor Brightness Test" \
        --enable-log "$TestSeconds second time progress" \
        --width=400             --height=550 \
        --log-expanded          --log-height=400 \
        --log-on-top            --percentage=0 \
        --no-cancel             --center \
        --bar=RTL               2>/dev/nul
    
    $WakeEyesome post eyesome-cfg.sh nosleep # $4 remaining sec not used
    sleep .25    # Give eyesome daemon time to wakeup & sleep before main menu

} # TestBrightness

CheckSunHours () {

    [[ $fSunHoursCheckedOnce == true ]] && return
    fSunHoursCheckedOnce=true

    ButnRetrieve=10

    while true ; do

        # If date of sun rise/set files are more than 2 days old then
        # /etc/cron.daily/daily-eyesome-sun may not be setup or when it
        # called /usr/local/bin/eyesome-sun.sh it crashed or there was
        # no internet access.
        if [[ $(find  "$SunsetFilename" -mtime +2 -print) ]]; then
            : # echo "File $SunsetFilename exists and is older than 2 days"
        else
            return 0 # Sunrise / sunset file times are up-to-date.
        fi

        Dummy=$(yad  --form \
            --image=preferences-desktop-screensaver \
            --window-icon=preferences-desktop-screensaver \
            --margins=10 \
            --height=500 \
            --title="eyesome setup" \
            --text="
<big><b>eyesome</b></big> - Sunrise / Sunset hours files are > 2 days old" \
            --field="
The web address for sunrise/sunset hours might be incorrect:\n:tXT" \
            "${CfgArr[CFG_SUNCITY_NDX]}" \
            --field="
NOTE: You cannot change the website address from this screen.    
You must use main menu's <b><i>Edit</i></b> button to change the address.

Once a day the web page is checked by 'cron' (Command Run ON).
The 'cron' script: '$CronSunHours' should call
the bash script: '$EyesomeSunProgram' each morning.

Sunrise time in '$SunriseFilename' is: <b>$(cat "$SunriseFilename")</b>
Sunset time in  '$SunsetFilename' is:  <b>$(cat "$SunsetFilename")</b>

Testing reveals these files have a date greater than two days old.

Click the <b><i>Retrieve</i></b> button below to call 'eyesome-sun.sh' and
access the internet to obtain today's sunrise and sunset times. If
successful this likely means 'cron' is not running as it should.

If retrieval fails, you can manually edit the files named above.
Do not enter the seconds, just the hours, minutes followed by am
or pm.  For example '8:37 am' for sunrise and '10:22 pm' for
sunset.:LBL" \
            --button="_Retrieve:$ButnRetrieve" \
            --button="_Cancel:$ButnQuit" \
            2>/dev/null)

        Retn="$?"

        if [[ $Retn == "$ButnRetrieve" ]] ; then
            $EyesomeSunProgram nosleep
            [[ "$?" == 0 ]] && return 0     # Success
            continue                        # Loop and offer another try
        else
            return 1                        # Quit
        fi
    done

} # CheckSunHours

# fEyesomeCheckedOnce=false

CheckEyesomeDaemon () {

    [[ $fEyesomeCheckedOnce == true ]] && return
    fEyesomeCheckedOnce=true

    ButnStart=10

    while true ; do

        # Does process tree contain "eyesome.sh"?
        pID=$(pstree -g -p | grep "${EyesomeDaemon##*/}")

        [[ $pID != "" ]] && return 0    # .../eyesome.sh daemon is running

        # If you run program to strip trailing spaces add 3 after "will run"    
        Dummy=$(yad  --form \
            --image=preferences-desktop-screensaver \
            --window-icon=preferences-desktop-screensaver \
            --margins=10 \
            --height=500 \
            --title="eyesome setup" \
            --text="
<big><b>eyesome</b></big> - eyesome daemon is not running!" \
            --field="
Each time your computer is turned on, 'cron' (Command Run ON) will run   
the cron script: '$CronStartEyesome'
which calls the bash script: '$EyesomeDaemon'.

Check of running processes reveals that '$EyesomeDaemon'
is not running.

If you just installed eyesome and haven't rebooted your
computer yet, then this is to be expected.

Click the <b><i>Start</i></b> button below to start '$EyesomeDaemon'.:LBL" \
            --button="_Start:$ButnStart" \
            --button="_Cancel:$ButnQuit" \
            2>/dev/null)

        Retn="$?"
        
        if [[ $Retn == "$ButnStart" ]] ; then
# TODO: Use $EyesomeDaemon variable
            (eyesome.sh &) &            # start deamon as background task
            sleep .25                        # .5 to allow daemon to sleep
        else
            return 1                        # Quit
        fi
        
    done
    
} # CheckEyesomeDaemon

###################################
#            MAINLINE             #
###################################

main () {

    # ReadConfiguration # This is already done somewhere, but where?

    ButnView=10
    ButnEdit=20
    ButnDay=30
    ButnNight=40
    ButnQuit=50

    while true ; do

        MainMenu
        
        if [[ $Retn == "$ButnEdit" ]] ; then
            EditConfiguration
            CheckSunHours
            CheckEyesomeDaemon
            # monitor settings may have changed, so wake up eyesome
            $WakeEyesome post eyesome-cfg.sh nosleep
        elif [[ $Retn == "$ButnDay" ]] ; then
            TestBrightness Day
        elif [[ $Retn == "$ButnNight" ]] ; then
            TestBrightness Ngt
            # TODO: Last brightness/gamma isn't reset after nighttime test
        elif [[ $Retn == "$ButnQuit" ]] ; then
            break
        fi

    done

    # Escape or Quit from yad notebook
    Cleanup
    exit 0

} # main

main "$@"
