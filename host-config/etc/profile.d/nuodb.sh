#
# Set of functions to use in bash (zsh seems to work bourne shell and ksh probably not).
#
# Three utility files can be used for functions in this script.
#  ~/.nuodb.properties    -- maps DBNAME to variables for username, password, schema, etc
#  ~/.nuodbmgr.properties -- setup commands to be every time nuodbmgr is run
#  ~/.nuodb.key           -- encryption key so passwords in .nuodb.properties aren't in the clear.

function __nuodb__home() {
    local home=${NUODB_HOME:-/opt/nuodb}
    echo ${home}
}

# if we store database parameters in .nuodb.properties file
function __nuodb__property() {
    local key=$1
    local properties=~/.nuodb.properties
    local param
    if [[ -e $properties ]]; then
	local PARAMS="$(gawk '{ st=index($0,"=");printf("%s %s\n",substr($0,0,st-1),substr($0,st+1)); }' ${properties})"
	param=$(gawk -v KEY="${DBNAME}.${key}" '$1 == KEY {print $2}' <<< "${PARAMS}")
	[[ "x$param" = "x" ]] && param=$(gawk -v KEY=".${key}" '$1==KEY { print $2}' <<< "${PARAMS}")
    else
	param=${2:-}
    fi
    [ "x$param" = "x" ] && param=$2
    echo ${param}
}

# get __nuodb__parameter for script from environment, .nuodb.properties file (based upon DBNAME) or default
function __nuodb__param()
{
  [ -z ${NUODB_VARDIR+x} ] && [ -r $(__nuodb__home)/etc/nuodb_setup.sh ] && . $(__nuodb_home)/etc/nuodb_setup.sh

  local dbname=${DBNAME:-LOG}
  DBNAME=${dbname}

  [ $1 = dbname ]          && echo ${dbname}
  [ $1 = dbuser ]          && echo ${DBUSER:-$(__nuodb__property $1 dba)}
  [ $1 = dbpass ]          && echo ${DBPASS:-$(__nuodb__getpass $(__nuodb__property $1 dba))}
  [ $1 = dbschema ]        && echo ${DBSCHEMA:-$(__nuodb__property $1 dbo)}
  [ $1 = archive ]         && echo ${ARCHIVE:-${NUODB_VARDIR}/production-archives/${dbname}}
#  [ $1 = broker ]          && echo ${BROKER:-$(__nuodb__property $1 $(hostname) )}
  [ $1 = broker ]          && echo ${BROKER:-$(__nuodb__property $1 127.0.0.1 )}
#  [ $1 = broker ]          && echo ${BROKER:-$(__nuodb__property $1 192.168.123.177 )}
  [ $1 = domain_password ] && echo ${DOMAIN_PASSWORD:-$(__nuodb__getpass $(DBNAME=domain __nuodb__property pass bird))}
  [ $1 = domain_user ]     && echo ${DOMAIN_USER:-$(DBNAME=domain __nuodb__property user domain)}
}


#
# sql snippet that adds microseconds ($2) to a timestamp ($1)
#
function __nuodb__add_microsecs()
{
  echo "date_add(date_add($1,interval $2/1000000. second), interval $2%100000. microsecond)"
}

#
# sql snippet to format microseconds to a time
#
function __nuodb__format_timing()
{
  echo "cast( $(__nuodb__add_microsecs "'today'" $1) as time)"
}

#
# Format multi line sql statement to single line and call sql.
#
function __nuodb__query()
{
    local last="${@:$#}"
    local -a rest
    rest=( "${@:1:$# - 1}" )
    # collapse multi-line statement into single line
    last=$(echo "${last}" | __nuodb__trim | tr -d "\\r" | tr "\\n" " ")
    nuosql "${rest[@]}" "${last}"
}

