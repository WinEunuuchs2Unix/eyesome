#!/bin/sh

# NAME: acpi-lid-eyesome.sh
# PATH: /etc/acpi
# DESC: Restart eyesome.sh when lid opened or closed.
# CALL: Automatically called by acpi when laptop lid is opened or closed.
# DATE: September 21, 2018.

logger "$0: Laptop lid opened or closed"
/usr/local/bin/wake-eyesome.sh post LidOpenClose nosleep

exit 0
