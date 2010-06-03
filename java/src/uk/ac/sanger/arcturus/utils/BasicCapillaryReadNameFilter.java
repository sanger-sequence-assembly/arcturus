package uk.ac.sanger.arcturus.utils;

/**
 * 
 * @author adh
 *
 * BasicCapillaryReadNameFilter is a very basic read name filter which identifies
 * reads which are likely to be capillary reads.  It uses the Sanger read-naming
 * convention, in which shotgun capillary read names always end with .p1k or .q1k.
 */

public class BasicCapillaryReadNameFilter implements ReadNameFilter {
	public boolean accept(String filename) {
		return filename != null && (filename.endsWith(".p1k") || filename.endsWith(".q1k"));
	}

}
