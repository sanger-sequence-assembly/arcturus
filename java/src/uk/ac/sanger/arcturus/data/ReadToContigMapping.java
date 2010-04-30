package uk.ac.sanger.arcturus.data;

public interface ReadToContigMapping {
	public Sequence getSequence();
	
	public boolean isForward();
	
	public int getContigStartPosition();
	public int getContigEndPosition();
	
	public BaseWithQuality getBaseAndQualityByReadPosition(int rpos);
	
	public BaseWithQuality getBaseAndQualityByContigPosition(int cpos);
	
	public AssembledFrom[] getAssembledFromRecords();
}
