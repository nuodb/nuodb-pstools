# nuodb-operations-framework


##### Table of Contents  

[Agent Plugins](#agent-plugins)  
[Bash Functions](#bash-functions)  

--

This projects contains files and setup procedures for setting up a linux host that are beyond what is normally done when NuoDB is installed. This represents some utilities and best practices done by the NuoDB Professional Services organization.  These practices apply for NuoDB 2.4.1 and will likely change in future releases as the product evolves.

## Agent Plugins

#### Password Provider - Properties Provider

PasswordProvider is an implementation of the [com.nuodb.plugin.agent.PropertiesProvider](http://doc.nuodb.com/Latest/Default.htm#PropertiesProvider-Interface-Class.htm?Highlight=PropertiesProvider) interface.  This implementation can be used in place of the default PropertiesProvider so that you can store an encrypted password as the value for domainPassword in your agent properties file (/opt/nuodb/etc/default.properties).
For explanation on how to install and use this properties provider see [src/PasswordProvider](src/PasswordProvider).  A prebuilt jar of the provider can be found at [opt/nuodb/plugin/agent/password-provider-1.0-SNAPSHOT.jar](opt/nuodb/plugin/agent). This requires configuration of nuoagent system property *propertyProvider* as in the example [etc/nuodb/jvm-options](etc/nuodb). 

For reference on developing your own properties provider see:

* [http://doc.nuodb.com/Latest/Default.htm#PropertiesProvider-Plugin-Class-Customization.htm](http://doc.nuodb.com/Latest/Default.htm#PropertiesProvider-Plugin-Class-Customization.htm).

#### ActivePassive Balancer

The active-passive balancer is a simple load balancer that will block all new sql client connections when in passive mode and allow the rest of the balancer chain to determine how to balance the load.   The source code and explanation of this load balancer can be found at [src/ActivePassiveBalancer](src/ActivePassiveBalancer) and a prebuilt jar can be found at [opt/nuodb/plugin/agent/active-passive-balancer-1.0-SNAPSHOT.jar](opt/nuodb/plugin/agent).  To use this balancer the nuoagent must be started with JMX support.  This requires configuration of some nuoagent system properties in [/etc/nuodb/jvm-options](etc/nuodb).

The interface for defining custom load balancers is not documented and might change without notice.

## Bash Functions

The bash functions (and supporting files) that provide a framework for encrypting passwords and, some convenience features and functions are provided in the file [etc/profile.d/nuodb.sh](etc/profile.d).  By installing this file in /etc/profile.d/nuodb.sh of your linux installation these functions will be available to all users.

The functions provided by this bash source are listed below and explained in detail in [etc/profile.d](etc/profile.d) README.md:

* [nuosql](#nuosql)
* [nuomgr](#nuomgr)
* [nuolist](#nuolist)
* [nuoschema](#nuoschema)
* [nuodbuser](#nuodbuser)

##### nuosql
A wrapper around /opt/nuodb/bin/nuosql that uses ~/.nuodb.properties to get arguments for nuosql.  Supports encrypting password in ~/.nuodb.properties and hides password via using a named pipe on invocation for the config file. Supports single line sql statements as last argument on the command line.  Specify which database to use with DBNAME variable.


##### nuomgr
A wrapper around /opt/nuodb/bin/nuodbmgr that uses ~/.nuodb.properties or variables for arguments to nuodbmgr.  --command is generated from arguments passed on command line.  If no arguments passed then interactive mode.  Password can be encrypted and is hidden in invocation of nuodbmgr by using a named pipe for a properties file.

##### nuolist
Some simple queries and formatted output for looking at system table in the database.  Can specify some filtering and ordering arguments to some of the queries.

##### nuoschema

Dumps the database schema for the database.

##### nuodbuser

List the system user that can start / stop nuoagent process and delete archives or run nuochk.  Typically this is nuodb.
