#!/bin/bash

# NAME: eyesome-cfg.sh
# PATH: /usr/local/bin
# DESC: Configuration for eyessome.sh's min/max values, sun rise/set time
#       and transition minutes.
# CALL: Called from terminal with `sudo` permissions.
# DATE: Feb 17, 2017. Modified: July 7, 2020.

# UPDT: Oct 5 2018: Allow lower setting for monitor test from "5" to "1" second
#       Add new field "Watch external monitor plugging / power switch?"

#       Dec 26 2018: Change screen to reflect test time of `1 to 20 seconds`.

#       May 18 2020: Add override window to pause eyesome daemon.  This allows
#       user to manually set brightness / color temperature.  Set yad window
#       geometry default to '--center' instead of top left.  Main Menu now
#       allows 'X' to close window or Escpae Key to exit.

#       Jun 2 2020: Expand Override window with Get, Preview and Apply
#       buttons. Add monitor fields and Help button to Override window.
#       Make $KEY randomized rather than hard coded for restart after crash.

#       Jun 3 2020: Yetserday's version never published to github. Remove
#       notebook --active-tab which doesn't work anyway and iconic reports to
#       break things in Ubuntu 19.04.

#       Jun 13 2020: Override button instructions on Main Menu. Add Sun Times
#       tab to notebook for manual setting / daily override of sunrise and
#       sunset times. When Overide exits set brightness to current time.

#       Jul 07 2020: Old bug when $Retn not global then time remaining countdown
#       when nothing clicked causes exit when countdown ends.

#       May 09, 2021 Support for German and Russian locale date formats

source eyesome-src.sh # Common code for eyesome___.sh bash scripts

if [[ $(id -u) != 0 ]]; then # root powers needed to call this script
    echo >&2 "$0 must be called with sudo powers"
    exit 1
fi

# Must have the yad package.
command -v yad >/dev/null 2>&1 || { echo >&2 \
        "'yad' package required but it is not installed.  Aborting."; \
        exit 2; }

# Must have the bc package.
command -v bc >/dev/null 2>&1 || { echo >&2 \
        "'bc' package required but it is not installed.  Aborting."; \
        exit 2; }

# $TERM variable may be missing when called via desktop shortcut
CurrentTERM=$(env | grep TERM)
if [[ $CurrentTERM == "" ]] ; then
    notify-send --urgency=critical \
    "$0 cannot be run from GUI without TERM environment variable."
    exit 3
fi

# Only one instance of eyesome-cfg.sh can be running
if pidof -o %PPID -x "$EyesomeCfgProgram">/dev/null; then
    notify-send --urgency=critical \
    "Eyesome configuration is already running."
    exit 4
fi

# Read configuration and create if it doesn't exist.
ReadConfiguration

# Key for tying Notebook tabs together. Cannot be same key twice.
KEY=$(echo $[($RANDOM % ($[10000 - 32000] + 1)) + 10000] )

GEOMETRY="--center" # Center windows on screen

# Temporary files for Notebook output
res1=$(mktemp --tmpdir iface1.XXXXXXXX) # Notebook Overview Page (Tab 1)
res2=$(mktemp --tmpdir iface2.XXXXXXXX) # Notebook Monitor 1 Page (Tab 2)
res3=$(mktemp --tmpdir iface3.XXXXXXXX) # Notebook Monitor 2 Page (Tab 3)
res4=$(mktemp --tmpdir iface4.XXXXXXXX) # Notebook Monitor 3 Page (Tab 4)
res5=$(mktemp --tmpdir iface4.XXXXXXXX) # Notebook Sun times Page (Tab 5)