#
# interface to nuosql that provides some
#
function nuosql() {
    local -a args
    local numargs=$#
    local -a iargv
    local verbose=0
    local titles="titles"
    local TIMEIT=""
    for ((i=1 ; i <= numargs ; i++))
    do
        if [ "$1" = "--verbose" ]; then
            verbose=1
        elif [ "$1" = "--csv" ]; then
	    local csv=1
        elif [ "$1" = "--notitles" ]; then
	    titles=""
        elif [ "$1" = "--time" ]; then
	    TIMEIT="time -p"
	else
            iargv+=( "$1" )
        fi
        shift
    done
    set -- "${iargv[@]}"

    local dbname=$(__nuodb__param dbname)
    if [ "$dbname" != "" ] ; then
        local broker=$(__nuodb__param broker)
	[ "$broker" != "" ] && dbname="${dbname}@${broker}"
       args=( "${dbname}" )
    fi

    local dbuser=$(__nuodb__param dbuser)
    if [ "$dbuser" != "" ] ;then
       args+=( "--user" $dbuser )
    fi
    local dbpass=$(__nuodb__param dbpass)
    if [ "$dbpass" != "" ]; then
        if [ -z ${csv+x} ]; then
	    local TMPDIR=$(mktemp -d)
	    local TMPPIPE=${TMPDIR}/nuosql
	    mkfifo -m 600 ${TMPPIPE}
	    args+=( "--config" "${TMPPIPE}" )
	    (echo "password ${dbpass}" > ${TMPPIPE} & ) 2>&1 >/dev/null
	else
	    args+=( "--password" "${dbpass}" )
	fi 
    fi
    local dbschema=$(__nuodb__param dbschema)
    if [ "$dbschema" != "" ]; then
       args+=( "--schema" $dbschema )
    fi

    if [ $# -eq 0 ] ; then 
       test $verbose -eq 1 && echo nuosql "${args[@]}"
       ${TIMEIT} $(__nuodb__home)/bin/nuosql "${args[@]}"
       local RC=$?
       [ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
       return ${RC}
    fi
    local last="${@:$#}"
    if [ "${last#* }" = "${last}" ]; then
        test $verbose -eq 1 && echo "nuosql ${args[@]} ${@:1:$#} "
  	${TIMEIT} $(__nuodb__home)/bin/nuosql "${args[@]}" "${@:1:$#}"
	local RC=$?
	[ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
        return ${RC}
    fi
    local -a rest
    rest=( "${@:1:$# - 1}" )
    if [ -z ${csv+x} ]; then
       test $verbose -eq 1 && echo "nuosql "${args[@]}" --nosemicolon "${rest[@]}" "
       echo "$last" | ${TIMEIT} $(__nuodb__home)/bin/nuosql "${args[@]}" --nosemicolon "${rest[@]}"
    else
       test $verbose -eq 1 && echo nuoloader "${args[@]}" "${rest[@]}" --export "${last}" --to ,${titles}
       ${TIMEIT} $(__nuodb__home)/bin/nuoloader "${args[@]}" "${rest[@]}" --export "${last}" --to ,${titles}
    fi
    local RC=$?
    [ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
    return ${RC}
}

function __nuodb__join_by { local IFS="$1"; shift; echo "$*"; }

#
# load into current database data from csvfile.
#
function nuoload()
{
    local file=""
    local table=""
    local -a args
    
    while (( $# ))
    do
	local key=$1
	shift
	case $key in
	    --csv | -c)
		file=$1
		shift
		;;
	    --table | -t)
		table=$1
		shift
		;;
	    *)
		echo $1
		echo "usage: $0 --csv <file> --table <tablename>"
		return 1
		;;
	esac
    done
    [ "$file" = "" ]   && echo "usage: $0 --csv <file> --table <tablename>" && return 1
    [ "$table" = "" ] && echo "usage: $0 --csv <file> --table <tablename>" && return 1

    local dbname=$(__nuodb__param dbname) 
    if [ "$dbname" != "" ]
    then
	local broker=$(__nuodb__param broker) 
	[ "$broker" != "" ] && dbname="${dbname}@${broker}" 
	args=("${dbname}") 
    fi
    local dbuser=$(__nuodb__param dbuser) 
    if [ "$dbuser" != "" ]
    then
	args+=("--user" $dbuser) 
    fi
    local dbpass=$(__nuodb__param dbpass) 
    if [ "$dbpass" != "" ]
    then
	args+=("--password" $dbpass)
    fi
    local dbschema=$(__nuodb__param dbschema) 
    if [ "$dbschema" != "" ]
    then
	args+=("--schema" $dbschema) 
    fi

    local X=$(head -1 $file |awk -F, '{ print NF; }')
    local icmd="INSERT INTO $table (\"$(head -1 ${file} | sed 's/,/","/g' | tr -d '\r')\") VALUES ($(__nuodb__join_by , $(printf "? %.0s" $(seq 1 $X))))"
 
    echo nuoloader "${args[@]}" --to "'${icmd}'" 
    tail -n +2 ${file} | $(__nuodb_home)/bin/nuoloader "${args[@]}" --to "${icmd}" 
    return $?
}


#
# call nuodbmgr
#
function nuocmd () {
    local broker=$(__nuodb__param broker) 
    local pass=$(__nuodb__param domain_password) 
    local user=$(__nuodb__param domain_user) 
    local verbose=0 
    local -a iargv
    local numargs=$# 
    local -a options
    local opt
    while (( $# ))
    do
        local key=$1
        shift
        case $key in
        --verbose | -v)
            verbose=1
            ;;
        --broker | -b)
            broker = $1
            shift ;;
        --password | -p)
            pass = $1
            shift ;;
        --user | -u)
            user = $1
            shift ;;
        --database | --log)
            options+=("$key"  "$1")
            shift ;;
        --help | --version | noLineEditor)
            options+=("$key")
            ;;
        *)
            iargv+=("$key") 
            ;;
        esac
    done
    set -- "${iargv[@]}"
    local TMPDIR=$(mktemp -d) 
    local TMPPIPE=${TMPDIR}/nuodbmgr 
    mkfifo -m 600 ${TMPPIPE}
    local PROPERTIES=$(cat <<EOF
$([ -r ~/.nuodbmgr.properties ] && cat ~/.nuodbmgr.properties)
password=${pass}
EOF
) 
    (
        echo "${PROPERTIES}" > ${TMPPIPE} &
    ) 2>&1 > /dev/null
    if [ $# -eq 0 ]
    then
        [[ $verbose -eq 1 ]] && echo nuodbmgr --broker $broker --password $pass --user $user ${options[@]}
        $(__nuodb__home)/bin/nuodbmgr --broker $broker --properties ${TMPPIPE} --user $user ${options[@]}
    else
        [[ $verbose -eq 1 ]] && echo nuodbmgr --broker $broker --password $pass --user $user  ${options[@]} --command \"$*\"
        $(__nuodb__home)/bin/nuodbmgr --broker $broker --properties ${TMPPIPE} --user $user  ${options[@]} --command "$*"
    fi
    local RCODE=$? 
    [ -z ${TMPDIR+x} ] || rm -i -rf ${TMPDIR}
    return ${RCODE}
}

