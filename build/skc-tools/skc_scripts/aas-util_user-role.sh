AAS_KEYWORD=AAS
USER_SET_KEYWORD=USER_SET
ROLE_SET_KEYWORD=ROLE_SET
END_SET_KEYWORD=END_SET

AAS_TOKEN=""

AAS_USERNAME=admin
AAS_PASSWORD=password
AAS_URL=https://127.0.0.1/aas

CONFIG=config.conf

add_users() {
    if [ -z $1 ]; then return 1; fi
    _user='${!'$1'[@]}'
    for user in $(eval echo "$_user")
    do
        _pwd="\${$1[$user]}"
        pwd=$(eval echo "$_pwd")

        curl_flags="-X POST $AAS_URL/users \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer $AAS_TOKEN' \
            -d '{\"username\": \"$user\",\"password\": \"$pwd\"}' \
            -k -s -x \"\" "
        eval "curl $curl_flags" > /dev/null
    done
}

add_roles() {
    if [ -z $1 ]; then return 1; fi
    _role='${!'$1'[@]}'
    for key in $(eval echo "$_role")
    do
        _context="\${$1[$key]}"
        serv=$(echo "$key" | cut -d':' -f1)
        name=$(echo "$key" | cut -d':' -f2)

        context=$(eval echo "$_context")
        context_field=""
        if [ "$context" != "-" ]; then context_field=', "context":"'$context'"'; fi

        curl_flags="-X POST $AAS_URL/roles \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer $AAS_TOKEN' \
            -d '{\"service\": \"$serv\", \"name\": \"$name\"$context_field}' \
            -k -s -x \"\" "
        eval "curl $curl_flags" > /dev/null
    done
}

user_id() {
    if [ -z $1 ]; then return 1; fi
    curl_flags="-G '$AAS_URL/users' \
        --data-urlencode 'name=$1' \
        -H 'Authorization: Bearer $AAS_TOKEN' \
        -k -s -x \"\" "
    echo "$(eval "curl $curl_flags")" | cut -d'"' -f4
}

role_id() {
    if [ -z $1 ] || [ -z $2 ]; then return 1; fi
    curl_flags="-G '$AAS_URL/roles' \
        --data-urlencode 'service=$1' \
        --data-urlencode 'name=$2' \
        --data-urlencode 'context=$3' \
        -H 'Authorization: Bearer $AAS_TOKEN' \
        -k -s -x \"\" "
    echo "$(eval "curl $curl_flags")" | cut -d'"' -f4
}

# this function associates all user with all roles
# in the array passed into it over REST api calls
map_roles_to_users() {
    if [ -z $1 ] || [ -z $2 ]; then return 1; fi

    r_ids=""
    _role='${!'$1'[@]}'
    for role_key in $(eval echo "$_role")
    do
        _context="\${$1[$role_key]}"
        serv=$(echo "$role_key" | cut -d':' -f1)
        name=$(echo "$role_key" | cut -d':' -f2)

        context=$(eval echo "$_context")
        if [ "$context" = "-" ]; then unset context; fi
        r_id=$(role_id $serv $name "$context")
        if [ "$r_id" = "[]" ]; then unset r_id; fi
        r_ids=$r_ids'"'$r_id'",'
    done

    _user='${!'$2'[@]}'
    for user in $(eval echo "$_user")
    do
        u_id=$(user_id $user)
        curl_flags="-X POST $AAS_URL/users/$u_id/roles \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer $AAS_TOKEN' \
            -d '{\"role_ids\": [${r_ids::-1}]}' \
            -k -s -x \"\" "
        eval "curl $curl_flags" > /dev/null
    done
}

read_config_and_run() {
    if [ -z $1 ]; then return 1; fi
    while read -r line
    do
        arg1=$(echo "$line" | cut -d' ' -f1)
        arg2=$(echo "$line" | cut -d' ' -f2-)

        if [ -z "$arg1" ] || [ ${arg1:0:1} == "#" ]; then continue; fi
        if [ $arg1 = $USER_SET_KEYWORD ] || [ $arg1 = $ROLE_SET_KEYWORD ]; then
            local current_array=$arg1
            declare -Ag $current_array
        elif [ $arg1 = $END_SET_KEYWORD ]; then
            if [ ! -z $ADD_USERS ]; then add_users $USER_SET_KEYWORD; fi
            if [ ! -z $ADD_ROLES ]; then add_roles $ROLE_SET_KEYWORD; fi
            map_roles_to_users $ROLE_SET_KEYWORD $USER_SET_KEYWORD
            unset current_array
            unset $USER_SET_KEYWORD
            unset $ROLE_SET_KEYWORD
        elif [ ! -z $current_array ] && [ ! -z "$arg2" ]; then
            eval "$current_array[$arg1]=\"$arg2\""
        fi
    done < $1
    return $?
}

print_help() {
    echo "Usage: $0 [-ru] -c [config_name]"
    echo "    -h    print help and exit"
    echo "    -c    read config from specified file,"
    echo "          if used, the filename must be given"
    echo "    -r    enable adding listed roles"
    echo "    -u    enable adding listed users"
}

if [ $# -eq 0 ] ; then
    print_help
    exit 1
fi

OPTIND=1
work_list=""
while getopts hc:ur opt; do
    case ${opt} in
    h)  print_help; exit 0 ;;
    r)  ADD_ROLES="true" ;;
    u)  ADD_USERS="true" ;;
    c)  if [ ! -z ${OPTARG} ] ; then CONFIG=${OPTARG}; fi ;;
    *)  print_help; exit 1 ;;
    esac
done

# read aas information
while read arg1 arg2 arg3
do
    if [ -z "$arg1" ] || [ ${arg1:0:1} == "#" ]; then continue; fi
    if [ $arg1 = $AAS_KEYWORD ]; then
        read="true"
    elif [ ! -z $arg2 ] && [ ! -z $read ]; then
        AAS_USERNAME=$arg1
        AAS_PASSWORD=$arg2
        AAS_URL=$arg3
        break
    fi
done < $CONFIG

AAS_TOKEN=$(eval "curl -X POST $AAS_URL/token -d '{\"username\": \"$AAS_USERNAME\", \"password\": \"$AAS_PASSWORD\" }' -k -s -x \"\"")
if [ $? -ne 0 ] ; then
    echo "Error: cannot get aas token"
    exit 1
fi

read_config_and_run $CONFIG

