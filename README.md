# eyesome

Eyesome will control up to three monitors including hardware laptop display.
Each day sunrise and sunset times are automatically retrievedfor your city.
Configure Daytime and Nighttime brightness and gamma levels for your monitors
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
- defining daytime and nightime brightness
- testing daytime and nighttime brightness
- setting transition period after sunrise to full monitor brighness
- setting transition period before sunset for reducing monitor brightness
- along with brightess, gamma can also be set (night light, redshift, etc.)
- setting how quickly brightness/gamma changes are made during transitions
- viewing the next interval brightess/gamma will be set
- viewing the last interval's setting of brightness/gamma per monitor

## Automatic operations

When you boot your computer a script in `/etc/cron.d` is run to load the
eyesome daemon: `eyesome.sh`. This will run 24/7 in the background.

When you suspend and resume your computer a script in `/etc/systemd/system-
sleep` runs `wake-eyesome.sh` to instantly adjust your screen brightness.
This is useful if you suspend your laptop at full brightness during day
and then wake it up at night.

Each morning a scxript in `/etc/cron.daily` is run to obtain that day's
sunrise and sunset times from https://www.timeanddate.com.

## Installation

Download the zip file, preferably to a new directory `~/eyesome` to
reduce clutter in `~/Downloads`.

Mark the file `install.sh` as executable with the command:

    sudo chmod a+x install.sh
    
Run the install program using:

    sudo install.sh
    
### Note:

You can also use `isntall.sh -h` or `install.sh --help` for help instructions.

You can use `sudo install.sh v` to verify MD5 hash checksums agree which means
your download is intact and secure.

You can use `sudo install.sh rm` to remove the eyesome programs. You can
install them again later and your configuration files will still be intact.
