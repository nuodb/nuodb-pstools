: ${NUODB_HOME:=/opt/nuodb}

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
  [ -z ${NUODB_VARDIR+x} ] && [ -r ${NUODB_HOME}/etc/nuodb_setup.sh ] && . $NUODB_HOME/etc/nuodb_setup.sh

  local dbname=${DBNAME:-LOG}
  DBNAME=${dbname}

  [ $1 = dbname ]          && echo ${dbname}
  [ $1 = dbuser ]          && echo ${DBUSER:-$(__nuodb__property $1 dba)}
  [ $1 = dbpass ]          && echo ${DBPASS:-$(__nuodb__getpass $(__nuodb__property $1 dba))}
  [ $1 = dbschema ]        && echo ${DBSCHEMA:-$(__nuodb__property $1 dbo)}
  [ $1 = archive ]         && echo ${ARCHIVE:-${NUODB_VARDIR}/production-archives/${dbname}}
  [ $1 = broker ]          && echo ${BROKER:-$(__nuodb__property $1 $(hostname) )}
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
    local TIMEIT=""
    for ((i=1 ; i <= numargs ; i++))
    do
        if [ "$1" = "--verbose" ]; then
            verbose=1
        elif [ "$1" = "--csv" ]; then
	    local csv=1
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
       ${TIMEIT} ${NUODB_HOME}/bin/nuosql "${args[@]}"
       local RC=$?
       [ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
       return ${RC}
    fi
    local last="${@:$#}"
    if [ "${last#* }" = "${last}" ]; then
        test $verbose -eq 1 && echo "nuosql ${args[@]} ${@:1:$#} "
  	${TIMEIT} ${NUODB_HOME}/bin/nuosql "${args[@]}" "${@:1:$#}"
	local RC=$?
	[ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
        return ${RC}
    fi
    local -a rest
    rest=( "${@:1:$# - 1}" )
    if [ -z ${csv+x} ]; then
       test $verbose -eq 1 && echo "nuosql "${args[@]}" --nosemicolon "${rest[@]}" "
       echo "$last" | ${TIMEIT} ${NUODB_HOME}/bin/nuosql "${args[@]}" --nosemicolon "${rest[@]}"
    else
       test $verbose -eq 1 && echo nuoloader "${args[@]}" "${rest[@]}" --export "${last}" --to ,titles
       ${TIMEIT} ${NUODB_HOME}/bin/nuoloader "${args[@]}" "${rest[@]}" --export "${last}" --to ,titles
    fi
    local RC=$?
    [ ! -z ${TMPDIR} ] && [ -e ${TMPDIR} ] && rm -rf ${TMPDIR}
    return ${RC}
}

#
# call nuodbmgr
#
function nuocmd()
{
   local broker=$(__nuodb__param broker)
   local pass=$(__nuodb__param domain_password)
   local user=$(__nuodb__param domain_user)
   local verbose=0
   local -a iargv
   local numargs=$#

   for ((i=1 ; i <= numargs ; i++))
   do
       if [ "$1" = "--verbose" ]; then
           verbose=1
       else
           iargv+=( "$1" )
       fi
       shift
   done

   set -- "${iargv[@]}"

   local TMPDIR=$(mktemp -d)
   local TMPPIPE=${TMPDIR}/nuodbmgr
   mkfifo -m 600 ${TMPPIPE}

   local PROPERTIES=$(cat <<EOF
password=${pass}
$([ -r ~/.nuocmd.properties ] && cat ~/.nuocmd.properties)
EOF
)
   (echo "${PROPERTIES}" > ${TMPPIPE} &) 2>&1 >/dev/null
   if [ $# -eq 0 ]; then
      [[ $verbose -eq 1 ]] && echo nuodbmgr --broker $broker --password $pass --user $user
      ${NUODB_HOME}/bin/nuodbmgr --broker $broker --properties ${TMPPIPE} --user $user
   else
      [[ $verbose -eq 1 ]] && echo nuodbmgr --broker $broker --password $pass --user $user --command \"$*\"
      ${NUODB_HOME}/bin/nuodbmgr --broker $broker --properties ${TMPPIPE} --user $user --command "$*"
   fi
   local RCODE=$?
   [ -z ${TMPDIR+x} ] || rm -rf ${TMPDIR}
   return ${RCODE}
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

#
# dump schema from current database
#
function nuoschema()
{
    nuodb-migrator schema  \
	--source.driver=com.nuodb.jdbc.Driver \
	--source.url=jdbc:com.nuodb://$(__nuodb__param broker)/$(__nuodb__param dbname) \
	--source.schema=$(__nuodb__param dbschema)  \
	--source.username=$(__nuodb__param dbuser)  \
	--source.password=$(__nuodb__param dbpass) #| sql-formatter | sed 's/; /;^/g' | tr '^' '\n'
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
    echo $(__nuodb__getown user "${NUODB_HOME}/jar")
}

# decrypts password if it is encrypted
# note that key must be in ~/.nuodb.key and not
# NUODB_PASSKEY environment variable
function __nuodb__getpass()
{
  local password=$1
  local home=${NUODB_HOME:-/opt/nuodb}
  local pass=$1
  local key=${NUODB_PASSKEY:-$([ -r $(eval echo ~$(whoami))/.nuodb.key ] && cat $(eval echo ~$(whoami))/.nuodb.key)}

  if [ "${key}x" != "x" ] ; then
      pass=$(NUODB_PASSKEY=${key} java -jar "${home}/plugin/agent/password-provider-1.0-SNAPSHOT.jar" --decrypt "${password}" 2> /dev/null)
      [ $? -ne 0 ] && pass=$1
  fi
  echo ${pass}
}

alias nuosummary="nuocmd show domain summary"
