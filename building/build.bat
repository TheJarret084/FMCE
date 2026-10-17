@echo off
rem FMCE - build para Windows.   building\build.bat <hl|cpp> <debug|release> [args extra para lime]
rem Instala las libs de building\libs.txt, compila con lime y deja
rem building\artifacts\FMCE-Windows-x64-<target>-<type>.zip   (el CI depende de ese nombre)
setlocal EnableDelayedExpansion
set "KIND=%~1"
set "MODE=%~2"
if "%KIND%"=="" set "KIND=cpp"
if "%MODE%"=="" set "MODE=release"
if /i not "%KIND%"=="hl" if /i not "%KIND%"=="cpp" (echo build.bat: target "%KIND%" no valido ^(hl, cpp^) & exit /b 2)
if /i not "%MODE%"=="debug" if /i not "%MODE%"=="release" (echo build.bat: modo "%MODE%" no valido ^(debug, release^) & exit /b 2)

cd /d "%~dp0.."
if not exist building\alsoft.txt (echo build.bat: falta building\alsoft.txt & exit /b 1)
where haxelib >nul 2>nul || (echo build.bat: haxe/haxelib no estan en PATH ^(Haxe 4.3.7^) & exit /b 127)

echo =^> Dependencias ^(building\libs.txt^)
for /f "usebackq eol=# tokens=1,2,3,4" %%a in ("building\libs.txt") do (
	if /i "%%b"=="git" (
		haxelib path %%a >nul 2>nul || (echo    instalando %%a ^(git^) & haxelib git %%a %%c %%d --always >nul || exit /b 1)
	) else if "%%b"=="" (
		haxelib path %%a >nul 2>nul || (echo    instalando %%a & haxelib install %%a --always >nul || exit /b 1)
	) else (
		haxelib list %%a 2>nul | findstr /c:"[%%b]" >nul || (
			echo    instalando %%a %%b
			haxelib install %%a %%b --always >nul 2>nul || haxelib install %%a --always >nul
			haxelib set %%a %%b >nul 2>nul
		)
	)
)

set "ARGS=build windows"
if /i "%KIND%"=="hl" set "ARGS=%ARGS% -hl"
if /i "%MODE%"=="debug" set "ARGS=%ARGS% -debug"
shift
shift
set "EXTRA=%1 %2 %3 %4 %5 %6 %7 %8 %9"

echo =^> FMCE %KIND% %MODE% ^(windows^)
haxelib run lime %ARGS% %EXTRA% || exit /b 1

if /i "%KIND%"=="hl" (set "BIN=export\%MODE%\hl\bin") else (set "BIN=export\%MODE%\windows\bin")
if not exist "%BIN%" (echo build.bat: no hay carpeta bin en %BIN% & exit /b 1)

if not exist building\artifacts mkdir building\artifacts
set "OUT=%CD%\building\artifacts\FMCE-Windows-x64-%KIND%-%MODE%.zip"
if exist "%OUT%" del "%OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%BIN%\*' -DestinationPath '%OUT%' -Force" || exit /b 1
echo =^> Listo: %OUT%
