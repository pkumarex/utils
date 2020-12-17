#!/bin/bash
HOME_DIR=~/
SKC_BINARY_DIR=$HOME_DIR/binaries

KBS_HOSTNAME=$("hostname")

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_FLAVOUR="$OS""$VER"

if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
        dnf install -y jq
elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" ]]; then        
	apt install -y jq
else
	echo "Unsupported OS. Please use RHEL 8.1/8.2 or Ubuntu 18.04"
	exit 1
fi


\cp -pf $SKC_BINARY_DIR/env/kbs.env $HOME_DIR

# read from environment variables file if it exists
if [ -f ./skc_kbs.conf ]; then
    echo "Reading Installation variables from $(pwd)/skc_kbs.conf"
    source skc_kbs.conf
    env_file_exports=$(cat ./skc_kbs.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
    if [ -n "$env_file_exports" ]; then eval export $env_file_exports; fi
fi


pushd $PWD
echo "################ Uninstalling KBS....  #################"
kbs uninstall --purge
pushd $PWD

# KBS User and Roles

KBS_USER=`curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "admin@kbs","password": "kbsAdminPass"}'`
KBS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=admin@kbs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created KBS User with user ID $KBS_USER_ID"
KBS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=KBS TLS Certificate;SAN='$KBS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created KBS TLS cert role with ID $KBS_ROLE_ID1"
KBS_ROLE_ID2=`curl --noproxy "*" -k -X GET https://$AAS_IP:8444/aas/roles?name=Administrator -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].role_id'`
echo "Retrieved KBS Administrator role with ID $KBS_ROLE_ID2"
KBS_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SQVS","name": "QuoteVerifier","context": ""}' | jq -r ".role_id"`

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$KBS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$KBS_ROLE_ID1"'", "'"$KBS_ROLE_ID2"'", "'"$KBS_ROLE_ID3"'"]}'
fi

KBS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "admin@kbs","password": "kbsAdminPass"}'`
echo "KBS Token $KBS_TOKEN"

AAS_URL=https://$AAS_IP:8444/aas
CMS_URL=https://$CMS_IP:8445/cms/v1/
CMS_TLS_SHA=`cat /etc/cms/config.yml | grep tls-cert-digest |  cut -d' ' -f2`


pushd $PWD
echo "################ Update KBS env....  #################"
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$KBS_IP/" ~/kbs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$KBS_TOKEN/" ~/kbs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/kbs.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/kbs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/kbs.env
sed -i "s@^\(SKC_CHALLENGE_TYPE\s*=\s*\).*\$@\1$SKC_CHALLENGE_TYPE@" ~/kbs.env
sed -i "s@^\(ENDPOINT_URL\s*=\s*\).*\$@\1$ENDPOINT_URL@" ~/kbs.env
SQVS_URL=https://$SQVS_IP:12000/svs/v1
sed -i "s@^\(SQVS_URL\s*=\s*\).*\$@\1$SQVS_URL@" ~/kbs.env
echo "################ Installing KBS....  #################"
./kbs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ KBS Installation Failed"
  exit 1
fi
echo "################ Installed KBS....  #################"
popd
