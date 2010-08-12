package uk.ac.sanger.arcturus.fasta;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;

import uk.ac.sanger.arcturus.Arcturus;

public class FastqFileReader {
	private static final String FASTQ_SEQUENCE_PREFIX = "@";
	
	private static final String FASTQ_QUALITY_PREFIX = "+";

	private static final String DNA_PATTERN = "^[ACGTNXacgtnx\\*]+$";
	
	private static final int FASTQ_QUALITY_OFFSET = 33;
	
	public void processFile(File file, SequenceProcessor processor) throws IOException, FastaFileException {
		FileInputStream fis = new FileInputStream(file);
		
		processFile(fis, processor);
	}

	public void processFile(InputStream is, SequenceProcessor processor) throws IOException, FastaFileException {
		BufferedReader br = new BufferedReader(new InputStreamReader(is));
		
		boolean done = false;
		
		while (!done) {
			done = ! processNextFastqRecord(br, processor);
		}
	}
	
	private boolean processNextFastqRecord(BufferedReader br, SequenceProcessor processor)
		throws IOException, FastaFileException {
		String line = br.readLine();
		
		if (line == null)
			return false;
		
		if (!line.startsWith(FASTQ_SEQUENCE_PREFIX))
			throw new FastaFileException("Line does not begin with the FASTQ sequence prefix character");
		
		line = line.substring(1);
		
		String[] words = line.split("\\s+");

		String seqname = words[0];
		
		String dnaString = br.readLine();
		
		if (dnaString == null)
			throw new FastaFileException("File ended prematurely: no DNA for sequence \"" + seqname + "\"");

		if (!dnaString.matches(DNA_PATTERN))
			throw new FastaFileException("Data format error: DNA line does not look like DNA for sequence \"" + seqname + "\"");

		line = br.readLine();
		
		if (line == null)
			throw new FastaFileException("File ended prematurely: failed to find line beginning with the FASTQ quality prefix character for sequence \"" +
					seqname + "\"");
	
		if (!line.startsWith(FASTQ_QUALITY_PREFIX))
			throw new FastaFileException("Data format error: line does not begin with the FASTQ quality prefix character for sequence \"" +
					seqname + "\"");
		
		String qualityString = br.readLine();
	
		if (qualityString == null)
			throw new FastaFileException("File ended prematurely: no quality string for sequence \"" + seqname + "\"");
		

		int dnaLength = dnaString.length();
		
		int qualityLength = qualityString.length();
		
		if (dnaLength != qualityLength)
			throw new FastaFileException("Data format error: the DNA length (" + dnaLength +
					" does not match the quality length (" + qualityLength +
					" for sequence \"" + seqname + "\"");

		processSequence(processor, seqname, dnaString, qualityString);
		
		return true;
	}

	private void processSequence(SequenceProcessor processor, String seqname,
			String dna, String quality) {
		byte[] sequence = null;
		byte[] qdata = null;

		try {
			sequence = dna.getBytes("US-ASCII");
			qdata = quality.getBytes("US-ASCII");
		} catch (UnsupportedEncodingException e) {
			Arcturus.logWarning(e);
		}
		
		if (qdata != null) {
			for (int i = 0; i < qdata.length; i++)
				qdata[i] -= FASTQ_QUALITY_OFFSET;
		}
		
		processor.processSequence(seqname, sequence, qdata);
	}	

}
