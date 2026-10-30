@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Install git-push-remotes for the current Windows user.
rem Git runs any executable named git-NAME found in PATH as "git NAME", the same mechanism git-filter-repo uses.
set "APP_NAME=git-push-remotes"
set "ERROR_MSG="
set "VENV_CREATED=0"
set "INSTALL_SWAPPED=0"
set "SCRIPT_LAUNCHER_INSTALLED=0"
set "CMD_LAUNCHER_INSTALLED=0"

if not defined USERPROFILE (
    set "ERROR_MSG=USERPROFILE is not set."
    goto :fail
)
if not defined LOCALAPPDATA set "LOCALAPPDATA=%USERPROFILE%\AppData\Local"

rem Keep Windows files separate from the POSIX installations used by WSL and Git Bash.
if not defined GPR_INSTALL_DIR set "GPR_INSTALL_DIR=%LOCALAPPDATA%\Programs\git-push-remotes\app"
if not defined GPR_VENV_DIR set "GPR_VENV_DIR=%LOCALAPPDATA%\git-push-remotes\venv"
if not defined GPR_BIN_DIR set "GPR_BIN_DIR=%LOCALAPPDATA%\Programs\git-push-remotes\bin"

rem Normalize configured paths to absolute Windows paths.
for %%I in ("%GPR_INSTALL_DIR%") do set "GPR_INSTALL_DIR=%%~fI"
for %%I in ("%GPR_VENV_DIR%") do set "GPR_VENV_DIR=%%~fI"
for %%I in ("%GPR_BIN_DIR%") do set "GPR_BIN_DIR=%%~fI"
set "SOURCE_DIR=%~dp0"

rem Refuse unsafe or overlapping custom paths so uninstall.bat can safely reverse this installation.
set "GPR_USER_HOME=%USERPROFILE%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $homePath=[IO.Path]::GetFullPath($env:GPR_USER_HOME).TrimEnd('\'); $inputs=@($env:GPR_INSTALL_DIR,$env:GPR_VENV_DIR,$env:GPR_BIN_DIR); $paths=@(); foreach($p in $inputs){ if([string]::IsNullOrWhiteSpace($p)){ throw 'An installation path is empty.' }; $full=[IO.Path]::GetFullPath($p); $root=[IO.Path]::GetPathRoot($full); $norm=$full.TrimEnd('\'); if($norm -ieq $root.TrimEnd('\')){ throw ('Refusing to use a drive root: '+$full) }; if($norm -ieq $homePath){ throw ('Refusing to use the user home directory itself: '+$full) }; if($homePath.StartsWith($norm+'\',[StringComparison]::OrdinalIgnoreCase)){ throw ('Refusing to use a parent of the user home directory: '+$full) }; $paths+=,$norm }; for($i=0;$i -lt $paths.Count;$i++){ for($j=$i+1;$j -lt $paths.Count;$j++){ if($paths[$i] -ieq $paths[$j] -or $paths[$i].StartsWith($paths[$j]+'\',[StringComparison]::OrdinalIgnoreCase) -or $paths[$j].StartsWith($paths[$i]+'\',[StringComparison]::OrdinalIgnoreCase)){ throw 'Installation paths overlap. Check GPR_INSTALL_DIR, GPR_VENV_DIR, and GPR_BIN_DIR.' } } }" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=The configured paths failed safety checks. Verify GPR_INSTALL_DIR, GPR_VENV_DIR, and GPR_BIN_DIR."
    goto :fail
)

set "SOURCE_DIR=%~dp0"
if not exist "%SOURCE_DIR%git-push-remotes" (
    set "ERROR_MSG=Cannot find git-push-remotes next to install.bat. Run this installer from the extracted project directory."
    goto :fail
)

rem Find a supported Python installation. Prefer the Windows Python launcher.
set "PYTHON_CMD="
set "PYTHON_ARGS="
py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=py"
    set "PYTHON_ARGS=-3"
    goto :python_found
)
python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=python"
    set "PYTHON_ARGS="
    goto :python_found
)
python3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=python3"
    set "PYTHON_ARGS="
    goto :python_found
)
set "ERROR_MSG=Python 3.8 or newer was not found. Install Python for Windows from python.org or with: winget install Python.Python.3.12 - enable the PATH option, then run this installer again."
goto :fail

