@echo off&title Routing list update
mode con: cols=80 lines=28

rem Go to batch dir.
cd /D "%~dp0"

:[inte]
rem Verify.
md latest\ipv4>nul 2>nul
md latest\ipv6>nul 2>nul
rem Bin check
.\bin\md5 -c609F46A341FEDEAEEC18ABF9FB7C9647 .\bin\md5.exe 2>nul||echo.Checksum incorrect, please download all files again.&&ping -n 5 127.0.0.1>nul&&goto END
.\bin\md5 -c2610BF5E8228744FFEB036ABED3C88B3 .\bin\curl.exe 2>nul||echo.Checksum incorrect, please download all files again.&&ping -n 5 127.0.0.1>nul&&goto END
.\bin\md5 -cC95C0A045697BE8F782C71BD46958D73 .\bin\sed.exe 2>nul||echo.Checksum incorrect, please download all files again.&&ping -n 5 127.0.0.1>nul&&goto END
.\bin\md5 -c9A5E35DCB4B35A2350E6FDF4620743B6 .\bin\CCase.exe 2>nul||echo.Checksum incorrect, please download all files again.&&ping -n 5 127.0.0.1>nul&&goto END

if not "%~1" == "" (
   if "%~1" == "-LOCAL" (set ST=%~1) else goto %~1
)

:[main]
rem Download via FTP.
title Routing list update: Downloading...
call:[DownloadData]

rem List file checksum
title Routing list update: Verifying...
call:[Hash_DAL]

rem No new data, build from local cache database or cancel.
:RebuildDAL
setlocal enabledelayedexpansion
cls
if defined DALmd5_lab (
   set ny=y&set /p ny=No any new data, build routing list from local cache database?[Y/N]
   if "!ny!" == "y" endlocal&goto BuildCNIP
   if "!ny!" == "n" exit
   endlocal&goto RebuildDAL
)
endlocal

rem Extract ip data of CN.
:BuildCNIP
call:[ExtractCNIPList] 4
call:[ExtractCNIPList] 6

rem Checksum of IP data list
call:[Hash_CNIPList] 4
call:[Hash_CNIPList] 6
rem No new data, build from local cache database.
if defined IPV4md5_lab if exist #Routingipv4# set IPV4RoutCache=EXIST
if defined IPV6md5_lab if exist #Routingipv6# set IPV6RoutCache=EXIST

rem Convert data.
:FormatIPList
title Analysing...
del /s/q "%temp%\#ipv4listLab#" >nul 2>nul
del /s/q "%temp%\#ipv6listLab#" >nul 2>nul
if not defined IPV4RoutCache null>"%temp%\#ipv4listLab#" 2>nul&start /min "IPv4 Processing..." "%~f0" [FormatIPV4List]S
if not defined IPV6RoutCache null>"%temp%\#ipv6listLab#" 2>nul&start /min "IPv6 Processing..." "%~f0" [FormatIPV6List]S
:FormatIPList_DetectLabel
rem Check EOF.
if exist "%temp%\#ipv4listLab#" ping /n 3 127.0.0.1>nul&goto FormatIPList_DetectLabel
if exist "%temp%\#ipv6listLab#" ping /n 3 127.0.0.1>nul&goto FormatIPList_DetectLabel

