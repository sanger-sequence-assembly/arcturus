// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
