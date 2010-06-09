package uk.ac.sanger.arcturus.samtools;

public class Utility {
	private static final int READ_FLAGS_MASK = 128 + 64 + 1;

	public static final int maskReadFlags(int flags) {
		return flags & READ_FLAGS_MASK;
	}
}
