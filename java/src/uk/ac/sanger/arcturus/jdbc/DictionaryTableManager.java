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
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.ResultSet;

import java.util.HashMap;
import java.util.Map;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class DictionaryTableManager extends AbstractManager {
	private String tableName;
	private String primaryKeyName;
	private String valueName;
	
	private Map<String, Integer> cacheByName = new HashMap<String, Integer>();
	private Map<Integer, String> cacheByID = new HashMap<Integer, String>();
	
	private PreparedStatement pstmtFetchAllEntries, pstmtFetchByName, pstmtStoreNewValue;
	
	public DictionaryTableManager(ArcturusDatabase adb, String tableName, String primaryKeyName,
			String valueName) throws ArcturusDatabaseException {
		super(adb);
		
		this.tableName = tableName;
		this.primaryKeyName = primaryKeyName;
		this.valueName = valueName;

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the dictionary manager for " + tableName,
					conn, adb);
		}
	}

	public void clearCache() {
		cacheByName.clear();
		cacheByID.clear();
	}
	
	private void cacheKeyAndValue(int primary_key, String value) {
		cacheByName.put(value, primary_key);
		cacheByID.put(primary_key, value);
	}

	public void preload() throws ArcturusDatabaseException {
		clearCache();
		
		try {
			ResultSet rs = pstmtFetchAllEntries.executeQuery();
			
			while (rs.next()) {
				int primary_key = rs.getInt(1);
				String value = rs.getString(2);
				
				cacheKeyAndValue(primary_key, value);
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload dictionary table " + tableName, conn, this);
		}
	}

	protected void prepareConnection() throws SQLException {
		String query = "select " + primaryKeyName + "," + valueName + " from " + tableName;
		
		pstmtFetchAllEntries = prepareStatement(query);
		
		query = "select " + primaryKeyName + " from " + tableName + " where " + valueName + " = ?";
		
		pstmtFetchByName = prepareStatement(query);
		
		query = "insert into " + tableName + " (" + valueName + ") VALUES (?)";
		
		pstmtStoreNewValue = prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
	}
	
	public int getID(String name) throws ArcturusDatabaseException {
		if (name == null)
			return -1;
		
		if (cacheByName.containsKey(name))
			return cacheByName.get(name);
		
		try {
			pstmtFetchByName.setString(1, name);
			
			ResultSet rs = pstmtFetchByName.executeQuery();
			
			int primaryKey = rs.next() ? rs.getInt(1) : 0;
				
			if (primaryKey > 0)
				cacheKeyAndValue(primaryKey, name);
				
			rs.close();
				
			if (primaryKey > 0)
				return primaryKey;
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to fetch ID by name from " + tableName, conn, this);
		}
		
		try {
			pstmtStoreNewValue.setString(1, name);
			
			int rc = pstmtStoreNewValue.executeUpdate();
			
			if (rc == 1) {
				ResultSet rs = pstmtStoreNewValue.getGeneratedKeys();
				
				int primaryKey = rs.next() ? rs.getInt(1) : 0;
				
				if (primaryKey > 0)
					cacheKeyAndValue(primaryKey, name);
					
				rs.close();
					
				return primaryKey;
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to insert new entry \"" + name + "\" into " + tableName, conn, this);			
		}
		
		return 0;
	}
	
	public String getValue(int id) {
		return cacheByID.get(id);
	}

	public String getCacheStatistics() {
		return "ByID: " + cacheByID.size() + ", ByName: " + cacheByName.size();
	}
}
