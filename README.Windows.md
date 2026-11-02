# OpenOCD for Windows

This README contains instructions that are specific to Windows.

## Building

You can build OpenOCD for Windows natively with either MinGW-w64/MSYS
or Cygwin (plain MinGW might work with `--disable-werror` but is not
recommended as it doesn't provide enough C99 compatibility).
Alternatively, one can cross-compile it using MinGW-w64 on a *nix
host. See [README](README.md) for the generic instructions.

Also, the MSYS2 project provides both ready-made binaries and an easy
way to self-compile from their software repository out of the box.

## USB adapters

For the adapters that use a HID-based protocol, e.g. CMSIS-DAP, you do
not need to perform any additional configuration.

For all the others you usually need to have WinUSB.sys (or
libusbK.sys) driver installed. Some vendor software (e.g. for
ST-LINKv2) does it on its own. For the other cases the easiest way to
assign WinUSB to a device is to use the latest Zadig installer: <https://zadig.akeo.ie>

When using a composite USB device, it's often necessary to assign
WinUSB.sys to the composite parent instead of the specific
interface. To do that one needs to activate an advanced option in the
Zadig installer.

If you need to use the same adapter with other applications that may
require another driver, a solution for Windows Vista and above is to
activate the `IgnoreHWSerNum` registry setting for the USB device.

That setting forces Windows to associate the driver per port instead of
per serial number, the same behaviour as when the device does not contain
a serial number. So different drivers can be installed for the adapter on
different ports and you just need to plug the adapter into the correct
port depending on which application to use.

For more information, see:

- <https://learn.microsoft.com/en-us/windows-hardware/drivers/usbcon/usb-device-specific-registry-settings>
- <https://www.ftdichip.com/Support/Knowledgebase/index.html?ignorehardwareserialnumber.htm>

## Using a locally built OpenOCD with xPack scripts

A locally built OpenOCD may not have the xPack script directory compiled in.
When replacing the xPack `openocd.exe`, pass the scripts directory explicitly:

```sh
openocd -s C:/xpack-openocd/openocd/scripts ...
```

Alternatively, set the `OPENOCD_SCRIPTS` environment variable. Keep
`libusb-1.0.dll` and `libftdi1.dll` next to the executable as well.

For USB-Blaster II, the `usb_blaster batch <n>` command can reduce the number of
USB round trips when reading TDO. The default is `1`; start with `8` and verify
the target after changing it. Values above `8` may exceed the adapter FIFO for
TDO-heavy operations. See the OpenOCD manual for details.
