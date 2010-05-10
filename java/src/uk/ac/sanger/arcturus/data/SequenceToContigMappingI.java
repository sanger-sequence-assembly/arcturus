package uk.ac.sanger.arcturus.data;

public interface SequenceToContigMappingI {
	public Contig getContig();
	
	public Sequence getSequence();
	
	public GenericMapping.Direction getDirection();
	
	public boolean isForward();
	
	public int getContigStartPosition();

	public int getContigEndPosition();
	
	public BaseWithQuality getBaseAndQualityByReadPosition(int rpos);
	
	public BaseWithQuality getBaseAndQualityByContigPosition(int cpos);
	
	public AssembledFrom[] getAssembledFromRecords();
}
