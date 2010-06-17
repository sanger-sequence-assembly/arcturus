package uk.ac.sanger.arcturus.data;

public class ContigToParentMapping extends GenericMapping<Contig,Contig> {
	private int readCount;

	public ContigToParentMapping(Contig contig, Contig parent, Alignment[] alignments) {
	    super(contig,parent,alignments);
	}
	public ContigToParentMapping(Contig contig, Contig parent) {
	    super(contig,parent);
	}
	
	public Contig getParentContig() {
	    return getSubject();
	}
	
    public void setReadCount(int count) {
    	this.readCount = count;
    }
    
    public int getReadCount() {
        return readCount;
    }
}
