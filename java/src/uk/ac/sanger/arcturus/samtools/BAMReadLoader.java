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

package uk.ac.sanger.arcturus.samtools;

import java.sql.Connection;
import java.sql.SQLException;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.traceserver.TraceServerClient;
import uk.ac.sanger.arcturus.utils.ReadNameFilter;

import net.sf.samtools.SAMFileReader;
import net.sf.samtools.SAMFileReader.ValidationStringency;
import net.sf.samtools.SAMRecord;
import net.sf.samtools.SAMRecordIterator;
import net.sf.samtools.SAMFileHeader;
import net.sf.samtools.SAMSequenceRecord;

public class BAMReadLoader {
	private ArcturusDatabase adb;
	private TraceServerClient traceServerClient;
	private ReadNameFilter readNameFilter;
	
	private int tsLookups;
	private int tsFailures;

	public BAMReadLoader(ArcturusDatabase adb, TraceServerClient traceServerClient, ReadNameFilter readNameFilter) throws ArcturusDatabaseException {
		this.adb = adb;
		this.traceServerClient = traceServerClient;
		this.readNameFilter = readNameFilter;
		
		prepareLoader();
	}
	
	public BAMReadLoader(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this(adb, null, null);
	}
	
	private void prepareLoader() {		
		adb.setCacheing(ArcturusDatabase.READ, false);
		adb.setCacheing(ArcturusDatabase.SEQUENCE, false);
		adb.setCacheing(ArcturusDatabase.TEMPLATE, false);
	}
	
	public void processFile(SAMFileReader reader) throws ArcturusDatabaseException {
		SAMRecordIterator iterator = reader.iterator();

		int n = 0;
		
		tsLookups = 0;
		tsFailures = 0;
		
		Connection conn = adb.getDefaultConnection();
		
		try {
			boolean savedAutoCommit = conn.getAutoCommit();
			conn.setAutoCommit(false);
						
			while (iterator.hasNext()) {
				SAMRecord record = iterator.next();
			
				findOrCreateSequence(record);
			
				n++;
			
				if ((n%10000) == 0) {
					conn.commit();
					reportMemory(n);
				}
			}
			
			iterator.close();
			
			conn.commit();
			
			conn.setAutoCommit(savedAutoCommit);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "An SQL exception occurred when processing a file", conn, this);
		}
	}
	
	public Sequence findOrCreateSequence(SAMRecord record) throws ArcturusDatabaseException {
		String readname = record.getReadName();
		
		int maskedFlags = 0;
		int flags = record.getFlags();
		int start = record.getAlignmentStart();
		Integer startInt = new Integer(start);
		String startString = startInt.toString();
		
		if (flags != 768) {
			maskedFlags = Utility.maskReadFlags(flags);
		}
		else {
			maskedFlags = flags;
			readname = "Dummy" + startString;
		}
		
		byte[] dna = record.getReadBases();
		
		byte[] quality = record.getBaseQualities();
		
		if (record.getReadNegativeStrandFlag()) {
			dna = Utility.reverseComplement(dna);
			quality = Utility.reverseQuality(quality);
		}
				
		Read read = adb.getReadByNameAndFlags(readname, maskedFlags);
		
		if (read == null && traceServerClient != null && readNameFilter != null
				&& readNameFilter.accept(readname)) {
			Sequence storedSequence = traceServerClient.fetchRead(readname);
				
			tsLookups++;
				
			if (storedSequence != null) {
				read = storedSequence.getRead();
				adb.findSequenceByReadnameFlagsAndHash(storedSequence);
			} else
				tsFailures++;
		}
		
		if (read == null)
			read = new Read(readname, maskedFlags);
		
		Sequence sequence = new Sequence(0, read, dna, quality, 0);
		
		Sequence newSequence = adb.findSequenceByReadnameFlagsAndHash(sequence);
		
		return newSequence;
	}

	private void reportMemory(int n) {
		String message = "Reads: " + n + "; traceserver lookups = " + tsLookups + ", failures = " + tsFailures;

		Utility.reportMemory(message);
		
		System.out.println("Loaded " + n + " new reads");
	}
}