function nuostartdb() {
   local pass=$(__nuodb__param dbpass)
   local user=$(__nuodb__param dbuser)
   local archive=$(__nuodb__param archive)
   local init=true
   [ -e $archive ] && init=false
   nuocmd "$@" start process sm database $(__nuodb__param dbname)  archive $archive host localhost initialize $init 
   sleep 2
   nuocmd "$@" start process te database $(__nuodb__param dbname)  host localhost  options "'--dba-user $user --dba-password $pass'"
}

function __nuodb__removeblanks() {
  grep -v '^[ \t]*$'
}

function __nuodb__doheader()
{
    local DO=${1:-0}
    # would like to left justify field name
    # optional verbose (__nuodb__query string)
    if [[ ${DO} = 0 ]]; then
        awk 'IN { print; } /---/ { IN=1; }'
    else        
        awk -v W=$(tput cols) '/-----/ { $0 = substr($0,0,W); } { print; }'
    fi
}

# ltrim and rtrim $0 (remove leading and trailing blanks)
function __nuodb__trim() {
   awk '{ gsub(/[ \t]+$/,"",$0) ; gsub(/^[ \t]+/,"",$0); print; }'
#  sed -e 's/^[ \t]*//' -e 's/[ \t]*$//'
}


#truncate output lines
function __nuodb__fit() {
    if [[ $1 == 0 ]] ; then
        # strip trailing blanks
        awk '{ gsub(/[ \t]+$/,"",$0) ; print; }'
    else
        awk -v W=$(tput cols) '{ print substr($0,0,W); }'
    fi
}

