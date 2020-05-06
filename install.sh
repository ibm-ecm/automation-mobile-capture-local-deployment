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
set -e
# debug log
# set -x

function retry {
  local retries=$1
  shift

  local count=0
  until "$@"; do
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1))
    if [ $count -lt $retries ]; then
      echo "Retry $count/$retries exited $exit, retrying in $wait seconds..."
      sleep $wait
    else
      echo "Retry $count/$retries exited $exit, no more retries left."
      return $exit
    fi
  done
  return 0
}

yq() {
    docker run --rm -v "$(pwd)":/workdir mikefarah/yq yq $@
}

helm() {
    docker run -ti --rm --network host -v "$(pwd)":/apps -v ~/.kube:/root/.kube -v "$helm_root"/.helm:/root/.helm:rw -v "$helm_root"/.helm_cache:/root/.cache/helm:rw -v "$helm_root"/.helm_config:/root/.config/helm:rw alpine/helm $@
}

function test_local_environment {
    if ! [[ $(command -v docker) ]]; then
        echo "🚫 Couldn't find 'docker' command."
        exit
    fi
    if ! [[ $(command -v kubectl) ]]; then
        echo "🚫 Couldn't find 'kubectl' command."
        exit
    fi

    local context=$(kubectl config current-context)
    echo 
    echo "ℹ️  You're about to install Mobile Capture into the kubernetes"
    echo "   context with name '$context'."
    echo
    echo "⚠️  Please make sure this context is your local kubernetes context."
    echo
    echo "   By continuing you agree with the following:"
    cat << EOF 
   |
   | Copyright 2020 IBM
   | 
   | Licensed under the Apache License, Version 2.0 (the "License");
   | you may not use this file except in compliance with the License.
   | You may obtain a copy of the License at
   | 
   |     http://www.apache.org/licenses/LICENSE-2.0
   | 
   | Unless required by applicable law or agreed to in writing, software
   | distributed under the License is distributed on an "AS IS" BASIS,
   | WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   | See the License for the specific language governing permissions and
   | limitations under the License.
   |
EOF
    echo

    local areyousure=''
    read -p "⚠️  Are you sure you want to install with context '$context' [Y/n]: " areyousure
    if ! [[ $areyousure == 'Y' || $areyousure == 'y' || $areyousure == '' || $areyousure == 'yes' || $areyousure == 'Yes' || $areyousure == 'YES' ]]; then
        echo "🚫 Aborting."
        exit
    fi
    
    # if the context is not "docker-desktop" (kubernetes single-node cluster provided by docker desktop)
    # then try to find minikube and point docker to the minikube environment
    if ! [[ $context == "docker-desktop" ]]; then
        if ! [[ $(command -v minikube) ]]; then
            echo "🚫 Couldn't find 'minikube' command."
            exit
        else
            eval $(minikube docker-env)
        fi
    fi
}

function load_docker_images {
    echo
    echo "⚙️  Loading images into Docker..."
    rails_image_registry=$(yq read values.images.yaml images.rails.registry)
    rails_image_repository=$(yq read values.images.yaml images.rails.repository)
    rails_image_tag=$(yq read values.images.yaml images.rails.tag)
    rails_image="$rails_image_registry/$rails_image_repository:$rails_image_tag"
    react_image_registry=$(yq read values.images.yaml images.react.registry)
    react_image_repository=$(yq read values.images.yaml images.react.repository)
    react_image_tag=$(yq read values.images.yaml images.react.tag)
    react_image="$react_image_registry/$react_image_repository:$react_image_tag"

    needs_to_load_images=false
    if ! [[ $(docker image ls -q $rails_image) ]]; then
        needs_to_load_images=true
    fi
    if ! [[ $(docker image ls -q $react_image) ]]; then
        needs_to_load_images=true
    fi

    if [ "$needs_to_load_images" = true ] ; then
        local images_tar=$(echo docker-images-*.tar*) 
        if test -f $images_tar; then
            docker load < $images_tar 1> /dev/null
        else
            echo
            echo "🚫 Couldn't find tar file with required images."
            echo
            echo "ℹ️  Please make sure you have the tar archive with the docker images"
            echo "   in this directory. It should be named 'docker-images-<number>.tar[.gz]'."
            echo
            exit
        fi
    else
        echo "✅ Found images in local docker. Skipping loading."
    fi
    echo "✅ Done."
    echo 
}

