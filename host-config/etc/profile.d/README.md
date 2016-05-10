#Bash Script Framework

The nuodb.sh file contains a set of wrapper functions that make it easier to execute some very common nuodb commands.   The functions also utilitize the PasswordProvider plugin to support encrypted passwords in the configuration file that two of the functions use.  For an explanation on the rational for the using encrypted passwords in the configuration file see [Encryption Rational](#encryption-rational).

The public functions provided by this script are:

* [nuocmd](#nuocmd)
* [nuosql](#nuosql)
* [nuolist](#nuolist)
* [nuoschema](#nuoschema)
* [nuodbuser](#nuodbuser)

The nuocmd and nuosql functions retrieve the username, password, and other options for a given database from a properties file instead of requiring the user to type in the username and password on every invocation. The functions also support the use of the password provider decryption function so that the passwords can be encrypted in this file.

The supporting files need to be in the users home directory.  These files are:

* [.nuodb.properties](#nuodb.properties)
* [.nuodb.key](#nuodb.key)

----
###nuocmd
The nuocmd function is a wrapper around [NuoDB Manager](http://doc.nuodb.com/Latest/Default.htm#NuoDB-Manager.htm).  NuoDB Manager requires the arguments:

* --broker
* --user
* --password

nuocmd will retrieve these values from the [~/.nuodb.properties](#nuodb.properties) file (or variable settings) to create the command line arguments and invoke /opt/nuodb/bin/nuodbmgr.

For example, to get the domain summary from a broker a user would execute the following:

```
[fred@c117 ~] /opt/nuodb/bin/nuodbmgr --broker sleepy --user domain --password bird --command 'show domain summary'

Hosts:
[broker] * sleepy/10.1.32.7:48004 (forest) CONNECTED
[broker] doc/10.1.32.10:48004 (forest) CONNECTED
[broker] grumpy/10.1.32.11:48004 (forest) CONNECTED
[broker] happy/10.1.32.8:48004 (forest) CONNECTED
[broker] doppy/10.1.32.12:48004 (forest) CONNECTED
[broker] bashful/10.1.32.9:48004 (forest) CONNECTED
[broker] sneezy/10.1.32.13:48004 (forest) CONNECTED

Database: SnowWhite, (unmanaged), processes [5 TE, 2 SM], ACTIVE
[SM] grumpy/10.1.32.11:48005 (forest) [ pid = 20474 ] [ nodeId = 1 ] RUNNING
[SM] happy/10.1.32.8:48005 (forest) [ pid = 5986 ] [ nodeId = 2 ] RUNNING
[TE] doppy/10.1.32.12:48005 (forest) [ pid = 18876 ] [ nodeId = 3 ] RUNNING
[TE] bashful/10.1.32.9:48005 (forest) [ pid = 23316 ] [ nodeId = 5 ] RUNNING
[TE] sneezy/10.1.32.13:48005 (forest) [ pid = 7710 ] [ nodeId = 4 ] RUNNING
[TE] doc/10.1.32.10:48005 (forest) [ pid = 16259 ] [ nodeId = 6 ] RUNNING
[TE] sleepy/10.1.32.7:48005 (forest) [ pid = 13686 ] [ nodeId = 7 ] RUNNING
``` 
With nuocmd after configuring broker,user,password in ~/.nuodb.properties you executed:

```
[fred@c117 ~] nuocmd show domain summary
Hosts:
[broker] * sleepy/10.1.32.7:48004 (forest) CONNECTED
[broker] doc/10.1.32.10:48004 (forest) CONNECTED
[broker] grumpy/10.1.32.11:48004 (forest) CONNECTED
[broker] happy/10.1.32.8:48004 (forest) CONNECTED
[broker] doppy/10.1.32.12:48004 (forest) CONNECTED
[broker] bashful/10.1.32.9:48004 (forest) CONNECTED
[broker] sneezy/10.1.32.13:48004 (forest) CONNECTED

Database: SnowWhite, (unmanaged), processes [5 TE, 2 SM], ACTIVE
[SM] grumpy/10.1.32.11:48005 (forest) [ pid = 20474 ] [ nodeId = 1 ] RUNNING
[SM] happy/10.1.32.8:48005 (forest) [ pid = 5986 ] [ nodeId = 2 ] RUNNING
[TE] doppy/10.1.32.12:48005 (forest) [ pid = 18876 ] [ nodeId = 3 ] RUNNING
[TE] bashful/10.1.32.9:48005 (forest) [ pid = 23316 ] [ nodeId = 5 ] RUNNING
[TE] sneezy/10.1.32.13:48005 (forest) [ pid = 7710 ] [ nodeId = 4 ] RUNNING
[TE] doc/10.1.32.10:48005 (forest) [ pid = 16259 ] [ nodeId = 6 ] RUNNING
[TE] sleepy/10.1.32.7:48005 (forest) [ pid = 13686 ] [ nodeId = 7 ] RUNNING
``` 

nuocmd will concatenate all the arguments passed to into a single --command. If no arguments are passed then it will run in interactive mode.  Currently there is no way to specify additional arguments to nuodbmgr (such as --log LEVEL).

For security reasons the password is not passed on the command line with the --password argument but instead a named pipe is used to pass it using --properties.  See [Encryption Rational](encryption-rational) for an explanation on why password is passed via --properties instead of --password.

While concatenating the argument list into one command is a slight easier to work with, it does limit you to only executing one command via --command.  You don't need to use this feature provide you quote your argument.  For example:

```
[fred@c117 ~] nuocmd 'set property showServerConfig value true; show domain summary'
Hosts:
[broker] * sleepy/10.1.32.7:48004 (forest) (FOLLOWER: doc/10.1.32.10:48004) CONNECTED
[broker] doc/10.1.32.10:48004 (forest) (LEADER) CONNECTED
[broker] grumpy/10.1.32.11:48004 (forest) CONNECTED
[broker] happy/10.1.32.8:48004 (forest) CONNECTED
[broker] doppy/10.1.32.12:48004 (forest) CONNECTED
[broker] bashful/10.1.32.9:48004 (forest) CONNECTED
[broker] sneezy/10.1.32.13:48004 (forest) CONNECTED

Database: SnowWhite, (unmanaged), processes [5 TE, 2 SM], ACTIVE
[SM] grumpy/10.1.32.11:48005 (forest) [ pid = 20474 ] [ nodeId = 1 ] RUNNING
[SM] happy/10.1.32.8:48005 (forest) [ pid = 5986 ] [ nodeId = 2 ] RUNNING
[TE] doppy/10.1.32.12:48005 (forest) [ pid = 18876 ] [ nodeId = 3 ] RUNNING
[TE] bashful/10.1.32.9:48005 (forest) [ pid = 23316 ] [ nodeId = 5 ] RUNNING
[TE] sneezy/10.1.32.13:48005 (forest) [ pid = 7710 ] [ nodeId = 4 ] RUNNING
[TE] doc/10.1.32.10:48005 (forest) [ pid = 16259 ] [ nodeId = 6 ] RUNNING
[TE] sleepy/10.1.32.7:48005 (forest) [ pid = 13686 ] [ nodeId = 7 ] RUNNING
``` 
Hiding the arguments passed can be problematic to debug if your having issues executing.  Use the --verbose flag to see what command is used and the execution results.   The outputted command will be as if --password was used.  This is useful for debugging especially when you are using encrypted passwords (the decrypted password will display).

For example:

```
[fred@c117 ~] nuocmd --verbose 'verify domain version'
nuodbmgr --broker sleepy --password bird --user domain --command "verify domain version"

All agents and processes are at version: 2.4.1.rel241-3
```

If I was encrypting my password in ~/.nuodb.properties and did not have ~/.nuodb.key, I would see something like.

Without verbose:

```
[fred@c117 ~] nuocmd 'verify domain version'
Domain entry failed: Invalid credentials, cause: [Invalid credentials]
```

With verbose, I can see that the password was not decrypted.

```
[fred@c117 ~] nuocmd --verbose 'verify domain version'
nuodbmgr --broker sleepy --password M0hTP2IhTDSQGmHFY6gE0Q== --user domain --command "verify domain version"
Domain entry failed: Invalid credentials, cause: [Invalid credentials]
```

Finally,  sometimes the arguments stored in ~/.nuodb.properties might not be the exactly what you want to use.  You can override these arguments by setting some variables before executing the function.

For example, using a different broker.

```
[fred@c117 ~] BROKER=doc nuocmd --verbose 'verify domain version'
nuodbmgr --broker doc --password bird --user domain --command "verify domain version"

All agents and processes are at version: 2.4.1.rel241-3
```


--
###nuosql
The nuosql function is a wrapper around the [NuoSQL](http://doc.nuodb.com/Latest/Default.htm#Using-NuoDB-SQL-Command-Line.htm) command.  Like nuocmd it gets some command arguments (broker, database, username, password, schema) from [~/.nuodb.properties](#nuodb.properties).  These arguments can be overridden via variable settings or including them as arguments to the function.   Unlike nuocmd additional arguments that can be passed to nuosql command can be passed when calling the nuosql function.  As a convenience to execute a single sql command you can pass it on the command line (as last argument).  With the cavaet that the sql command must include a space.

There are two additional arguments that can be passed:

* --verbose 

Overrides the verbose flag of nuosql command and will instead display the command invoked and the arguments.

* --csv

With a single query specified on the command line will output results in csv format by using nuoloader instead of nuosql.   If this is used the password could be intercepted with a ps command as there is no properties or configuration file with nuoloader.

#####Examples

* simple query
 
 ```
[fred:c117 ~] nuosql 'select id,port,address,hostname,state,type from system.nodes limit 1'
select id,port,address,hostname,state,type from system.nodes limit 1

 ID  PORT   ADDRESS   HOSTNAME   STATE   TYPE
 --- ----- ---------- -------- ------- -------

  1  48005 10.1.32.11 grumpy   Running Storage
```

* with --verbose
 
 ```
[fred:c117 ~] nuosql --verbose 'select id,port,address,hostname,state,type from system.nodes limit 1'
nuosql SnowWhite@grumpy --user fred --config /var/folders/k5/89mb5vs96zb7gpyrt39q6pn00000gn/T/tmp.awLbkLW1/nuosql --schema dwarfs --nosemicolon
select id,port,address,hostname,state,type from system.nodes limit 1

 ID  PORT   ADDRESS   HOSTNAME   STATE   TYPE
 --- ----- ---------- -------- ------- -------

  1  48005 10.1.32.11 grumpy   Running Storage
```

* with --csv

 ```
[fred:c117 ~] nuosql --csv 'select id,port,address,hostname,state,type from system.nodes limit 1'
ID,PORT,ADDRESS,HOSTNAME,STATE,TYPE
1,48005,10.1.32.11,grumpy,Running,Storage
```
* with additional arguments

 ```
[fred:c117 ~] nuosql --connection-property LBTag=doc 'select id,port,address,hostname,state,type from system.nodes where id = getnodeid()'
select id,port,address,hostname,state,type from system.nodes limit 1

 ID  PORT   ADDRESS   HOSTNAME   STATE    TYPE
 --- ----- ---------- -------- ------- -----------

  1  48005 10.1.32.10 doc      Running Transaction
 ```
* interactively

	 ```
[fred:c117 ~] nuosql
SQL> exit
```
* commands from a file

	```
[fred:c117 ~] nuosql --file getonenode.sql
select id,port,address,hostname,state,type from system.nodes limit 1

 ID  PORT   ADDRESS   HOSTNAME   STATE    TYPE
 --- ----- ---------- -------- ------- -----------

  1  48005 10.1.32.10 doc      Running Transaction
  ```
* Used in a bash script

 ```
nuosql <<EOF
CREATE INDEX Transactions_timestamp_idx ON Transactions(timestamp),
CREATE INDEX Transactions_starttimestamp_idx ON Transactions(starttimestamp),
CREATE INDEX Transactions_length_idx ON Transactions(length),
CREATE INDEX Transactions_connid_idx ON Transactions(connid);
CREATE INDEX Statements_timestamp_idx ON Statements(timestamp),
CREATE INDEX Statements_totaltime_idx ON Statements(totaltime),
CREATE INDEX Statements_cmdid_idx     ON Statements(cmdid);
QUIT;
EOF
```

####Variables

The arguments that are added to the nuosql command from the nuosql script are

```
 --user :dbuser: --password :dbpass: --schema :dbschema: :dbname:&:broker:
```

where :xxxx: is a variable that is defaulted, set in ~/.nuodb.properties, or read from variable.  Precedence is to use the variable setting if set.  If not set then read from ~/.nuodb.properties.  If not in ~/.nuodb.properties then use the default.

|argument | shell variable | nuodb.properties | defaults | 
|------|----|----------|----|
| :dbuser: | DBUSER   | DBNAME.dbuser| dba |
| :dbpass: |DBPASS   | DBNAME.dbpass| dba |
| :dbschema: | DBSCHEMA | DBNAME.dbschema| dbo |
| :broker: | BROKER   | DBNAME.broker| localhost |
| :dbname: | DBNAME | | LOG |

DBNAME is most likely the only variable that you'll need to worry about if you manage ~/.nuodb.properties properly.   You might also try different BROKER settings.  Especially if you want to test load balancer settings.

Example of using variables:

Our default broker as set in properties file is grumpy but we want to connect via sleepy.

```
[fred:c117 ~] BROKER=sleepy nuosql --verbose 'select getnodeid() from dual'
nuosql SnowWhite@sleepy --user dbadmin --config /tmp/tmp.6bxfrzZp5S/nuosql --schema drawfs --nosemicolon
select getnodeid() from dual

 -

 7
```

  
--
###nuolist
nuolist uses the nuosql function to query various system tables of the database and format the output for a quick view.

```
Usage:  nuolist [ :args: ] :view: ... 
```

The table below describes the quick views available.

| view  | descriptions | arguments |
|----|----|---|
|tables | list tables in given schema or whole database in  |
|schemas | column listing of all schema names in database |
|users | column listing of all users in database |
|nodes | select * from system.nodes |
|properties | list of system properties: name , value |
|views | list of views:  name , view defintion |
|transactions
|connections| list of connections | 
|indexes | list of indexes | index type, name, table |



--
###nuoschema
This function will use nuodb-migrator to dump the schema of your database.  It will get dbuser, dbpass, database, broker and dbschema using the precedences of variable, ~/nuodb.properties setting or default.

--
###nuodbuser

This function just returns the system user id for how nuoagent and database processes run.  This is typically nuodb.

```
[fred:c117 ~] nuodbuser
nuodb
```

--
###nuodb.properities
...
--
###nuodb.key
...

----
###Encryption Rational
To support the password encryption securities added by the password provider plugin it would also be necessarily to *hide* the password when invoking nuodbmgr or nuosql.  Currently these functions allow you to pass the password as an argument on the command line.  So a user on the same host could intercept the password by looking at ps output while these commands are running.

For example:

Given two users **Fred** and **Joe**.  Fred wants to execute some sql commands against the database and Joe wants to get ahold of Fred's password.

Fred runs his command:

```shell
[fred@c117 ~] /opt/nudob/bin/nuosql --user fred --password dba SnowWhite@sneezy
SQL>
```

Joe runs his:

```
[joe@c117 ~]$ ps -def | grep nuosql
fred  28154 28129  0 11:33 pts/0    00:00:00 /opt/nuodb/bin/nuosql --user fred --password dba SnowWhite@sneezy
joe   28227 28158  0 11:33 pts/2    00:00:00 grep nuosql
``` 
Joe now knows Fred's password is dba.

--

To prevent Fred from knowing Joe's password.  Joe should invoke /opt/nuodb/bin/nuosql differently using a config file and setting the password in the config file.

```
[joe@c117 ~]$ nuosql --user fred --config ~/snowwhite.config SnowWhite@sneezy
SQL>
```
So now when Joe runs his command:

```
[joe@c117 ~]$ ps -def | grep nuodb
fred  2152  8219  0 11:33 pts/0    00:00:00 /opt/nuodb/bin/nuosql --user fred --config ~/snowwhite.config dba SnowWhite@sneezy
joe   2827  2158  0 11:33 pts/2    00:00:00 grep nuosql
``` 

Joe can't see Fred's password but, he knows where it is **~fred/snowwhite.config**. He also knows that the password is stored in clear text within that file.  So he can go look at the password if *Fred* set read permissions on the file.  Also Joe would have to maintain a config file for each database or use the same password for each database which is not very secure neither.

--

Another alternative is to use a named pipe and to store the password somewhere else in an encrypted form.  Then before calling nuosql Fred would:

	1. Create a named pipe with permissions 600.
	2. Decrypt the password and write to the named pipe.
	3. Pass the named pipe as config file to nuosql.
	4. Delete named pipe when done.

Something like this:

```bash
[fred@c117 ~]$ TMPPIPE=$(mktemp -d)/nuosql
[fred@c117 ~]$ mkfifo -m 600 ${TMPPIPE}
[fred@c117 ~]$ awk '/SnowWhite/ { print $2; }' ~/.passwords | mydecrypt > /tmp/tmp.1kbcQEytC3/nuosql
[fred@c117 ~]$ nuosql --user fred --config /tmp/tmp.1kbcQEytC3/nuosql SnowWhite@sneezy
SQL> exit
[fred@c117 ~]$ rm -rf $(dirname ${TMPPIPE})
```

Above Fred stored his passwords in a file ~/.passwords where each line in the file contains first database name followed by encrypted password.  The mydecrypt is a program to decrypt the encrypted password.

If Joe tried to intercept the password, he'll see:

```
[joe@c117 ~]$ ps -def | grep nuodb
fred  2152  8219  0 11:33 pts/0    00:00:00 /opt/nuodb/bin/nuosql --user fred --config /tmp/tmp.1kbcQEytC3/nuosql SnowWhite@sneezy
joe   2827  2158  0 11:33 pts/2    00:00:00 grep nuosql
```
But he would not be able to read the password from the named pipe.
