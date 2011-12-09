@echo off
setlocal EnableDelayedExpansion

set "MODULES="
for %%i in (*.d) do set MODULES=!MODULES! %%i

set "WINVERSIONS=-version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista"

set "FLAGS=-g -w -wi -debug"
:: ~ set "FLAGS=-release -inline -O -noboundscheck"
set "VERSION=-version=MultiThreaded"
:: ~ set "VERSION=-version=MultiThreaded -version=Profile"
:: ~ set "VERSION=-version=MultiThreaded -version=Profile -unittest"
set "RUN="
:: ~ set "RUN=&& bin\xfbuild.exe"

dmd -ofbin\xfbuild.exe %FLAGS% %MODULES% %VERSION% -I.. win32.lib %WINVERSIONS% -Idcollections-2.0c dcollections-2.0c\dcollections.lib %RUN%
