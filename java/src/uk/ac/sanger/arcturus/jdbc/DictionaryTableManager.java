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
	private ArcturusDatabase adb;
	
	private String tableName;
	private String primaryKeyName;
	private String valueName;
	
	private Map<String, Integer> cache = new HashMap<String, Integer>();
	
	private PreparedStatement pstmtFetchAllEntries, pstmtFetchByName, pstmtStoreNewValue;
	
	public DictionaryTableManager(ArcturusDatabase adb, String tableName, String primaryKeyName,
			String valueName) throws ArcturusDatabaseException {
		this.adb = adb;
		this.tableName = tableName;
		this.primaryKeyName = primaryKeyName;
		this.valueName = valueName;
		
		if (adb instanceof ArcturusDatabaseImpl)
			((ArcturusDatabaseImpl)adb).addManager(this);

		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the dictionary manager for " + tableName,
					conn, adb);
		}
	}

	public void clearCache() {
		cache.clear();
	}

	public void preload() throws ArcturusDatabaseException {
		clearCache();
		
		try {
			ResultSet rs = pstmtFetchAllEntries.executeQuery();
			
			while (rs.next()) {
				int primary_key = rs.getInt(1);
				String value = rs.getString(2);
				
				cache.put(value, primary_key);
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
	
	public int getValue(String name) throws ArcturusDatabaseException {
		if (cache.containsKey(name))
			return cache.get(name);
		
		try {
			pstmtFetchByName.setString(1, name);
			
			ResultSet rs = pstmtFetchByName.executeQuery();
			
			int primaryKey = rs.next() ? rs.getInt(1) : 0;
				
			if (primaryKey > 0)
				cache.put(name, primaryKey);
				
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
					cache.put(name, primaryKey);
					
				rs.close();
					
				return primaryKey;
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to insert new entry \"" + name + "\" into " + tableName, conn, this);			
		}
		
		return 0;
	}
}
