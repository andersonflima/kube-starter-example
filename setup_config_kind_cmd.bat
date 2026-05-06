@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage:
    echo setup-kind-artifactory.bat artifactory.company.com
    exit /b 1
)

set ARTIFACTORY=%~1

echo.
echo =========================================
echo KIND + ARTIFACTORY CONFIG
echo =========================================
echo.

REM ----------------------------------------
REM PATHS
REM ----------------------------------------

set KIND_CERT_DIR=%USERPROFILE%\.kind\certs\%ARTIFACTORY%
set DOCKER_CERT_DIR=C:\ProgramData\Docker\certs.d\%ARTIFACTORY%

echo [1/9] Creating directories...

mkdir "%KIND_CERT_DIR%" 2>nul
mkdir "%DOCKER_CERT_DIR%" 2>nul

REM ----------------------------------------
REM CHECK OPENSSL
REM ----------------------------------------

echo [2/9] Checking openssl...

where openssl >nul 2>nul

if errorlevel 1 (
    echo.
    echo ERROR: openssl not found
    echo.
    echo Install:
    echo choco install openssl -y
    echo.
    exit /b 1
)

REM ----------------------------------------
REM DOWNLOAD CERT
REM ----------------------------------------

echo [3/9] Downloading certificate...

cd /d "%KIND_CERT_DIR%"

openssl s_client -showcerts -connect %ARTIFACTORY%:443 <nul 2>nul | openssl x509 -outform PEM > ca.crt

if not exist ca.crt (
    echo ERROR: failed downloading certificate
    exit /b 1
)

REM ----------------------------------------
REM COPY TO DOCKER
REM ----------------------------------------

echo [4/9] Installing Docker cert...

copy /Y ca.crt "%DOCKER_CERT_DIR%\ca.crt" >nul

REM ----------------------------------------
REM CREATE HOSTS.TOML
REM ----------------------------------------

echo [5/9] Creating hosts.toml...

(
echo server = "https://%ARTIFACTORY%"
echo.
echo [host."https://%ARTIFACTORY%"]
echo   capabilities = ["pull", "resolve", "push"]
echo   ca = "/etc/containerd/certs.d/%ARTIFACTORY%/ca.crt"
) > hosts.toml

REM ----------------------------------------
REM CREATE KIND CONFIG
REM ----------------------------------------

echo [6/9] Creating kind-config.yaml...

(
echo kind: Cluster
echo apiVersion: kind.x-k8s.io/v1alpha4
echo.
echo containerdConfigPatches:
echo   - ^|-
echo     [plugins."io.containerd.grpc.v1.cri".registry]
echo       config_path = "/etc/containerd/certs.d"
echo.
echo nodes:
echo   - role: control-plane
echo     extraMounts:
echo       - hostPath: %KIND_CERT_DIR:\=/%
echo         containerPath: /etc/containerd/certs.d/%ARTIFACTORY%
echo.
echo   - role: worker
echo     extraMounts:
echo       - hostPath: %KIND_CERT_DIR:\=/%
echo         containerPath: /etc/containerd/certs.d/%ARTIFACTORY%
) > "%USERPROFILE%\kind-config.yaml"

REM ----------------------------------------
REM RESTART DOCKER
REM ----------------------------------------

echo [7/9] Restarting Docker Desktop...

taskkill /F /IM "Docker Desktop.exe" >nul 2>nul

timeout /t 5 >nul

start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"

echo Waiting Docker startup...

:docker_wait
docker info >nul 2>nul

if errorlevel 1 (
    timeout /t 2 >nul
    goto docker_wait
)

REM ----------------------------------------
REM DELETE CLUSTER
REM ----------------------------------------

echo [8/9] Removing old cluster...

kind delete cluster

REM ----------------------------------------
REM CREATE CLUSTER
REM ----------------------------------------

echo [9/9] Creating cluster...

kind create cluster --config "%USERPROFILE%\kind-config.yaml"

echo.
echo =========================================
echo CONFIGURATION FINISHED
echo =========================================
echo.

echo Test:
echo docker exec -it kind-control-plane bash
echo ctr image pull %ARTIFACTORY%/my-image:latest
echo.
