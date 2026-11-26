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
for /f "usebackq tokens=1,2,3,4,5 delims=|" %%a in (`%PY% -c "import json; d=json.load(open('building/libs.json')); [print('|'.join([x.get('type','') or '-',x.get('name','') or '-',x.get('version','') or '-',x.get('url','') or '-',x.get('ref','') or '-'])) for x in d.get('dependencies',[])]"`) do (
	set "T=%%a" & set "N=%%b" & set "V=%%c" & set "U=%%d" & set "R=%%e"
	if "!V!"=="-" set "V="
	if "!R!"=="-" set "R="
	if /i "!T!"=="git" (
		rem Instalado solo si la URL coincide y el checkout esta en el ref pedido (tag o rama).
		set "INSTALAR=1"
		set "REFOK="
		haxelib list !N! 2>nul | findstr /c:"[git]" >nul && (
			git -C "%HAXELIB_REPO%\!N!\git" remote get-url origin 2>nul | findstr /x /c:"!U!" >nul && (
				set "INSTALAR="
				if not "!R!"=="" (
					for /f "delims=" %%r in ('git -C "%HAXELIB_REPO%\!N!\git" describe --tags --exact-match HEAD 2^>nul') do if "%%r"=="!R!" set "REFOK=1"
					if not defined REFOK (
						for /f "delims=" %%r in ('git -C "%HAXELIB_REPO%\!N!\git" rev-parse --abbrev-ref HEAD 2^>nul') do if "%%r"=="!R!" set "REFOK=1"
					)
					if not defined REFOK set "INSTALAR=1"
				)
			)
		)
		if defined INSTALAR (
			echo    instalando !N! ^(git^)
			if "!R!"=="" (haxelib git !N! !U! --always --quiet) else (haxelib git !N! !U! !R! --always --quiet)
			if errorlevel 1 (
				echo    haxelib git fallo, intentando clone manual...
				if exist "%HAXELIB_REPO%\!N!\git" rmdir /s /q "%HAXELIB_REPO%\!N!\git"
				if not exist "%HAXELIB_REPO%\!N!" mkdir "%HAXELIB_REPO%\!N!"
				set "GIT_TERMINAL_PROMPT=0"
				if "!R!"=="" (git clone --recursive --depth 1 !U! "%HAXELIB_REPO%\!N!\git" || exit /b 1) else (git clone --recursive --depth 1 --branch !R! !U! "%HAXELIB_REPO%\!N!\git" || exit /b 1)
				echo git> "%HAXELIB_REPO%\!N!\.current"
			)
		)
	) else if /i "!T!"=="haxelib" (
		if not "!V!"=="" (
			haxelib list !N! 2>nul | findstr /c:"[!V!]" >nul || (
				echo    instalando !N! !V!
				haxelib install !N! !V! --always --quiet || haxelib install !N! --always --quiet || exit /b 1
				haxelib set !N! !V! >nul 2>nul
			)
		) else (
			haxelib path !N! >nul 2>nul || (echo    instalando !N! & haxelib install !N! --always --quiet || exit /b 1)
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
	haxelib run lime rebuild funkfmpeg windows -64 || exit /b 1
	rem Si el Build.xml de funkfmpeg aun nombra el ndll con sufijo MSVC -19, lime busca funkfmpeg.ndll: se copia con el nombre correcto.
	set "FFDIR=%HAXELIB_REPO%\funkfmpeg\git\ndll\Windows64"
	if not exist "!FFDIR!\funkfmpeg.ndll" if exist "!FFDIR!\funkfmpeg-19.ndll" (echo =^> funkfmpeg-19.ndll a funkfmpeg.ndll & copy /y "!FFDIR!\funkfmpeg-19.ndll" "!FFDIR!\funkfmpeg.ndll" >nul)
	if not exist "!FFDIR!\funkfmpeg.ndll" (echo build.bat: no se genero !FFDIR!\funkfmpeg.ndll & dir "!FFDIR!" & exit /b 1)
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
