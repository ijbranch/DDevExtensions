@echo off
SETLOCAL

:: *************************
:: * rebuild with Delphi 2009 (much smaller file). XE2 is required for the .res file
REM Set BuildInstallerWith="C:\CodeGear\RAD Studio\6.0\bin\rsvars.bat"
:: Build the installer with whichever Delphi is actually present, newest first. This used
:: to be hardcoded to Studio 21.0 (Delphi 10.4), so the script could not run at all on a
:: machine that did not happen to have that exact version installed.
SET BuildInstallerWith=
for %%V in (37.0 23.0 22.0 21.0 20.0 19.0) do (
  if not defined BuildInstallerWith if exist "C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat" set BuildInstallerWith="C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat"
)

SET curdir=%CD%
cd /d "%~dp0"

if NOT "%fileversion%#" == "#" goto HASVERSION
:: *************************
:: * Adjust version number
:: Explicit path: with NoDefaultCurrentDirectoryInExePath=1 set - common on hardened and
:: CI machines - cmd refuses to resolve a batch file from the current directory, so a bare
:: "call version.bat" fails with "not recognized" even though the file is right there.
call "%~dp0version.bat"
if "%releaseversion%#" == "#" (
  echo ERROR: version.bat does not set releaseversion. The product version has THREE
  echo        fields; building with two would silently write a lower version into
  echo        Source\version.inc, version.h and Version.res.
  goto Error1
)
SET fileversion=%majorversion%%minorversion%%releaseversion%
SET version=%majorversion%.%minorversion%.%releaseversion%
SET versioninfo=%version%
SET ReleaseDir=%~dp0\Release\%version%

:: *************************
:HASVERSION
echo Version    : %version%
echo FileVersion: %fileversion%
echo Major.Minor.Release: %majorversion%.%minorversion%.%releaseversion%
echo VersionInfo: %versioninfo%
echo.

:: Redirect FIRST. "echo text >file" leaves the space before the ">" in the output, and a
:: digit immediately before ">" would be read as a stream handle - this form avoids both,
:: so the generated files are byte-identical to the ones in the repository.
>Source\version.inc echo  VersionNumber = '%versioninfo%';
>version.h echo #define VER_PRODUCTVERSION          %majorversion%,%minorversion%,%releaseversion%,0
>>version.h echo #define VER_PRODUCTVERSION_STR      "%majorversion%.%minorversion%.%releaseversion%"
:: brcc32 first: cgrc in RAD Studio 12+ rejects this invocation with
:: "Error: .res is not an executable image". brcc32 ships in every Delphi bin folder
:: and has taken the same syntax for decades, so it is the portable choice.
brcc32 Version.rc -foVersion.res
if ERRORLEVEL 1 cgrc Version.rc -foVersion.res
if ERRORLEVEL 1 (
  echo ERROR: could not compile Version.rc - the DLL would keep its previous version.
  goto Error1
)
:: version.h is TRACKED and hand-editable, so it is deliberately NOT deleted here.
:: Deleting it removed a committed file and left the tree dirty after every build.

:: **********************************************************************************************

SET LINKMAPFILE=..\..\Tools\LinkMapFile\linkmapfile.exe

:: Delete intermediate files. Only the folders this repository carries - the pre-10.2
:: project folders live in the upstream repository, see README.md.
del /Q /S D_D102\lib\*.dcu >NUL
del /Q /S D_D103\lib\*.dcu >NUL
del /Q /S D_D104\lib\*.dcu >NUL
del /Q /S D_D110\lib\*.dcu >NUL
del /Q /S D_D120\lib\*.dcu >NUL
del /Q /S D_D130\lib\*.dcu >NUL
:: Delete intermediate files
del /Q /S D_2009\lib\*.dcu >NUL
del /Q /S D_2010\lib\*.dcu >NUL
del /Q /S D_XE\lib\*.dcu >NUL
del /Q /S D_XE2\lib\*.dcu >NUL
del /Q /S D_XE3\lib\*.dcu >NUL
del /Q /S D_XE4\lib\*.dcu >NUL
del /Q /S D_XE5\lib\*.dcu >NUL
del /Q /S D_XE6\lib\*.dcu >NUL
del /Q /S D_XE7\lib\*.dcu >NUL
del /Q /S D_XE8\lib\*.dcu >NUL
del /Q /S D_D10\lib\*.dcu >NUL
del /Q /S D_D101\lib\*.dcu >NUL
del /Q /S D_D102\lib\*.dcu >NUL
del /Q /S D_D103\lib\*.dcu >NUL
del /Q /S D_D104\lib\*.dcu >NUL
del /Q /S D_D110\lib\*.dcu >NUL
del /Q /S D_D120\lib\*.dcu >NUL
del /Q /S D_D130\lib\*.dcu >NUL