function setup_helm {
    mkdir -p .helm
    mkdir -p .helm_cache
    mkdir -p .helm_config
    docker pull alpine/helm:latest 1> /dev/null
    helm_root=$(pwd)
    helm repo add stable https://kubernetes-charts.storage.googleapis.com 1> /dev/null
    helm repo update 1> /dev/null
}

function setup_ingress_controller {
    if ! [[ $(kubectl get pods --all-namespaces | grep ingress) ]]; then
        echo "⚠️ Couldn't find an ingress controller. Installing..."
        if [[ $(kubectl api-versions | grep rbac) ]]; then
            echo "ℹ️ RBAC is enabled for this cluster."
            echo "⚙️ Installing nginx-ingress Helm Chart creating RBAC roles..."
            helm install nginx-ingress stable/nginx-ingress --set rbac.create=true --wait 1> /dev/null
            echo "✅ Done."
        else
            echo "⚙️  Installing nginx-ingress Helm Chart..."
            helm install nginx-ingress stable/nginx-ingress --wait 1> /dev/null
            echo "✅ Done."
        fi
    else
        echo "✅ Found an ingress controller. Skipping installation."
    fi
}

function setup_cert-manager {
    if ! [[ $(helm list -f cert-manager -n cert-manager | grep cert-manager) ]]; then
        echo "⚠️ Couldn't find 'cert-manager'. Installing..."
        kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/v0.13.0/deploy/manifests/00-crds.yaml 1> /dev/null
        kubectl create namespace cert-manager --save-config --dry-run=true -o yaml | kubectl apply -f - &> /dev/null
        helm repo add jetstack https://charts.jetstack.io 1> /dev/null
        helm repo update 1> /dev/null
        helm install cert-manager \
        --namespace cert-manager \
        --version v0.13.0 \
        jetstack/cert-manager \
        --wait \
        1> /dev/null
        sleep 10
        echo "✅ Done."
    else
        echo "✅ Found 'cert-manager'. Skipping installation."
    fi
}

function setup_requirements {
    echo
    echo "⚙️  Setting up requirements..."
    setup_ingress_controller
    setup_cert-manager
    echo "✅ Requirements."
}

function setup_secrets {
    echo 
    echo "⚙️  Setting up secrets..."
    if ! [[ $(kubectl get secret | grep "mobilecapture-demo ") ]]; then
        kubectl create secret generic mobilecapture-demo --from-literal=secret-key-base=$(openssl rand -hex 64) &> /dev/null
        echo "✅ Created 'secret/mobilecapture-demo'."
    else
        echo "✅ 'secret/mobilecapture-demo' already exists."
    fi
    if ! [[ $(kubectl get secret | grep mobilecapture-demo-smtp) ]]; then
        kubectl create secret generic mobilecapture-demo-smtp --from-literal=smtp-password="anonymous" &> /dev/null
        echo "✅ Created 'secret/mobilecapture-demo-smtp'."
    else
        echo "✅ 'secret/mobilecapture-demo-smtp' already exists."
    fi
    if ! [[ $(kubectl get secret | grep mobilecapture-demo-admin-seed) ]]; then
        kubectl create secret generic mobilecapture-demo-admin-seed --from-literal=password="adminpassword" &> /dev/null
        echo "✅ Created 'secret/mobilecapture-demo-admin-seed'."
    else
        echo "✅ 'secret/mobilecapture-demo-admin-seed' already exists."
    fi
    if ! [[ $(kubectl get secret | grep mobilecapture-demo-postgresql) ]]; then
        kubectl create secret generic mobilecapture-demo-postgresql --from-literal=postgresql-password="$(openssl rand -hex 16)" &> /dev/null
        echo "✅ Created 'secret/mobilecapture-demo-postgresql'."
    else
        echo "✅ 'secret/mobilecapture-demo-postgresql' already exists."
    fi
    echo "✅ Secrets."
}

