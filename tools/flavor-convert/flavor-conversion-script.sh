#!/bin/bash
echo "START FLAVOR CONVERT TOOL"

#Database connection details
HVS_DB_NAME=vsdb
HVS_DB_PORT=5432
HVS_DB_USERNAME=vsdbuser
HVS_DB_HOSTNAME=localhost

#Directories to be used for storing Flavors, Flavor templates and others
TOOL_DIR=/root/fc/
TEMPLATE_DIR=${TOOL_DIR}templates/
OLD_FLAVORS_DIR=${TOOL_DIR}old_flavors/
SIGNING_CERT_DIR=${TOOL_DIR}trusted-keys/
TEMPLATES_CLONE_DIR=/root/templates-to-be-uploaded/
BASIC_TEMPLATES_TO_INSERT=${TEMPLATES_CLONE_DIR}intel-secl/build/linux/hvs/templates/

#Flavor conversion tool Github clone url and branch
FC_TOOL_GIT=https://github.com/pkumarex/utils.git
FC_TOOL_GIT_BRANCH=flavorconvert-devel

#INTEL-SECL Github url
INTEL_SECL_GIT=https://github.com/pkumarex/intel-secl.git

#exporting papassfile which contains DB password
export PGPASSFILE=/home/.pgpass

#Creating the required directories and removing older ones if exists
for directory in $TOOL_DIR $TEMPLATES_CLONE_DIR $TEMPLATE_DIR $OLD_FLAVORS_DIR $SIGNING_CERT_DIR; do
if [ -d $directory ]; then
  echo "Remove existing directory $directory..."
  rm -rf $directory
fi
    mkdir $directory
    if [ $? -ne 0 ]; then
        echo "Cannot create directory: $directory"
        exit 1
    fi
done

#Cloning the default templates to a local directory.
echo "Cloning the basic flavor templates to local directory from Github"

cd $TEMPLATES_CLONE_DIR

git clone $INTEL_SECL_GIT

echo "Inserting the basic flavor templates to DB"

FILE='/tmp/listofbasictemplates.txt'
ls $BASIC_TEMPLATES_TO_INSERT > $FILE

#Check the DB for the existence of flavor_template table. If yes, dropping it
echo "Checking the DB for the existence of flavor_template table"
psql -h $HVS_DB_HOSTNAME -p $HVS_DB_PORT -U $HVS_DB_USERNAME -d $HVS_DB_NAME <<EOF
DROP TABLE IF EXISTS flavor_template;
EOF

while read line; do
flavorID=`$echo uuidgen`
sed -i '1 a "id": "'${flavorID}'",' ${BASIC_TEMPLATES_TO_INSERT}${line}

#changing single quote into double single quote
sed -i "s/'/\''/g" ${BASIC_TEMPLATES_TO_INSERT}${line}

#Storing a whole template json file content into a variable
content=`cat ${BASIC_TEMPLATES_TO_INSERT}${line}`

#Opening DB and inserting templates to it
psql -h $HVS_DB_HOSTNAME -p $HVS_DB_PORT -U $HVS_DB_USERNAME -d $HVS_DB_NAME <<EOF

CREATE TABLE IF NOT EXISTS flavor_template (id UUID NOT NULL, content JSONB NOT NULL, deleted BOOLEAN NOT NULL);

INSERT INTO flavor_template("id","content","deleted") VALUES('${flavorID}','${content}',FALSE);

EOF

done < $FILE
echo "Uploading flavor templates to DB is completed successfully"

#Downloading flavors and flavor templates from DB
echo "Accessing DB to download Flavors and Flavor templates"

#Flavor templates
if test -f "/tmp/tempflavortemplate.json"; then
  echo "Removing the existing /tmp/tempflavortemplate.json..."
  rm -f /tmp/tempflavortemplate.json
fi

psql -h $HVS_DB_HOSTNAME -p $HVS_DB_PORT -U $HVS_DB_USERNAME -d $HVS_DB_NAME <<EOF
COPY (
  SELECT row_to_json(template_data) FROM (
    SELECT
      content
    FROM flavor_template
  ) template_data
) TO '/tmp/tempflavortemplate.json';
EOF

#Checking the file exists with data. If not, throw error and exit from script
if ! [ -s "/tmp/tempflavortemplate.json" ];then
    echo "Error in retrieving the Flavor templates from DB or There is no Flavor template exists in the DB"
    exit
fi
echo "Retrieved flavor templates from db successfully"

#Flavors
if test -f "/tmp/tempflavors.json"; then
  echo "Removing the existing /tmp/tempflavors.json..."
  rm -f /tmp/tempflavors.json
fi

psql -h $HVS_DB_HOSTNAME -p $HVS_DB_PORT -U $HVS_DB_USERNAME -d $HVS_DB_NAME <<EOF
COPY (
  SELECT row_to_json(flavor_data) FROM (
    SELECT
      content
    FROM flavor
  ) flavor_data
) TO '/tmp/tempflavors.json';
EOF

if ! [ -s "/tmp/tempflavors.json" ];then
    echo "Error in retrieving the old Flavors from DB or There is no old flavor exists in the DB"
    exit
fi
echo "Retrieved flavors from db successfully"

echo "Successfully downloaded Flavor templates and Flavors from DB"

#Splitting flavor templates into separate files
echo "Started parsing the flavor templates"

FILE='/tmp/tempflavortemplate.json'  
 
while read line; do  
  
#Reading each line and store
echo $line >  ${TEMPLATE_DIR}tmp.json

templateID=`cat ${TEMPLATE_DIR}tmp.json | jq '.content.id'`
#removing "" in the id
templateID=`echo $templateID | sed 's/^.\(.*\).$/\1/'`

