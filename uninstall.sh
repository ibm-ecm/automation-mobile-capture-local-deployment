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

# fail if any commands fails
# set -e
# debug log
# set -x

echo
echo "⚙️  Deleting Helm Chart..."
helm delete mobilecapture-demo
echo "✅ Done."

echo
echo "⚙️  Removing Certificate Authority..."
kubectl delete clusterissuers/ca-clusterissuer -n cert-manager
kubectl delete secret/certificate-authority -n cert-manager
echo "✅ Done."

echo
echo "⚙️  Removing Secrets..."
kubectl delete secret/mobilecapture-demo
kubectl delete secret/mobilecapture-demo-smtp
kubectl delete secret/mobilecapture-demo-admin-seed
kubectl delete secret/mobilecapture-demo-postgresql
echo "✅ Done."

echo
echo "⚙️  Removing root CA certificate server..."
kubectl delete ingress/mobilecapture-demo-nginx
kubectl delete service/mobilecapture-demo-nginx
kubectl delete deployment/mobilecapture-demo-nginx
kubectl delete configmap/mobilecapture-demo-nginx-ca-certificate
kubectl delete configmap/mobilecapture-demo-nginx-conf
echo "✅ Done."

echo
echo "⚙️  Removing Persistent Volume Claims..."
kubectl delete pvc/data-mobilecapture-demo-postgresql-0
kubectl delete pvc/mobilecapture-demo-mobile-capture-upload
echo "✅ Done."