:python_found
git --version >nul 2>&1
if errorlevel 1 echo WARNING: Git was not found in PATH. "git push-remotes" needs Git for Windows: https://git-scm.com/download/win
rem Reset ERRORLEVEL so the checks below never see the result of the Git probe.
ver >nul
rem Create the required directories without administrator privileges.
for %%I in ("%GPR_INSTALL_DIR%") do set "INSTALL_PARENT=%%~dpI"
if not exist "%INSTALL_PARENT%" mkdir "%INSTALL_PARENT%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create the program installation parent directory."
    goto :fail
)
if not exist "%GPR_BIN_DIR%" mkdir "%GPR_BIN_DIR%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create the command directory."
    goto :fail
)
for %%I in ("%GPR_VENV_DIR%") do set "VENV_PARENT=%%~dpI"
if not exist "%VENV_PARENT%" mkdir "%VENV_PARENT%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create the Python environment parent directory."
    goto :fail
)

rem Stage the program files before replacing the current installation.
set "STAGE_DIR=%INSTALL_PARENT%.git-push-remotes.stage.%RANDOM%.%RANDOM%"
set "BACKUP_DIR=%INSTALL_PARENT%.git-push-remotes.backup.%RANDOM%.%RANDOM%"
set "LAUNCHER_SCRIPT_TMP=%GPR_BIN_DIR%\.git-push-remotes.%RANDOM%.tmp"
set "LAUNCHER_CMD_TMP=%GPR_BIN_DIR%\.git-push-remotes.%RANDOM%.cmd"
set "LAUNCHER_SCRIPT=%GPR_BIN_DIR%\git-push-remotes"
set "LAUNCHER_CMD=%GPR_BIN_DIR%\git-push-remotes.cmd"
set "LAUNCHER_SCRIPT_BACKUP=%GPR_BIN_DIR%\.git-push-remotes.backup.%RANDOM%.tmp"
set "LAUNCHER_CMD_BACKUP=%GPR_BIN_DIR%\.git-push-remotes.backup.%RANDOM%.cmd"
mkdir "%STAGE_DIR%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create a temporary staging directory."
    goto :fail
)

copy /B /Y "%SOURCE_DIR%git-push-remotes" "%STAGE_DIR%\git-push-remotes" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not copy the main program file."
    goto :fail
)
if exist "%SOURCE_DIR%git-push-remotes.py" copy /B /Y "%SOURCE_DIR%git-push-remotes.py" "%STAGE_DIR%\git-push-remotes.py" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not copy git-push-remotes.py."
    goto :fail
)
if exist "%SOURCE_DIR%requirements.txt" copy /B /Y "%SOURCE_DIR%requirements.txt" "%STAGE_DIR%\requirements.txt" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not copy requirements.txt."
    goto :fail
)
if exist "%SOURCE_DIR%README.md" copy /B /Y "%SOURCE_DIR%README.md" "%STAGE_DIR%\README.md" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not copy README.md."
    goto :fail
)
if exist "%SOURCE_DIR%LICENSE" copy /B /Y "%SOURCE_DIR%LICENSE" "%STAGE_DIR%\LICENSE" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not copy LICENSE."
    goto :fail
)

rem Create the virtual environment at its permanent location; venvs should not be moved.
if exist "%GPR_VENV_DIR%\Scripts\python.exe" goto :venv_ready
set "VENV_ARGS="
if exist "%GPR_VENV_DIR%" (
    if not exist "%GPR_VENV_DIR%\pyvenv.cfg" (
        set "ERROR_MSG=The configured virtual environment directory exists but is not a Python virtual environment. Remove it or set GPR_VENV_DIR to another path, then retry."
        goto :fail
    )
    echo The existing virtual environment is broken. Recreating it.
    set "VENV_ARGS=--clear"
)
set "VENV_CREATED=1"
call "%PYTHON_CMD%" %PYTHON_ARGS% -m venv %VENV_ARGS% "%GPR_VENV_DIR%"
if errorlevel 1 (
    set "ERROR_MSG=Could not create the Python virtual environment. Verify that your Python installation includes venv support."
    goto :fail
)

