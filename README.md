# eyesome

Eyesome will control up to three monitors including hardware laptop display.
Each day sunrise and sunset times are automatically retrievedfor your city.
Configure Daytime and Nighttime brightness and gamma levels for your monitors.
Configure the transition duration after sunrise and before sunset to gradually
adjust brightness and gamma levels so changes are not noticable.

## Prerequisites

Internet access is required to access https://www.timeanddate.com each day to
obtain your city's sunrise and sunset times.

`yad` GUI windowing is required to use `eyesome-cfg.sh`, the heart of eyesome.

For controlling external monitors, `xrandr` is required. `wayland` is not
supported. If you don't know what **Wayland** is then you are fine because
**Xrandr** has been primarily used for 35 years.

## Configuration

From your terminal run `sudo eyesome-cfg` which configures all your monitors 
and operates as a control center for:

- overriding your country/city name if eyesome didn't detect automatically
- overriding your hardware `/sys/class/*/brightness` directory if needed
- overriding your `xrandr` software names for external monitors if needed
- defining daytime and nightime brightness/gamma (color temperature)
- testing daytime and nighttime brightness/gamma (color temperature)
- setting transition period after sunrise to full monitor brighness
- setting transition period before sunset for reducing monitor brightness
- along with brightess, gamma can also be set (night light, redshift, etc.)
- setting how quickly brightness/gamma changes are made during transitions
- viewing the next interval brightess/gamma will be set
- viewing the last interval's setting of brightness/gamma per monitor
- overriding eyesome daemon to manually set brightness/gamma for a period
- input gamma with red, green, blue values or use a color temperature slider

For screen shots please see: https://askubuntu.com/a/887249/307523

## Automatic operations

When you boot your computer a script in `/etc/cron.d` is run to load the
eyesome daemon: `eyesome.sh`. This will run 24/7 and spend most of it's time
sleeping in the background to consume as little computer resources as possible.

When you suspend and resume your computer a script in `/etc/systemd/system-sleep` 
runs `wake-eyesome.sh` to instantly adjust your screen brightness.
This is useful if you suspend your laptop at full brightness during day
and then wake it up at night.

When your laptop lid is opened or closed the control file
`/etc/acpi/events/lid-event-eyesome` calls the script 
`/etc/acpi/acpi-lid-eyesome.sh`. This in turn calls `wake-eyesome.sh` to
reset brightness and gamma on all monitors. This is necessary because 
linux resets all monitors to full brightness `1.00` and full gamma `1.00`
using `xrandr` when the laptop lid is closed or opened.

Each morning the control file `/etc/cron.daily/daily-eyes-sun` calls the 
script `eyesome-sun.sh`.  This script obtain the current day's
sunrise and sunset times from https://www.timeanddate.com.

## Installation

1. Download the zip file and extract it using Archive Manager or another tool.

2. Open a terminal and change to the download directory. eg 
`cd ~/eyesome-MASTER`

3. Mark the file `install.sh` as executable with the command:

    `sudo chmod a+x install.sh`
    
4. Run the install program using:

    `sudo ./install.sh`
    
    If you don't have the program `yad` installed you will be prompted to install
    it. Proceed to install it by entering `y` or `Y`. It is needed in order to
    run eyesome's configuration program.
    
5. Configure your monitors using:

    `sudo eyesome-cfg.sh`
    
6. Note after saving configuration for the frist time you are prompted to 
update Sunrise and Sunset times as they haven't been initialized yet. You
are also prompted to start the eyesome dameon because you haven't rebooted
your computer yet. Go ahead and accept both these prompts. You should never
see them again after the first time configuration.

7. A new enhancement (June 3, 2020) are default sunrise and sunset files called:
`/usr/local/bin/.eyesome-sunrise` and `/usr/local/bin/.eyesome-sunset`.
After installation you will need to delee these for auto-configuration in
Step 6. to take place. Otherwise real suntimes won't be updated until the next
day. As was in original version, you can manually set the time for eyesome by 
updating these plain text files. Do this if you don't want the internet knowing
which city you are really in when you are using a VPN to hide your ISP's city.
The file format is simple and the defaults are "7:00 am" for sunrise and
"9:00 pm" for sunset. Use `cat /usr/local/bin/.eyesome-sun*` to see current
sunrise and sunset times. A future version will make this more user-friendly.
    
### Note:

You can also use `./isntall.sh -h` or `./install.sh --help` for help instructions.

You can use `sudo ./install.sh v` to verify MD5 hash checksums agree which means
your download is intact and secure.

You can use `sudo ./install.sh rm` to remove the eyesome programs. You can
install them again later and your configuration files will still be intact.

## Glitches

