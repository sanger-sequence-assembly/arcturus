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

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.ReadGroup;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ReadGroupManager  extends AbstractManager{

	protected PreparedStatement pstmtCreateReadGroup = null;
	protected PreparedStatement pstmtGetReadGroupByImportId = null;
	protected PreparedStatement pstmtGetReadGroupByReadTag = null;
	protected PreparedStatement pstmtGetReadGroupById = null;
	protected PreparedStatement pstmtGetReadGroupByLineId = null;
	protected PreparedStatement pstmtGetLastImportId = null;
	
	protected ManagerEvent event = null;

	private HashMap<Integer, ReadGroup> hashById;
	private HashMap<Integer, ReadGroup> hashByImportId;
	private HashMap<Integer, ReadGroup> hashByLineId;
	private HashMap<String, ReadGroup> hashByReadTag;
	
	/**
	 * Creates a new ReadGroupManager to provide read tag group management services to an
	 * ArcturusDatabase object.  Called to process or produce a SAMFileHeader record 
	 */

		public ReadGroupManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		event = new ManagerEvent(this);

		hashById = new HashMap<Integer, ReadGroup>();
		hashByImportId = new HashMap<Integer, ReadGroup>();
		hashByLineId = new  HashMap<Integer, ReadGroup>();
		hashByReadTag = new HashMap<String, ReadGroup>();

	}

	public void clearCache() {
		hashById.clear();
		hashByImportId.clear();
		hashByLineId.clear();
		hashByReadTag.clear();
	}

	protected void prepareConnection() throws SQLException {
		String query;

		query = "insert into READGROUP(read_group_line_id, import_id, tag_name, tag_value) values ( ?, ?, ?, ?)";

		pstmtCreateReadGroup = prepareStatement(query);
		
		query = "select read_group_line_id, tag_name, tag_value from READGROUP where import_id = ?";
		
		pstmtGetReadGroupByImportId = prepareStatement(query);
		
		query = "select read_group_line_id, tag_name, tag_value from READGROUP where tag_name = ? and import_id = ?";
		
		pstmtGetReadGroupByReadTag = prepareStatement(query);
		
		query = "select read_group_line_id, tag_name, tag_value from READGROUP where tag_name = 'ID' and tag_value = ? and import_id = ?"; 
			
		pstmtGetReadGroupById = prepareStatement(query);
		
		query = "select tag_name, tag_value from READGROUP where read_group_line_id = ?";
		
		pstmtGetReadGroupByLineId = prepareStatement(query);
		
	

	}
	
	protected void addReadGroup(ReadGroup readGroup) throws SQLException, ArcturusDatabaseException{
		
		pstmtCreateReadGroup.setInt(1, readGroup.getRead_group_line_id());
		pstmtCreateReadGroup.setInt(2, readGroup.getImport_id());
		pstmtCreateReadGroup.setString(3, readGroup.getTag_name());
		pstmtCreateReadGroup.setString(4, readGroup.getTag_value());
		
		try {
			pstmtCreateReadGroup.executeQuery();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to add ReadGroup", conn, this);
		}
	}
	
	protected void addReadGroupsFromThisImport(Set<ReadGroup> readGroups) throws SQLException, ArcturusDatabaseException {
		
		Iterator it = readGroups.iterator();
		while (it.hasNext()) {
		    // Get element
			addReadGroup((ReadGroup) it.next());
		}
		
	}
	
	protected Set<ReadGroup> findReadGroupsFromLastImport(Project project) throws SQLException, ArcturusDatabaseException {
		
		int last_import_id = 0;
		
		HashSet hashSet = new HashSet();
		Set<ReadGroup> readGroups = hashSet;
		
		try {
			last_import_id = adb.getLastImportId(project);
			pstmtGetReadGroupByImportId.setInt(1, last_import_id);

			ResultSet rs = pstmtGetReadGroupByImportId.executeQuery();

			/*
+--------------------+----------+---------------+
| read_group_line_id | tag_name | tag_value     |
+--------------------+----------+---------------+
|                  1 | ID       | GE6QGXJ01.sff | 
|                  1 | SM       | unknown       | 
|                  1 | LB       | GE6QGXJ01.sff | 
|                  2 | ID       | GI1YXNO01.sff | 
|                  2 | SM       | unknown       | 
|                  2 | LB       | GI1YXNO01.sff | 
|                  3 | ID       | GWSHH1C01.sff | 
|                  3 | SM       | unknown       | 
|                  3 | LB       | GWSHH1C01.sff | 
+--------------------+----------+---------------+

			 */

			while (rs.next()) {
			
				int read_group_line_id = rs.getInt(1);
				int import_id = rs.getInt(2);
			String tag_name = rs.getString(3);
				String tag_value = rs.getString(4);

				ReadGroup readGroup = new ReadGroup(read_group_line_id, import_id, tag_name, tag_value);
				readGroups.add(readGroup);
			} 

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get read group for last import", conn, this);
		}

			return readGroups;
	}

	@Override
	public String getCacheStatistics() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public void preload() throws ArcturusDatabaseException {
		// TODO Auto-generated method stub
		
	}
}