function nuolist() {
    local -a OPS
    local SCHEMA=""
    local WIDTH=0
    local DEF="substring(viewdefinition,position('as' in viewdefinition)+3)"
    local STMT='sqlstring'
    local TTYPE="type like '%TABLE'"
    local ANDFILTER=""
    local ONLYFILTER=""
    local HEADER=0
    local USAGE="usage: nuolist [-s|--schema <schema>] [-w|--width ] [-f|--filter <filter>] connections|transactions|[-t type] tables|views|indexes|schemas|properties|users"
    if [[ $# = 0 ]]; then
        echo $USAGE
        return
    fi
   
    while (( $# ))
    do
        local key=$1
        shift
        case $key in
            -f|--filter)
                ONLYFILTER=" WHERE $1 "
                ANDFILTER=" AND ( $1 ) "
                shift
                ;;
            -t|--type)
                TTYPE=" type = '$1'"
                shift
                ;;
            -s|--schema)
                SCHEMA=$(printf "t.schema = '%s' and" "$1")
                shift
                ;;
            -w|--width)
                WIDTH=1
                ;;
            -H|--header)
                HEADER=1
                ;;
            -h|--help)
                echo $USAGE
                return
                ;;
            *)
                OPS+=("$key")
                ;;
        esac
    done

    for op in "${OPS[@]}"; do
        if [ "${op}" = "tables" ] ; then
           __nuodb__query "
              SELECT schema||'.'||tablename AS TABLE
                FROM system.allsystemtables t
               WHERE ${SCHEMA} ${TTYPE} ${ANDFILTER}
            ORDER BY schema,tablename;
           " | __nuodb__doheader 0 | column
        fi

        [ "${op}" = "schemas" ] && __nuodb__query "SELECT schema from system.schemas" | __nuodb__doheader | column | __nuodb__removeblanks

        [ "${op}" = "users" ] && __nuodb__query "SELECT username from system.users" | __nuodb__doheader | column | __nuodb__removeblanks

        [ "${op}" = "nodes" ] && __nuodb__query "SELECT * from system.nodes" | __nuodb__doheader $HEADER  | __nuodb__removeblanks

        [ "${op}" = "properties" ] && __nuodb__query "select * from system.properties order by property" | __nuodb__doheader $HEADER | __nuodb__removeblanks

        [ "${op}" = "views" ] && __nuodb__query "
             SELECT schema||'.'||tablename AS VIEWNAME ,
                    ${DEF} AS DEFINITION
               FROM system.tables t 
              WHERE ${SCHEMA} type = 'VIEW' ${ANDFILTER}
           ORDER BY schema,tablename;
        " | __nuodb__doheader $HEADER | __nuodb__trim | __nuodb__fit $WIDTH

        [ "${op}" = "transactions" ] && __nuodb__query "
             SELECT  connid,
                     t.id as transaction,
                     blockedby,
                     hostname||':'||port as TE,
                     user,
                     $(__nuodb__format_timing transruntime) as txntime,
                     $(__nuodb__format_timing runtime) as stmttime,
                     ${STMT} as statement
                FROM system.connections c 
           LEFT JOIN system.transactions t
                  ON c.transid = t.id
           LEFT JOIN system.nodes n
                  ON n.id = t.nodeid ${ONLYFILTER};
        " | __nuodb__doheader $HEADER | __nuodb__fit $WIDTH

        [ "${op}" = "connections" ] && __nuodb__query "
             SELECT  connid,
                     transid as transaction,
                     hostname||':'||port as TE,
                     user,
                     $(__nuodb__format_timing transruntime) as txntime,execid,
                     ${STMT} as statement
               FROM  system.connections c
          LEFT JOIN system.nodes n
                 ON n.id = c.nodeid ${ONLYFILTER};
        " | __nuodb__doheader $HEADER | __nuodb__fit $WIDTH

        [ "${op}" = "indexes" ] && __nuodb__query "
            SELECT
                  (SELECT CASE (indextype) 
                   WHEN 0 THEN 'PK' 
                   WHEN 1 THEN 'UNIQUE'
                   WHEN 2 THEN ''
                   END
                   FROM dual) AS INDEXTYPE ,
                   indexname,
                   schema||'.'||tablename as tablename
              FROM system.indexes t
             WHERE $SCHEMA TRUE
          ORDER BY tablename,indexname
        " | __nuodb__doheader $HEADER | __nuodb__removeblanks | __nuodb__fit $WIDTH
	echo
    done
}

function __nuosql__formatter()
{
#    cat - 
    sql-formatter | sed 's/; /;^/g' | tr '^' '\n'
}

