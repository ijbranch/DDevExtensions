@echo off
SETLOCAL

:: *************************
:: * Locate a Delphi to build the version-independent artefacts with (the installer and
:: * CompileInterceptor), newest first. This used to be hardcoded to Studio 21.0 (Delphi
:: * 10.4), so the script could not run at all on a machine that did not happen to have
:: * that exact version installed.
SET NewestRsvars=
for %%V in (37.0 23.0 22.0 21.0 20.0 19.0) do (
  if not defined NewestRsvars if exist "C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat" set NewestRsvars="C:\Program Files (x86)\Embarcadero\Studio\%%V\bin\rsvars.bat"
)

SET curdir=%CD%
SET ScriptDir=%~dp0
cd /d "%ScriptDir%."

SET InterceptorDir=%~dp0..\..\CompileInterceptor

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

:: Delete intermediate files. Delphi 10.2 is the oldest version this script supports;
:: the pre-10.2 project folders live in the upstream repository, see README.md.
del /Q /S D_D102\lib\*.dcu >NUL 2>&1
del /Q /S D_D103\lib\*.dcu >NUL 2>&1
del /Q /S D_D104\lib\*.dcu >NUL 2>&1
del /Q /S D_D110\lib\*.dcu >NUL 2>&1
del /Q /S D_D120\lib\*.dcu >NUL 2>&1
del /Q /S D_D130\lib\*.dcu >NUL 2>&1
del /Q /S "%InterceptorDir%\lib\*.dcu" >NUL 2>&1

if "%1-" == "clean-" goto Leave

echo.

:: ----------------------------------------------------------------------------------------
:: A version whose IDE is not installed, or whose project folder is not in this repository,
:: is SKIPPED with a notice rather than failing the run. That is what lets this script go
:: end to end on a machine carrying a single Delphi. Only a genuine COMPILE failure stops it.
:: Delphi 2009 - 10.1 are not built here; those project folders live upstream (see README.md).
::
:: EVERY msbuild call passes /p:Platform explicitly. Without it msbuild falls back to the
:: .dproj's own default Platform, which is Win64 in D_D130 - so the script silently produced
:: the 64-bit DLL only and never built a single 32-bit artefact. The 32-bit IDE host is
:: still the common case, so that is not optional.
:: ----------------------------------------------------------------------------------------
SET BUILT=0
SET SKIPPED=0
SET BUILDERROR=

:: CompileInterceptor FIRST: the DDevExtensions projects copy its DLL into bin\ from a
:: PreBuildEvent, so building it afterwards would ship whatever stale copy happened to be
:: on disk - or fail outright on a fresh clone, where CompileInterceptor\Bin has no
:: CompileInterceptorW.dll at all.
echo.
echo === CompileInterceptor =====================
call :BuildInterceptor Win32 CompileInterceptorW
call :BuildInterceptor Win64 CompileInterceptorWx64

echo.
echo === Installer ==============================
:: The installer is built Win32 deliberately: it reads the IDE's RootDir from
:: HKLM\Software\Embarcadero\BDS\<n>, which RAD Studio writes into the 32-bit registry
:: view (WOW6432Node). A 64-bit installer sees the empty native view there and has to
:: fall back to the per-user HKCU copy, so it detects fewer IDEs than a 32-bit one does.
if not defined NewestRsvars (
  echo   SKIPPED - no Delphi installation found to build the installer with.
  set /A SKIPPED+=1
) else (
  call %NewestRsvars%
  cd Installer
  msbuild /nologo /t:Build /p:Config=Release /p:Platform=Win32 DDevExtensionsReg.dproj
  if ERRORLEVEL 1 (
    cd ..
    echo   *** BUILD FAILED for the installer
    set BUILDERROR=1
  ) else (
    cd ..
    del bin\DDevExtensionsReg.map bin\DDevExtensionsReg.drc >NUL 2>&1
    set /A BUILT+=1
  )
)

:: Delphi 12 and 13 are built twice, Win32 then Win64, because both ship a 64-bit IDE host
:: (bin64\bds.exe) - RAD Studio 12.2 added one as an opt-in preview, and 13 made it the real
:: thing. On a 12.0 or 12.1 installation there is no bin64\bds.exe, so the installer simply
:: never offers that row; building the DLL costs nothing and hurts nothing.
:: D_D102 - D_D110 declare Win64=False and carry no x64 $LIBSUFFIX, so Win32 is all there is.
call :BuildOne "Delphi 13.0 - 32-bit IDE host" "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" D_D130 Win32 DDevExtensionsD130
call :BuildOne "Delphi 13.0 - 64-bit IDE host" "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" D_D130 Win64 DDevExtensionsD130x64
call :BuildOne "Delphi 12.0 - 32-bit IDE host" "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" D_D120 Win32 DDevExtensionsD120
call :BuildOne "Delphi 12.2+ - 64-bit IDE host" "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" D_D120 Win64 DDevExtensionsD120x64
call :BuildOne "Delphi 11.0" "C:\Program Files (x86)\Embarcadero\Studio\22.0\bin\rsvars.bat" D_D110 Win32 DDevExtensionsD110
call :BuildOne "Delphi 10.4" "C:\Program Files (x86)\Embarcadero\Studio\21.0\bin\rsvars.bat" D_D104 Win32 DDevExtensionsD104
call :BuildOne "Delphi 10.3" "C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\rsvars.bat" D_D103 Win32 DDevExtensionsD103
call :BuildOne "Delphi 10.2" "C:\Program Files (x86)\Embarcadero\Studio\19.0\bin\rsvars.bat" D_D102 Win32 DDevExtensionsD102

