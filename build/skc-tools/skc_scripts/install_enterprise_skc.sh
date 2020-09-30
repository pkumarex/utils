#!/bin/bash
SKC_BINARY_DIR=../../../../binaries

KMS_HOSTNAME=$("hostname")

# Copy env files to Home directory
HOME_DIR=~/
cp -pf ../../../../sgx-caching-service/dist/linux/scs.env $HOME_DIR
cp -pf ../../../../sgx-verification-service/dist/linux/sqvs.env $HOME_DIR
cp -pf env/kms.env $HOME_DIR
cp -pf env/iseclpgdb.env $HOME_DIR
cp -pf env/cms.env $HOME_DIR
cp -pf env/authservice.env $HOME_DIR

# Copy DB scripts to Home directory
cp -pf ../../../../sgx-caching-service/dist/linux/install_pgscsdb.sh $HOME_DIR
cp -pf env/install_pg.sh $HOME_DIR

cp -pf env/trusted_rootca.pem /tmp
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
  yum install -y jq
fi

echo "################ Uninstalling CMS....  #################"
cms uninstall --purge
echo "################ Uninstalling AAS....  #################"
authservice uninstall --purge
echo "################ Remove AAS DB....  #################"
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb aas_db
echo "################ Uninstalling SCS....  #################"
scs uninstall --purge
echo "################ Remove SCS DB....  #################"
sudo -u postgres dropdb pgscsdb
echo "################ Uninstalling SQVS....  #################"
sqvs uninstall --purge
echo "################ Uninstalling KBS....  #################"
kms uninstall --purge
popd

export PGPASSWORD=dbpassword
function is_database() {
    psql -U dbuser -lqt | cut -d \| -f 1 | grep -wq $1
}

export DBNAME=aas_db
if is_database $DBNAME
then 
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for AAS....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   pushd $PWD
   cd ~
   bash install_pg.sh
fi

export DBNAME=pgscsdb
if is_database $DBNAME
then
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for SCS....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   bash install_pgscsdb.sh
fi

popd

pushd $PWD
cd $SKC_BINARY_DIR
echo "################ Installing CMS....  #################"
AAS_URL=https://$AAS_IP:8444/aas/
sed -i "s/^\(AAS_TLS_SAN\s*=\s*\).*\$/\1$AAS_IP/" ~/cms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/cms.env
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$CMS_IP/" ~/cms.env

./cms-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ CMS Installation Failed"
  exit 1
fi
echo "################ Installed CMS....  #################"

echo "################ Installing AuthService....  #################"

echo "################ Copy CMS token to AuthService....  #################"
export AAS_TLS_SAN=$AAS_IP
CMS_TOKEN=`cms setup cms_auth_token --force | grep 'JWT Token:' | awk '{print $3}'`
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$CMS_TOKEN/"  ~/authservice.env

CMS_TLS_SHA=`cat /etc/cms/config.yml | grep tlscertdigest |  cut -d' ' -f2`
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/"  ~/authservice.env

CMS_URL=https://$CMS_IP:8445/cms/v1/
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@"  ~/authservice.env

sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$AAS_IP/"  ~/authservice.env

./authservice-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ AuthService Installation Failed"
  exit 1
fi
echo "################ Installed AuthService....  #################"

echo "################ Create user and role on AuthService....  #################"
TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -d '{"username": "admin", "password": "password" }'`

if [ $? -ne 0 ]; then
  echo "############ Could not get TOKEN from AuthService "
  exit 1
fi

USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=admin -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Got admin user ID $USER_ID"

# SGX Caching Service User and Roles

SCS_USER=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "scsuser@scs","password": "scspassword"}'`
SCS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=scsuser@scs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SCS User with user ID $SCS_USER_ID"
SCS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SCS TLS Certificate;SAN='$SCS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SCS TLS cert role with ID $SCS_ROLE_ID1"
SCS_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "CacheManager","context": ""}' | jq -r ".role_id"`
echo "Created SCS CacheManager role with ID $SCS_ROLE_ID2"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$SCS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SCS_ROLE_ID1"'", "'"$SCS_ROLE_ID2"'"]}'
fi

SCS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "scsuser@scs","password": "scspassword"}'`
echo "SCS Token $SCS_TOKEN"

# SGX Quote Verification Service User and Roles

SQVS_USER=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "sqvsuser@sqvs","password": "sqvspassword"}'`
SQVS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=sqvsuser@sqvs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SQVS User with user ID $SQVS_USER_ID"
SQVS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SQVS TLS Certificate;SAN='$SQVS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SQVS TLS cert role with ID $SQVS_ROLE_ID1"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users/$SQVS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SQVS_ROLE_ID1"'"]}'
fi

SQVS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "sqvsuser@sqvs","password": "sqvspassword"}'`
echo "SQVS Token $SQVS_TOKEN"

# KBS User and Roles

KMS_USER=`curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "kmsuser@kms","password": "kmspassword"}'`
KMS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=kmsuser@kms -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created KMS User with user ID $KMS_USER_ID"
KMS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=KMS TLS Certificate;SAN='$KMS_IP','$KMS_HOSTNAME';certType=TLS"}' | jq -r ".role_id"`
echo "Created KMS TLS cert role with ID $KMS_ROLE_ID1"
KMS_ROLE_ID2=`curl --noproxy "*" -k -X GET https://$AAS_IP:8444/aas/roles?name=Administrator -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].role_id'`
echo "Retrieved KMS Administrator role with ID $KMS_ROLE_ID2"
KMS_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SQVS","name": "QuoteVerifier","context": ""}' | jq -r ".role_id"`

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$KMS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$KMS_ROLE_ID1"'", "'"$KMS_ROLE_ID2"'", "'"$KMS_ROLE_ID3"'"]}'
fi

KMS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "kmsuser@kms","password": "kmspassword"}'`
echo "KMS Token $KMS_TOKEN"

echo "################ Update SCS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SCS_IP/"  ~/scs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SCS_TOKEN/"  ~/scs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/scs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/scs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/scs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER@" ~/scs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER_API_KEY\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER_API_KEY@" ~/scs.env

echo "################ Installing SCS....  #################"
./scs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SCS Installation Failed"
  exit 1
fi
echo "################ Installed SCS....  #################"

echo "################ Update SQVS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SQVS_IP/"  ~/sqvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SQVS_TOKEN/"  ~/sqvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sqvs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/sqvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sqvs.env
SCS_URL=https://$SCS_IP:9000/scs/sgx/certification/v1
sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/sqvs.env

echo "################ Installing SQVS....  #################"
./sqvs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SQVS Installation Failed"
  exit 1
fi
echo "################ Installed SQVS....  #################"

echo "################ Update KBS env....  #################"
sed -i "s/^\(JETTY_TLS_CERT_IP\s*=\s*\).*\$/\1$KMS_IP/" ~/kms.env
sed -i "s/^\(JETTY_TLS_CERT_DNS\s*=\s*\).*\$/\1$KMS_HOSTNAME/" ~/kms.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$KMS_TOKEN/" ~/kms.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/kms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/kms.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/kms.env
SQVS_URL=https://$SQVS_IP:12000/svs/v1
sed -i "s@^\(SVS_BASE_URL\s*=\s*\).*\$@\1$SQVS_URL@" ~/kms.env
echo "################ Installing KBS....  #################"
./kms-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ KBS Installation Failed"
  exit 1
fi
echo "################ Installed KBS....  #################"
popd
