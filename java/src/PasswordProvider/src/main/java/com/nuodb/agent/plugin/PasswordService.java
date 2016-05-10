package com.nuodb.agent.plugin;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;

public class PasswordService {

    private static final String SPEC = "AES";

	/* Called during initialization of PasswordProvider */

    protected static String getSecretKey() {
        String secretKey = System.getenv("NUODB_PASSKEY");
        if (secretKey == null) {
            String home = System.getenv("HOME");
            String filename = home + "/.nuodb.key";
            File file = new File(filename);
            if (file.exists()) {
                try (FileReader reader = new FileReader(file)) {
                    char[] chars = new char[(int) file.length()];
                    reader.read(chars);
                    secretKey = new String(chars);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        if (secretKey != null) {
            secretKey = secretKey.trim();
        }
        return secretKey;
    }

	/* Used by PasswordProvider to decrypt password */
    protected static String decrypt(String str, String secretKey) {
        try {
            Cipher dcipher = Cipher.getInstance(SPEC);
            byte bkey[] = Base64.decode(secretKey);
            SecretKey key = new SecretKeySpec(bkey, SPEC);
            dcipher.init(Cipher.DECRYPT_MODE, key);
            return new String(dcipher.doFinal(Base64.decode(str)), "UTF8");
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }


	/**
	 * Utility program to encrypt / decrpyt password for use by
	 * PasswordProvider.
	 * <ul>
	 * <li>encrypt -  java PasswordProvider password
	 * <li>decrypt -  java PasswordProvider --decrypt
	 * encrypted_password
	 * </ul>
	 * 
	 * encrypt to get encrypt_password from password.  This encrypted
	 * password would then be used as domainPassword property in
	 * URLPropertyProvider.  If a NUODB_PASSKEY is not provided then
	 * one will be generated.  You'll need the passkey in order to
	 * decrypt the password.
	 *
	 * decrypt in order to remove clear text passwords from scripts.
	 * use as a utility function for the script.
	 */
    public static void main(String[] args) {
        try {
            boolean decrypt = false;

			/* get arguments */
            if (args.length == 2 && "--decrypt".equalsIgnoreCase(args[0])) {
                decrypt = true;
            } else if (args.length == 1) {
                decrypt = false;
            } else {
                System.err.println("usage: " + PasswordService.class.getName() + "[--decrypt] password");
                System.err.println("\tencrypt or decrypt password using supplied passkey");
                System.err.println("\t   decrypt requires passkey: $HOME/.nuodb.key or $NUODB_PASSKEY");
                System.err.println("\t   encrypt will create a passkey if one is not given.");
                System.exit(-1);
            }
            String pwd = args[0];
            if (decrypt) {
                pwd = args[1];
            }

			/* setup Cipher key */
            Cipher ecipher = Cipher.getInstance(SPEC);
            String passKey = getSecretKey();
            SecretKey key = null;
            if (passKey == null && !decrypt) {
				/* no passkey given so generate one */
                key = KeyGenerator.getInstance(SPEC).generateKey();
                passKey = Base64.encode(key.getEncoded());
                System.out.println("NUODB_PASSKEY = " + passKey);
            } else if (passKey != null) {
				/* use given passkey */
                key = new SecretKeySpec(Base64.decode(passKey), SPEC);
            }
            if (!decrypt) {
				/* encrypt password given on command line */
                ecipher.init(Cipher.ENCRYPT_MODE, key);
                String encodedPassword = Base64.encode(ecipher.doFinal(pwd.getBytes("UTF8")));
                System.out.println("domainPassword = " + encodedPassword);
            } else if (key != null) {
				/* decrypt password given on command line */
				try {
					ecipher.init(Cipher.DECRYPT_MODE, key);
					String decodedPassword = new String(ecipher.doFinal(Base64.decode(pwd)),"UTF8");
					System.out.println(decodedPassword);
				} catch (Exception x) {
					System.exit(-1);
				}
            } else {
                System.err.println("Can't find passkey to decrypt " + pwd);
                System.exit(-1);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

	/* encode / decode byte array to an ASCII string */

    private static class Base64 {
        public static String encode(byte[] data) {
            char[] tbl = {
                    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
                    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
                    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'};

            StringBuilder buffer = new StringBuilder();
            int pad = 0;
            for (int i = 0; i < data.length; i += 3) {

                int b = ((data[i] & 0xFF) << 16) & 0xFFFFFF;
                if (i + 1 < data.length) {
                    b |= (data[i + 1] & 0xFF) << 8;
                } else {
                    pad++;
                }
                if (i + 2 < data.length) {
                    b |= (data[i + 2] & 0xFF);
                } else {
                    pad++;
                }

                for (int j = 0; j < 4 - pad; j++) {
                    int c = (b & 0xFC0000) >> 18;
                    buffer.append(tbl[c]);
                    b <<= 6;
                }
            }
            for (int j = 0; j < pad; j++) {
                buffer.append("=");
            }

            return buffer.toString();
        }

        public static byte[] decode(String data) {
            int[] tbl = {
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, 52, 53, 54,
                    55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, -1, 0, 1, 2,
                    3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
                    20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1, -1, 26, 27, 28, 29, 30,
                    31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
                    48, 49, 50, 51, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
                    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};
            byte[] bytes = data.getBytes();
            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            for (int i = 0; i < bytes.length; ) {
                int b;
                if (tbl[bytes[i]] != -1) {
                    b = (tbl[bytes[i]] & 0xFF) << 18;
                }
                // skip unknown characters
                else {
                    i++;
                    continue;
                }

                int num = 0;
                if (i + 1 < bytes.length && tbl[bytes[i + 1]] != -1) {
                    b = b | ((tbl[bytes[i + 1]] & 0xFF) << 12);
                    num++;
                }
                if (i + 2 < bytes.length && tbl[bytes[i + 2]] != -1) {
                    b = b | ((tbl[bytes[i + 2]] & 0xFF) << 6);
                    num++;
                }
                if (i + 3 < bytes.length && tbl[bytes[i + 3]] != -1) {
                    b = b | (tbl[bytes[i + 3]] & 0xFF);
                    num++;
                }

                while (num > 0) {
                    int c = (b & 0xFF0000) >> 16;
                    buffer.write((char) c);
                    b <<= 8;
                    num--;
                }
                i += 4;
            }
            return buffer.toByteArray();
        }
    }

}
