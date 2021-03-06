#!/bin/bash

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_FLAVOUR="$OS""$VER"

HOME_DIR=~/
SKC_BINARY_DIR=$HOME_DIR/binaries

KBS_HOSTNAME=$("hostname")

# Copy env files to Home directory
\cp -pf $SKC_BINARY_DIR/env/cms.env $HOME_DIR
\cp -pf $SKC_BINARY_DIR/env/authservice.env $HOME_DIR
\cp -pf $SKC_BINARY_DIR/env/scs.env $HOME_DIR
\cp -pf $SKC_BINARY_DIR/env/sqvs.env $HOME_DIR
\cp -pf $SKC_BINARY_DIR/env/kbs.env $HOME_DIR
\cp -pf $SKC_BINARY_DIR/env/iseclpgdb.env $HOME_DIR

# Copy DB scripts to Home directory
\cp -pf $SKC_BINARY_DIR/install_pg.sh $HOME_DIR
\cp -pf $SKC_BINARY_DIR/install_pgscsdb.sh $HOME_DIR

\cp -pf $SKC_BINARY_DIR/trusted_rootca.pem /tmp
# read from environment variables file if it exists
if [ -f ./enterprise_skc.conf ]; then
    echo "Reading Installation variables from $(pwd)/enterprise_skc.conf"
    source enterprise_skc.conf
    env_file_exports=$(cat ./enterprise_skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
    if [ -n "$env_file_exports" ]; then eval export $env_file_exports; fi
fi

############## Install pre-req
which jq &> /dev/null 
if [ $? -ne 0 ]; then
if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
    dnf install -y jq
elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" ]]; then
    apt install -y jq curl
else
    echo "Unsupported OS. Please use RHEL 8.1/8.2 or Ubuntu 18.04"
    exit 1
fi
fi

echo "################ Uninstalling CMS....  #################"
cms uninstall --purge
echo "################ Uninstalling AAS....  #################"
authservice uninstall --purge
echo "################ Remove AAS DB....  #################"
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb $AAS_DB_NAME
echo "################ Uninstalling SCS....  #################"
scs uninstall --purge
echo "################ Remove SCS DB....  #################"
sudo -u postgres dropdb $SCS_DB_NAME
echo "################ Uninstalling SQVS....  #################"
sqvs uninstall --purge
echo "################ Uninstalling KBS....  #################"
kbs uninstall --purge
popd

function is_database() {
    export PGPASSWORD=$3
    psql -U $2 -lqt | cut -d \| -f 1 | grep -wq $1
}

if is_database $AAS_DB_NAME $AAS_DB_USERNAME $AAS_DB_PASSWORD
then 
   echo $AAS_DB_NAME database exists
else
   echo "################ Update iseclpgdb.env for AAS....  #################"
   sed -i "s@^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$@\1$AAS_DB_NAME@" ~/iseclpgdb.env
   sed -i "s@^\(ISECL_PGDB_USERNAME\s*=\s*\).*\$@\1$AAS_DB_USERNAME@" ~/iseclpgdb.env
   sed -i "s@^\(ISECL_PGDB_USERPASSWORD\s*=\s*\).*\$@\1$AAS_DB_PASSWORD@" ~/iseclpgdb.env
   pushd $PWD
   cd ~
   bash install_pg.sh
fi

if is_database $SCS_DB_NAME $SCS_DB_USERNAME $SCS_DB_PASSWORD
then
   echo $SCS_DB_NAME database exists
else
   echo "################ Update iseclpgdb.env for SCS....  #################"
   sed -i "s@^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$@\1$SCS_DB_NAME@" ~/iseclpgdb.env
   sed -i "s@^\(ISECL_PGDB_USERNAME\s*=\s*\).*\$@\1$SCS_DB_USERNAME@" ~/iseclpgdb.env
   sed -i "s@^\(ISECL_PGDB_USERPASSWORD\s*=\s*\).*\$@\1$SCS_DB_PASSWORD@" ~/iseclpgdb.env
   bash install_pgscsdb.sh
fi

popd

pushd $PWD
cd $SKC_BINARY_DIR
echo "################ Installing CMS....  #################"
AAS_URL=https://$SYSTEM_IP:8444/aas
sed -i "s/^\(AAS_TLS_SAN\s*=\s*\).*\$/\1$SYSTEM_IP/" ~/cms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/cms.env
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_IP/" ~/cms.env

./cms-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ CMS Installation Failed"
  exit 1
fi
echo "################ Installed CMS....  #################"

echo "################ Installing AuthService....  #################"

echo "################ Copy CMS token to AuthService....  #################"
export AAS_TLS_SAN=$SYSTEM_IP
CMS_TOKEN=`cms setup cms_auth_token --force | grep 'JWT Token:' | awk '{print $3}'`
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$CMS_TOKEN/"  ~/authservice.env

CMS_TLS_SHA=`cms tlscertsha384`
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/"  ~/authservice.env

CMS_URL=https://$SYSTEM_IP:8445/cms/v1/
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@"  ~/authservice.env

sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_IP/"  ~/authservice.env
sed -i "s/^\(AAS_DB_NAME\s*=\s*\).*\$/\1$AAS_DB_NAME/"  ~/authservice.env
sed -i "s/^\(AAS_DB_USERNAME\s*=\s*\).*\$/\1$AAS_DB_USERNAME/"  ~/authservice.env
sed -i "s/^\(AAS_DB_PASSWORD\s*=\s*\).*\$/\1$AAS_DB_PASSWORD/"  ~/authservice.env

./authservice-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ AuthService Installation Failed"
  exit 1
fi
echo "################ Installed AuthService....  #################"

echo "################ Create user and role on AuthService....  #################"
TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/token -d '{"username": "admin@aas", "password": "aasAdminPass" }'`

if [ $? -ne 0 ]; then
  echo "############ Could not get TOKEN from AuthService "
  exit 1
fi

USER_ID=`curl --noproxy "*" -k https://$SYSTEM_IP:8444/aas/users?name=admin@aas -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Got admin user ID $USER_ID"

# SGX Caching Service User and Roles

SCS_USER=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "scsuser@scs","password": "scspassword"}'`
SCS_USER_ID=`curl --noproxy "*" -k https://$SYSTEM_IP:8444/aas/users?name=scsuser@scs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SCS User with user ID $SCS_USER_ID"
SCS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SCS TLS Certificate;SAN='$SYSTEM_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SCS TLS cert role with ID $SCS_ROLE_ID1"
SCS_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "CacheManager","context": ""}' | jq -r ".role_id"`
echo "Created SCS CacheManager role with ID $SCS_ROLE_ID2"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/users/$SCS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SCS_ROLE_ID1"'", "'"$SCS_ROLE_ID2"'"]}'
fi

