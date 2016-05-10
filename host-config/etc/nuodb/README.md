#JVM-OPTIONS

--

To set system properties for NuoDB java processes you would set the appropriate variables in /etc/nuodb/jvm-options.  This directory contains a sample implementation of jvm-options that would be used if configuring the agent to use either of the two plugins described in this project.

--

###NuoAgent

To set system properties for the nuoagent process,  set ```NUODB_AGENT_JAVA_OPTS```.

* To configure nuoagent to use the PasswordProvider

```
  NUODB_AGENT_JAVA_OPTS= \
     -DpropertyProvider=com.nuodb.agent.plugin.PasswordProvider  
```
* To configure nuoagent to use the ActivePassiveBalancer

```
  NUODB_AGENT_JAVA_OPTS=\
	-Dcom.sun.management.jmxremote \
	-Dcom.sun.management.jmxremote.ssl=false \
	-Dcom.sun.management.jmxremote.port=19999 \
	-Dcom.sun.management.jmxremote.authenticate=false
```