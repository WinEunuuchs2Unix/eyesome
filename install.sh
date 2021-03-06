#!/bin/bash

# NAME: install.sh
# PATH: Current directory where files downloaded from github
# DESC: Copy eyesome scripts / command files to target directories
# DATE: September 21, 2018. Modified: June 3, 2020.

# PARM: $1=dev developer mode, publish files
#         =rm  remove files
#         =v   verify files (again)

# UPDT: Jun 02 2020 - Default sunrise "7:00 am" and sunset "9:00 pm" files.
#       Add option to install 'bc'. Correct typos.

#       Jun 03 2020 - Don't automatically copy default sunrise and sunset
#       files but leave them in installation directory if user wants to
#       manually copy them.

#       Jun 13 2020 - Use cp -a to keep same file date and time.

CopyFiles () {

    echo 
    echo Installing eyesome programs...
    echo 
    install -v ./eyesome.sh             /usr/local/bin/
    install -v ./eyesome-cfg.sh         /usr/local/bin/
    install -v ./eyesome-src.sh         /usr/local/bin/
    install -v ./eyesome-sun.sh         /usr/local/bin/
    install -v ./wake-eyesome.sh        /usr/local/bin/
    install -v ./eyesome-dbus.sh        /usr/local/bin/
    # June 3, 2020 intentionally omit /usr/local/bin/.eyesome-sunrise (& set)
    # cp      -v ./.eyesome-sunrise       /usr/local/bin/
    # cp      -v ./.eyesome-sunset        /usr/local/bin/
    cp      -v ./start-eyesome          /etc/cron.d/
    install -v ./daily-eyesome-sun      /etc/cron.daily/
    install -v ./systemd-wake-eyesome   /lib/systemd/system-sleep/
    install -v ./acpi-lid-eyesome.sh    /etc/acpi/
    cp      -v ./acpi-lid-event-eyesome /etc/acpi/events/

} # CopyFiles

RemoveFiles () {

    echo 
    echo Removing eyesome programs...
    echo 

    rm -v -f /usr/local/bin/eyesome.sh
    rm -v -f /usr/local/bin/eyesome-cfg.sh
    rm -v -f /usr/local/bin/eyesome-src.sh
    rm -v -f /usr/local/bin/eyesome-sun.sh
    rm -v -f /usr/local/bin/wake-eyesome.sh
    rm -v -f /usr/local/bin/eyesome-dbus.sh
    rm -v -f /etc/cron.d/start-eyesome
    rm -v -f /etc/cron.daily/daily-eyesome-sun
    rm -v -f /lib/systemd/system-sleep/systemd-wake-eyesome
    rm -v -f /etc/acpi/acpi-lid-eyesome.sh
    rm -v -f /etc/acpi/events/acpi-lid-event-eyesome

    echo 
    echo All eyesome programs have been removed, except data files:
    echo 
    echo     /usr/local/bin/.eyesome-cfg
    echo     /usr/local/bin/.eyesome-sunrise
    echo     /usr/local/bin/.eyesome-sunset
    echo
    echo This script you are running 'install.sh' has not been removed.
    exit 0
    
} # RemoveFiles

VerifyFiles () {

    md5sum -c eyesome.md5

    exit 0
    
} # VerifyFiles

PublishFiles () {

    mkdir -p ~/eyesome
    cd  ~/eyesome

    cp -a -v "$0" .                        # This script install.sh
    cp -a -v /usr/local/bin/eyesome.sh .
    cp -a -v /usr/local/bin/eyesome-cfg.sh .
    cp -a -v /usr/local/bin/eyesome-src.sh .
    cp -a -v /usr/local/bin/eyesome-sun.sh .
    cp -a -v /usr/local/bin/wake-eyesome.sh .
    cp -a -v /usr/local/bin/eyesome-dbus.sh .
    # June 2, 2020 intentionally omit /usr/local/bin/.eyesome-sunrise (& set)
    cp -a -v /etc/cron.d/start-eyesome .
    cp -a -v /etc/cron.daily/daily-eyesome-sun .
    cp -a -v /lib/systemd/system-sleep/systemd-wake-eyesome .
    cp -a -v /etc/acpi/acpi-lid-eyesome.sh .
    cp -a -v /etc/acpi/events/acpi-lid-event-eyesome .

    md5sum \
        install.sh \
        eyesome.sh \
        eyesome-cfg.sh \
        eyesome-src.sh \
        eyesome-sun.sh \
        wake-eyesome.sh \
        eyesome-dbus.sh \
        .eyesome-sunrise \
        .eyesome-sunset \
        start-eyesome \
        daily-eyesome-sun \
        systemd-wake-eyesome \
        acpi-lid-eyesome.sh \
        acpi-lid-event-eyesome \
        > eyesome.md5

    echo
    echo "~/eyesome/eyesome.md5 has been created."
    
    exit 0
    
} # PublishFiles

Help () {

    echo " \
        
Eyesome will control up to three monitors including hardware laptop display.
Each day sunrise and sunset times are automatically retrieved for your city.
Configure Daytime and Nighttime brightness and gamma levels for your monitors.
Configure the transition duration after sunrise and before sunset to gradually
adjust brightness and gamma levels so changes are not noticable.

This is the main install/removal/verification program. Your options are:

   sudo ./install.sh
   sudo ./install.sh v
   sudo ./install.sh rm

Use 'v' parameter to verify files were downloaded correctly.
Use 'rm' parameter to remove a previous installation.  Data files remain.
In the first instance with no parameter passed, eyesome is installed.
After installation configure eyesome by running 'sudo eyesome-cfg.sh'.
"
    exit 0
        
} # Help

Main () {

    [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] && Help    # Exits
    
    if [ $(id -u) != 0 ]; then # root powers needed to call this script
        echo >&2 $0 must be called with sudo powers
        exit 1
    fi
    
    [[ "$1" == "dev" ]] && PublishFiles # exits
    
    [[ "$1" == "v" ]] && VerifyFiles    # exits
    
    [[ "$1" == "rm" ]] && RemoveFiles   # exits

    [[ "$1" != "" ]] && Help            # exits
       
    if [[ $(command -v yad) == "" ]]; then
        echo " \

'yad' package is required for eyesome but it is not installed.
Do you wish to install it now? 

Enter [y/Y], any other key to skip installation: "
        read -rsn1 input
        echo $input
        if [[ $input == y ]] || [[ $input == Y ]] ; then
            sudo apt install yad
        fi
    fi

    if [[ $(command -v bc) == "" ]]; then
        echo " \

'bc' package is required for eyesome but it is not installed.
Do you wish to install it now? 

Enter [y/Y], any other key to skip installation: "
        read -rsn1 input
        echo $input
        if [[ $input == y ]] || [[ $input == Y ]] ; then
            sudo apt install bc
        fi
    fi
    
    CopyFiles
    
    echo
    echo Eyesome has been installed. Use 'sudo eyesome-cfg.sh' to configure it.

    exit 0
    
} # Main

Main "$@"