function setup_certificate_authority {
    echo
    echo "⚙️  Setting up Certificate Authority..."

    if ! test -f ca.crt -a -f ca.key; then
        echo "⚙️  Generating Certificate Authority private key and certificate..."
        docker build -t easyrsa:latest -f ./ca/Dockerfile.easyrsa ./ca/ &> /dev/null
        # easyrsa reference: https://kubernetes.io/docs/concepts/cluster-administration/certificates/
        docker run --rm -it -v "$(pwd)":/pki easyrsa init-pki &> /dev/null
        docker run --rm -it -v "$(pwd)":/pki easyrsa --batch "--req-cn=IBM Mobile Capture Demo CA" build-ca nopass &> /dev/null
        cp easyrsa-ca/ca.crt ca.crt
        cp easyrsa-ca/private/ca.key ca.key
        rm -rf easyrsa-ca
        echo "✅ Done."
    else
        echo "✅ Found Certificate Authority private key and certificate. Skipping generation."
    fi

    kubectl -n cert-manager create secret tls certificate-authority --cert=ca.crt --key=ca.key --save-config --dry-run=true -o yaml | kubectl apply -f - &> /dev/null

    if ! [[ $(kubectl get clusterissuers -n cert-manager | grep ca-clusterissuer &> /dev/null) ]]; then
        echo "⚙️  Creating ClusterIssuer..."
        retry 10 kubectl -n cert-manager apply -f ca/clusterissuer.yaml 1> /dev/null
        echo "✅ Created ClusterIssuer."
    else
        echo "✅ ClusterIssuer found. Skipping creation."
    fi
    echo "✅ Certificate Authority."
}

function deploy_ca-certificate-server {
    echo
    echo "⚙️  Installing root CA certificate server..."
    kubectl create configmap mobilecapture-demo-nginx-ca-certificate --from-file=ca.crt --save-config --dry-run=true -o yaml | kubectl apply -f - &> /dev/null
    kubectl create configmap mobilecapture-demo-nginx-conf --from-file=./ca-certificate-server/nginx.conf --save-config --dry-run=true -o yaml | kubectl apply -f - &> /dev/null
    kubectl apply -f ca-certificate-server/k8s-nginx.yaml 1> /dev/null
    cat << EOF > ca-certificate-server/ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  name: mobilecapture-demo-nginx
  namespace: default
  labels:
    app: mobilecapture-demo-nginx
spec:
  backend:
    serviceName: mobilecapture-demo-nginx
    servicePort: 80
  rules:
  - host: $hostname
    http:
      paths:
      - path: /certificate
        backend:
          serviceName: mobilecapture-demo-nginx
          servicePort: 80
EOF
    kubectl apply -f ca-certificate-server/ingress.yaml 1> /dev/null
    rm ca-certificate-server/ingress.yaml
    echo "✅ Done."
}

function setup_helm_chart {
    echo
    echo
    echo "⚙️  Setting up Mobile Capture Helm Chart..."
    hostname=$(hostname | tr '[:upper:]' '[:lower:]')
    echo "⚠️  You need to make sure the machine's hostname is correct"
    echo "⚠️  Press enter to accept the detected hostname, or enter the correct one"
    read -p "⚠️  Hostname [$hostname]: " hostname_user
    if [[ $hostname_user != '' ]]; then
        hostname=$hostname_user
    fi

    cat << EOF > values.hostname.yaml
hostname: $hostname
tls:
    host: $hostname
EOF

    yq merge -x -i mobilecapture/values.yaml values.ibm-demo.yaml values.images.yaml values.hostname.yaml
    rm values.hostname.yaml
    echo "✅ Setup Mobile Capture Helm Chart."
}

