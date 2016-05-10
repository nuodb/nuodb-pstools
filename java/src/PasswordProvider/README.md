#Properties Provider - PasswordProvider 

### Contents
[Introduction](#introduction)  
[Rational](#rational)  
[Usage](#usage)  
[Encrypt Password](#encrypt-password)  
[Store Encryption Key](#store-encryption-key)  
[Use Encrypted Password](#use-encrypted-password)  
[Install Plugin](#install-plugin)  
[Configure NuoAgent](#configure-nuoagent)  
[Configure NuoRestSvc](#configure-nuorestsvc)  

### Introduction

The Password Provider allows you to encrypt the domainPassword value
in /opt/nuodb/etc/default.properties.  The source code for the
PasswordProvider is in the [src/main/java/com/nuodb/agent/plugin](src/main/java/com/nuodb/agent/plugin).
A prebuilt jar of the jar is located in [../../opt/nuodb/plugin/agent/password-provider-1.0-SNAPSHOT.jar](../../opt/nuodb/plugin/agent).

Using this jar you can generate an encrypted password and encryption
key allowing you to store the encrypted password in default.properties
provided:

1. The encryption key is stored in ~nuodb/.nuodb.key
2. password-provider-1.0-SNAPSHOT.jar is installed in /opt/nuodb/plugin/agent
3. NUODB_AGENT_JVM_OPTS in /etc/nuodb/jvm-options includes
```
-DpropertyProvider=com.nuodb.agent.plugin.PasswordProvider 
```

### Rational

With version 2.4.1 of NuoDB a domainPassword must be specified for each
nuoagent (peer) in the domain.  This password must be the same for
every nuoagent and is typically configured in
/opt/nuodb/etc/default.properties by setting the property
domainPassword.

For example, a simple properties file might look like:

```
domainPassword = bird
domain = domain
broker = true
portRange = 48005
balancer = RoundRobinBalancer
singleHostDbRestart = true
```

Reading of the properties is actually a plugin in the nuoagent which
defaults to a URLPropertiesProvider that reads the default.properties
file by default.  As you can see from the listing above the
domainPassword is in plain text.  This file only has read permissions
by user nuodb and, thus a normal user could not get to the password.
However, some enterprises have requirements that a password not be
stored in plain text in any file (regardless of file permissions).

The PasswordProvider is a Properties Provider that allows you to
encrypt the domainPassword in /opt/nuodb/etc/default.properties.

### Usage

NuoDB Professional Services has developed a replacement Properties
Provider that can be used in place of the default.  This Properties
Provider (com.nuodb.plugin.agent.PasswordProvider) uses the default
provider but intercepts request by the nuoagent and decrypts the
domainPassword that is read from the default.properties.   So instead
of the plain text password as shown above you can specify your properties in
default.properties like:

```java
domainPassword = M0hTP2IhTDSQGmHFY6gE0Q==
domain = domain
broker = true
portRange = 48005
balancer = com.nuodb.plugin.agent.activepassive.Gate,RoundRobinBalancer
singleHostDbRestart = true
```

In order to use this approach several steps need to be taken.

   1. generate encrypt password and encryption key
   2. store encryption key in ~nuodb/.nuodb.key
   3. use encrypted password in /opt/nuodb/etc/default.properties for domainPassword
   4. install PropertyProvider plugin in /opt/nuodb/plugin/agent
   5. configure nuoagent to use the PasswordProvider
   6. configure nuorestsvc to use the
      PasswordProvider.

#### Encrypt Password

The PasswordProvider jar is also a runnable jar where the main class
will allow you to encrypt or decrypt passwords.  The encryption key is
either read from ~/.nuodb.key or from the environment variable
NUODB_PASSKEY if it is set.  If the encryption key is not set then an
encryption key will be generated when trying to encrypt a password.

```
$ java -jar opt/nuodb/plugin/agent/password-provider-1.0-SNAPSHOT.jar bird
NUODB_PASSKEY = ZXGI1gNIpEzTeh8XPyISHg==
domainPassword = H23YFs+GMkKyN79O7kWaRg==
```

#### Store Encryption Key

This key is used by the plugin to decrypt the password set in
/opt/nuodb/etc/default.properties.

```
$ sudo -u nuodb echo "ZXGI1gNIpEzTeh8XPyISHg==" > ~nuodb/.nuodb.key
$ sudo -u nuodb chmod 400 ~nuodb/.nuodb.key
```

#### Use Encrypted Password

Now the password can be encrypted instead of plain text.  Provided
that the encryption key is stored in ~nuodb/.nuodb.key 

```
$ sudo -u nuodb cat /opt/nuodb/etc/default.properties
domainPassword = H23YFs+GMkKyN79O7kWaRg==
domain = domain
broker = true
portRange = 48005
balancer = com.nuodb.plugin.agent.activepassive.Gate,RoundRobinBalancer
singleHostDbRestart = true
```

#### Install Plugin

Nuoagent will load custom plugins from jars located in the
/opt/nuodb/plugin/agent directory.

```
$ sudo -u nuodb cp password-provider-1.0-SNAPSHOT.jar /opt/nuodb/plugin/agent/password-provider-1.0-SNAPSHOT.jar
```

#### Configure NuoAgent

To configure the nuoagent to use the PasswordProvider you need to
modify the NUODB_AGENT_JAVA_OPTS variable in /etc/nuodb/jvm-options to
include setting the system property *propertyProvider*.

```
$ sudo -u nuodb cat /etc/nuodb/jvm-options
...
NUODB_AGENT_JAVA_OPTS="-DpropertyProvider=com.nuodb.agent.plugin.PasswordProvider"
...
```

#### Configure NuoRestSvc

To use the nuorestsvc with the new PasswordProvider you need to
configure /opt/nuodb/etc/nuodb-rest-api.yml to use the
PasswordProvider propertyProvider.  The restsvc will use this provider
to get the domainPassword.

```
$ sudo -u nuodb cat /opt/nuodb/etc/nuodb-rest-api.yml
# NuoDB options
nuoDBConfiguration:
  # Optional property provider plugin class which implements the interface
  # com.nuodb.agent.PropertiesProvider. You can use the same plugin class
  # that is supported with the NuoAgent. Only the "domainPassword" property
  # is read and copied into "password" property. This provider is used by
  # default; set to value "none" to skip any plugin
  propertyProvider: com.nuodb.agent.plugin.PasswordProvider
...
```

### Jar Usage

The password-provider-1.0-SNAPSHOT.jar is a runnable jar that can be used to encrypt or decrypt  a password.

```
[fred@c117 ~] java -jar /opt/nuodb/plugin/agent/password-provider-1.0-SNAPSHOT.jar
usage: com.nuodb.agent.plugin.PasswordService [--decrypt] password
	encrypt or decrypt password using supplied passkey
	   decrypt requires passkey: $HOME/.nuodb.key or $NUODB_PASSKEY
	   encrypt will create a passkey if one is not given.
```

A user would create an encrypted password same as for nuodb user which was shown in [Encrypt Password](#encrypt-password).  The generated key would be stored in ~/.nuodb.key as stated in [Store Encryption Key](#store-encryption-key).  The encrypted password would then need to be decrypted to get the password to use.  To decrypt the password: 

```java -jar /opt/nuodb/plugin/agent/password-provider-1.0-SNAPSHOT.jar --decrypt <password>```

The [bash shell framework](../../etc/profile.d) uses this approach in the nuocmd or nuosql functions with the encrypted password stored in ~/.nuodb.properties.  An example of storing the encryption key and storing the password in .nuodb.properties can be found in the sample [home directory](../../home/user).
 
### Cavaet

The current implement requires AES encryption to be available from the
JVM.  Java 1.7 states that all java platforms must support DES.  So it
is possible that this implementation will not work on all java
platforms.