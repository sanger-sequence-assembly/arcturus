package uk.ac.sanger.arcturus.samtools;

import java.util.zip.DataFormatException;
import java.util.zip.Inflater;

public class Utility {
	private static final int READ_FLAGS_MASK = 128 + 64 + 1;
	
	private static final Inflater decompresser = new Inflater();

	public static final int maskReadFlags(int flags) {
		return flags & READ_FLAGS_MASK;
	}

	public static byte[] reverseComplement(byte[] src) {
		if (src == null)
			return null;
		
		int srclen = src.length;
		
		byte[] dst = new byte[srclen];
		
		int j = srclen - 1;
		
		for (int i = 0; i < srclen; i++)
			dst[j--] = reverseComplement(src[i]);
		
		return dst;
	}
	
	private static byte reverseComplement(byte c) {
		switch (c) {
			case 'a': return 't';
			case 'A': return 'T';
			
			case 'c': return 'g';
			case 'C': return 'G';
			
			case 'g': return 'c';
			case 'G': return 'C';
			
			case 't': return 'a';
			case 'T': return 'A';
			
			default: return c;
		}
	}
	
	public static byte[] reverseQuality(byte[] src) {
		if (src == null)
			return null;
		
		int srclen = src.length;
		
		byte[] dst = new byte[srclen];
		
		int j = srclen - 1;
		
		for (int i = 0; i < srclen; i++)
			dst[j--] = src[i];
		
		return dst;
	}

	public static byte[] decodeCompressedData(byte[] compressed, int length) throws DataFormatException {
		byte[] buffer = new byte[length];

		decompresser.setInput(compressed, 0, compressed.length);
		decompresser.inflate(buffer, 0, buffer.length);
		decompresser.reset();

		return buffer;
	}

}
