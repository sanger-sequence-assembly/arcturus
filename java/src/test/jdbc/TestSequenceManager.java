package test.jdbc;

import static org.junit.Assert.*;
import static org.junit.Assume.*;

import java.io.UnsupportedEncodingException;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Clipping;
import uk.ac.sanger.arcturus.data.Sequence;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestSequenceManager extends Base {
	@Test
	public void storeSequence() throws ArcturusDatabaseException, UnsupportedEncodingException {
		Sequence sequence = new Sequence(0, null);
		
		String dnastr = "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT";
		
		byte[] dna = dnastr.getBytes("US-ASCII");
		
		assumeNotNull(dna);
		
		sequence.setDNA(dna);
		
		byte[] quality = new byte[dna.length];
		
		for (int i = 0; i < quality.length; i++)
			quality[i] = (byte)2;
		
		sequence.setQuality(quality);
		
		Clipping clip = new Clipping(Clipping.QUAL, 10, 40);
		
		sequence.setQualityClipping(clip);
		
		clip = new Clipping(Clipping.SVEC, "SVEC1234", 1, 20);
		
		sequence.setSequenceVectorClippingLeft(clip);
		
		clip = new Clipping(Clipping.CVEC, "CVEC9876", 1, 30);
		
		sequence.setCloningVectorClipping(clip);

		ArcturusDatabase adb = getArcturusDatabase();		
	
		int seq_id = adb.putSequence(sequence);
		
		assertTrue(seq_id > 0);
	}
}
