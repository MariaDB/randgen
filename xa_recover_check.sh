##############################################################################################
#This script applies XA RECOVER items both on master and slave. It also checks table         #
#checksums on both master and slave. Returns 0 if checksums match, otherwise 1.                                                        #
#NOTE: Make sure the XA PREPARE db sessions are closed.                                      #
#      Ideally this script should be run when the slave is not connected to the master.      #
#Example usage:                                                                              #
#xa_recover_check.sh --master=localhost:11243:xadb:root: --slave=localhost:11508:xadb:root:  #
##############################################################################################

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

IFS=':' read -r -a connect_info <<< "${master_info}"
host=${connect_info[0]}
port=${connect_info[1]}
database=${connect_info[2]}
user=${connect_info[3]}
password=${connect_info[4]}
master_db_connect_str="--host=$host --port=$port --database=$database --user=$user --password=$password"

IFS=':' read -r -a connect_info <<< "${slave_info}"
host=${connect_info[0]}
port=${connect_info[1]}
database=${connect_info[2]}
user=${connect_info[3]}
password=${connect_info[4]}
slave_db_connect_str="--host=$host --port=$port --database=$database --user=$user --password=$password"

for db_connect_str in "${master_db_connect_str}" "${slave_db_connect_str}"
do
  echo "Apply XA RECOVER on server: $db_connect_str"
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
echo "Apllied XA RECOVER items successfully both on master and slave."

echo "Check table checksums on master and slave"
slave_matched=0
tables=($(mariadb $master_db_connect_str -Bse "SHOW TABLES;"))
for table in "${tables[@]}"
do
  res=$(mariadb $master_db_connect_str -Bse "CHECKSUM TABLE $table;")
  read -ra arr <<<"$res"
  master_tbl_chksum=${arr[1]}
  res=$(mariadb $slave_db_connect_str -Bse "CHECKSUM TABLE $table;")
  read -ra arr <<<"$res"
  slave_tbl_chksum=${arr[1]}
  if [[ "$master_tbl_chksum" != "$slave_tbl_chksum" ]]; then
    slave_matched=1
    echo "Master $table checksum $master_tbl_chksum != Slave $table checksum $slave_tbl_chksum"
  fi
done

if [[ $slave_matched -eq 0 ]]; then
  echo "Slave test data is matching with the master data."
else
  echo "Slave test data is NOT matching with the master data."
fi

exit  $slave_matched
