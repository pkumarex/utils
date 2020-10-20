#!/bin/bash
clean_flag=0

if [ "$1" = "clean" ]; then
	clean_flag=1
fi

rm -f *.log
rm -f *response.json
rm -f *.status
rm -rf .srl

if [ $clean_flag -eq 1 ]; then
	exit 0
fi

if dnf list installed "jq" >/dev/null 2>&1; then
    	echo "jq package already installed"
else
	dnf install jq -y
fi

KMS_IP=kms.server.com
KMS_PORT=9443
AAS_IP=aas.server.com
AAS_PORT=8444
AAS_USERNAME=admin
AAS_PASSWORD=password
EnterPriseAdmin=EAdmin
EnterPrisePassword=EPassword
CACERT_PATH=cms-ca.cert

CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/json"
aas_token=`curl -k -H "$CONTENT_TYPE" -H "$ACCEPT" --data \{\"username\":\"$AAS_USERNAME\",\"password\":\"$AAS_PASSWORD\"\} https://$AAS_IP:$AAS_PORT/aas/token`

#Create EnterPriseAdmin User and assign the roles.
user_="\"username\":\"$EnterPriseAdmin\""
password_="\"password\":\"$EnterPrisePassword\""
curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" --data \{$user_,$password_\} $http_header https://$AAS_IP:$AAS_PORT/aas/users

user_details=`curl -k "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" -w %{http_code}  https://$AAS_IP:$AAS_PORT/aas/users?name=$EnterPriseAdmin`
user_id=`echo $user_details| awk 'BEGIN{RS="user_id\":\""} {print $1}' | sed -n '2p' | awk 'BEGIN{FS="\",\"username\":\""} {print $1}'`

#createRoles("KMS","KeyCRUD","","permissions:["*:*:*"]")
curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" --data \{\"service\":\"KBS\",\"name\":\"KeyCRUD\",\"permissions\":[\"*:*:*\"]\} $http_header https://$AAS_IP:$AAS_PORT/aas/roles
role_details=`curl -k "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" -w %{http_code}  https://$AAS_IP:$AAS_PORT/aas/roles?service=KBS\&name=KeyCRUD`
role_id1=`echo $role_details | cut -d '"' -f 4`

#map roles to user id
curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer ${aas_token}" --data \{\"role_ids\":\[\"$role_id1\"\]\} -w %{http_code} https://$AAS_IP:$AAS_PORT/aas/users/$user_id/roles

#get token
BEARER_TOKEN=`curl -k -H "$CONTENT_TYPE" -H "$ACCEPT" -H "Authorization: Bearer $aas_token" --data \{\"username\":\"$EnterPriseAdmin\",\"password\":\"$EnterPrisePassword\"\} https://$AAS_IP:$AAS_PORT/aas/token`
echo $BEARER_TOKEN

curl -v -H "Authorization: Bearer ${BEARER_TOKEN}" -H "Content-Type: application/json" --cacert $CACERT_PATH \
	-H "Accept: application/json" --data @transfer_policy_request.json  -o transfer_policy_response.json -w "%{http_code}" \
	https://$KMS_IP:$KMS_PORT/v1/key-transfer-policies >transfer_policy_response.status 2>transfer_policy_debug.log

transfer_policy_id=$(cat transfer_policy_response.json | jq '.id');

if [ "$1" = "reg" ]; then
	source gen_cert_key.sh
printf "{
   \"key_information\":{
      \"algorithm\":\"RSA\",
      \"key_length\":2048,
\"key_string\":\"$(cat ${SERVER_PKCS8_KEY} | tr '\r\n' '@')\"
   },
    \"transfer_policy_ID\": ${transfer_policy_id}
}" > key_request.json

sed -i "s/@/\\\n/g" key_request.json
else
printf "{
   \"key_information\":{
      \"algorithm\":\"AES\",
      \"key_length\":128
   },
\"transfer_policy_ID\":${transfer_policy_id}
}" > key_request.json
fi

curl -v -H "Authorization: Bearer ${BEARER_TOKEN}" -H "Content-Type: application/json" --cacert $CACERT_PATH \
    -H "Accept: application/json" --data @key_request.json -o key_response.json -w "%{http_code}" \
    https://$KMS_IP:$KMS_PORT/v1/keys > key_response.status \
 2>key_debug.log

key_id=$(cat key_response.json | jq '.key_information.id');
if [ "$1" = "reg" ]; then
    file_name=$(echo $key_id | sed -e "s|\"||g")
    cp output/server.cert output/$file_name.crt
    echo "cert path:$(realpath output/$file_name.crt)"
fi

echo "Created Key:$key_id"