:venv_ready
"%GPR_VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 echo WARNING: Could not upgrade pip. Continuing with the version bundled with Python.
if exist "%SOURCE_DIR%requirements.txt" (
    "%GPR_VENV_DIR%\Scripts\python.exe" -m pip install -r "%SOURCE_DIR%requirements.txt"
) else (
    "%GPR_VENV_DIR%\Scripts\python.exe" -m pip install GitPython
)
if errorlevel 1 (
    set "ERROR_MSG=Could not install the dependencies. Check your network connection. If Python was upgraded or removed since the last installation, delete the virtual environment directory and retry."
    goto :fail
)

rem Create a CMD launcher for direct use and a shebang launcher for Git's external-command lookup.
set "GPR_LAUNCHER_SCRIPT_TMP=%LAUNCHER_SCRIPT_TMP%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; function Quote-Shell { param([string]$value) $single=[string][char]39; $escaped=$value.Replace($single,($single+'\'+$single+$single)); return $single+$escaped+$single }; $venv=$env:GPR_VENV_DIR.Replace('\','/'); if($venv -match '^([A-Za-z]):/(.*)$'){ $venv='/'+$matches[1].ToLower()+'/'+$matches[2] }; $app=$env:GPR_INSTALL_DIR.Replace('\','/'); if($app -match '^([A-Za-z]):/(.*)$'){ $app='/'+$matches[1].ToLower()+'/'+$matches[2] }; $double=[char]34; $suffix=' '+$double+'$@'+$double; $line='exec '+(Quote-Shell ($venv+'/Scripts/python.exe'))+' '+(Quote-Shell ($app+'/git-push-remotes'))+$suffix; $lf=[char]10; $content='#!/bin/sh'+$lf+$line+$lf; [IO.File]::WriteAllText($env:GPR_LAUNCHER_SCRIPT_TMP,$content,(New-Object System.Text.UTF8Encoding($false)))" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MSG=Could not create the Git external-command launcher."
    goto :fail
)
>"%LAUNCHER_CMD_TMP%" echo @echo off
if errorlevel 1 (
    set "ERROR_MSG=Could not create the CMD launcher."
    goto :fail
)
>>"%LAUNCHER_CMD_TMP%" echo rem Launcher generated by install.bat
>>"%LAUNCHER_CMD_TMP%" echo "%GPR_VENV_DIR%\Scripts\python.exe" "%GPR_INSTALL_DIR%\git-push-remotes" %%*
if errorlevel 1 (
    set "ERROR_MSG=Could not write the CMD launcher."
    goto :fail
)

rem Back up old launcher files before replacing them.
if exist "%LAUNCHER_SCRIPT%" (
    move "%LAUNCHER_SCRIPT%" "%LAUNCHER_SCRIPT_BACKUP%" >nul
    if errorlevel 1 (
        set "ERROR_MSG=Could not back up the previous Git command launcher."
        goto :fail
    )
)
if exist "%LAUNCHER_CMD%" (
    move "%LAUNCHER_CMD%" "%LAUNCHER_CMD_BACKUP%" >nul
    if errorlevel 1 (
        set "ERROR_MSG=Could not back up the previous CMD launcher."
        goto :fail
    )
)

rem Keep the previous program available for rollback until both launchers are installed.
if exist "%GPR_INSTALL_DIR%" (
    move "%GPR_INSTALL_DIR%" "%BACKUP_DIR%" >nul
    if errorlevel 1 (
        set "ERROR_MSG=Could not back up the previous program installation."
        goto :fail
    )
)
move "%STAGE_DIR%" "%GPR_INSTALL_DIR%" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not activate the new program installation."
    goto :fail
)
set "INSTALL_SWAPPED=1"
move /Y "%LAUNCHER_SCRIPT_TMP%" "%LAUNCHER_SCRIPT%" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not install the Git external-command launcher."
    goto :fail
)
set "SCRIPT_LAUNCHER_INSTALLED=1"
move /Y "%LAUNCHER_CMD_TMP%" "%LAUNCHER_CMD%" >nul
if errorlevel 1 (
    set "ERROR_MSG=Could not install the CMD launcher."
    goto :fail
)
set "CMD_LAUNCHER_INSTALLED=1"