:WriteFile
rem Merge data.
(echo.[Local Routing]
echo.## China mainland routing blocks
echo.## Last update: %date:~0,4%-%date:~5,2%-%date:~8,2%)>Routing.txt
rem Create header of file.
call:[WriteIPHead] 4
call:[WriteIPHead] 6
rem Consolidate data.
copy /y/b Routing.txt+"%temp%\IPv4ListHead"+#Routingipv4#+"%temp%\IPv6ListHead"+#Routingipv6# Routing.txt


goto END



:[DownloadData]
if not "%ST%" == "LOCAL" (
   ping /n 1 ftp.apnic.net>nul 2>nul||echo.Network error&&ping /n 3 127.0.0.1>nul&&goto END
   .\bin\curl "http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest" -o "%temp%\delegated-apnic-latest"
   copy /b/y "%temp%\delegated-apnic-latest" .\delegated-apnic-latest >nul
) else .\bin\curl "file://delegated-apnic-latest" -o "%temp%\delegated-apnic-latest" 2>nul||echo.No such file.&&ping /n 2 127.0.0.1>nul&&goto END
goto :eof

:[Hash_DAL]
setlocal enabledelayedexpansion
rem Checksum of the new file.
for /f "delims=" %%i in ('.\bin\md5 -n "%temp%\delegated-apnic-latest"') do set DAL_newmd5=%%i
rem Checksum of the latest file.
for /f "delims=." %%i in ('dir /a:-d/b ".\latest\*.md5" 2^>nul') do set DAL_oldmd5=%%i
if not defined DAL_oldmd5 set DAL_oldmd5=00000000000000000000000000000000
rem Verify data.
if "%DAL_oldmd5%" == "%DAL_newmd5%" (
   rem Data not changed flag
   set DALmd5_lab=EQUAL
) else (
   rem Update local cache database.
   copy /b/y "%temp%\delegated-apnic-latest" ".\latest\%DAL_oldmd5%.md5" >nul
   ren ".\latest\%DAL_oldmd5%.md5" "%DAL_newmd5%.md5" >nul 2>nul
)
del /s/q "%temp%\delegated-apnic-latest" >nul 2>nul
for /f "tokens=1-2 delims=|" %%i in ("%DAL_newmd5%|%DALmd5_lab%") do endlocal&set DALmd5=%%i&set DALmd5_lab=%%j
goto :eof

:[ExtractCNIPList]
rem Read CN IP.
type ".\latest\%DALmd5%.md5"|findstr ipv%1|findstr CN>"%temp%\#listipv%1#"
goto :eof

:[Hash_CNIPList]
setlocal enabledelayedexpansion
rem Checksum of the new file.
for /f "delims=" %%i in ('.\bin\md5 -n "%temp%\#listipv%1#"') do set IPV%1_newmd5=%%i
rem Checksum of the latest file.
for /f "delims=." %%i in ('dir /a:-d/b ".\latest\ipv%1\*.md5" 2^>nul') do set IPV%1_oldmd5=%%i
if not defined IPV%1_oldmd5 set IPV%1_oldmd5=00000000000000000000000000000000
rem Verify data.
if "!IPV%1_oldmd5!" == "!IPV%1_newmd5!" (
   rem Data not changed flag
   set IPV%1md5_lab=EQUAL
) else (
   rem Update local cache database.
   copy /b/y "%temp%\#listipv%1#" ".\latest\ipv%1\!IPV%1_oldmd5!.md5" >nul
   ren ".\latest\ipv%1\!IPV%1_oldmd5!.md5" "!IPV%1_newmd5!.md5" >nul 2>nul
)
del /s/q "%temp%\#listipv%1#" >nul 2>nul
for /f "tokens=1-2 delims=|" %%i in ("!IPV%1_newmd5!|!IPV%1md5_lab!") do endlocal&set IPV%1md5=%%i&set IPV%1md5_lab=%%j
goto :eof

:[FormatIPV6List]S
rem Convert IPv6 data.
@echo off&title Routing list update: Building IPv6 routing list...
(for /f "tokens=4-5 delims=|" %%i in ('type ".\latest\ipv6\%IPV6md5%.md5"') do echo %%i/%%j|.\bin\ccase)>#Routingipv6#
rem Remove flag.
del /s/q "%temp%\#ipv6listLab#" >nul 2>nul
exit

:[FormatIPV4List]S
rem Convert IPv4 data.
@echo off&title Routing list update: Building IPv4 routing list...
(for /f "tokens=4-5 delims=|" %%i in ('type ".\latest\ipv4\%IPV4md5%.md5"') do echo.%%i/%%j#)>#Routingipv4#
set /a index=1,indexx=2,index_out=0
set str=*&set lop=0
:[FormatIPV4List]S_LOOP
if %lop% geq 32 start /w "Building IPv4 routing list error." "%~f0" [FormatIPV4List]S_ERROR&goto END
for /f "tokens=1-2 delims=/#" %%i in ('findstr /v "%str%" #Routingipv4#') do (
   set address=%%i&set /a value_mi=%%j
   call:[SearchLIB]
   set /a lop+=1
   goto [FormatIPV4List]S_LOOP
)
.\bin\sed -i "s/#//g" #Routingipv4#
goto [FormatIPV4List]S_END
:[FormatIPV4List]S_ERROR
echo.Unknown error.
ping /n 3 127.0.0.1>nul
:[FormatIPV4List]S_END
rem Remove flag.
del /s/q "%temp%\#ipv4listLab#" >nul 2>nul
exit

:[SearchLIB]
for /f "tokens=1-2 delims=/" %%i in ('findstr "%value_mi%\/" Log_Lib 2^>nul') do set count=%%j
if not defined count call:[logT]
rem Convert /%value_mi% to /%count%
.\bin\sed -i "s/\/%value_mi%#/\/%count%#/g" #Routingipv4#
if not "%str%" == "*" (set str=%str% \/%count%#) else set str=\/%count%#
set count=
goto :eof

:[logT]
rem value_mi must no more than 2^31-1 or 2147483647.
:[logT][inte]
setlocal enabledelayedexpansion
if %value_mi% == 0 goto [logT][end]
if %value_mi% == 1 goto [logT][end]
:[logT][main]
if %value_mi% gtr 1 (
   set /a value_mi">>="index,index_out+=index
   if !value_mi! equ 1 goto [logT][end]
   if !value_mi! lss 1 set /a index=1,indexx=2,value_mi=%value_mi%,index_out=%index_out%&goto [logT][main]
   if !value_mi! lss !indexx! set /a index=1,indexx=2&goto [logT][main]
   if !value_mi! equ !indexx! set /a index_out+=index&goto [logT][end]
   set /a index*=2,indexx*=indexx
   goto [logT][main]
)
:[logT][end]
for /f %%s in ("%index_out%") do endlocal&set /a count=32-%%s
echo.%value_mi%/%count%>>Log_Lib
goto :eof
rem Exit.

:[WriteIPHead]
rem Write IP header.
if %1 == 4 set "port=32-log($5)/log(2)"
if %1 == 6 set "port=$5"
(echo.
echo.
echo.## IPv%1
echo.## Get the latest database from APNIC -^> "curl 'https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | grep ipv%1 | grep CN | awk -F\| '{printf("%%s/%%d\n", $4, %port%)}' > Routing_IPv%1.txt"
)>"%temp%\IPv%1ListHead"
goto :eof



:END
exit
