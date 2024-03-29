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

import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

/**
 * This class manages Template objects.
 */

public class TemplateManager extends AbstractManager {
	private ArcturusDatabase adb;
	private HashMap<Integer, Template> hashByID;
	private HashMap<String, Template> hashByName;
	private PreparedStatement pstmtByID, pstmtByName;

	/**
	 * Creates a new TemplateManager to provide template management services to
	 * an ArcturusDatabase object.
	 * 
	 * @param adb
	 *            the ArcturusDatabase object to which this manager belongs.
	 */

	public TemplateManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;

		hashByID = new HashMap<Integer, Template>();
		hashByName = new HashMap<String, Template>();
		
		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the contig manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		String query = "select name,ligation_id from TEMPLATE where template_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select template_id,ligation_id from TEMPLATE where name = ?";
		pstmtByName = conn.prepareStatement(query);
	}

	public void clearCache() {
		hashByID.clear();
		hashByName.clear();
	}

	/**
	 * Returns a template identified by the specified name. If the template has
	 * not already been loaded from the database, it is created from information
	 * in the database.
	 * 
	 * @param name
	 *            the name of the template which is required.
	 * 
	 * @return the template identified by the specified name.
	 */

	public Template getTemplateByName(String name) throws ArcturusDatabaseException {
		return getTemplateByName(name, true);
	}

	/**
	 * Returns a template identified by the specified name. If the template has
	 * not already been loaded from the database, it may optionally be created
	 * from information in the database.
	 * 
	 * @param name
	 *            the name of the template which is required.
	 * @param autoload
	 *            if true, and the template has not already been loaded, a new
	 *            template object is created and registered, and this object is
	 *            returned.
	 * 
	 * @return the template identified by the specified name, or null if
	 *         autoload is false and the template has not already been loaded.
	 */

	public Template getTemplateByName(String name, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByName.get(name);

		return (obj == null && autoload) ? loadTemplateByName(name)
				: (Template) obj;
	}

	/**
	 * Returns a template with the specified identifier. If the template has not
	 * already been loaded from the database, it is created from information in
	 * the database.
	 * 
	 * @param id
	 *            the identifer of the template which is required.
	 * 
	 * @return the template with the specified identifer.
	 */

	public Template getTemplateByID(int id) throws ArcturusDatabaseException {
		return getTemplateByID(id, true);
	}

	/**
	 * Returns a template with the specified identifier. If the template has not
	 * already been loaded from the database, it may optionally be created from
	 * information in the database.
	 * 
	 * @param id
	 *            the identifier of the template which is required.
	 * @param autoload
	 *            if true, and the template has not already been loaded, a new
	 *            template object is created and registered, and this object is
	 *            returned.
	 * 
	 * @return the template with the specified identifier, or null if autoload
	 *         is false and the template has not already been loaded.
	 */

	public Template getTemplateByID(int id, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByID.get(new Integer(id));

		return (obj == null && autoload) ? loadTemplateByID(id)
				: (Template) obj;
	}

	private Template loadTemplateByName(String name) throws ArcturusDatabaseException {
		Template template = null;

		try {
			pstmtByName.setString(1, name);
			ResultSet rs = pstmtByName.executeQuery();

			if (rs.next()) {
				int id = rs.getInt(1);
				int ligation_id = rs.getInt(2);
				template = createAndRegisterNewTemplate(name, id, ligation_id);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load template by name=\"" + name + "\"", conn, this);
		}

		return template;
	}

	private Template loadTemplateByID(int id) throws ArcturusDatabaseException {
		Template template = null;

		try {
			pstmtByID.setInt(1, id);
			ResultSet rs = pstmtByID.executeQuery();

			if (rs.next()) {
				String name = rs.getString(1);
				int ligation_id = rs.getInt(2);
				template = createAndRegisterNewTemplate(name, id, ligation_id);
			}

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load template by ID=" + id, conn, this);
		}
		
		return template;
	}

	private Template createAndRegisterNewTemplate(String name, int id,
			int ligation_id) throws ArcturusDatabaseException {
		Ligation ligation = adb.getLigationByID(ligation_id);

		Template template = new Template(name, id, ligation, adb);

		registerNewTemplate(template);

		return template;
	}

	void registerNewTemplate(Template template) {
	    if (cacheing) {
		hashByName.put(template.getName(), template);
		hashByID.put(new Integer(template.getID()), template);
	    }
	}

	/**
	 * Pre-loads all available templates into the cache.
	 */

	public void preload() throws ArcturusDatabaseException {
		String query = "select template_id,name,ligation_id from TEMPLATE";

		try {
		Statement stmt = conn.createStatement();

		ResultSet rs = stmt.executeQuery(query);

		while (rs.next()) {
			int id = rs.getInt(1);
			String name = rs.getString(2);
			int ligation_id = rs.getInt(3);
			createAndRegisterNewTemplate(name, id, ligation_id);
		}

		rs.close();
		stmt.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload templates", conn, this);
		}
	}

	/**
	 * If the template with the specified identifer already exists in the cache,
	 * it is returned. Otherwise, a new template is created from the information
	 * supplied and added to the cache, and this object is returned.
	 * 
	 * @param id
	 *            the identifier of the template.
	 * @param name
	 *            the name of the template.
	 * @param ligation
	 *            the ligation of the template.
	 * 
	 * @return the template with the specified identifer. This template is
	 *         returned from the cache if it exists, otherwise a new template is
	 *         created from the information supplied and added to the cache.
	 */

	public Template findOrCreateTemplate(int id, String name, Ligation ligation) {
		Template template = (Template) hashByID.get(new Integer(id));

		if (template == null) {
			template = new Template(name, id, ligation, adb);

			registerNewTemplate(template);
		}

		return template;
	}
}
