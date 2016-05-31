/* Copyright 2016 NuoDB, Inc. All rights reserved */

package com.nuodb.agent.plugin.activepassive;

import com.nuodb.agent.PropertiesContainer;

import com.nuodb.agent.TagContainer;
import com.nuodb.agent.db.Node;
import com.nuodb.agent.net.NetworkContainer;
import com.nuodb.agent.net.Session;
import java.lang.management.*;
import javax.management.*;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL; 


/**
 * Balancer that prevents broker from routing to TE when gate is in place.  Use jmx to open / close gate.
 * This balancer (com.nuodb.activepassive.Gate) should be first in list of chainable balancers.
 *
 * @see Gate
 */
public class Gate extends com.nuodb.agent.db.Balancer {

	// default to same as if active passive gate does not exist.
    private static boolean isPassive = false;
    
    public interface HandlerMXBean
    {
    	public boolean getPassive();
    	public void setPassive(boolean passive);
    	public void flip();
    }
    
    public static class Handler implements HandlerMXBean
    {
    	public Handler()
    	{
    		;
    	}
    	
    	public boolean getPassive()
    	{
    		return isPassive;
    	}
    	
    	public void setPassive(boolean passive)
    	{
    		isPassive = passive;
    	}
    	
    	public void flip() {
    		isPassive = !isPassive;
    	}
    }
    
    // setup mbean to allow remote access to open/close the gate. (isPassive true/false).
    // the gate is open by default.
    static {
    	try {
    		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer(); 
    		ObjectName name = new ObjectName("com.nuodb:type=ActivePassive"); 
    		Handler mbean = new Handler(); 
    		mbs.registerMBean(mbean, name);
    	} catch (Exception x) {
    		;
    	}
    }
    
    /**
     * Creates an instance of {@code Gate} with no fall-back policy.
     *
     * @param propContainer the brokers's {@code PropertiesContainer}
     * @param netContainer the broker's {@code NetworkContainer}
     * @param tagContainer the broker's {@code TagContainer}
     */
    public Gate(PropertiesContainer propContainer, NetworkContainer netContainer,
            TagContainer tagContainer) {
        this(propContainer, netContainer, tagContainer, null);
    }

    /**
     * Creates an instance of {@code Gate}.
     *
     * @param propContainer the brokers's {@code PropertiesContainer}
     * @param netContainer the broker's {@code NetworkContainer}
     * @param tagContainer the broker's {@code TagContainer}
     * @param nextBalancer the next balancer in the chain
     */
    public Gate(PropertiesContainer propContainer, NetworkContainer netContainer,
            TagContainer tagContainer, Gate nextBalancer) {
        setNextBalancer(nextBalancer);
    }

    @Override
    public Node getTransactionNode(Session session) {
    	if (!isPassive && getNextBalancer() != null) {
    		return getNextBalancer().getTransactionNode(session);
    	}
    	return null;
    }

    @Override
    public String toString() {
        return String.format("ActivePassive(%s)", getNextBalancer());
    }

	@Override	
	public void nodeJoined(Node arg0) {
		if (getNextBalancer() != null) {
			getNextBalancer().nodeJoined(arg0);
		}
	}

	@Override
	public void nodeLeft(Node arg0, String arg1, boolean arg2) {
		if (getNextBalancer() != null) {
			getNextBalancer().nodeLeft(arg0,arg1,arg2);
		}
	}
}