if "%1-" == "clean-" goto :EOF

echo.

:: ----------------------------------------------------------------------------------------
:: A version whose IDE is not installed, or whose project folder is not in this repository,
:: is SKIPPED with a notice rather than failing the run. That is what lets this script go
:: end to end on a machine carrying a single Delphi. Only a genuine COMPILE failure stops it.
:: Delphi 2009 - 10.1 are not built here; those project folders live upstream (see README.md).
:: ----------------------------------------------------------------------------------------
SET BUILT=0
SET SKIPPED=0
SET BUILDERROR=

echo.
echo === Installer ==============================
if not defined BuildInstallerWith (
  echo   SKIPPED - no Delphi installation found to build the installer with.
  set /A SKIPPED+=1
) else (
  cd Installer
  call %BuildInstallerWith%
  msbuild /nologo /t:Build /p:Config=Release DDevExtensionsReg.dproj
  if ERRORLEVEL 1 goto Error1
  cd ..
  del bin\DDevExtensionsReg.map bin\DDevExtensionsReg.drc 2>NUL
  set /A BUILT+=1
)

call :BuildOne "Delphi 13.0" "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" D_D130 DDevExtensionsD130
call :BuildOne "Delphi 12.0" "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" D_D120 DDevExtensionsD120
call :BuildOne "Delphi 11.0" "C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat" D_D110 DDevExtensionsD110
call :BuildOne "Delphi 10.4" "C:\Program Files (x86)\Embarcadero\Studio\21.0\bin\rsvars.bat" D_D104 DDevExtensionsD104
call :BuildOne "Delphi 10.3" "C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\rsvars.bat" D_D103 DDevExtensionsD103
call :BuildOne "Delphi 10.2" "C:\Program Files (x86)\Embarcadero\Studio\19.0\bin\rsvars.bat" D_D102 DDevExtensionsD102

if defined BUILDERROR goto Error0

echo DDevExtensions Version %majorversion%.%minorversion%.%releaseversion%>bin\Version.txt
if "%fileversion%#" == "Dev#" echo %versioninfo%>>bin\Version.txt

:: Delete old files
del "%ReleaseDir%\DDevExtensions*.*" /Q 2>NUL
md "%ReleaseDir%" 2>NUL

if not exist "C:\Program Files\7-Zip\7z.exe" (
  echo   SKIPPED packaging - 7-Zip is not installed at C:\Program Files\7-Zip.
  cd ..
  goto Summary
)
cd bin
SET FILENAME=..\DDevExtensions

del "%FILENAME%.7z" 2>NUL >NUL
"C:\Program Files\7-Zip\7z.exe" a -y "%FILENAME%.7z" *.dll *.txt *.exe
if ERRORLEVEL 1 GOTO Error1

move "%FILENAME%.7z" "%ReleaseDir%\DDevExtensions%fileversion%.7z"
cd ..

if "%fileversion%#" == "Dev#"  copy /Y ChangeLog.txt "%ReleaseDir%\Changelog.txt"

:: ===========================================
goto Leave
:Error1

:Summary
echo.
echo === Summary ================================
echo   Built   : %BUILT%
echo   Skipped : %SKIPPED%
echo.
goto Leave

:: ----------------------------------------------------------------------------------------
:: :BuildOne  %1 display name  %2 rsvars.bat (quoted)  %3 project folder  %4 output DLL name
:: ----------------------------------------------------------------------------------------
:BuildOne
echo.
echo === %~1 ==============================
if not exist %2 (
  echo   SKIPPED - %~1 is not installed on this machine.
  set /A SKIPPED+=1
  goto :EOF
)
if not exist "%~3\DDevExtensions.dproj" (
  echo   SKIPPED - project folder %~3 is not in this repository.
  set /A SKIPPED+=1
  goto :EOF
)
call %2
cd %~3
msbuild /nologo /t:Build /p:Config=Release DDevExtensions.dproj
if ERRORLEVEL 1 (
  cd ..
  echo   *** BUILD FAILED for %~1
  set BUILDERROR=1
  goto :EOF
)
cd ..
if exist "%LINKMAPFILE%" "%LINKMAPFILE%" bin\%~4.dll
del bin\%~4.map bin\DDevExtensions.drc 2>NUL
set /A BUILT+=1
goto :EOF

cd ..
:Error0
pause


:Leave
SET FILENAME=
SET LINKMAPFILE=
cd /d "%curdir%"

ENDLOCAL
