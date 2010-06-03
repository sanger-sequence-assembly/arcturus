package test.jdbc;

import static org.junit.Assert.*;
import static org.junit.Assume.*;

import java.io.UnsupportedEncodingException;
import java.util.Date;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Clipping;
import uk.ac.sanger.arcturus.data.CapillaryRead;
import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Template;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestSequenceManager extends Base {
	@Test
	public void storeSequence() throws ArcturusDatabaseException, UnsupportedEncodingException {
		ArcturusDatabase adb = getArcturusDatabase();		
		
		Read read = createCapillaryRead("MyRead1", "MyTemplate1");
		
		read = adb.findOrCreateRead(read);
		
		assumeNotNull(read);
		
		assumeTrue(read.getID() != 0);
		
		String dnastr = "ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT";
				
		Clipping clip1 = new Clipping(Clipping.QUAL, 10, 40);
		
		Clipping clip2 = new Clipping(Clipping.SVEC, "SVEC1234", 1, 20);
		
		Clipping clip3 = new Clipping(Clipping.CVEC, "CVEC9876", 1, 30);
	
		Sequence sequence = createSequence(read, dnastr, 10, clip1, clip2, clip3);
		
		int seq_id = adb.putSequence(sequence);
		
		assertTrue(seq_id > 0);
	}
	
	@Test
	public void findOrCreateSequence() throws ArcturusDatabaseException, UnsupportedEncodingException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		Read read = createCapillaryRead("MyRead2", null);
		
		read = adb.findOrCreateRead(read);
		
		assumeNotNull(read);
		
		assumeTrue(read.getID() != 0);
		
		Sequence sequence = createSequence(read, "ACGTACGTACGT", 10, null, null, null);
		
		Sequence newSequence = adb.findOrCreateSequence(sequence);
		
		assertNotNull("Sequence was null", newSequence);
		
		assertTrue("Sequence had an invalid ID", sequence.getID() > 0);
	}
	
	@Test
	public void findOrCreateTwoCapillarySequences() throws ArcturusDatabaseException, UnsupportedEncodingException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		Read read = createCapillaryRead("MyRead3", null);
		
		read = adb.findOrCreateRead(read);
		
		assumeNotNull(read);
		
		assumeTrue(read.getID() != 0);
		
		Sequence sequence = createSequence(read, "ACGTACGTACGT", 10, null, null, null);
		
		Sequence newSequence = adb.findOrCreateSequence(sequence);
		
		assertNotNull("Sequence was null", newSequence);
		
		assertTrue("Sequence had an invalid ID", sequence.getID() > 0);
		
		Sequence sequence2 = createSequence(read, "GTGTATTACACAT", 20, null, null, null);
		
		Sequence newSequence2 = adb.findOrCreateSequence(sequence2);
		
		assertNotNull("Second sequence was null", newSequence2);
		
		assertTrue("Second sequence had an invalid ID", sequence2.getID() > 0);		
	}
	
	@Test
	public void findOrCreateTwoIlluminaSequences() throws ArcturusDatabaseException, UnsupportedEncodingException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		Read read = new Read("MyRead4", 0);
		
		read = adb.findOrCreateRead(read);
		
		assumeNotNull(read);
		
		assumeTrue(read.getID() != 0);
		
		Sequence sequence = createSequence(read, "ACGTACGTACGT", 10, null, null, null);
		
		Sequence newSequence1 = adb.findOrCreateSequence(sequence);
		
		assertNotNull("Sequence was null", newSequence1);
		
		assertTrue("Sequence had an invalid ID", newSequence1.getID() > 0);
		
		Sequence sequence2 = createSequence(read, "GTGTATTACACAT", 20, null, null, null);
		
		Sequence newSequence2 = adb.findOrCreateSequence(sequence2);
		
		assertNotNull("Second sequence was null", newSequence2);
		
		assertTrue("Second sequence had an invalid ID", newSequence2.getID() > 0);		
	}
	
	@Test
	public void findOrCreateTwoIdenticalIlluminaSequences() throws ArcturusDatabaseException, UnsupportedEncodingException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		final String dna = "ATTACACATGAGATTACACAT";
		final int qvalue = 10;
		
		Read read = new Read("MyRead5", 0);
		
		read = adb.findOrCreateRead(read);
		
		assumeNotNull(read);
		
		assumeTrue(read.getID() != 0);
		
		Sequence sequence = createSequence(read, dna, qvalue, null, null, null);
		
		Sequence newSequence1 = adb.findOrCreateSequence(sequence);
		
		assertNotNull("Sequence was null", newSequence1);
		
		assertTrue("Sequence had an invalid ID", newSequence1.getID() > 0);
		
		sequence = createSequence(read, dna, qvalue, null, null, null);
		
		Sequence newSequence2 = adb.findOrCreateSequence(sequence);
		
		assertNotNull("Second sequence was null", newSequence2);
		
		assertTrue("Second sequence had an invalid ID", newSequence2.getID() > 0);
		
		assertTrue("First and second sequences should have the same ID",
				newSequence1.getID() == newSequence2.getID());
	}

	private Read createCapillaryRead(String readName, String templateName) {
		Template template = templateName == null ? null : new Template(templateName);
		
		Date asped = new Date();
		
		String basecaller = "UnitTesting";
		
		String status = "PASS";
		
		return new CapillaryRead(readName, 0, template, asped,
				CapillaryRead.FORWARD, CapillaryRead.UNIVERSAL_PRIMER, CapillaryRead.DYE_TERMINATOR,
				basecaller, status, null);
	}
	
	private Sequence createSequence(Read read, String dnastr, int qvalue, Clipping qualityClip,
			Clipping sequencingVectorClipping, Clipping cloningVectorClipping)
		throws UnsupportedEncodingException {
		Sequence sequence = new Sequence(0, read);

		byte[] dna = dnastr.getBytes("US-ASCII");
		
		sequence.setDNA(dna);
		
		byte[] quality = new byte[dna.length];
		
		for (int i = 0; i < quality.length; i++)
			quality[i] = (byte)2;
		
		sequence.setQuality(quality);

		sequence.setQualityClipping(qualityClip);
		sequence.setSequenceVectorClippingLeft(sequencingVectorClipping);
		sequence.setCloningVectorClipping(cloningVectorClipping);
		
		return sequence;
	}
}
