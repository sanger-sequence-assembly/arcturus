package test.importer;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.samtools.*;
import uk.ac.sanger.arcturus.samtools.Utility;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.Connection;
import java.util.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;
import uk.ac.sanger.arcturus.jdbc.*;

import net.sf.samtools.*;
import net.sf.samtools.util.CloseableIterator;

public class BAMContigLoaderWrapper extends BAMContigLoader {
	
	public BAMContigLoaderWrapper(ArcturusDatabase adb, BAMReadLoader brl) throws ArcturusDatabaseException {
		super(adb,brl);
	}

    public void processFile(SAMFileReader reader, Project project) throws ArcturusDatabaseException {
    	
    	System.out.println("USING TEST SCRIPT");
	    	
	    Contig[] contigs = getContigs(reader);
	    
	    for (Contig contig : contigs)
	    	contig.setProject(project);

//	    prepareLinkManagerCache(adb, project);

//	    identifyParentsForContigs(contigs,reader);

	    adb.preloadCanonicalMappings();

	    addMappingsToContigs(contigs,reader);
	    
    }
	
/*	
	private void identifyParentsForContigs(Contig[] contigs, SAMFileReader reader) {
	    	
	     	for (int i=0 ; i < contigs.length ; i++) {
	    		String referenceSequenceName = contigs[i].getName();
	     		System.out.println("Processing contig " + referenceSequenceName);
	 
	     		CloseableIterator<SAMRecord> iterator = reader.query(referenceSequenceName, 0, 0, false);

	     	   	Map<Integer,Integer> graph = new HashMap<Integer,Integer>();
	     	   	
	     		while (iterator.hasNext()) {
	     		    SAMRecord record = iterator.next();
	    		    String readName = record.getReadName();
	    		    int flags = record.getFlags();
// System.out.println("get readname " + readName + " flag " + flags);

	    		    try {
	    			    int maskedFlags = Utility.maskReadFlags(flags);
	    				Read read = new Read(readName,maskedFlags);
	    		        int parent_id = adb.getCurrentContigIDForRead(read);
//	    		        System.out.println("cpcid " + parent_id + " for readname " + readName + " flag " + flags);
	     		        if (parent_id > 0) {
	     		    	    int count = 0;
	     		    	    if (graph.containsKey(parent_id))
	     		    		    count = (Integer)graph.get(parent_id);
	     		    	    count++;
	     		    	    graph.put(parent_id, count);
	     		        }
	// either the read is not in the database, or not in a current contig (of the project)
	     		        else if (parent_id < 0 && brl != null) { // only load if it's not in the database
	System.out.println("Trying to load read " + readName);
	     		            if (adb.getReadByNameAndFlags(readName,flags) == null)
	     		            	brl.findOrCreateSequence(record);
	     		        }
	     		    }
	    		    catch (ArcturusDatabaseException e) {
	    		    	System.err.println(e + "possibly database access lost");
	    		    }
	     		}
	     		
	     		iterator.close();
	     		
	     	    Set parentIDs = graph.keySet();
	     	    Iterator parentIDiterator = parentIDs.iterator();
	            Vector<ContigToParentMapping> M = new Vector<ContigToParentMapping>();
	System.out.println("Resulting parent contigs");
	                        
	     		while (parentIDiterator.hasNext()) {
	     			int parent_id = (Integer)parentIDiterator.next();
	     			int readCount = (Integer)graph.get(parent_id);
	System.out.println("Parent contig ID " + parent_id + " readcount: " + readCount);
	        		Contig parent = new Contig(parent_id,adb); // minimal parent object
	        		ContigToParentMapping cpmapping = new ContigToParentMapping(contigs[i],parent);
	        		cpmapping.setReadCount(readCount);
	        		M.add(cpmapping);
	     		}
	     		contigs[i].setContigToParentMappings(M.toArray(new ContigToParentMapping[0]));
	     	}
	// here all input contigs have parent-to-contig mappings and their weights    	
	    }
*/	 
	    

	    
	    
	    
	 
    private void addMappingsToContigs(Contig[] contigs, SAMFileReader reader) {
System.out.println("addMappingsToContigs " + contigs.length);
    	for (int i=0 ; i < contigs.length ; i++) {
    		try {
     		    addMappingsToContig(contigs[i],reader);
    		}
    		catch (ArcturusDatabaseException e) {
    		
    		}
    		
    	}
    }
	    
	private void addMappingsToContig(Contig contig,SAMFileReader reader) throws ArcturusDatabaseException {

		String referenceName = contig.getName();
System.out.println("addMappingsToContig " + referenceName);
		    	    	
	    CloseableIterator<SAMRecord> iterator = reader.query(referenceName, 0, 0, false);
	 		
	 	Vector<SequenceToContigMapping> M = new Vector<SequenceToContigMapping>();
	 		
	    while (iterator.hasNext()) {
	 	    SAMRecord record = iterator.next();
	 		SequenceToContigMapping mapping = buildSequenceToContigMapping(record,contig);
	 	    M.add(mapping);
	    }
	 		
	    iterator.close();
System.out.println("DONE : addMappingsToContig " + referenceName);
	 		
	    contig.setSequenceToContigMappings(M.toArray(new SequenceToContigMapping[0]));
	    
	    try {
	        adb.putContig(contig);
	    }
	    catch (ArcturusDatabaseException e) {
	        Arcturus.logWarning(e);
	    }
    }
	  
	private SequenceToContigMapping buildSequenceToContigMapping(SAMRecord record, Contig contig) throws ArcturusDatabaseException {
		    
	    String cigar = record.getCigarString();
// System.out.println("buildSequenceToContigMapping " + cigar);

		CanonicalMapping mapping = new CanonicalMapping(cigar);
		CanonicalMapping cached = adb.findOrCreateCanonicalMapping(mapping);
		
// System.out.println("RETURNED buildSequenceToContigMapping " + cigar);

		Sequence sequence = brl.findOrCreateSequence(record);

// System.out.println("RETURNED from findOrCreateSequence");
		  
		Direction direction = record.getReadNegativeStrandFlag() ? Direction.REVERSE : Direction.FORWARD;
		  
Read read = sequence.getRead();
if (cached == mapping) {
//	System.out.println("new mapping " + cigar + " read " + read.getUniqueName());
}
else if (cached.getMappingID() <= 0 ){
    System.out.println("existing mapping " + cigar + " read " + read.getUniqueName());
	System.out.println("mapping id " + cached.getMappingID());
	System.exit(1);
}

		int contigStartPosition = record.getAlignmentStart();
		int contigEndPosition = record.getAlignmentEnd();
//System.out.println("read " + read.getUniqueName() + " cstart " + contigStartPosition +
//			         " cend " + contigEndPosition + " D: " + direction);

		return new SequenceToContigMapping(sequence,contig,cached,contigStartPosition,1,direction);
	}

	/**
	 * 
	 */
	
		public void writeImportMarker() {
			
		}
		
		private int getLinkManagerCacheSize(ArcturusDatabase adb) {
			int size = 0;
		
		    if (adb instanceof ArcturusDatabaseImpl) {
		        ArcturusDatabaseImpl adbi = (ArcturusDatabaseImpl)adb;
		        LinkManager lm = (LinkManager)adbi.getManager(ArcturusDatabaseImpl.LINK);
		        size = lm.getCacheSize();
		    }
		    
		    return size;
		}

}
