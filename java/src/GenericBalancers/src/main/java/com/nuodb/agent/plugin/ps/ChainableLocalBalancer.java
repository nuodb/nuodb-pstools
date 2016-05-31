/* Copyright 2014 NuoDB, Inc. All rights reserved */

package com.nuodb.agent.plugin.ps;

import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nuodb.agent.PropertiesContainer;
import com.nuodb.agent.TagContainer;
import com.nuodb.agent.db.Balancer;
import com.nuodb.agent.db.Node;
import com.nuodb.agent.net.NetworkContainer;
import com.nuodb.agent.net.Session;

/**
 * Balancer that will only round-robin among nodes local to the broker.
 *
 * @see ChainableLocalBalancer
 */
public class ChainableLocalBalancer extends Balancer {

    private static final Logger logger = Logger.getLogger(ChainableLocalBalancer.class.getName());

    /** the ordered collections of transaction engines in the chorus */
	
    private final ConcurrentLinkedQueue<Node> nodes = new ConcurrentLinkedQueue<Node>();

    /**
     * Creates an instance of {@code ChainableLocalBalancer} with no fall-back policy.
     *
     * @param propContainer the brokers's {@code PropertiesContainer}
     * @param netContainer the broker's {@code NetworkContainer}
     * @param tagContainer the broker's {@code TagContainer}
     */
    public ChainableLocalBalancer(PropertiesContainer propContainer, NetworkContainer netContainer,
            TagContainer tagContainer) {
        this(propContainer, netContainer, tagContainer, null);
    }

    /**
     * Creates an instance of {@code ChainableLocalBalancer}.
     *
     * @param propContainer the brokers's {@code PropertiesContainer}
     * @param netContainer the broker's {@code NetworkContainer}
     * @param tagContainer the broker's {@code TagContainer}
     * @param nextBalancer the next balancer in the chain
     */
    public ChainableLocalBalancer(PropertiesContainer propContainer, NetworkContainer netContainer,
            TagContainer tagContainer, Balancer nextBalancer) {
        setNextBalancer(nextBalancer);
    }

    @Override
    public synchronized void nodeJoined(Node node) {
        if (node.isTransactional() && node.isLocal()) {
            if (!nodes.contains(node)) {
				// this should not fail as 
                nodes.offer(node);
            } else {
                logger.log(Level.INFO, "duplicated node joined ignored: {0}", node);
            }
        }
        getNextBalancer().nodeJoined(node);
    }

    @Override
    public synchronized void nodeLeft(Node node, String reason, boolean observed) {
        if (node.isTransactional() && node.isLocal()) {
            boolean removed = nodes.remove(node);
            while (removed) {
                removed = nodes.remove(node);
            }
        }
        getNextBalancer().nodeLeft(node, reason, observed);
    }

    @Override
    public Node getTransactionNode(Session session) {
		Node node = null;
		synchronized (this) {
			node = nodes.poll();
			if (node != null) {
				nodes.add(node);
			}
		}
		return (node != null) ? node : getNextBalancer().getTransactionNode(session);
    }

    @Override
    public String toString() {
        return String.format("ChainableLocalBalancer(%s)", getNextBalancer());
    }
}