#
# dump schema from current database
#
function nuoschema()
{
    local TMPDIR=$(mktemp -d) 
    local TMPPIPE=${TMPDIR}/nuoschema
    mkfifo -m 600 ${TMPPIPE}
    local PROPERTIES=$(cat <<EOF
--source.driver=com.nuodb.jdbc.Driver
--source.url=jdbc:com.nuodb://$(__nuodb__param broker)/$(__nuodb__param dbname)
--source.schema=$(__nuodb__param dbschema) 
--source.username=$(__nuodb__param dbuser)
--source.password=$(__nuodb__param dbpass)
EOF
) 
    (
        echo "${PROPERTIES}" > ${TMPPIPE} &
    ) 2>&1 > /dev/null
    
    $(__nuodb__home)/bin/nuodb-migrator schema  --config=${TMPPIPE} | __nuosql_formatter
    [ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
}

#
# import data from export
#
function nuoimport()
{
   local dir=.
   local dbname=$(__nuodb__param dbname)
   local dbuser=$(__nuodb__param dbuser)
   local broker=$(__nuodb__param broker)
   local dbpass=$(__nuodb__param dbpass)
   local dbschema=$(__nuodb__param dbschema)
   local tables='*'
   local data=true
   local schema=false

    while (( $# ))
    do
        local key=$1
        shift
        case $key in
	    -t|--tables)
		tables=$1
		shift
		;;
	    -d|--dir)
	        dir=$1
		shift
		;;
	    -D|--data)
	        data=$1
		shift
		;;
	    -s|--schema)
	        schema=$1
		shift
		;;
            -h|*)
		echo "$0 [-d|--dir dumpdirectory] [-t|--tables tablelist] [-D|--data true|false] [-s|--schema false|true]"
		return
                ;;
        esac
    done

    if [ -e ${dir}/backup.cat ] ; then
	local TMPDIR=$(mktemp -d) 
	local TMPPIPE=${TMPDIR}/nuoschema
	mkfifo -m 600 ${TMPPIPE}
	local PROPERTIES=$(cat <<EOF
--target.username=$(__nuodb__param dbuser)
--target.password=$(__nuodb__param dbpass)
--target.driver=com.nuodb.jdbc.Driver
--target.url=jdbc:com.nuodb://${broker}/${dbname}
--target.schema=${dbschema} --input.path=${dir}
--table=${tables} --data=${data} --schema=${schema}
EOF
) 
	(
            echo "${PROPERTIES}" > ${TMPPIPE} &
	) 2>&1 > /dev/null
	$(__nuodb__home)/bin/nuodb-migrator load --config=${TMPPIPE}
	[ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
    else
       echo "${dir} does not have exported data."
    fi
}


#
# export data from database to a directory
#
function nuoexport()
{
   local dir=.
   local dbname=$(__nuodb__param dbname)
   local dbuser=$(__nuodb__param dbuser)
   local broker=$(__nuodb__param broker)
   local dbpass=$(__nuodb__param dbpass)
   local dbschema=$(__nuodb__param dbschema)
   local format=CSV
   local tables='*'

    while (( $# ))
    do
        local key=$1
        shift
        case $key in
            -f|--format)
		format=$1
                shift
                ;;
	    -t|--tables)
		tables=$1
		shift
		;;
	    -d|--dir)
	        dir=$1
		shift
		;;
            -h|*)
		echo "$0 [-d|--dir dumpdirectory] [-f|--format CSV|BSON|XML] [-t|--tables tablelist]"
		return
                ;;
        esac
    done

    local TMPDIR=$(mktemp -d) 
    trap "rm -rf ${TMPDIR}" SIGINT SIGTERM SIGEXIT

    local TMPPIPE=${TMPDIR}/nuoschema
    mkfifo -m 600 ${TMPPIPE}
    local PROPERTIES=$(cat <<EOF
--source.driver=com.nuodb.jdbc.Driver
--source.url=jdbc:com.nuodb://${broker}/${dbname}
--source.username=$(__nuodb__param dbuser)
--source.password=$(__nuodb__param dbpass)
--source.schema=${dbschema}
--output.type=${format}
--output.path=${dir} 
--threads=10
EOF
) 
    (
        echo "${PROPERTIES}" > ${TMPPIPE} &
    ) 2>&1 > /dev/null
    $(__nuodb__home)/bin/nuodb-migrator dump --table ${tables} --config="${TMPPIPE}"
    [ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
}


function __nuodb__getown () {
    case $1 in
        (user)  stat -c %U "$2" 2>/dev/null || stat -f %Su "$2" 2>/dev/null ;;
        (group) stat -c %G "$2" 2>/dev/null || stat -f %Sg "$2" 2>/dev/null ;;
    esac
}

function __nuodb__log() {
    local LOGDATE=$(date)
    echo ${LOGDATE} - "$@"
}

function nuodbuser() {
    echo $(__nuodb__getown user "$(__nuodb__home)/jar")
}

# decrypts password if it is encrypted
# note that key must be in ~/.nuodb.key and not
# NUODB_PASSKEY environment variable
function __nuodb__getpass()
{
  local password=$1
  local home=$(__nuodb__home)
  local pass=$1
  local key=${NUODB_PASSKEY:-$([ -r $(eval echo ~$(whoami))/.nuodb.key ] && cat $(eval echo ~$(whoami))/.nuodb.key)}

  if [ "${key}x" != "x" ] ; then
      pass=$(NUODB_PASSKEY=${key} java -jar "${home}/plugin/agent/password-provider-1.0-SNAPSHOT.jar" --decrypt "${password}" 2> /dev/null)
      [ $? -ne 0 ] && pass=$1
  fi
  echo ${pass}
}

alias nuosummary="nuocmd show domain summary"
export PATH=$(__nuodb__home)/etc:$PATH
