// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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