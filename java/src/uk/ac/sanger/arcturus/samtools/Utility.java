package uk.ac.sanger.arcturus.samtools;

import java.text.DecimalFormat;
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

	private static long T0 = System.currentTimeMillis();
	
	private static DecimalFormat format;
	
	static {
		format = new DecimalFormat();
		format.setGroupingSize(3);
	}
	
	public static void reportMemory(String message) {
		Runtime rt = Runtime.getRuntime();
		
		long freeMemory = rt.freeMemory();
		long totalMemory = rt.totalMemory();
		
		long usedMemory = totalMemory - freeMemory;
		
		freeMemory /= 1024;
		totalMemory /= 1024;
		usedMemory /= 1024;
		
		long t = System.currentTimeMillis();
		
		long dt = t - T0;
		
		T0 = t;
		
		System.err.println(message + " ; Memory used " + format.format(usedMemory) + " kb, free " +
				format.format(freeMemory) + " kb, total " + format.format(totalMemory) +
				" kb ; dt = " + format.format(dt) + " ms");
	}

}