mv -f ${TEMPLATE_DIR}tmp.json ${TEMPLATE_DIR}${templateID}.json

#REMOVE "content" tag from flavor template file
sed -i 's/{"content"://g'  $TEMPLATE_DIR/$templateID.json

#REMOVE Last character } from flavor template file
sed -i 's/.$//'  $TEMPLATE_DIR/$templateID.json

done < $FILE 

echo "Downloaded Flavor templates are..."
ls -l ${TEMPLATE_DIR}

echo "Parsing and Storing the flavor templates are Successful"

#Splitting flavors into separate files
echo "Started parsing the flavors"

FILE='/tmp/tempflavors.json'  

while read line; do  
  
#Reading each line and store
echo $line >  ${OLD_FLAVORS_DIR}tmp.json

flavorID=`cat ${OLD_FLAVORS_DIR}tmp.json | jq '.content.meta.id'`
#removing "" in the id
flavorID=`echo $flavorID | sed 's/^.\(.*\).$/\1/'`

mv -f ${OLD_FLAVORS_DIR}tmp.json ${OLD_FLAVORS_DIR}${flavorID}.json

#REMOVE "content" tag from flavor file
sed -i 's/{"content"://g'  $OLD_FLAVORS_DIR/$flavorID.json

#REMOVE Last character } from flavor file
sed -i 's/.$//'  $OLD_FLAVORS_DIR/$flavorID.json

#construct proper json
sed 's/^/{"signed_flavors":[{"flavor":/' ${OLD_FLAVORS_DIR}${flavorID}.json > temp.json
mv -f temp.json $OLD_FLAVORS_DIR/$flavorID.json

sed 's/$/}]}/' ${OLD_FLAVORS_DIR}${flavorID}.json > temp.json
mv -f temp.json $OLD_FLAVORS_DIR/$flavorID.json

rm -f ${OLD_FLAVORS_DIR}temp.json

done < $FILE 

echo "Downloaded old flavors are..."
ls -l ${OLD_FLAVORS_DIR}

echo "Parsing and Storing the flavors are successful"
echo "Fetching old flavors from DB and constructing it properly are successfully completed"

#Downloading the flavor signing certificate
echo "Downloading the flavor signing certificate"

cp /etc/hvs/trusted-keys/flavor-signing.key $SIGNING_CERT_DIR
ls $SIGNING_CERT_DIR
echo "Copied Flavor signing certificate under $SIGNING_CERT_DIR"

#Cloning flavor convert tool from Git
echo "Cloning flavor convert tool from Git"

cd $TOOL_DIR

if [ -d utils ]; then
  echo "Remove existing directory utils..."
  rm -rf utils
fi

git clone $FC_TOOL_GIT

cd utils
echo "Switching branch"
git checkout $FC_TOOL_GIT_BRANCH
cd tools/flavor-convert
echo "Building the flavor convert tool"
make all

#Getting GIT Tag if available
TAG=git describe --tags --abbrev=0 2> /dev/null
echo $TAG

echo "Building flavor convert tool is Successful"

#Starting flavor conversion
echo "Start converting old flavors into new format"

#Get the list of old flavors from directory and Iterate one by one.
FILE='/tmp/listofoldflavorjson.txt'  
ls $OLD_FLAVORS_DIR > $FILE

while read line; do
if [ $TAG ] ; then
ConvertedData=$($TOOL_DIR/utils/tools/flavor-convert/flavor-convert-${TAG} -o ${OLD_FLAVORS_DIR}${line} -f $TEMPLATE_DIR -k ${SIGNING_CERT_DIR}flavor-signing.key)
else
ConvertedData=$($TOOL_DIR/utils/tools/flavor-convert/flavor-convert-v0.0.0 -o ${OLD_FLAVORS_DIR}${line} -f $TEMPLATE_DIR -k ${SIGNING_CERT_DIR}flavor-signing.key)
fi

convertedFlavor=$(echo $ConvertedData | cut -f1 -d@)
newsignature=$(echo $ConvertedData | cut -f2 -d@)

#Upload the new flavor back to the DB
id=`cat ${OLD_FLAVORS_DIR}${line} | jq '.signed_flavors['${index}'].flavor.meta.id'`
label=`cat ${OLD_FLAVORS_DIR}${line} | jq '.signed_flavors['${index}'].flavor.meta.description.label'`
newflavor_part=`cat ${OLD_FLAVORS_DIR}${line} | jq '.signed_flavors['${index}'].flavor.meta.description.flavor_part'`
newlabel=`echo $label | sed 's/^.\(.*\).$/\1/'`
newid=`echo $id | sed 's/^.\(.*\).$/\1/'`
created_at=$(date --rfc-3339=ns)

psql -h $HVS_DB_HOSTNAME -p $HVS_DB_PORT -U $HVS_DB_USERNAME -d $HVS_DB_NAME <<EOF
UPDATE flavor SET content='${convertedFlavor}',created_at='${created_at}',signature='${newsignature}' WHERE id='${newid}';
EOF

done < $FILE

#Removing created temporary files in /tmp directory
echo "Removing created temporary files in /tmp directory"
if test -f "/tmp/tempflavors.json"; then
  rm -f /tmp/tempflavors.json
fi

if test -f "/tmp/tempflavortemplate.json"; then
  rm -f /tmp/tempflavortemplate.json
fi

if test -f "/tmp/listofoldflavorjson.json"; then
  rm -f /tmp/listofoldflavorjson.json
fi

if test -f "/tmp/listofbasictemplates.json"; then
  rm -f /tmp/listofbasictemplates.json
fi
  
echo "END FLAVOR CONVERT TOOL"
################################# END ###################################