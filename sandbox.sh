#!/bin/bash

# VARS
OS=UNKNOWN #Linux, MacOS
DISTRO=UNKNOWN #Debian, RedHat, Gentoo, Arch or None
INSTALLCMD=UNKNOWN # APT; YUM; PACMAN; EMERGE
ANSIBLEPARAMS="" # Parameters passed to ansible
AMIOP=UNKNOWN #TRUE; FALSE
CILIUM_NAMESPACE=kube-system

###################################################  BASE ###################################################
logmsg() {
    if [ ! -n "$3" ]; then
        GREEN='\033[0;32m'
        RED='\033[0;31m'
        ORANGE='\033[0;33m'
        Underlined='\e[4m'
        NC='\033[0m' # No Color

        case "$1" in
           INFO)
                    echo -e -n "${GREEN}[$1 ]${NC} - "
                    ;;
            WARN)
                    echo -e -n "${ORANGE}[$1 ]${NC} - "
                    ;;
            ERROR)
                    echo -e -n "${RED}[$1]${NC} - "
                    ;;
            *)
                    echo -e -n "${Underlined}[$1]${NC} - "
                    ;;
        esac

        prompt="$2"
        echo -e $prompt
    fi

    fileLogEntry=${prompt//\\033[0m}
    echo $(date) - $fileLogEntry >> sandbox.log
}

displayAsciiDisclaimer() {

echo "██╗  ██╗ █████╗ ███████╗      ███████╗ █████╗ ███╗   ██╗██████╗ ██████╗  ██████╗ ██╗  ██╗"
echo "██║ ██╔╝██╔══██╗██╔════╝      ██╔════╝██╔══██╗████╗  ██║██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝"
echo "█████╔╝ ╚█████╔╝███████╗█████╗███████╗███████║██╔██╗ ██║██║  ██║██████╔╝██║   ██║ ╚███╔╝ "
echo "██╔═██╗ ██╔══██╗╚════██║╚════╝╚════██║██╔══██║██║╚██╗██║██║  ██║██╔══██╗██║   ██║ ██╔██╗ "
echo "██║  ██╗╚█████╔╝███████║      ███████║██║  ██║██║ ╚████║██████╔╝██████╔╝╚██████╔╝██╔╝ ██╗"
echo "╚═╝  ╚═╝ ╚════╝ ╚══════╝      ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
echo ""
    
    logmsg "INFO" "${NC} K8s Sandbox!"
}

envDetector(){
    logmsg "INFO" "${NC} Detecting Environment"
    case "$(uname -s)" in
    Darwin)
        OS=MacOS
        DISTRO=none
        INSTALLCMD="brew install"
        ANSIBLEPARAMS="-K"
    ;;
    Linux)
        OS=Linux
        if [ -n "$(command -v apt-get)" ];
        then
            INSTALLCMD="sudo apt-get -y --allow-unauthenticated install"
            DISTRO=Debian
        elif [ -n "$(command -v apt)" ];
        then
            INSTALLCMD="sudo apt -f install"
            DISTRO=Debian
        elif [ -n "$(command -v yum)" ];
        then
            INSTALLCMD="sudo yum -y"
            DISTRO=RedHat

        elif [ -n "$(command -v dnf)" ];
        then
            INSTALLCMD="sudo dnf -y"
            DISTRO=RedHat
        elif [ -n "$(command -v pacman)" ];
        then
            INSTALLCMD="sudo pacman -S "
            DISTRO=Arch
        elif [ -n "$(command -v yay)" ];
        then
            INSTALLCMD="sudo yay -S"
            DISTRO=Arch
        elif [ -n "$(command -v emerge)" ];
        then
            INSTALLCMD="sudo emerge"
            DISTRO=Gentoo
        fi
    ;;
    CYGWIN*|MINGW32*|MSYS*)
        logmsg "WARN" "${NC} Detected MS Windows - Not Supported ..."
        exit 1
    ;;
    *)
        logmsg "ERROR" "${NC} Detected other OS is not Supported..."
        exit 1
    ;;
  esac
  logmsg "INFO" "${NC} Detected OS: $OS; Detected Distribution: $DISTRO;"
  logmsg "INFO" "${NC} Install Command: $INSTALLCMD <PACKAGE>"

}

waitForWord() {
    command=$1
    wordSearch=$2

    tries=10
    waitTime=2

    while [ "$tries" -gt 0 ]; do
        if $(echo $command) | grep -q "${wordSearch}"
        then
            logmsg "INFO" "${NC} Found statement: ${wordSearch}"
            break
        fi
        tries=$(( tries - 1 ))
        sleep ${waitTime}

    done

    if [ "$tries" -eq 0 ]; then
        logmsg "INFO" "${NC}--> Command output not found."
        exit 1
    fi
}


installKind() {
  case "$(uname -s)" in
    Darwin)
        # For Intel Macs
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-darwin-amd64
        # For M1 / ARM Macs
        [ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-darwin-arm64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        logmsg "INFO" "${NC} Mac Kind Installed!"
    ;;
    Linux)
        # For AMD64 / x86_64
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
        # For ARM64
        [ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-arm64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        logmsg "INFO" "${NC} Linux Kind Installed!"
    ;;
  esac
}


################################################  KIND SPECIFIC  ###############################################
installHelm(){
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    helmvar=$(./get_helm.sh)
    logmsg "INFO" "${helmvar}"
    command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required but it's not installed. Please Install it first and re-run this script."; exit 1; }
    logmsg "INFO" "${NC} Helm Installed!"
}

createK8sCluster(){
    kind create cluster --config=./files/kind-config.yaml
    waitForWord "kubectl cluster-info --context kind-mysandbox" "running"
    logmsg "INFO" "${NC} Kind Cluster Created!"
}

installIngressNginx(){
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    logmsg "INFO" "${NC} Kind Cluster Created!"
}

deleteK8sCluster(){
    kind delete clusters --all
    logmsg "INFO" "${NC} Kind Cluster Deleted!"
}

deployBox(){
    kubectl create ns $1
    kubectl $2 -n $1 -f box/$1/manifests/*
}



#####################################################  RUN  ####################################################

displayAsciiDisclaimer

case "$1" in
    help)
        echo "installKind - To install Kind binaries";
        echo "createCluster - To create Kind Cluster based on the configuration in files/kind-config.yaml"
        echo "deleteClister - To delete all the Kind Clusters"
        echo "box - to deploy your box application present on box/*"
        echo "  usage:"
        echo "    ./sandbox.sh box e2e-app apply #Deploy the e2e-app application"
        echo "    ./sandbox.sh box e2e-app delete #Delete the e2e-app deployment"
    ;;
    installHelm)
        installHelm
    ;;
    installKind)
        installKind
    ;;
    createCluster)
        createK8sCluster
        installIngressNginx
    ;;
    deleteCluster)
        deleteK8sCluster
    ;;
    box)
        deployBox $2 $3
    ;;
esac