function install_helm_chart {
    echo
    echo 
    echo "⚙️  Installing Mobile Capture Helm Chart..."
    if [[ $(helm list -f mobilecapture-demo | grep mobilecapture-demo ) ]]; then
        echo "ℹ️  Found an existing release with name 'mobilecapture-demo'"
        echo "ℹ️  Upgrading Helm Chart..."
        helm upgrade mobilecapture-demo ./mobilecapture/ --wait 1> /dev/null
    else
        echo "ℹ️  Installing new release with name 'mobilecapture-demo'..."
        echo "ℹ️  Installing Helm Chart..."
        helm install mobilecapture-demo ./mobilecapture/ --wait 1> /dev/null

        echo "🛠  Patching Ingress to support 'cert-manager' and '50m' uploads on Nginx..."
        kubectl patch ingress/mobilecapture-demo-mobile-capture -p '{"metadata":{"annotations":{"cert-manager.io/issuer-kind": "ClusterIssuer", "cert-manager.io/issuer":"ca-clusterissuer","nginx.ingress.kubernetes.io/proxy-body-size":"50m", "nginx.ingress.kubernetes.io/ssl-redirect": "false"}}}' 1> /dev/null
        echo "✅ Done."
    fi
    echo "✅ Installed Mobile Capture Helm Chart."
}

test_local_environment
setup_helm
load_docker_images
setup_requirements
setup_secrets
setup_certificate_authority
setup_helm_chart
deploy_ca-certificate-server
install_helm_chart

## QR CODE GENERATION
echo
echo
echo
docker build -t segno:latest -f ./qr-code/Dockerfile.segno ./qr-code/ &> /dev/null
docker run --rm -it segno "http://$hostname/certificate/ca.crt"


echo
echo

echo "✅"
echo "✅ IBM Mobile Capture has been successfuly deployed!"
echo "✅"
echo 
echo "ℹ️"
echo "ℹ️  In order to successfuly connect from your iOS Device,"
echo "ℹ️  you need to perform the following steps:"
echo "ℹ️"
echo 
echo "⚠️  IMPORTANT: Your phone and computer must be on the same network."
echo 
echo "ℹ️   1. Scan the QR code above with the native Camera app"
echo "ℹ️   2. Tap the notfication 'Open \"$hostname\""" in Safari'"
echo "ℹ️   3. Tap the 'Allow' button on the popup"
echo "ℹ️   4. If asked to choose a device, tap 'iPhone'"
echo "ℹ️   5. Tap 'Close'"
echo "ℹ️   6. Open the 'Settings' app"
echo "ℹ️   7. On the 'Settings' app navigate to 'General > Profiles & Device Management'"
echo "ℹ️   8. Under 'Downloaded Profile' select 'IBM Mobile Capture Demo CA'"
echo "ℹ️   9. On the rightside of the navigation bar, tap 'Install'"
echo "ℹ️  10. Enter your passcode"
echo "ℹ️  11. On the rightside of the navigation bar, tap 'Install'"
echo "ℹ️  12. On the action sheet, tap 'Install'"
echo "ℹ️  13. On the rightside of the navigation bar, tap 'Done'"
echo "ℹ️  14. On the 'Settings' app navigate to 'General > About > Certificate Trust Settings'"
echo "ℹ️  15. Under 'Enable full trust for root certificates', turn switch on for"
echo "       'IBM Mobile Capture Demo CA'"
echo "ℹ️  16. Tap 'Continue'"
echo "ℹ️  17. You're now ready to connect your device to this server."
echo
echo
echo "ℹ️"
echo "ℹ️  To reach the admin console on your computer:"
echo "ℹ️  1. Install and trust the certificate at http://$hostname/certificate/ca.crt"
echo "ℹ️  2. Open the browser at https://$hostname/"
echo "ℹ️"
echo "ℹ️  👨‍💼 Username: admin@ibm.com"
echo "ℹ️  🔑 Password: adminpassword"
echo "ℹ️"
