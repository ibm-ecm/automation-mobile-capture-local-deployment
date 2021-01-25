@echo off

@REM   Copyright 2020 IBM

@REM   Licensed under the Apache License, Version 2.0 (the "License");
@REM   you may not use this file except in compliance with the License.
@REM   You may obtain a copy of the License at

@REM       http://www.apache.org/licenses/LICENSE-2.0

@REM   Unless required by applicable law or agreed to in writing, software
@REM   distributed under the License is distributed on an "AS IS" BASIS,
@REM   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@REM   See the License for the specific language governing permissions and
@REM   limitations under the License.

IF EXIST "mc-demo-installation-image.tar.gz" (
    ECHO Loading Installation Environment...
    docker load -i mc-demo-installation-image.tar.gz
    ECHO Done.
    ECHO -
)

FOR /F "usebackq" %%i IN (`hostname`) DO SET COMPUTERHOSTNAME=%%i

FOR /f "tokens=14" %%a IN ('ipconfig ^| findstr IPv4') do (
  SET IPADDRESS=%%a
  GOTO ipbreak
) 
:ipbreak

ECHO Running Installation Environment...
docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v %USERPROFILE%/.kube/:/root/.kube/ -v %cd%\docker-images.tar.gz:/deployment/docker-images.tar.gz -v %cd%\helm-chart.tar.gz:/deployment/helm-chart.tar.gz -e INSTALL_HOSTNAME=%COMPUTERHOSTNAME% -e INSTALL_IP_ADDRESS=%IPADDRESS% quay.io/futureworkshops/ibm-amc-local-deployment:3ca85d7150acef823b4677623afff65452d08b6a
ECHO Done.
ECHO -

ECHO Cleaning Installation Environment...
docker image rm quay.io/futureworkshops/ibm-amc-local-deployment:3ca85d7150acef823b4677623afff65452d08b6a
ECHO Done.
ECHO -
