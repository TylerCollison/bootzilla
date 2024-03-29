@echo off
:_start

::_____________________________________________________________

setlocal
set LABEL=Windows
set BCDEDIT=bcdedit.exe
set BCDSTORE=%~dp0BCD



cls
Echo Creating store...
%BCDEDIT% /createstore %BCDSTORE%
echo.
echo.

Echo Creating bootmgr entry...
%BCDEDIT% /store %BCDSTORE% /create {bootmgr}
%BCDEDIT% /store %BCDSTORE% /set {bootmgr} description "Boot Manager"
rem Setting the "device" to "boot" ensures that the boot manager can always boot the partition on which it is installed
%BCDEDIT% /store %BCDSTORE% /set {bootmgr} device boot
%BCDEDIT% /store %BCDSTORE% /set {bootmgr} timeout 20
echo.
echo.

Echo Adding Windows entry...
for /f "tokens=2 delims={}" %%g in ('%BCDEDIT% /store %BCDSTORE% /create /d %LABEL% /application osloader') do set guid={%%g}
echo guid=%guid%
rem Setting the "device" to "boot" ensures that the bootloader can always boot the partition on which it is installed
%BCDEDIT% /store %BCDSTORE% /set %guid% device boot
%BCDEDIT% /store %BCDSTORE% /set %guid% path \Windows\system32\winload.exe
rem Setting the "osdevice" to "boot" ensures that the bootloader can always boot the partition on which it is installed
%BCDEDIT% /store %BCDSTORE% /set %guid% osdevice boot
%BCDEDIT% /store %BCDSTORE% /set %guid% systemroot \Windows
%BCDEDIT% /store %BCDSTORE% /displayorder %guid% /addlast
%BCDEDIT% /store %BCDSTORE% /default %guid%
echo.
echo.
endlocal
pause
:_end