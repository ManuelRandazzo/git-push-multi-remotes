@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Uninstall the native Windows installation of git-push-remotes.
set "APP_NAME=git-push-remotes"
set "ASSUME_YES=0"
set "ERROR_MSG="
set "PATH_REMOVAL_FAILED=0"
set "PATH_REMOVAL_ATTEMPTED=0"
set "SKIPPED=0"

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="-y" (
    set "ASSUME_YES=1"
    shift
    goto :parse_args
)
if /I "%~1"=="--yes" (
    set "ASSUME_YES=1"
    shift
    goto :parse_args
)
if /I "%~1"=="/Y" (
    set "ASSUME_YES=1"
    shift
    goto :parse_args
)
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="/h" goto :usage
if /I "%~1"=="/?" goto :usage
echo ERROR: Unknown option: %~1 1>&2
goto :usage_error

:args_done
if not defined USERPROFILE (
    set "ERROR_MSG=USERPROFILE is not set."
    goto :fail
)
if not defined LOCALAPPDATA set "LOCALAPPDATA=%USERPROFILE%\AppData\Local"

rem Keep these Windows-specific defaults in sync with install.bat.
if not defined GPR_INSTALL_DIR set "GPR_INSTALL_DIR=%LOCALAPPDATA%\Programs\git-push-remotes\app"
if not defined GPR_VENV_DIR set "GPR_VENV_DIR=%LOCALAPPDATA%\git-push-remotes\venv"
if not defined GPR_BIN_DIR set "GPR_BIN_DIR=%LOCALAPPDATA%\Programs\git-push-remotes\bin"
for %%I in ("%GPR_INSTALL_DIR%") do set "GPR_INSTALL_DIR=%%~fI"
for %%I in ("%GPR_VENV_DIR%") do set "GPR_VENV_DIR=%%~fI"
for %%I in ("%GPR_BIN_DIR%") do set "GPR_BIN_DIR=%%~fI"
set "GPR_USER_HOME=%USERPROFILE%"

rem Validate targets and refuse root, HOME, parent-of-HOME, or overlapping paths before deleting anything.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $homePath=[IO.Path]::GetFullPath($env:GPR_USER_HOME).TrimEnd('\'); $inputs=@($env:GPR_INSTALL_DIR,$env:GPR_VENV_DIR,$env:GPR_BIN_DIR); $paths=@(); foreach($p in $inputs){ if([string]::IsNullOrWhiteSpace($p)){ throw 'An installation path is empty.' }; $full=[IO.Path]::GetFullPath($p); $root=[IO.Path]::GetPathRoot($full); $norm=$full.TrimEnd('\'); if($norm -ieq $root.TrimEnd('\')){ throw ('Refusing to remove a drive root: '+$full) }; if($norm -ieq $homePath){ throw ('Refusing to remove the user home directory: '+$full) }; if($homePath.StartsWith($norm+'\',[StringComparison]::OrdinalIgnoreCase)){ throw ('Refusing to remove a parent of the user home directory: '+$full) }; $paths+=,$norm }; for($i=0;$i -lt $paths.Count;$i++){ for($j=$i+1;$j -lt $paths.Count;$j++){ if($paths[$i] -ieq $paths[$j] -or $paths[$i].StartsWith($paths[$j]+'\',[StringComparison]::OrdinalIgnoreCase) -or $paths[$j].StartsWith($paths[$i]+'\',[StringComparison]::OrdinalIgnoreCase)){ throw 'Installation paths overlap. Check GPR_INSTALL_DIR, GPR_VENV_DIR, and GPR_BIN_DIR.' } } }" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=The configured paths failed safety checks. Verify GPR_INSTALL_DIR, GPR_VENV_DIR, and GPR_BIN_DIR; no files have been removed."
    goto :fail
)

set "LAUNCHER_SCRIPT=%GPR_BIN_DIR%\git-push-remotes"
set "LAUNCHER_CMD=%GPR_BIN_DIR%\git-push-remotes.cmd"
set "PATH_MARKER=%GPR_BIN_DIR%\.git-push-remotes-path-added"
echo Target program: %GPR_INSTALL_DIR%
echo Python env:    %GPR_VENV_DIR%
echo Command dir:   %GPR_BIN_DIR%
echo.

if "%ASSUME_YES%"=="0" goto :confirm_uninstall
goto :confirmed_uninstall

:confirm_uninstall
set "ANSWER="
set /P "ANSWER=Remove this git-push-remotes installation? [y/N] "
if /I "%ANSWER%"=="y" goto :confirmed_uninstall
if /I "%ANSWER%"=="yes" goto :confirmed_uninstall
echo Uninstallation cancelled.
endlocal & exit /b 0

