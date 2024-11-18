host='localhost'
dbuser='root'
dbport=10558

#!/bin/bash

usage(){
echo "Usage: [ options ]"
echo "Options:"
echo "  -m, --master Master info in the format 'hostname:port:database:user:password'"
echo "  -s, --slave  Slave info in the format 'hostname:port:database:user:password'"
}
IN_ARGS=$(getopt -o m:s:h --long master:,slave:,help -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1;
fi

eval set -- "$IN_ARGS"

while [ : ]; do
  case "$1" in
		-m | --master) 
		master_info=$2
		shift 2
		;;
    -s | --slave) 
		slave_info=$2
		shift 2
		;;
    -h | --help) 
		shift 2
		usage
    exit 0
		;;
		--) shift;
		    break
		;;
  esac
done

if [[ -z "${master_info}" || -z "${slave_info}" ]]; then
  usage
  exit 1
fi

for server_info in ${master_info} ${slave_info}
do
  echo "Apply XA RECOVER on server: $server_info"
  IFS=':' read -r -a connect_info <<< "${server_info}"
  host=${connect_info[0]}
  port=${connect_info[1]}
  database=${connect_info[2]}
  user=${connect_info[3]}
  password=${connect_info[4]}
  db_connect_str="--host=$host --port=$port --database=$database --user=$user --password=$password"
  results=($(mariadb $db_connect_str -Bse "XA RECOVER;"))
  re='^[0-9]+$'
  for row in "${results[@]}"
  do
    if ! [[ $row =~ $re ]] ; then
      echo "mariadb $db_connect_str -Bse \"XA COMMIT '$row';\""
      mariadb $db_connect_str  -Bse "XA COMMIT '$row';"
    fi
  done
done
