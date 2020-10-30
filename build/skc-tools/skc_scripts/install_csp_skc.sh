#!/bin/bash
HOME_DIR=~/
SKC_BINARY_DIR=$HOME_DIR/binaries

# Copy env files to Home directory
cp -pf $SKC_BINARY_DIR/env/cms.env $HOME_DIR
cp -pf $SKC_BINARY_DIR/env/authservice.env $HOME_DIR
cp -pf $SKC_BINARY_DIR/env/scs.env $HOME_DIR
cp -pf $SKC_BINARY_DIR/env/shvs.env $HOME_DIR
cp -pf $SKC_BINARY_DIR/env/ihub.env $HOME_DIR
cp -pf $SKC_BINARY_DIR/env/iseclpgdb.env $HOME_DIR

# Copy DB scripts to Home directory
cp -pf $SKC_BINARY_DIR/install_pg.sh $HOME_DIR
cp -pf $SKC_BINARY_DIR/install_pgscsdb.sh $HOME_DIR
cp -pf $SKC_BINARY_DIR/install_pgshvsdb.sh $HOME_DIR

# read from environment variables file if it exists
if [ -f ./csp_skc.conf ]; then
    echo "Reading Installation variables from $(pwd)/csp_skc.conf"
    source csp_skc.conf
    env_file_exports=$(cat ./csp_skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
    if [ -n "$env_file_exports" ]; then eval export $env_file_exports; fi
fi

yum install -y jq

echo "################ Uninstalling CMS....  #################"
cms uninstall --purge
echo "################ Uninstalling AAS....  #################"
authservice uninstall --purge
echo "################ Remove AAS DB....  #################"
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb aasdb
echo "################ Uninstalling SCS....  #################"
scs uninstall --purge
echo "################ Remove SCS DB....  #################"
sudo -u postgres dropdb pgscsdb
echo "################ Uninstalling SHVS....  #################"
shvs uninstall --purge
echo "################ Remove SHVS DB....  #################"
sudo -u postgres dropdb pgshvsdb
echo "################ Uninstalling IHUB....  #################"
ihub uninstall --purge
popd

export PGPASSWORD=aasdbpassword
function is_database() {
    psql -U aasdbuser -lqt | cut -d \| -f 1 | grep -wq $1
}

export DBNAME=aasdb
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

export DBNAME=pgshvsdb
if is_database $DBNAME
then
   echo $DBNAME database exists
else
   echo "################ Update iseclpgdb.env for SHVS....  #################"
   sed -i "s/^\(ISECL_PGDB_DBNAME\s*=\s*\).*\$/\1$DBNAME/" ~/iseclpgdb.env
   bash install_pgshvsdb.sh
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

CMS_TLS_SHA=`cat /etc/cms/config.yml | grep tls-cert-digest |  cut -d' ' -f2`
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
TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -d '{"username": "admin@aas", "password": "aasAdminPass" }'`

if [ $? -ne 0 ]; then
  echo "############ Could not get TOKEN from AuthService "
  exit 1
fi

USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=admin@aas -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
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

# SGX Host Verification Service User and Roles

SHVS_USER=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "shvsuser@shvs","password": "shvspassword"}'`
SHVS_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=shvsuser@shvs -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created SHVS User with user ID $SHVS_USER_ID"
SHVS_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=SHVS TLS Certificate;SAN='$SHVS_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created SHVS TLS cert role with ID $SHVS_ROLE_ID1"
SHVS_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SGX_AGENT","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataReader role with ID $SHVS_ROLE_ID2"
SHVS_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "HostDataUpdater","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataUpdater role with ID $SHVS_ROLE_ID3"
SHVS_ROLE_ID4=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SCS","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataReader role with ID $SHVS_ROLE_ID4"
SHVS_ROLE_ID5=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostListManager","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostListManager role with ID $SHVS_ROLE_ID5"
SHVS_ROLE_ID6=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostsListReader","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostsListReader role with ID $SHVS_ROLE_ID6"
SHVS_ROLE_ID7=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostDataReader role with ID $SHVS_ROLE_ID7"
SHVS_ROLE_ID8=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostRegistration","context": ""}' | jq -r ".role_id"`
echo "Created SHVS HostRegistration role with ID $SHVS_ROLE_ID8"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$SHVS_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$SHVS_ROLE_ID1"'", "'"$SHVS_ROLE_ID2"'", "'"$SHVS_ROLE_ID3"'", "'"$SHVS_ROLE_ID4"'", "'"$SHVS_ROLE_ID5"'", "'"$SHVS_ROLE_ID6"'", "'"$SHVS_ROLE_ID7"'", "'"$SHVS_ROLE_ID8"'"]}'
fi

SHVS_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "shvsuser@shvs","password": "shvspassword"}'`
echo "SHVS Token $SHVS_TOKEN"

#  IHUB User and Roles

IHUB_USER=`curl --noproxy "*" -k  -X POST https://$AAS_IP:8444/aas/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "admin@hub","password": "hubAdminPass"}'`
IHUB_USER_ID=`curl --noproxy "*" -k https://$AAS_IP:8444/aas/users?name=admin@hub -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' | jq -r '.[0].user_id'`
echo "Created IHUB User with user ID $IHUB_USER_ID"
IHUB_ROLE_ID1=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN=Integration HUB TLS Certificate;SAN='$IHUB_IP';certType=TLS"}' | jq -r ".role_id"`
echo "Created IHUB TLS cert role with ID $IHUB_ROLE_ID1"
IHUB_ROLE_ID2=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostDataReader","context": ""}' | jq -r ".role_id"`
echo "Created IHUB HostDataReader role with ID $IHUB_ROLE_ID2"
IHUB_ROLE_ID3=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "SHVS","name": "HostsListReader","context": ""}' | jq -r ".role_id"`
echo "Created IHUB HostsListReader role with ID $IHUB_ROLE_ID3"

if [ $? -eq 0 ]; then
  curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/users/$IHUB_USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$IHUB_ROLE_ID1"'", "'"$IHUB_ROLE_ID2"'", "'"$IHUB_ROLE_ID3"'"]}'
fi

IHUB_TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:8444/aas/token -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"username": "admin@hub","password": "hubAdminPass"}'`
echo "IHUB Token $IHUB_TOKEN"

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

echo "################ Update SHVS env....  #################"
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SHVS_IP/" ~/shvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$SHVS_TOKEN/" ~/shvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/shvs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/shvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/shvs.env
SCS_URL=https://$SCS_IP:9000/scs/sgx/
sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/shvs.env

echo "################ Installing SHVS....  #################"
./shvs-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ SHVS Installation Failed"
  exit 1
fi
echo "################ Installed SHVS....  #################"

echo "################ Update IHUB env....  #################"
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$IHUB_IP/" ~/ihub.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$IHUB_TOKEN/" ~/ihub.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/ihub.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/ihub.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/ihub.env
SHVS_URL=https://$SHVS_IP:13000/sgx-hvs/v1
K8S_URL=https://$K8S_IP:6443/
sed -i "s@^\(ATTESTATION_SERVICE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/ihub.env
sed -i "s@^\(KUBERNETES_URL\s*=\s*\).*\$@\1$K8S_URL@" ~/ihub.env

echo "################ Installing IHUB....  #################"
./ihub-*.bin || exit 1
if [ $? -ne 0 ]; then
  echo "############ IHUB Installation Failed"
  exit 1
fi
echo "################ Installed IHUB....  #################"

popd
