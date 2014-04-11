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

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;

import uk.ac.sanger.arcturus.Arcturus;

public class FastaFileReader {
	private static final String FASTA_PREFIX = ">";

	private static final String DNA_PATTERN = "^[ACGTNXacgtnx]+$";
	
	public void processFile(File file, SequenceProcessor processor) throws IOException, FastaFileException {
		FileInputStream fis = new FileInputStream(file);
		
		processFile(fis, processor);
	}

	public void processFile(InputStream is, SequenceProcessor processor) throws IOException, FastaFileException {
		BufferedReader br = new BufferedReader(new InputStreamReader(is));
		
		StringBuilder sb = null;

		String seqname = null;

		String line;

		while ((line = br.readLine()) != null) {
			if (line.startsWith(FASTA_PREFIX)) {
				if (seqname != null) {
					processSequence(processor, seqname, sb.toString());
					seqname = null;
				}

				line = line.substring(1);

				String[] words = line.split("\\s+");

				seqname = words[0];

				sb = new StringBuilder();
			} else if (line.matches(DNA_PATTERN)) {
				sb.append(line);
			}
		}

		if (seqname != null && processor != null)
			processSequence(processor, seqname, sb.toString());		
	}

	private void processSequence(SequenceProcessor processor, String seqname,
			String dna) {
		byte[] sequence = null;

		try {
			sequence = dna.getBytes("US-ASCII");
		} catch (UnsupportedEncodingException e) {
			Arcturus.logWarning(e);
		}
		
		processor.processSequence(seqname, sequence, null);
	}	
}