:confirmed_uninstall
rem Remove only what the installer created: every item is checked before it is deleted.
if exist "%LAUNCHER_SCRIPT%" (
    findstr /I /C:"git-push-remotes" "%LAUNCHER_SCRIPT%" >nul 2>&1
    if errorlevel 1 (
        echo WARNING: Skipping "%LAUNCHER_SCRIPT%": it was not created by this installer.
        set "SKIPPED=1"
    ) else (
        del /F /Q "%LAUNCHER_SCRIPT%" >nul 2>&1
    )
)
if exist "%LAUNCHER_CMD%" (
    findstr /I /C:"git-push-remotes" "%LAUNCHER_CMD%" >nul 2>&1
    if errorlevel 1 (
        echo WARNING: Skipping "%LAUNCHER_CMD%": it was not created by this installer.
        set "SKIPPED=1"
    ) else (
        del /F /Q "%LAUNCHER_CMD%" >nul 2>&1
    )
)
if exist "%GPR_INSTALL_DIR%\git-push-remotes" (
    rmdir /S /Q "%GPR_INSTALL_DIR%" >nul 2>&1
    if exist "%GPR_INSTALL_DIR%" (
        set "ERROR_MSG=Could not remove the program directory: %GPR_INSTALL_DIR%"
        goto :fail
    )
) else if exist "%GPR_INSTALL_DIR%" (
    echo WARNING: Skipping "%GPR_INSTALL_DIR%": it does not contain git-push-remotes.
    set "SKIPPED=1"
)
if exist "%GPR_VENV_DIR%\pyvenv.cfg" (
    rmdir /S /Q "%GPR_VENV_DIR%" >nul 2>&1
    if exist "%GPR_VENV_DIR%" (
        set "ERROR_MSG=Could not remove the Python environment: %GPR_VENV_DIR%"
        goto :fail
    )
) else if exist "%GPR_VENV_DIR%" (
    echo WARNING: Skipping "%GPR_VENV_DIR%": it is not a Python virtual environment.
    set "SKIPPED=1"
)

rem Remove only the PATH entries recorded by install.bat; preserve entries that existed before installation.
if exist "%PATH_MARKER%" set "PATH_REMOVAL_ATTEMPTED=1"
if exist "%PATH_MARKER%" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $marker=Join-Path $env:GPR_BIN_DIR '.git-push-remotes-path-added'; $managed=@(Get-Content -LiteralPath $marker | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }); $old=[Environment]::GetEnvironmentVariable('Path','User'); $kept=@(); foreach($entry in ($old -split ';')){ if([string]::IsNullOrWhiteSpace($entry)){ continue }; try { $full=[IO.Path]::GetFullPath($entry).TrimEnd('\') } catch { $full=$entry.TrimEnd('\') }; $remove=$false; foreach($item in $managed){ try { $target=[IO.Path]::GetFullPath($item).TrimEnd('\') } catch { $target=$item.TrimEnd('\') }; if([string]::Equals($full,$target,[StringComparison]::OrdinalIgnoreCase)){ $remove=$true } }; if(-not $remove){ $kept+=$entry } }; [Environment]::SetEnvironmentVariable('Path',($kept -join ';'),'User'); Remove-Item -LiteralPath $marker -Force" >nul 2>&1
    if errorlevel 1 (
        set "PATH_REMOVAL_FAILED=1"
        echo WARNING: Could not remove the PATH entries automatically. Review your user PATH and remove the entries recorded in "%PATH_MARKER%" if needed.
    )
)

rem Remove the command directory only when it is empty; preserve unrelated user files.
rmdir "%GPR_BIN_DIR%" >nul 2>&1
for %%I in ("%GPR_INSTALL_DIR%\..") do for %%J in ("%%~fI") do if /I "%%~nxJ"=="git-push-remotes" rmdir "%%~fJ" >nul 2>&1
for %%I in ("%GPR_VENV_DIR%\..") do for %%J in ("%%~fI") do if /I "%%~nxJ"=="git-push-remotes" rmdir "%%~fJ" >nul 2>&1
echo.
if "%SKIPPED%"=="0" echo Uninstallation completed.
if "%SKIPPED%"=="0" echo The Windows program, virtual environment, and launchers have been removed.
if "%SKIPPED%"=="1" echo Uninstallation finished with skipped items. See the warnings above.
if "%PATH_REMOVAL_FAILED%"=="0" if "%PATH_REMOVAL_ATTEMPTED%"=="1" echo Installer-managed PATH entries have been removed.
if "%PATH_REMOVAL_ATTEMPTED%"=="0" echo No installer-managed PATH entries were recorded.
if "%PATH_REMOVAL_FAILED%"=="1" echo WARNING: PATH cleanup could not be confirmed.
echo Existing unrelated files and shell profile files were left untouched.
endlocal & exit /b 0

:usage
echo Usage: uninstall.bat [--yes ^|-y ^| /Y]
echo.
echo Remove the native Windows git-push-remotes installation.
echo.
echo Options:
echo   -y, --yes, /Y   Skip the confirmation prompt.
echo   --help, /h, /?  Show this help message.
echo.
echo Optional environment variables (also used by install.bat):
echo   GPR_INSTALL_DIR  Program directory
echo   GPR_VENV_DIR     Python virtual environment directory
echo   GPR_BIN_DIR      Directory containing command launchers
endlocal & exit /b 0

:usage_error
echo Usage: uninstall.bat [--yes ^|-y ^| /Y] 1>&2
endlocal & exit /b 2

:fail
echo ERROR: %ERROR_MSG% 1>&2
endlocal & exit /b 1