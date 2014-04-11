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

package uk.ac.sanger.arcturus.repository;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.ResultSet;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

public class SangerRepositoryManager implements RepositoryManager {
	private static final String URL_KEY = "sangerrepositorymanager.url";
	private static final String USERNAME_KEY = "sangerrepositorymanager.username";
	private static final String PASSWORD_KEY = "sangerrepositorymanager.password";
	private static final String CACHE_LIFETIME_KEY = "sangerrepositorymanager.cachelifetime";
	
	private static final String ONLINE_AND_WRITABLE = "Online - physically on disk";
	
	private final String url;
	private final String username;
	private final String password;
	
	private Connection connection;
	
	private PreparedStatement pstmtGetRepositoryData;
	
	private static final String GET_REPOSITORY_DATA = 
		"select od.online_path,od.is_available,os.statusdate,osd.description" +
		" from project p, online_data od, online_status os, onlinestatusdict osd" +
		" where p.projectname = ?" +
		" and p.id_online=od.id_online" +
		" and p.id_online=os.id_online" +
		" and os.iscurrent=1" +
		" and os.status=osd.id_dict";
	
	static {
		try {
			Class.forName("oracle.jdbc.driver.OracleDriver");
		} catch (ClassNotFoundException e) {
			e.printStackTrace();
		}
	}
	
	private Map<String, Repository> cache = new HashMap<String, Repository>();
	
	private static final long DEFAULT_CACHE_LIFETIME = 600L;
	
	private long cacheLifetime = DEFAULT_CACHE_LIFETIME;

	public SangerRepositoryManager(Properties props) throws RepositoryException {
		url = props.getProperty(URL_KEY);
		
		if (url == null)
			throw new RepositoryException("Database URL was not specified in properties passed to constructor");
		
		username = props.getProperty(USERNAME_KEY);
		
		if (username == null)
			throw new RepositoryException("Database username was not specified in properties passed to constructor");
	
		password = props.getProperty(PASSWORD_KEY);
		
		if (password == null)
			throw new RepositoryException("Database password was not specified in properties passed to constructor");
		
		String lifetime = props.getProperty(CACHE_LIFETIME_KEY);
		
		if (lifetime != null) {
			try {
				long l = Long.parseLong(lifetime);
				
				if (l > 0)
					cacheLifetime = l;
			}
			catch (NumberFormatException e) {}
		}
	}
	
	private Connection getConnection() throws RepositoryException {
		try {
			if (connection == null) {	
				connection = DriverManager.getConnection(url, username, password);
		
				prepareConnection(connection);
			}
		}
		catch (SQLException e) {
			throw new RepositoryException("A database exception occurred", e);
		}
		
		return connection;
	}
	
	private void prepareConnection(Connection conn) throws SQLException {
		pstmtGetRepositoryData = conn.prepareStatement(GET_REPOSITORY_DATA);
	}
	
	public Repository getRepository(String name) throws RepositoryException {
		Repository repository = cache.get(name);
		
		if (repository == null) {
			repository = new Repository(name);
			
			if (updateRepository(repository)) {
				cache.put(name, repository);
				return repository;
			} else
				return null;
		}
		
		if (repository.isExpired())
			updateRepository(repository);
		
		return repository;
	}

	public boolean updateRepository(Repository repository)
			throws RepositoryException {
		if (repository == null)
			return false;
		
		getConnection();
		
		boolean status = false;
		
		String name = repository.getName();
		
		try {
			pstmtGetRepositoryData.setString(1, name);
			
			ResultSet rs = pstmtGetRepositoryData.executeQuery();
			
			if (rs.next()) {
				String path = rs.getString(1);
				int available = rs.getInt(2);
				Date date = rs.getTimestamp(3);
				String description = rs.getString(4);
				
				repository.setPath(path);
				
				repository.setDate(date);
				
				repository.setOnline(available > 0);
				
				repository.setWritable(description.equalsIgnoreCase(ONLINE_AND_WRITABLE));
				
				repository.setExpires(System.currentTimeMillis() + cacheLifetime * 1000L);
				
				return true;
			}
			
			rs.close();
		}
		catch (SQLException e) {
			throw new RepositoryException("A database exception occurred when looking up \"" + name + "\"", e);
		}
		
		return status;
	}

	public void close() throws RepositoryException {
		if (connection != null) {
			try {
				connection.close();
			} catch (SQLException e) {
				throw new RepositoryException("A problem occurred when closing the database connection", e);
			}
			
			connection = null;
		}
	}
}
