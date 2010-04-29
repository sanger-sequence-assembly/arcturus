package uk.ac.sanger.arcturus.test;

import java.util.*;
// import java.io.*;

import uk.ac.sanger.arcturus.database.*;
//import uk.ac.sanger.arcturus.jdbc.*;

public class TestContigManager extends TestRun {
	
    public static void main (String[] args) {
    	TestContigManager tcm = new TestContigManager();
      	tcm.run(args);
      	System.exit(0);
	}

	public void dotest (ArcturusDatabase adb, Properties props) {
	    System.out.println ("Method 'dotest' is overwritten");
	    
	    String cid = props.getProperty("contig");
	    int contig_id =  cid == null ? 0 : Integer.parseInt(cid);
	    System.out.println ("to delete contig_id " + contig_id);
	    String confirmkey = props.getProperty("confirm");
	    boolean confirm =  (confirmkey != null);

	    try {
	       	if (adb.isSingleReadCurrentContig(contig_id)) {
	    		System.out.println("Contig " + contig_id + " is a single-read current contig");
	    		if (confirm && adb.deleteSingleReadCurrentContig(contig_id)) {
		    		System.out.println("Contig " + contig_id + " has been deleted");	    			
	    		}
	    		else if (!confirm ) {
		    		System.out.println("Confirm deleting " + contig_id);	    						
	    		}
	    		else {
		    		System.out.println("Contig " + contig_id + " could not be deleted (locked project?)");
		    		if (adb.canUserDeleteContig(contig_id)) {	    			
			    		System.out.println("User has access to contig " + contig_id);	    						
		    		}
	    		}
	    	}
	       	else {
	    		System.out.println("Contig " + contig_id + " is NOT a single-read current contig"
	    				                                 + " or does not exist");	       	    
	       	}
		} catch (ArcturusDatabaseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}	
}
