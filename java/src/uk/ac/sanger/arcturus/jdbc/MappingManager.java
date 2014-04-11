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

package uk.ac.sanger.arcturus.jdbc;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.Vector;

import uk.ac.sanger.arcturus.data.Mapping;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class MappingManager extends AbstractManager {
	private ArcturusDatabase adb;
	private Connection conn;

	private ManagerEvent event = null;

	private transient Vector<ManagerEventListener> eventListeners = new Vector<ManagerEventListener>();
	
	private static final String SQL_COUNT_MAPPINGS = "select count(*) from MAPPING where contig_id = ?";

	protected PreparedStatement pstmtCountMappings;

	private static final String SQL_GET_MAPPING_DATA = "select M.seq_id,M.cstart,M.cfinish,M.direction,S.seqlen"
			+ " from MAPPING M left join SEQUENCE S using(seq_id)"
			+ " where contig_id=? order by cstart asc,seq_id asc";

	private PreparedStatement pstmtMappingData;

	private static final String SQL_GET_SEGMENT_DATA = "select M.seq_id,S.cstart,S.rstart,S.length "
			+ " from MAPPING M left join SEGMENT S using(mapping_id) "
			+ " where contig_id = ? order by M.cstart asc,seq_id asc";

	private PreparedStatement pstmtSegmentData;

	/**
	 * Creates a new ContigManager to provide contig management services to an
	 * ArcturusDatabase object.
	 */

	public MappingManager(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;

		event = new ManagerEvent(this);

		conn = adb.getConnection();

		prepareStatements();
	}

	private void prepareStatements() throws SQLException {
		pstmtCountMappings = conn.prepareStatement(SQL_COUNT_MAPPINGS);
		
		pstmtMappingData = conn.prepareStatement(SQL_GET_MAPPING_DATA);

		pstmtSegmentData = conn.prepareStatement(SQL_GET_SEGMENT_DATA);
	}

	public void clearCache() {
		// Does nothing
	}

	public void preload() throws SQLException {
		// Does nothing
	}

	public int countMappings(int contig_id) throws SQLException {
		pstmtCountMappings.setInt(1, contig_id);
		
		ResultSet rs = pstmtCountMappings.executeQuery();
		
		int rc = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		
		return rc;
	}
	
	public Mapping[] getMappings(int contig_id, int mode)
			throws SQLException {
		if ((mode & ArcturusDatabase.CONTIG_MAPPING_SEGMENTS) == 0)
			return getMappingsOnly(contig_id);
		else
			return getMappingsAndSegments(contig_id);
	}
	
	private Mapping[] getMappingsOnly(int contig_id) throws SQLException {
		int nMappings = countMappings(contig_id);

		Mapping[] mappings = new Mapping[nMappings];
		
		pstmtMappingData.setInt(1, contig_id);

		event.begin("Execute mapping query", nMappings);
		fireEvent(event);

		ResultSet rs = pstmtMappingData.executeQuery();

		event.end();
		fireEvent(event);

		int kMapping = 0;

		event.begin("Creating mappings", nMappings);
		fireEvent(event);

		while (rs.next()) {
			int seq_id = rs.getInt(1);
			int cstart = rs.getInt(2);
			int cfinish = rs.getInt(3);
			boolean forward = rs.getString(4).equalsIgnoreCase("Forward");
			int length = rs.getInt(5);

			Sequence sequence = adb.findOrCreateSequence(seq_id, length);

			mappings[kMapping++] = new Mapping(sequence, cstart, cfinish,
					forward);

			if ((kMapping % 10) == 0) {
				event.working(kMapping);
				fireEvent(event);
			}
		}

		event.end();
		fireEvent(event);

		rs.close();
		
		Arrays.sort(mappings);
		
		return mappings;
	}
	
	private Mapping[] getMappingsAndSegments(int contig_id) throws SQLException {
		int nMappings = countMappings(contig_id);

		Mapping[] mappings = new Mapping[nMappings];
		
		return mappings;
	}

	public void addContigManagerEventListener(ManagerEventListener listener) {
		eventListeners.addElement(listener);
	}

	public void removeContigManagerEventListener(ManagerEventListener listener) {
		eventListeners.removeElement(listener);
	}

	private void fireEvent(ManagerEvent event) {
		Enumeration e = eventListeners.elements();
		while (e.hasMoreElements()) {
			ManagerEventListener l = (ManagerEventListener) e.nextElement();
			l.managerUpdate(event);
		}
	}

}