if defined BUILDERROR goto Summary

echo DDevExtensions Version %majorversion%.%minorversion%.%releaseversion%>bin\Version.txt
if "%fileversion%#" == "Dev#" echo %versioninfo%>>bin\Version.txt

:: Delete old files
del "%ReleaseDir%\DDevExtensions*.*" /Q 2>NUL
md "%ReleaseDir%" 2>NUL

if not exist "C:\Program Files\7-Zip\7z.exe" (
  echo.
  echo   SKIPPED packaging - 7-Zip is not installed at C:\Program Files\7-Zip.
  goto Summary
)
cd bin
SET FILENAME=..\DDevExtensions

del "%FILENAME%.7z" 2>NUL >NUL
"C:\Program Files\7-Zip\7z.exe" a -y "%FILENAME%.7z" *.dll *.txt *.exe
if ERRORLEVEL 1 (
  cd ..
  goto Error1
)

move "%FILENAME%.7z" "%ReleaseDir%\DDevExtensions%fileversion%.7z"
cd ..

if "%fileversion%#" == "Dev#"  copy /Y ChangeLog.txt "%ReleaseDir%\Changelog.txt"

goto Summary

:: ===========================================
:Error1
echo.
echo *** BUILD ABORTED
SET BUILDERROR=1

:Summary
echo.
echo === Summary ================================
echo   Built   : %BUILT%
echo   Skipped : %SKIPPED%
if defined BUILDERROR echo   FAILED  : one or more projects did not compile - see the log above.
echo.
goto Leave

:: ----------------------------------------------------------------------------------------
:: :BuildInterceptor  %1 platform  %2 output DLL name (without extension)
:: Builds the helper DLL that DDevExtensions injects into the IDE. One build serves every
:: Delphi version - it resolves the IDE DLLs by name at run time - but it does need one
:: build per BITNESS, because it is loaded into the IDE's own process.
:: ----------------------------------------------------------------------------------------
:BuildInterceptor
echo.
echo --- CompileInterceptor %~1 ---------------
if not defined NewestRsvars (
  echo   SKIPPED - no Delphi installation found to build CompileInterceptor with.
  set /A SKIPPED+=1
  goto :EOF
)
if not exist "%InterceptorDir%\Source\CompileInterceptorW.dproj" (
  echo   SKIPPED - CompileInterceptor sources are not in this repository.
  set /A SKIPPED+=1
  goto :EOF
)
call %NewestRsvars%
cd /d "%InterceptorDir%\Source"
msbuild /nologo /t:Build /p:Config=Release /p:Platform=%~1 CompileInterceptorW.dproj
if ERRORLEVEL 1 (
  cd /d "%ScriptDir%."
  echo   *** BUILD FAILED for CompileInterceptor %~1
  set BUILDERROR=1
  goto :EOF
)
cd /d "%ScriptDir%."
:: The plug-in DLL and its interceptor ship side by side, so put the fresh build where the
:: installer picks it up. The PreBuildEvent in the .dproj files does the same for an IDE
:: build; doing it here as well keeps a command-line build self-contained.
copy /Y "%InterceptorDir%\Bin\%~2.dll" bin\ >NUL
if ERRORLEVEL 1 (
  echo   *** could not copy %~2.dll into bin
  set BUILDERROR=1
  goto :EOF
)
del "%InterceptorDir%\Bin\%~2.map" "%InterceptorDir%\Bin\CompileInterceptorW.drc" >NUL 2>&1
set /A BUILT+=1
goto :EOF

:: ----------------------------------------------------------------------------------------
:: :BuildOne  %1 display name  %2 rsvars.bat (quoted)  %3 project folder  %4 platform
::            %5 output DLL name (without extension)
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
msbuild /nologo /t:Build /p:Config=Release /p:Platform=%~4 DDevExtensions.dproj
if ERRORLEVEL 1 (
  cd ..
  echo   *** BUILD FAILED for %~1
  set BUILDERROR=1
  goto :EOF
)
cd ..
if exist "%LINKMAPFILE%" "%LINKMAPFILE%" bin\%~5.dll
del bin\%~5.map bin\DDevExtensions.drc >NUL 2>&1
set /A BUILT+=1
goto :EOF

:Leave
SET FILENAME=
SET LINKMAPFILE=
SET InterceptorDir=
SET ScriptDir=
cd /d "%curdir%"

ENDLOCAL
