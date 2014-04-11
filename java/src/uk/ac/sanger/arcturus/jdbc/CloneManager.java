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

import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.util.*;

/**
 * This class manages Clone objects.
 */

public class CloneManager extends AbstractManager {
	private ArcturusDatabase adb;
	private Connection conn;
	private HashMap hashByID, hashByName;
	private PreparedStatement pstmtByID, pstmtByName;

	/**
	 * Creates a new CloneManager to provide clone management services to an
	 * ArcturusDatabase object.
	 */

	public CloneManager(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;

		conn = adb.getConnection();

		String query = "select name from CLONE where clone_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select clone_id from CLONE where name = ?";
		pstmtByName = conn.prepareStatement(query);

		hashByID = new HashMap();
		hashByName = new HashMap();
	}

	public void clearCache() {
		hashByID.clear();
		hashByName.clear();
	}

	public Clone getCloneByName(String name) throws SQLException {
		Object obj = hashByName.get(name);

		return (obj == null) ? loadCloneByName(name) : (Clone) obj;
	}

	public Clone getCloneByID(int id) throws SQLException {
		Object obj = hashByID.get(new Integer(id));

		return (obj == null) ? loadCloneByID(id) : (Clone) obj;
	}

	private Clone loadCloneByName(String name) throws SQLException {
		pstmtByName.setString(1, name);
		ResultSet rs = pstmtByName.executeQuery();

		Clone clone = null;

		if (rs.next()) {
			int id = rs.getInt(1);
			clone = registerNewClone(name, id);
		}

		return clone;
	}

	private Clone loadCloneByID(int id) throws SQLException {
		pstmtByID.setInt(1, id);
		ResultSet rs = pstmtByID.executeQuery();

		Clone clone = null;

		if (rs.next()) {
			String name = rs.getString(1);
			clone = registerNewClone(name, id);
		}

		return clone;
	}

	private Clone registerNewClone(String name, int id) {
		Clone clone = new Clone(name, id, adb);

		hashByName.put(name, clone);
		hashByID.put(new Integer(id), clone);

		return clone;
	}

	public void preload() throws SQLException {
		String query = "select clone_id, name from CLONE";

		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int id = rs.getInt(1);
			String name = rs.getString(2);
			registerNewClone(name, id);
		}

		rs.close();
		stmt.close();
	}
}
