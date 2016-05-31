/* Copyright 2014 NuoDB, Inc. All rights reserved */

package com.nuodb.agent.plugin;

import com.nuodb.agent.PropertiesProvider;

import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Property Provider that allows encrypted password for
 * domainPassword in $NUODB_HOME/etc/default.properties
 * or -DpropertiesUrl.

 * <ul>
 * <li>If the NUODB_PASSKEY is set then the password in
 * $NUODB_HOME/etc/defaults.properties will be decrypted
 * <li>If NUODB_PASSKEY is not set then password in
 * $NUODB_HOME/etc/defaults.properties will be treated as clear text.
 * </ul>
 * 
 * @see PasswordService
 */
public class PasswordProvider extends PasswordService implements PropertiesProvider {

    private static final Logger logger = Logger.getLogger(PasswordProvider.class.getName());

    private final PropertiesProvider urlPropertiesProvider;
    private String secretKey;

	/* Initialize PasswordProvider to intercept getProperty to
	 * URLPropertiesProvider.
	 */
    public PasswordProvider(Properties systemProperties) {
        URLPropertiesProvider provider = null;
        try {
            provider = new URLPropertiesProvider(systemProperties);
        } catch (IllegalArgumentException iae) {
            logger.log(Level.WARNING, "no local backing properties", iae);
        }
        urlPropertiesProvider = provider;

        secretKey = PasswordService.getSecretKey();
    }

	/* Call URLPropertiesProvider to get property and if property 
	 * requested is domainPassword decrypt if the NUODB_PASSKEY is
	 * set.
	 *
	 * Return value from URLProperitesProvider or decrypted value.
	 */
    public String getProperty(String key) {
        String value = urlPropertiesProvider.getProperty(key);
        if ("domainPassword".equals(key) && (secretKey != null)) {
            try {
                value = PasswordService.decrypt(value, secretKey);
            } catch (Exception x) {
                x.printStackTrace();
            }
        }
        return value;
    }

}