SCS_TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "scsuser@scs","password": "scspassword"}'`
echo "SCS Token $SCS_TOKEN"

# SGX Quote Verification Service User and Roles

SQVS_USER=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "sqvsuser@sqvs","password": "sqvspassword"}'`
SQVS_USER_ID=`curl --noproxy "*" -k https://$SYSTEM_IP:8444/aas/users?name=sqvsuser@sqvs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SQVS User with user ID $SQVS_USER_ID"
SQVS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SQVS TLS Certificate;SAN='$SYSTEM_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SQVS TLS cert role with ID $SQVS_ROLE_ID1"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k  -X POST https://$SYSTEM_IP:8444/aas/users/$SQVS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SQVS_ROLE_ID1"'"]}'
fi

SQVS_TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "sqvsuser@sqvs","password": "sqvspassword"}'`
echo "SQVS Token $SQVS_TOKEN"

# KBS User and Roles

KBS_USER=`curl --noproxy "*" -k  -X POST https://$SYSTEM_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "admin@kbs","password": "kbsAdminPass"}'`
KBS_USER_ID=`curl --noproxy "*" -k https://$SYSTEM_IP:8444/aas/users?name=admin@kbs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created KBS User with user ID $KBS_USER_ID"
KBS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=KBS TLS Certificate;SAN='$KBS_DOMAIN';certType=TLS"}' | jq -r ".role_id"`
echo "Created KBS TLS cert role with ID $KBS_ROLE_ID1"
KBS_ROLE_ID2=`curl --noproxy "*" -k -X GET https://$SYSTEM_IP:8444/aas/roles?name=Administrator -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].role_id'`
echo "Retrieved KBS Administrator role with ID $KBS_ROLE_ID2"
KBS_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SQVS","name": "QuoteVerifier","context": ""}' | jq -r ".role_id"`

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/users/$KBS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$KBS_ROLE_ID1"'", "'"$KBS_ROLE_ID2"'", "'"$KBS_ROLE_ID3"'"]}'
fi

KBS_TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "admin@kbs","password": "kbsAdminPass"}'`
echo "KBS Token $KBS_TOKEN"

echo "################ Update SCS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_IP/"  ~/scs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SCS_TOKEN/"  ~/scs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/scs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/scs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/scs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER@" ~/scs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER_API_KEY\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER_API_KEY@" ~/scs.env
sed -i "s/^\(SCS_DB_NAME\s*=\s*\).*\$/\1$SCS_DB_NAME/"  ~/scs.env
sed -i "s/^\(SCS_DB_USERNAME\s*=\s*\).*\$/\1$SCS_DB_USERNAME/"  ~/scs.env
sed -i "s/^\(SCS_DB_PASSWORD\s*=\s*\).*\$/\1$SCS_DB_PASSWORD/"  ~/scs.env

echo "################ Installing SCS....  #################"
./scs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SCS Installation Failed"
  exit 1
fi
echo "################ Installed SCS....  #################"

echo "################ Update SQVS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_IP/"  ~/sqvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SQVS_TOKEN/"  ~/sqvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sqvs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/sqvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sqvs.env
SCS_URL=https://$SYSTEM_IP:9000/scs/sgx/certification/v1
sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/sqvs.env

echo "################ Installing SQVS....  #################"
./sqvs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SQVS Installation Failed"
  exit 1
fi
echo "################ Installed SQVS....  #################"

echo "################ Update KBS env....  #################"
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$KBS_DOMAIN/" ~/kbs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$KBS_TOKEN/" ~/kbs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/kbs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/kbs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/kbs.env
SQVS_URL=https://$SYSTEM_IP:12000/svs/v1
sed -i "s@^\(SQVS_URL\s*=\s*\).*\$@\1$SQVS_URL@" ~/kbs.env
ENDPOINT_URL=https://$SYSTEM_IP:9443/v1
sed -i "s@^\(ENDPOINT_URL\s*=\s*\).*\$@\1$ENDPOINT_URL@" ~/kbs.env
echo "################ Installing KBS....  #################"
./kbs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ KBS Installation Failed"
  exit 1
fi
echo "################ Installed KBS....  #################"
popd