Cleanup () {
    # Remove temporary files
    rm -f "$res1" "$res2" "$res3" "$res4" "$res5"
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


MakeHourMin () {
    # Assumes time passed in "$3" is valid
    # Declare reference to argument 1 & 2 provided (Bash 4.3 or greater)
    declare -n Hour=$1      # 1-12
    declare -n Min=$2       # 0-59
    Time="$3"               # Format: "hh:mm xm" where x='a' or 'p'

    Major="${Time%% *}"    # Strip of ' xm' = 'hh:mm'
    Hour="${Major%%:*}"    # Get left ':'   = 'hh'
    Min="${Major##*:}"     # Get right ':'  = 'mm'
    #echo "Time: $Time  Major: $Major  Hour: $Hour  Min: $Min"
} # MakeHourMin


EditConfiguration () {

    # Not enough room in panel anymore for:
    #   Set internval between 5 and 300 seconds (5 minutes).
    #   15 to 60 seconds should provide the best results.

    local Retn ButnRefresh=10 ButnSave=20

    # Prevent eyesome daemon from changing brightness/gamma while configuration
    # is being edited. This allows other programs to change settings while
    # this function is running. The Override () function does same thing.
    PauseMonitors

    # Test if files exist and have valid content, if not use 7:00 am / 9:00 pm
    if [[ -e "$SunriseFilename" && -e "$SunriseFilename" ]] ; then
        NetSunrise="$(cat $SunriseFilename)"
        NetSunset="$(cat $SunsetFilename)"
    else
        NetSunrise="7:00 am"
        NetSunset="9:00 pm"
    fi

    # Variables must be global for called functions to see
    # Note 'Make' functions take variable name , not contents using $
    MakeHourMin SunriseHour SunriseMinute "$NetSunrise"
    MakeHourMin SunsetHour  SunsetMinute  "$NetSunset"

    # Loop while BTN calls bash -c and kills notebook dialog
    while true ; do # Dummy loop, always exists after first time.

        # General notebook page
        yad --plug=$KEY --tabnum=1 --form \
            --field="
The web page with sunrise/sunset hours must begin
with <b>https://www.timeanddate.com/sun/</b> and 
followed by your country/city name.

Well known cities might only contain your city
name or just a number. Usually the correct web
address is found automatically.  If not, navigate
to www.timeanddate.com and search for your city. 
Copy browser's web address and paste it below:\n:TXT" \
            "${CfgArr[CFG_SUNCITY_NDX]}" \
            --field="
Transition brightness/gamma interval in
seconds. Longer interval saves resources.
If interval is longer noticable brightness 
and gamma adjustments occur. 60 seconds
is a good compromise::NUM" \
            "${CfgArr[CFG_SLEEP_NDX]}"!5..300!1!0 \
            --field="Transition minutes after sunrise::NUM" \
            "${CfgArr[CFG_AFTER_SUNRISE_NDX]}"!0..180!1!0 \
            --field="Transition minutes before sunset::NUM" \
            "${CfgArr[CFG_BEFORE_SUNSET_NDX]}"!0..180!1!0 \
            --field="
Test button duration. 1 to 20 seconds.:
:NUM" \
            "${CfgArr[CFG_TEST_SECONDS_NDX]}"!1..20!1!0 \
            --field="Watch external monitor plugging / power switching:CHK" \
            "${CfgArr[CFG_DBUS_MONITOR_NDX]}" \
                     > "$res1" &

        # Monitor 1 notebook page
        BuildMonitorPage "$CFG_MON1_NDX"
        yad --plug=$KEY --tabnum=2 --form \
            "${aMonPage[@]}" \
            > "$res2" &

        # Monitor 2 notebook page
        BuildMonitorPage "$CFG_MON2_NDX"
        yad --plug=$KEY --tabnum=3 --form \
            "${aMonPage[@]}" \
            > "$res3" &

        # Monitor 3 notebook page
        BuildMonitorPage "$CFG_MON3_NDX"
        yad --plug=$KEY --tabnum=4 --form \
            "${aMonPage[@]}" \
            > "$res4" &

        Indent="                        "
        # Sun times
        yad --plug=$KEY --tabnum=5 --form \
            --field="
Although sunrise and sunset times are automatically 
retrieved from internet, you can enter them here.

Do this if you don't have internet access or don't
want to use the internet for getting sun times.
Another example is when curtains closed for movie
watching or extremely dark storm clouds are out at
3:00 pm. In this case set sunset time to 2:00 pm
and your monitors will instantly dim for nightttime
settings when you click <b><i>Save</i></b> button.

Tomorrow sun times are automatically retrieved via
internet (if country/city provided) and changes 
made here are reset. Sun times are in AM/PM format 
not 24 hour clock. 12 AM is before 1 AM and 12 PM
is before 1 PM.:LBL" "" \
            --field="$Indent Sunrise setting::RO" \
            "$NetSunrise" \
            --field="$Indent Sunset setting::RO" \
            "$NetSunset" \
            --field="$Indent Sunrise Hour 1-12::NUM" \
            "$SunriseHour"!1..12!1!0 \
            --field="$Indent Sunrise Minute 0-59:    :NUM" \
            "$SunriseMinute"!0..59!1!0 \
            --field="$Indent Sunset Hour 1-12::NUM" \
            "$SunsetHour"!1..12!1!0 \
            --field="$Indent Sunset Minute 0-59::NUM" \
            "$SunsetMinute"!0..59!1!0 \
                     > "$res5" &

        # run main dialog that swallows tabs
        #  --image=gnome-calculator
        yad --notebook --key=$KEY --tab="General" --tab="Monitor 1" \
            --tab="Monitor 2" --tab="Monitor 3" --tab="Sun times" \
            --image=sleep --image-on-top "$GEOMETRY" \
            --title="eyesome setup" --width=400 \
            --text="<big><b>eyesome</b></big> - edit configuration" \
            --button="_Save:$ButnSave" \
            --button="_Cancel:$ButnQuit" \
            2>/dev/null

        Retn="$?"

        [[ $Retn == "$ButnSave" ]] && break        # Save changes

        UnPauseMonitors
        return      # Quit button, Escape Key, Alt-F4, X close window

    done

    # Save configuration
    truncate -s -1 "$res1"  # Remove new line at EOF
    cat "$res1" >  "$ConfigFilename"
    AddEmptyFields 4        # Extra fields for future use
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

    # Save sunrise/sunset files
    local Arr
    IFS='|' read -ra Arr < "$res5"

    # Skip over Arr[0]=empty, Arr[1]=Sunrise time, Arr[2]=Sunset time
    NetSunrise=$(date -d "${Arr[3]%%.*}:${Arr[4]%%.*} am" +"%I:%M %P")
    NetSunset=$(date -d "${Arr[5]%%.*}:${Arr[6]%%.*} pm" +"%I:%M %P")

    # Don't allow invalid times (date function returns zero length variable)
    [[ "${#NetSunrise}" == 0 ]] && Netsunrise="7:00 am"
    [[ "${#NetSunset}"  == 0 ]] &&  Netsunset="9:00 pm"

    echo "$NetSunrise" > "$SunriseFilename"     # Save Sunrise time
    echo "$NetSunset"  > "$SunsetFilename"      # Save Sunset time

    # We do NOT want to unpause monitors because we will override the
    # Enabled/Disabled settings the user just saved!
    # UnPauseMonitors

} # EditConfiguration

MainMenu () {

    ReadConfiguration
    
    SecondsToUpdate=$("$WakeEyesome" post eyesome-cfg.sh nosleep remain)

    # Blowout protection blank, 0 or negative (bug)
    if [[ $SecondsToUpdate == "" ]] || [[ $SecondsToUpdate == 0 ]] \
        || [[ $SecondsToUpdate == -* ]] ; then
        log "Seconds to update invalid value: $SecondsToUpdate"
        SecondsToUpdate="${CfgArr[$CFG_SLEEP_NDX]%.*}"
    fi

    # May 9, 2021 Use epcoh seconds to correct error:
    #    date: invalid date ‘So 9. Mai 07:32:52 MDT 2021’
    NextDate=$(date --date="$SecondsToUpdate seconds" +%s) # Sleep seconds Epoch

    # Germany has 24 hour clock: https://stackoverflow.com/a/60335820/6929343
    # So am/pm will be blank so: Last: 08:00:00 AM / Next: 07:00:00 PM
    #                   becomes: Last: 08:00:00    / Next: 07:00:00
    var=$(date +'%I:%M:%S %p')              # Create test date
    var="${var%"${var##*[![:space:]]}"}"    # Remove trailing space(s)
    if [[ "${#var}" -gt 8 ]] ; then
        # Test date longer than 8 then AM/PM is supported use 12 hour clock
        NextCheckTime=$(date --date=@"$NextDate" +'%I:%M:%S %p') # Now + Sleep
        LastCheckTime=$(date +'%I:%M:%S %p') # Now
    else
        # Test date <= 8 then AM/PM is NOT supported use 24 hour clock
        NextCheckTime=$(date --date=@"$NextDate" +'%H:%M:%S') # Now + Sleep
        LastCheckTime=$(date +'%H:%M:%S') # Now
    fi

    # Getting dozens of Green Beakers (yad icons) in taskbar when left running
    # and auto updating every 15 seconds. Use --skip-taskbar
    Result=$(yad  --form --skip-taskbar "$GEOMETRY" \
        --image=preferences-desktop-screensaver \
        --window-icon=preferences-desktop-screensaver \
        --margins=10 \
        --title="eyesome setup" \
        --text="<big><b>eyesome</b></big> - main menu" \
        --timeout="$SecondsToUpdate" --timeout-indicator=top \
        --field="Eyesome daemon sleep time checked at::RO" \
        --field="Seconds until eyesome daemon wakes::RO" \
        --field="The next time eyesome daemon wakes::RO" \
        --field="

This window refreshes when eyesome daemon wakes up to check
your monitor(s) brightness.

Click the <b><i>Remaining</i></b> button below to update how many seconds
remain until brightness is checked by eyesome daemon.

Click the <b><i>Edit</i></b> button below to change the brighness and/or
gamma monitor levels for Daytime and Nighttime. There you
can also change your city name used to obtain sunrise and
sunset times daily from the internet.

After using <b><i>Edit</i></b>, tests are done to ensure sunrise time was
recently updated. Also to ensure eyesome daemon is running.

Click the <b><i>Daytime</i></b> button below for a $TestSeconds second test of what
the monitors will look like in daytime. The same $TestSeconds second
test can be used for nighttime using the <b><i>Nighttime</i></b> button.

Click the <b><i>Override</i></b> button below to pause eyesome daemon.
A color temperature slider can be used to calculate red,
green and blue gamma channels. Gamma in turn can be
applied to the configuration for any monitor.

Click the <b><i>Quit</i></b> button to close this program.

:LBL" \
        --button="_Remaining:$ButnRemaining" \
        --button="_Edit:$ButnEdit" \
        --button="_Daytime:$ButnDay"  \
        --button="_Nighttime:$ButnNight" \
        --button="_Override:$ButnOverride" \
        --button="_Quit:$ButnQuit" \
        "$LastCheckTime" "$SecondsToUpdate" "$NextCheckTime" 2>/dev/null)

    Retn="$?"
    
} # MainMenu

TestBrightness () {

    # $1 = Day or Ngt for short test
    # $1 = Gam for gamma preview applied to all monitors

    SetBrightness "$1"      # SetBrightnes function also used by eyesome.sh

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

    local TitleString
    if [[ $1 == "Gam" ]] ; then
        TitleString="eyesome Color Temperature Preview"
    else
        TitleString="eyesome Monitor Brightness Test"
    fi

    done | yad --progress       --auto-close \
        --title="$TitleString" \
        --enable-log "$TestSeconds second time progress" \
        --width=400             --height=550 \
        --log-expanded          --log-height=400 \
        --log-on-top            --percentage=0 \
        --no-cancel             --center \
        --bar=RTL               2>/dev/nul
    
    $WakeEyesome post eyesome-cfg.sh nosleep # $4 remaining sec not used

} # TestBrightness


math () {

    # Written for: https://askubuntu.com/a/1241983/307523 and eyesomed-cfg.sh

    [[ $2 != "=" ]] && { echo "Second parm must be '='"; return 1; }

    # Declare mathres as reference to argument 1 provided (Bash 4.3 or greater)
    declare -n mathres=$1

    math_op="$4"    # '*' as parameter changes operator to 'aptfielout' and
                    # operand2 to 'aptfilein' so force 'x' instead.

    case "$math_op" in
        x | \- | \/ | \+ | % ) # echo "Good"
            ;;
        *)
            echo "Invalid: $1 $2 $3 $4 $5 (For mutiplication use 'x' not '*')"
            echo 'Usage: math c = $a operator $b'
            echo 'Where operator is: "+", "-", "/", or "x" (without quotes)'
            ;;
    esac
   
    [[ $math_op == "x" ]] && math_op="*"

    mathres=$(awk "BEGIN { print ($3 $math_op $5) }")

} # math

adjust_channel () {

    local last_temp current multiplier
    local added subtracted

    last_val="$2"
    current="$3"
    multiplier="$4"

    # Declare mathres as reference to argument 1 provided (Bash 4.3 or greater)
    declare -n retn="$1"

    if [[ $current > "$last_val" ]]; then
        # normal increasing values
        math added = "$current" - "$last_val"
        math added = "$added" x "$multiplier"
        math retn = "$last_val" + "$added"
    else
        # decreasing values
        math subtracted = "$last_val" - "$current"
        math subtracted = "$subtracted" x "$multiplier"
        math retn = "$last_val" - "$subtracted"
    fi

} # adjust_channel

TempToGamma () {

    # May 18, 2020 - Python code from mmm's temp_to_gamma (srch_temp) function
    # Convert Temp to Gamma (Xrandr Inverted or REAL Gamma returned)

    local srch_temp i red green blue temp
    local last_red last_green last_blue last_temp
    local full_gap multiplier r g b Retn
    
    # global variables set are Red, Green, Blue

    # Override breaking values
    srch_temp="$1"
    [[ $srch_temp -lt 1000 ]] && srch_temp=1000
    [[ $srch_temp -gt 10000 ]] && srch_temp=10000

    # Get array entries before and after search temperature
    for ((i=0; i<"${#GammaRampArr[@]}"; i=i+GRA_ENT_LEN)); do
        red="${GammaRampArr[i+GRA_RED_OFF]}"
        green="${GammaRampArr[i+GRA_GRN_OFF]}"
        blue="${GammaRampArr[i+GRA_BLU_OFF]}"
        temp="${GammaRampArr[i+GRA_TMP_OFF]}"
        [[ $srch_temp -lt "$temp" ]] && break
        last_red="$red"
        last_green="$green"
        last_blue="$blue"
        last_temp="$temp"
    done

    # Calculate percentange (multiplier) search temperature between entries
    math full_gap = "$temp" - "$last_temp"
    math multiplier = "$srch_temp" - "$last_temp"
    math multiplier = "$multiplier" / "$full_gap"
    adjust_channel r "$last_red" "$red" "$multiplier"
    adjust_channel g "$last_green" "$green" "$multiplier"
    adjust_channel b "$last_blue" "$blue" "$multiplier"

    # Deviation from mmm old line returned concatenated string for xrandr:
    # return (str(round(r,2)) + ":" + str(round(g,2)) + ":" + str(round(b,2)))
    # Here though we simply set global variables Red, Greeen, Blue 

    Red="$r"
    Green="$g"
    Blue="$b"
    xRed=$(printf '%.*f\n' 2 "$Red")
    xGreen=$(printf '%.*f\n' 2 "$Green")
    xBlue=$(printf '%.*f\n' 2 "$Blue")
    XrandrGammaString="$xRed:$xGreen:$xBlue"

} # TempToGamma

GammaToTemp() {

    # Based on gamma_to_temp(srch_gamma) from mmm Python Program
    # Convert Gamma to Temp (normal and NOT Xrandr Inverted Gamma passed)
    
    # Returns $Temperature already defined globally
    # Requires $Red $Green and $Blue passed as $1 $2 $3

    local srch_red srch_green srch_blue i red green blue temp
    local last_red last_green last_blue last_temp
    local cutoff full_gap multiplier r g b

    srch_red="$1"
    srch_green="$2"
    srch_blue="$3"    

    # Override breaking values
    [[ $srch_red > "1.0" ]] && srch_red=1.0
    [[ $srch_green > "1.0" ]] && srch_green=1.0
    [[ $srch_blue > "1.0" ]] && srch_blue=1.0

    # Get array entries before and after search colors
    cutoff=$(( ${#GammaRampArr[@]} - ($GRA_ENT_LEN * 2) ))
    for ((i=0; i<"${#GammaRampArr[@]}"; i=i+GRA_ENT_LEN)); do

        red="${GammaRampArr[i+GRA_RED_OFF]}"
        green="${GammaRampArr[i+GRA_GRN_OFF]}"
        blue="${GammaRampArr[i+GRA_BLU_OFF]}"
        temp="${GammaRampArr[i+GRA_TMP_OFF]}"

        if [[ $srch_red == 1.0* ]] && [[ $blue == 0.0* ]] ; then
            # Temperature is 1000K to 2000K
            # Test srch_green <= green
            if [[ "$green" > "$srch_green" ]] && [[ $i -ne 0 ]] ; then
                #  red static at 1 and blue static at 0 whilst green increasing
                math full_gap = "$green" - "$last_green"
                math multiplier = "$srch_green" - "$last_green"
                math multiplier = "$multiplier" / "$full_gap"
                break
            fi

        elif [[ $srch_red == 1.0* ]] && [[ $blue != 0.0* ]] ; then
            # Temperature is 2001K to 6499K
            # Test srch_blue <= blue
            if [[ "$blue" > "$srch_blue" ]] ; then
                #  red static at 1 whilst green and blue are increasing
                math full_gap = "$blue" - "$last_blue"
                math multiplier = "$srch_blue" - "$last_blue"
                math multiplier = "$multiplier" / "$full_gap"
                break
            fi

        else
            # Temperature is over 6499K and cannot be last index 10500 K
            # Test srch_red >= red
            if [[ "$red" < "$srch_red" ]] ; then
                # blue static at 1.0 whilst red and green are decreasing
                math full_gap = "$last_red" - "$red"
                math multiplier = "$last_red" - "$srch_red"
                math multiplier = "$multiplier" / "$full_gap"
                break
            fi
        fi

        [[ $i -ge "$cutoff" ]] && { Temperature="$temp" ; return ; }

        last_red="$red"
        last_green="$green"
        last_blue="$blue"
        last_temp="$temp"
    done

    Temperature=500.0
    math Temperature = "$Temperature" x "$multiplier"
    math Temperature = "$Temperature" + "$last_temp"
    Temperature=$(printf "%.0f" "$Temperature")

} # GammaToTemp

ColorTemperature () {

    ButnConvert=10
    [[ $Temperature == "$EmptyString" ]] && Temperature=6500

    Result=$(yad  --scale --mouse \
        --image=preferences-desktop-screensaver \
        --window-icon=preferences-desktop-screensaver \
        --value="$Temperature" --step=100 \
        --min-value=1000  --max-value=10000 \
        --mark=Night:3500 --mark=Day:6500 \
        --margins=10 \
        --title="eyesome color convertor" \
        --text="
<big><b>eyesome</b></big> - Convert color temperature to gamma  

Recommended nighttime color is 3500 K (Kelvins).
Recommended daytime color is 6500 K." \
        --button="_Convert:$ButnConvert" \
        --button="_Quit:$ButnQuit" \
        2>/dev/null)

    Retn="$?"

    if [[ $Retn == "$ButnConvert" ]] ; then
        Temperature="$Result"
        TempToGamma "$Temperature"
        return 0
    fi
    return 1

} # ColorTemperature

PauseMonitors () {

    # Code lifted from movie.sh update on May 18, 2020.
    # Get current monitor status to restore when exiting.
    sMon1Status=$(grep -oP '(?<=\|1\|).*?(?=\|)' "$ConfigFilename")
    sMon2Status=$(grep -oP '(?<=\|2\|).*?(?=\|)' "$ConfigFilename")
    sMon3Status=$(grep -oP '(?<=\|3\|).*?(?=\|)' "$ConfigFilename")
    # Change each Enabled monitor status to Paused.
    [[ $sMon1Status == Enabled ]] && \
        sed -i "s/|1|$sMon1Status|/|1|Paused|/g" "$ConfigFilename"
    [[ $sMon2Status == Enabled ]] && \
        sed -i "s/|2|$sMon2Status|/|2|Paused|/g" "$ConfigFilename"
    [[ $sMon3Status == Enabled ]] && \
        sed -i "s/|3|$sMon3Status|/|3|Paused|/g" "$ConfigFilename"

} # PauseMonitors

UnPauseMonitors () {

    # Restore each paused monitor status to enabled setting.
    sed -i "s/|1|Paused|/|1|Enabled|/g" "$ConfigFilename"
    sed -i "s/|2|Paused|/|2|Enabled|/g" "$ConfigFilename"
    sed -i "s/|3|Paused|/|3|Enabled|/g" "$ConfigFilename"

} # UnPauseMonitors

ErrMsg () {
    # Parmater 1 = message to display

    yad --image "dialog-error" --title "eyesome - Logical Error" \
        --mouse --button=gtk-ok:0 --text "$1" 2>/dev/null

 
} # ErrMsg

InfoMsg () {
    # Parmater 1 = message to display

    yad --image "dialog-information" --title "eyesome - Information" \
        --mouse --button=gtk-ok:0 --text "$1" 2>/dev/null
 
} # InfoMsg

ConfirmUpdate () {

    local ButnUpdate
    ButnUpdate=10

    yad --image "gtk-dialog-question" --title "eyesome - Confirm Update" \
        --text="<big><b>eyesome</b></big> - Apply changes to configuration


Are you sure you want to permenantly apply Monitor $OverrideMonitor - $OverrideDayNight
gamma settings ('$XrandrGammaString') to eyesome's configuration file?   " \
        --mouse \
        --button="_Update settings:$ButnUpdate" \
        --button="_Cancel update:$ButnQuit" \
        2>/dev/null

    [[ "$?" != "$ButnUpdate" ]] && return 1

    return 0

} # ConfirmUpdate


OverrideHelp () {

    # Parent window stays active and this function is called in sub-shell.
    # Parent variables are not visible here unless they are exported.
    Tip="Use Escape key, Alt+F4 or click X in top window coner to close."
    yad --form --mouse \
        --image=preferences-desktop-screensaver \
        --window-icon=preferences-desktop-screensaver \
        --margins=10 \
        --title="eyesome Override Help" \
        --text="<big><b>eyesome</b></big> - Override Help" \
        --field="

You can now manually reset brightness or tint for monitor(s). Eyesome daemon   
has been paused and will not change monitor(s) until Override window is closed.

Click the <b><i>Get</i></b> button to get the Day or Night settings for a monitor
into memory.

Click the <b><i>Color</i></b> button to pop up a window for converting color temperature 
to gamma channels of Red, Green and Blue. The gamma channels can be used
with xrandr to control screen color temperature (also called tint):

   xrandr --output <b>Monitor_Name</b> --brigthness <b>0.85</b> --gamma <b>Red:Green:Blue</b>     

Substitute <b>bold fields</b> above with desired values:

   <b>Monitor_Name</b> = Xrandr monitor name, e.g. 'eDP-1'.

   <b>0.85</b>                       = Set brightness to 0.85 which is 85%.
                                     If ommitted 1.0 brightness (100%) is used.   

   <b>Red:Green:Blue</b> = Xrandr gamma string e.g. '1.00:0.94:0:89'.

The starting color value will be 6500 K (daytime) unless <b><i>Get</i></b> button was
used to get a given monitor's day or night settings into memory.

Click the <b><i>Preview</i></b> button to test what ALL monitors look like with the color
temperature in memory.

Click the <b><i>Apply</i></b> button to change Daytime or Nighttime setting for the  
SINGLE monitor in memory using the current Color Temperature set with <b><i>Color</i></b>  
button. This permanently updates eyesome's configuration file.

<b>NOTE:</b> The 'xrandr --gamma string' appears as an input field but it is not. The 
string can be copied into the clipboard and pasted into the terminal.
:LBL" \
        --field="<b>Tip:</b> $Tip:RO" " " \
        --button="_Back:$ButnQuit" \
        2>/dev/null

    # At least one Read Only (:RO) field is needed or window goes super large

} # OverrideHelp
export -f OverrideHelp      # Make available to OVerride functions Help button

Override () {

    local ButnGet ButnColor ButnPreview ButnApply aMonNdx Result Arr
    local EmptyString cbMonitor cbDayNight Retn

    ButnGet=10
    ButnColor=20
    ButnPreview=30
    ButnApply=40

    EmptyString="Nothing in memory."

    # Define global fields
    Temperature="$EmptyString"
    Red="$EmptyString"
    Green="$EmptyString"
    Blue="$EmptyString"
    XrandrGammaString="1.00:1.00:1.00"
    # MonNdx must be global for ConfirmUpdate function
    MonNdx="$EmptyString"

    # Monitor number (1-3) to monitor index in Cfg Arr
    aMonNdx=( $CFG_MON1_NDX $CFG_MON2_NDX $CFG_MON3_NDX )
    MonName="$EmptyString"            # "Laptop Display" / '50" Sony TV'
    MonHardwareName="$EmptyString"    # "intel_backlight" / "xrandr"
    MonXrandrName="$EmptyString"      # "eDP-1-1" (primary) / "HDMI-0", etc

    InitXrandrArray # Run $(xrandr --verbose --current) to build array

    # If eyesome daemon wakes it won't change our monitors whilst paused
    PauseMonitors

    # Global Monitor number and time kept in memory between Override buttons
    OverrideMonitor="1"
    OverrideDayNight="Night"

    while true ; do

        # Build monitor number and Day/Night Choice Boxes for yad
        cbMonitor="1!2!3"
        cbMonitor="${cbMonitor/$OverrideMonitor/\^$OverrideMonitor}"
        cbDayNight="Day!Night"
        cbDayNight="${cbDayNight/$OverrideDayNight/\^$OverrideDayNight}"
        # Set default highlighted time (denoted by ^)

        Result=$(yad --form "$GEOMETRY" \
            --image=preferences-desktop-screensaver \
            --window-icon=preferences-desktop-screensaver \
            --margins=10 \
            --title="eyesome Override" \
            --text="
<big><b>eyesome</b></big> - Override (Pause eyesome daemon)   " \
            --field="Monitor Number::CB" \
                    "$cbMonitor" \
            --field="Day or Night::CB" \
                    "$cbDayNight" \
            --field="Monitor Name::RO" "$MonName" \
            --field="Internal Name::RO" "$MonHardwareName" \
            --field="Xrandr Plug Name::RO" "$MonXrandrName" \
            --field="Color temperature::RO" "$Temperature" \
            --field="Red gamma channel::RO" "$Red" \
            --field="Green gamma channel::RO" "$Green" \
            --field="Blue gamma channel::RO" "$Blue" \
            --field="_Help using this window:FBTN" \
                    'bash -c "OverrideHelp"'  \
            --field="xrandr --gamma string:" "$XrandrGammaString" \
            --button="_Get:$ButnGet" \
            --button="_Color:$ButnColor" \
            --button="_Preview:$ButnPreview" \
            --button="_Apply:$ButnApply" \
            --button="_Back:$ButnQuit" \
            2>/dev/null)

        Retn="$?"       # Button return value, 254 = Escape or Alt+F4

        # Convert Yad result string into an array
        IFS='|' read -r -a Arr <<< "$Result"    # Result string has | delimiters
        OverrideMonitor="${Arr[0]}"             # Extract Monitor Number
        OverrideDayNight="${Arr[1]}"            # Extract Day or Night
        MonNdx="${aMonNdx[$(($OverrideMonitor - 1))]}"

        [[ $Retn == "$ButnQuit" || $Retn == "$ButnEscape" ]] && break

        if [[ $Retn == "$ButnColor" ]] ; then
            ColorTemperature || continue
            Red=$(printf '%.*f\n' 2 "$Red")
            Green=$(printf '%.*f\n' 2 "$Green")
            Blue=$(printf '%.*f\n' 2 "$Blue")
            XrandrGammaString="$Red:$Green:$Blue"

        elif [[ $Retn == "$ButnPreview" ]] ; then
            [[ $Red == "$EmptyString" ]] && { \
                ErrMsg "\n\n\nGamma must be in memory before 'Preview'.   " ;
                continue ; }

            UnPauseMonitors
            TestBrightness Gam
            PauseMonitors

        elif [[ $Retn == "$ButnGet" ]] ; then
            # Set OverrideMonitor and OverrideDayNight fields
            # Read values from CfgArr into work fields for:
            #   - Brightness (not used yet), Red, Green & Blue.
            # Then calculate approximate Temperature from RGB
            GetMonitorWorkSpace "$MonNdx"
            if [[ $OverrideDayNight == Day ]] ; then
                Red=$(printf '%.*f\n' 2 "$MonDayRed")
                Green=$(printf '%.*f\n' 2 "$MonDayGreen")
                Blue=$(printf '%.*f\n' 2 "$MonDayBlue")
            else
                Red=$(printf '%.*f\n' 2 "$MonNgtRed")
                Green=$(printf '%.*f\n' 2 "$MonNgtGreen")
                Blue=$(printf '%.*f\n' 2 "$MonNgtBlue")
            fi
            XrandrGammaString="$Red:$Green:$Blue"
            GammaToTemp "$Red" "$Green" "$Blue"

        elif [[ $Retn == "$ButnApply" ]] ; then
            # Apply current gamma settings to selected monitor and time of day.
            [[ $MonName == "$EmptyString" ]] && { \
                ErrMsg "\n\n\nYou must 'Get' a monitor into memory first.   " ;
                continue ; }

            ConfirmUpdate || continue

            # Update configuration file
            UnPauseMonitors
            ReadConfiguration
            GetMonitorWorkSpace "$MonNdx"

            if [[ $OverrideDayNight == Day ]] ; then
                # Yad uses 6 decimal places internally
                MonDayRed=$(printf '%.*f\n' 6 "$Red")
                MonDayGreen=$(printf '%.*f\n' 6 "$Green")
                MonDayBlue=$(printf '%.*f\n' 6 "$Blue")
            else
                MonNgtRed=$(printf '%.*f\n' 6 "$Red")
                MonNgtGreen=$(printf '%.*f\n' 6 "$Green")
                MonNgtBlue=$(printf '%.*f\n' 6 "$Blue")
            fi

            SetMonitorWorkSpace "$MonNdx"
            WriteConfiguration
            PauseMonitors
            local Msg
            Msg="\n\n\nGamma settings have been updated for monitor:"
            Msg="$Msg $OverrideMonitor - $OverrideDayNight   "
            InfoMsg "$Msg"

        else
            ErrMsg "eyesome - Override function - unknown button: $Retn"
        fi

    done

    # Allow eyesome daemon to control monitors when he wakes
    UnPauseMonitors

} # Override

CheckSunHours () {

    [[ $fSunHoursCheckedOnce == true ]] && return
    fSunHoursCheckedOnce=true

    local Retn ButnRetrieve=10

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

        Result=$(yad --form "$GEOMETRY" \
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

    local Retn ButnStart=10

    while true ; do

        # Does process tree contain "eyesome.sh"?
        pID=$(pstree -g -p | grep "${EyesomeDaemon##*/}")

        [[ $pID != "" ]] && return 0    # .../eyesome.sh daemon is running

        # If you run program to strip trailing spaces add 3 after "will run"    
        Result=$(yad  --form "$GEOMETRY" \
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
            ("$EyesomeDaemon" &) &          # start deamon as background task
            sleep .5                        # .5 to allow daemon to sleep
        else
            return 1                        # Quit
        fi
        
    done
    
} # CheckEyesomeDaemon

###################################
#            MAINLINE             #
###################################

Retn=""         # Define globally. Old bug encountered July 6, 2020.

Main () {

    # ReadConfiguration # This is already done somewhere, but where?

    ButnRemaining=10
    ButnEdit=20
    ButnDay=30
    ButnNight=40
    ButnOverride=50
    ButnQuit=60
    ButnEscape=252  # Also used by 'X' Window Close and Alt-F4

    while true ; do

        # Give eyesome.sh daemon time to wakeup & sleep before menu repaints.
        # If time is not long enough main menu will repaint twice after Update
        # Interval followed by deamon's long sleep cycle.
        sleep .5

        MainMenu

        if [[ $Retn == "$ButnEscape" || $Retn == "$ButnQuit" ]] ; then
            # At this point clicked Quit button or Escape or Window X'd.
            break
        elif [[ $Retn == "$ButnEdit" ]] ; then
            EditConfiguration
            CheckSunHours
            CheckEyesomeDaemon
            # monitor changes were paused, so wake up eyesome
            $WakeEyesome post eyesome-cfg.sh nosleep
        elif [[ $Retn == "$ButnDay" ]] ; then
            TestBrightness Day
        elif [[ $Retn == "$ButnNight" ]] ; then
            TestBrightness Ngt
            # TODO: Last brightness/gamma isn't reset after nighttime test
            # Jun 13 2020: Don't know what above means can't find problem today
        elif [[ $Retn == "$ButnOverride" ]] ; then
            Override
            # monitor changes were paused, so wake up eyesome
            $WakeEyesome post eyesome-cfg.sh nosleep
        elif [[ $Retn == "$ButnRemaining" || $Retn == "70" ]] ; then
            continue    # 70 = menu times out when eyesome daemon wakes
        else
            continue    # Not reachable
        fi

    done

    # End program
    Cleanup
    exit 0

} # Main

Main "$@"
