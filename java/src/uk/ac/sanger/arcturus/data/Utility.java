package uk.ac.sanger.arcturus.data;

import java.io.*;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import uk.ac.sanger.arcturus.Arcturus;

public class Utility {
    private static MessageDigest digester;

    public static byte[] calculateMD5Hash(String data) {
    	byte [] dataAsByte = null;
        try {
        	 dataAsByte = data.getBytes("US-ASCII");
        } catch (UnsupportedEncodingException e) {
        	Arcturus.logWarning(e);
        }
        return calculateMD5Hash(dataAsByte);
	}

    public static byte[] calculateMD5Hash(byte[] data) {
    	if (digester == null) {
		    try {
			    digester = MessageDigest.getInstance("MD5");
		    } catch (NoSuchAlgorithmException e) {
			    Arcturus.logWarning(e);
			    return null;
		    }			
	    }
   	    digester.reset();
	    return digester.digest(data);
    }
    
    public static char complement(char base) {
		switch (base) {
			case 'a':
				return 't';
				
			case 'A':
				return 'T';
				
			case 'c':
				return 'g';
				
			case 'C':
				return 'G';
				
			case 'g':
				return 'c';
				
			case 'G':
				return 'C';
				
			case 't':
				return 'a';
				
			case 'T':
				return 'A';
				
			default:
				return base;
		}
    }
    	
	public static void report(String report) {
		System.err.println(report);
	}
}