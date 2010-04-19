package uk.ac.sanger.arcturus.gui.scaffoldmanager;

public class ScaffoldExportMessage {
	private int countScaffolds;
	private int countContigs;
	private int countContigLength;
	
	public ScaffoldExportMessage(int countScaffolds, int countContigs, int countContigLength) {
		this.countScaffolds = countScaffolds;
		this.countContigs = countContigs;
		this.countContigLength = countContigLength;
	}
	
	public int getScaffoldCount() {
		return countScaffolds;
	}
	
	public int getContigCount() {
		return countContigs;
	}
	
	public int getContigLength() {
		return countContigLength;
	}
}
