package uk.ac.sanger.arcturus.data;

public interface Traversable {
	public enum Placement { ATLEFT , INSIDE, ATRIGHT };
	
	public Placement getPlacementOfPosition(int pos);

}