if exist "%BACKUP_DIR%" rmdir /S /Q "%BACKUP_DIR%" >nul 2>&1
if exist "%LAUNCHER_SCRIPT_BACKUP%" del /F /Q "%LAUNCHER_SCRIPT_BACKUP%" >nul 2>&1
if exist "%LAUNCHER_CMD_BACKUP%" del /F /Q "%LAUNCHER_CMD_BACKUP%" >nul 2>&1
set "VENV_CREATED=0"
set "INSTALL_SWAPPED=0"

rem Add the launcher directory to the user's PATH without using setx.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $dir=$env:GPR_BIN_DIR; $targets=@($dir); $old=[Environment]::GetEnvironmentVariable('Path','User'); $parts=@($old -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }); $added=@(); foreach($target in $targets){ $present=$false; foreach($item in $parts){ if([string]::Equals($item.TrimEnd('\'),$target.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){ $present=$true } }; if(-not $present){ $added+=,$target } }; if($added.Count -gt 0){ $marker=Join-Path $dir '.git-push-remotes-path-added'; $existing=@(); if(Test-Path -LiteralPath $marker){ $existing=@(Get-Content -LiteralPath $marker) }; $managed=@($existing + $added | Select-Object -Unique); $new=@($added + $parts) -join ';'; Set-Content -LiteralPath $marker -Value $managed -Encoding UTF8; [Environment]::SetEnvironmentVariable('Path',$new,'User') }" >nul 2>&1
if errorlevel 1 echo WARNING: Could not update the current user's PATH automatically. Add "%GPR_BIN_DIR%" to your user PATH manually.

echo.
echo Installation completed successfully.
echo Program:      %GPR_INSTALL_DIR%
echo Python env:   %GPR_VENV_DIR%
echo Git launcher: %GPR_BIN_DIR%\git-push-remotes (shebang launcher for Git)
echo CMD launcher: %GPR_BIN_DIR%\git-push-remotes.cmd
echo.
echo Usage: git push-remotes
echo Open a new terminal for the updated PATH to take effect.
goto :success

:fail
if defined STAGE_DIR if exist "%STAGE_DIR%" rmdir /S /Q "%STAGE_DIR%" >nul 2>&1
if defined LAUNCHER_SCRIPT_TMP if exist "%LAUNCHER_SCRIPT_TMP%" del /F /Q "%LAUNCHER_SCRIPT_TMP%" >nul 2>&1
if defined LAUNCHER_CMD_TMP if exist "%LAUNCHER_CMD_TMP%" del /F /Q "%LAUNCHER_CMD_TMP%" >nul 2>&1
if "%INSTALL_SWAPPED%"=="1" if exist "%GPR_INSTALL_DIR%" rmdir /S /Q "%GPR_INSTALL_DIR%" >nul 2>&1
if defined BACKUP_DIR if exist "%BACKUP_DIR%" if not exist "%GPR_INSTALL_DIR%" move "%BACKUP_DIR%" "%GPR_INSTALL_DIR%" >nul
if "%SCRIPT_LAUNCHER_INSTALLED%"=="1" if exist "%LAUNCHER_SCRIPT%" del /F /Q "%LAUNCHER_SCRIPT%" >nul 2>&1
if "%CMD_LAUNCHER_INSTALLED%"=="1" if exist "%LAUNCHER_CMD%" del /F /Q "%LAUNCHER_CMD%" >nul 2>&1
if defined LAUNCHER_SCRIPT_BACKUP if exist "%LAUNCHER_SCRIPT_BACKUP%" if not exist "%LAUNCHER_SCRIPT%" move "%LAUNCHER_SCRIPT_BACKUP%" "%LAUNCHER_SCRIPT%" >nul
if defined LAUNCHER_CMD_BACKUP if exist "%LAUNCHER_CMD_BACKUP%" if not exist "%LAUNCHER_CMD%" move "%LAUNCHER_CMD_BACKUP%" "%LAUNCHER_CMD%" >nul
if "%VENV_CREATED%"=="1" if exist "%GPR_VENV_DIR%" rmdir /S /Q "%GPR_VENV_DIR%" >nul 2>&1
echo ERROR: %ERROR_MSG% 1>&2
endlocal & exit /b 1

:success
endlocal & exit /b 0
