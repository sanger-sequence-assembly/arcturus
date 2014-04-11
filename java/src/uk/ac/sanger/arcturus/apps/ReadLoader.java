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

package uk.ac.sanger.arcturus.apps;

import java.io.*;

import uk.ac.sanger.arcturus.samtools.BAMReadLoader;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import net.sf.samtools.*;

public class ReadLoader extends AbstractLoader {
	public static void main(String[] args) {
		File file = null;
		String instance = null;
		String organism = null;
		
	    for (int i = 0; i < args.length; i++) {
            if (args[i].equalsIgnoreCase("-in"))
                file = new File(args[++i]);
            else if (args[i].equalsIgnoreCase("-instance"))
                instance = args[++i];
            else if (args[i].equalsIgnoreCase("-organism"))
                organism = args[++i];
             else {
            	System.err.println("Invalid parameter " + args[i]);
    		    showUsage(System.err);
    		    System.exit(1);
            }
 	    }

	    if (file == null || instance == null || organism == null) {
		    showUsage(System.err);
		    System.exit(1);
		}
	    
	    try {	    	
 	        ArcturusInstance ai = ArcturusInstance.getInstance(instance);
 	        
 			ArcturusDatabase adb = ai.findArcturusDatabase(organism);
 
 	    	BAMReadLoader brl = createBAMReadLoader(adb);
 	    	
 			SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);
 			
 			SAMFileReader reader = new SAMFileReader(file);
 			
 	    	if (reader.isBinary() == false || reader.hasIndex() == false)
 	    		throw new ArcturusDatabaseException("The input file is not indexed: " + file);
	    	
   			brl.processFile(reader);
	    }
	    catch (Exception e) {
	    	Arcturus.logWarning("Failed to initialise or execute the read loader", e);
	    	System.exit(1);
	    }
	    
    	System.exit(0);
	}
	
	public static void showUsage(PrintStream ps) {
		ps.println("Invalid or missing input parameters");
		ps.println();
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-in\t\tName of ordered and indexed BAM file to be imported");
	}
}
