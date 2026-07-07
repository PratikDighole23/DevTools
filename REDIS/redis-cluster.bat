
@echo off
setlocal enabledelayedexpansion

echo Starting Redis Cluster Nodes...

set REDIS_PATH=C:\Users\pratik.2802367\Documents\Redis-x64-5.0.14.1
set PORTS=7000 7001 7002 7003 7004 7005

if not exist "%REDIS_PATH%\redis-server.exe" (
    echo redis-server.exe not found at "%REDIS_PATH%"
    pause
    exit /b 1
)

if not exist "%REDIS_PATH%\redis-cli.exe" (
    echo redis-cli.exe not found at "%REDIS_PATH%"
    pause
    exit /b 1
)

echo.
echo Creating node folders...

for %%P in (%PORTS%) do (
    if not exist "%REDIS_PATH%\%%P" mkdir "%REDIS_PATH%\%%P"
)

echo.
echo Starting Redis nodes...

for %%P in (%PORTS%) do (
    start "Redis Node %%P" /D "%REDIS_PATH%\%%P" cmd /k ""%REDIS_PATH%\redis-server.exe" --port %%P --bind 127.0.0.1 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes --dir "%REDIS_PATH%\%%P""
)

echo.
echo Waiting for Redis nodes to respond...

set ALL_READY=0

for /L %%A in (1,1,20) do (
    set READY_COUNT=0

    for %%P in (%PORTS%) do (
        "%REDIS_PATH%\redis-cli.exe" -h 127.0.0.1 -p %%P ping >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            set /A READY_COUNT+=1
        )
    )

    echo Ready nodes: !READY_COUNT! / 6

    if !READY_COUNT! EQU 6 (
        set ALL_READY=1
        goto NODES_READY
    )

    timeout /t 2 /nobreak >nul
)

:NODES_READY

if "%ALL_READY%" NEQ "1" (
    echo.
    echo Redis nodes did not start properly.
    echo Check the opened Redis Node windows for startup errors.
    pause
    exit /b 1
)

echo.
echo Checking whether cluster is already OK...

"%REDIS_PATH%\redis-cli.exe" -h 127.0.0.1 -p 7000 cluster info | findstr /C:"cluster_state:ok" >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo Redis cluster is already OK.
    "%REDIS_PATH%\redis-cli.exe" -h 127.0.0.1 -p 7000 cluster info
    goto END
)

echo.
echo Creating Redis cluster...

echo yes | "%REDIS_PATH%\redis-cli.exe" --cluster create 127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 --cluster-replicas 1

echo.
echo Waiting for cluster to stabilize...
timeout /t 3 /nobreak >nul

echo.
echo Cluster info:
"%REDIS_PATH%\redis-cli.exe" -h 127.0.0.1 -p 7000 cluster info

echo.
echo Cluster nodes:
"%REDIS_PATH%\redis-cli.exe" -h 127.0.0.1 -p 7000 cluster nodes

echo.
echo Cluster slots:
"%REDIS_PATH%\redis-cli.exe" -h 127.0.0.1 -p 7000 cluster slots

:END
echo.
echo Done.
pause