Every now and then (once a month?) your system may inexplicably invoke `xrandr`
and reset your system to 100% brightness and gamma (6500K color temperature). If 
this happens simply run `sudo eyesome-cfg.sh` and click the Daytimne or Nighttime
Test buttons. After the test eyesome is forced to wakeup and reset monitors to
the current time of day settings. Do the same if you intentionally change
settings in gnome-terminal or elsewhere and are ready to set them back to normal.

## Messages

To see eyesome daemon messages the eaiest way is with the terminal command:

    journalctl -b | grep eyesome

You will see this from when your computer boots:

    Oct 23 04:16:28 CRON[965]: (root) CMD (   /usr/local/bin/eyesome.sh)
    Oct 23 04:16:28 eyesome[998]: Daemon: Launching /usr/local/bin/eyesome-dbus.sh daemon
    Oct 23 04:16:28 eyesome[1014]: DBUS: Starting DBUS-Monitor using type=method_call, interface=org.freedesktop.ColorManager, path=/org/freedesktop/ColorManager, member=FindDeviceByProperty
    
You will see this from when you sign on (login):

    Oct 23 04:16:35 eyesome[2107]: DBUS: Event Count: 5 over: 7 seconds
    Oct 23 04:16:35 eyesome[2114]: DBUS: Waiting for user to log in, not waking up eyesome
    Oct 23 04:16:48 eyesome[2465]: Daemon: Waited 20 seconds for rick to login.
    Oct 23 04:16:53 eyesome[2908]: DBUS: Event Count: 27 over: 18 seconds
    Oct 23 04:16:53 eyesome[2917]: DBUS: rick logged in 5 seconds, not waking eyesome
    Oct 23 04:16:59 eyesome[4111]: Daemon: Login: Slept 2 seconds x 5 times.

You will see this when cron runs daily jobs:

    Oct 23 04:25:31 eyesome[2206]: Sun Times: https://www.timeanddate.com/sun/canada/edmonton.
    Oct 23 04:25:32 eyesome[2278]: Wakeup: Called from eyesome-sun.sh.

You will see this when you suspend your home laptop and head off to work:

    Oct 23 05:46:49 eyesome[26964]: Lid Open/Close: Wait 3 seconds to see if suspending
    Oct 23 05:46:50 eyesome[27017]: DBUS: Event Count: 27 over: 5397 seconds
    Oct 23 05:46:50 eyesome[27028]: Wakeup: Called from eyesome-dbus.sh.
    Oct 23 05:46:50 eyesome[27079]: Wakeup: DBUS: Waiting 3 seconds to see if supending
    Oct 23 05:46:52 eyesome[27170]: Lid Open/Close: DBUS responding, not waking eyesome
    Oct 23 05:47:04 eyesome[28119]: Daemon: Monitor connect: Slept 2 seconds x 5 times.
    Oct 23 05:47:04 eyesome[28122]: Daemon: Removed file: /tmp/eyesome-DBUS
    Oct 23 05:47:06 eyesome[28308]: Wakeup: Creating /tmp/eyesome-is-suspending

You will see this when you return home from work:

    Oct 23 16:55:11 eyesome[28511]: Lid Open/Close: Wait 3 seconds to see if suspending
    Oct 23 16:55:11 eyesome[28578]: Wakeup: Called from suspend.
    Oct 23 16:55:14 eyesome[28792]: DBUS: Event Count: 54 over: 40104 seconds
    Oct 23 16:55:14 eyesome[28798]: Wakeup: Called from eyesome-dbus.sh.
    Oct 23 16:55:14 eyesome[28804]: Wakeup: DBUS: Waiting 3 seconds to see if supending
    Oct 23 16:55:14 eyesome[28807]: Lid Open/Close: System supending, not waking eyesome
    Oct 23 16:55:17 eyesome[29319]: Wakeup: System supending, Cancel DBUS waking eyesome
    Oct 23 16:55:26 eyesome[30689]: Daemon: Resuming: Slept 2 seconds x 5 times.
    Oct 23 16:55:26 eyesome[30704]: Daemon: Removed file: /tmp/eyesome-is-suspending
    Oct 23 16:55:26 eyesome[30715]: Daemon: Removed file: /tmp/eyesome-DBUS
    Oct 23 16:59:48 eyesome[13909]: DBUS: Event Count: 51 over: 273 seconds
    Oct 23 16:59:48 eyesome[13922]: Wakeup: Called from eyesome-dbus.sh.
    Oct 23 16:59:49 eyesome[13965]: Wakeup: DBUS: Waiting 3 seconds to see if supending
    Oct 23 17:00:03 eyesome[15222]: Daemon: Monitor connect: Slept 2 seconds x 5 times.
    Oct 23 17:00:03 eyesome[15225]: Daemon: Removed file: /tmp/eyesome-DBUS

If you unplug one of your external monitors, or turn it off or on you will also see messages similar to above.
