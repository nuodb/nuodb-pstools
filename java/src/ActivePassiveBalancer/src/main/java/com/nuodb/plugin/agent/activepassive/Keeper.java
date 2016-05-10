/* Copyright 2016 NuoDB, Inc. All rights reserved */

package com.nuodb.plugin.agent.activepassive;

import javax.management.*;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL; 


public class Keeper {

	static public void main(String... args) throws Exception
	{		
		if (! (args.length > 0 && args.length <= 2)) 
		{
			System.out.println("Usage: java -jar ActivePassive.jar HOST[:PORT] [--active|--passive]");
			System.out.println("   HOST - broker host.");
			System.out.println("   PORT - jmx port defaults to 19999 (as configured in /etc/nuodb/jvm-options).");
			System.out.println("   --active  - make given broker active, noop if broker already active.");
			System.out.println("   --passive - make given broker inactive, noop if broker already inactive.");
			System.out.println("   no second argument - flip current state of given broker.");
			System.exit(0);
		}

		try
		{
			if (! args[0].contains(":")) {
				args[0] = args[0] + ":19999";
			}
			JMXServiceURL target = new JMXServiceURL("service:jmx:rmi:///jndi/rmi://"+ args[0] + "/jmxrmi");
			JMXConnector connector = JMXConnectorFactory.connect(target);
			MBeanServerConnection remote = connector.getMBeanServerConnection();

    		ObjectName name = new ObjectName("com.nuodb:type=ActivePassive");
    		boolean isPassive = (Boolean) remote.getAttribute(name, "Passive");
    		if (args.length == 1) {
    			remote.invoke(name, "flip", null, null);    			
    		} else {
    			if ("--passive".equalsIgnoreCase(args[1]) && !isPassive) {
    				remote.invoke(name, "flip", null, null);    				
    			} else if ("--active".equalsIgnoreCase(args[1]) && isPassive) {
    				remote.invoke(name, "flip", null, null);    				    				
    			}
    		}
    		isPassive = (Boolean) remote.getAttribute(name,  "Passive");
    		System.out.println(isPassive ? "Passive" : "Active");
    		connector.close();
		}
		catch(Exception e)
		{
			System.out.println(e.getMessage());
			System.exit(0);
		}
	}
}
