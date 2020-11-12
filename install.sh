#!/usr/bin/env bash

#    Copyright 2020 IBM

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#        http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

if test -f mc-demo-installation-image.tar.gz; then
    echo 'Loading Installation Environment...'
    docker load -i mc-demo-installation-image.tar.gz
    echo Done.
    echo 
fi

echo Running Installation Environment...
hostname=$(hostname | tr '[:upper:]' '[:lower:]')
ip_address=$(hostname --ip-address 2> /dev/null || (ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | awk '{print$1; exit}'))
docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v ~/.kube/:/root/.kube/ -v $(pwd)/docker-images.tar.gz:/deployment/docker-images.tar.gz -v $(pwd)/helm-chart.tar.gz:/deployment/helm-chart.tar.gz  -e INSTALL_HOSTNAME=$hostname -e INSTALL_IP_ADDRESS=$ip_address quay.io/futureworkshops/ibm-amc-local-deployment:3ca85d7150acef823b4677623afff65452d08b6a
echo Done.
echo

echo Cleaning Installation Environment...
docker image rm quay.io/futureworkshops/ibm-amc-local-deployment:3ca85d7150acef823b4677623afff65452d08b6a
echo Done.
echo