package uk.ac.sanger.arcturus.fasta;

import java.io.File;
import java.io.IOException;

import javax.swing.JFileChooser;

public class TestFastaFileReader implements SequenceProcessor {
	public static void main(String[] args) {
		File file = getFile();
		
		if (file != null) {
			TestFastaFileReader processor = new  TestFastaFileReader();
			FastaFileReader reader = new FastaFileReader();
			
			try {
				reader.processFile(file, processor);
			} catch (IOException e) {
				e.printStackTrace();
			} catch (FastaFileException e) {
				e.printStackTrace();
			}
		}
		
		System.exit(0);
	}

	private static File getFile() {
		JFileChooser chooser = new JFileChooser();
			
		File cwd = new File(System.getProperty("user.home"));
		
		chooser.setCurrentDirectory(cwd);

		int returnVal = chooser.showOpenDialog(null);

		return (returnVal == JFileChooser.APPROVE_OPTION) ?
			chooser.getSelectedFile() : null;
	}

	public void processSequence(String name, byte[] dna, byte[] quality) {
		System.out.println(name + " " + (dna == null ? 0 : dna.length) +
				" " + (quality == null ? 0 : quality.length));
	}
}
