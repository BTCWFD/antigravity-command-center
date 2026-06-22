@echo off
title Compilador de APK de Antigravity
echo ====================================================================
echo             COMPILADOR DE APK DE ANTIGRAVITY COMMAND CENTER
echo ====================================================================
echo.

:: Comprobar si flutter está disponible en el PATH
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ADVERTENCIA] No se detecta 'flutter' en el PATH del sistema.
    echo.
    echo Si tienes el SDK de Flutter instalado en una carpeta personalizada,
    echo por favor introduce la ruta completa hasta el directorio 'bin'.
    echo (Ejemplo: C:\src\flutter\bin)
    echo.
    set /p FLUTTER_BIN_PATH="Introduce la ruta de Flutter bin (o presiona ENTER para cancelar): "
    
    if "%FLUTTER_BIN_PATH%"=="" (
        echo Cancelado. Asegurate de instalar Flutter y agregarlo a tu PATH.
        pause
        exit /b 1
    )
    
    :: Agregar temporalmente al PATH para esta sesion
    set PATH=%PATH%;%FLUTTER_BIN_PATH%
)

echo.
echo [+] Verificando version de Flutter...
call flutter --version
if %errorlevel% neq 0 (
    echo [ERROR] No se pudo ejecutar Flutter. Verifica la ruta ingresada.
    pause
    exit /b 1
)

echo.
echo [+] Limpiando compilaciones previas...
call flutter clean

echo.
echo [+] Descargando dependencias de Flutter...
call flutter pub get

echo.
echo [+] Compilando el APK de produccion (Release)...
call flutter build apk --release

if %errorlevel% eq 0 (
    echo.
    echo ====================================================================
    echo [+] COMPILACION COMPLETADA CON EXITO!
    echo [+] Tu archivo APK listo para Android se encuentra en:
    echo     build\app\outputs\flutter-apk\app-release.apk
    echo ====================================================================
    echo.
    echo Abriendo la carpeta del APK...
    explorer build\app\outputs\flutter-apk\
) else (
    echo.
    echo [ERROR] La compilacion del APK fallo. Verifica los logs anteriores.
)

pause
