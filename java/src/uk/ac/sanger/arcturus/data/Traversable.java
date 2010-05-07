package uk.ac.sanger.arcturus.data;

public interface Traversable {
	public enum Placement { AT_LEFT , INSIDE, AT_RIGHT };
	
	public Placement getPlacementOfPosition(int pos);

}
