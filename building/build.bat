@echo off
rem FMCE - build para Windows.   building\build.bat <hl|cpp> <debug|release> [args extra para lime]
rem Instala las libs de building\libs.json, compila con lime y deja
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

echo =^> Dependencias ^(building\libs.json^)
set "PY="
py -3 --version >nul 2>nul && set "PY=py -3"
if not defined PY (python --version >nul 2>nul && set "PY=python")
if not defined PY (echo build.bat: falta Python 3 ^(necesario para leer building\libs.json^) & exit /b 127)
for /f "delims=" %%i in ('haxelib config 2^>nul') do if not defined HAXELIB_REPO set "HAXELIB_REPO=%%i"
if not defined HAXELIB_REPO set "HAXELIB_REPO=%USERPROFILE%\haxelib"
for /f "usebackq tokens=1,2,3,4,5 delims=|" %%a in (`%PY% -c "import json; d=json.load(open('building/libs.json')); [print('|'.join([x.get('type',''),x.get('name',''),x.get('version','') or '',x.get('url','') or '',x.get('ref','') or ''])) for x in d.get('dependencies',[])]"`) do (
	if /i "%%a"=="git" (
		haxelib list %%b 2>nul | findstr /c:"[git]" >nul && git -C "%HAXELIB_REPO%\%%b\git" remote get-url origin 2>nul | findstr /x /c:"%%d" >nul && (
			rem ya instalado
		) || (
			echo    instalando %%b ^(git^)
			if "%%e"=="" (haxelib git %%b %%d --always >nul || exit /b 1) else (haxelib git %%b %%d %%e --always >nul || exit /b 1)
		)
	) else if /i "%%a"=="haxelib" (
		if not "%%c"=="" (
			haxelib list %%b 2>nul | findstr /c:"[%%c]" >nul || (
				echo    instalando %%b %%c
				haxelib install %%b %%c --always >nul 2>nul || haxelib install %%b --always >nul
				haxelib set %%b %%c >nul 2>nul
			)
		) else (
			haxelib path %%b >nul 2>nul || (echo    instalando %%b & haxelib install %%b --always >nul || exit /b 1)
		)
	)
)

rem -- Assets -^> assets.pack: assets\ se compila en building\_pack\assets.pack (Project.xml lo mete en el build)
set "PY="
py -3 --version >nul 2>nul && set "PY=py -3"
if not defined PY (python --version >nul 2>nul && set "PY=python")
if not defined PY (echo build.bat: falta Python 3 ^(building\pack-assets.py arma assets.pack^) & exit /b 127)
echo =^> Empaquetando assets\ en assets.pack
%PY% building\pack-assets.py --verify || exit /b 1

set "ARGS=build windows"
if /i "%KIND%"=="hl" set "ARGS=%ARGS% -hl"
if /i "%MODE%"=="debug" set "ARGS=%ARGS% -debug"
shift
shift
set "EXTRA=%1 %2 %3 %4 %5 %6 %7 %8 %9"

rem funkfmpeg: ndll nativo para cpp desktop (no viene precompilado en el repo git)
if /i "%KIND%"=="cpp" (
	echo =^> Recompilando ndll funkfmpeg ^(windows^)
	haxelib run lime rebuild funkfmpeg windows || exit /b 1
)

echo =^> FMCE %KIND% %MODE% ^(windows^)
haxelib run lime %ARGS% %EXTRA% || exit /b 1

if /i "%KIND%"=="hl" (set "BIN=export\%MODE%\hl\bin") else (set "BIN=export\%MODE%\windows\bin")
if not exist "%BIN%" (echo build.bat: no hay carpeta bin en %BIN% & exit /b 1)


if not exist building\artifacts mkdir building\artifacts
set "OUT=%CD%\building\artifacts\FMCE-Windows-x64-%KIND%-%MODE%.zip"
if exist "%OUT%" del "%OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%BIN%\*' -DestinationPath '%OUT%' -Force" || exit /b 1
echo =^> Listo: %OUT%
