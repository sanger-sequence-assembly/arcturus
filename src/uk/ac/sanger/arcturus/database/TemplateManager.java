package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.data.Ligation;

import java.sql.*;
import java.util.*;

/**
 * This class manages Template objects.
 */

public class TemplateManager extends AbstractManager {
	private ArcturusDatabase adb;
	private Connection conn;
	private HashMap hashByID, hashByName;
	private PreparedStatement pstmtByID, pstmtByName;

	/**
	 * Creates a new TemplateManager to provide template management services to
	 * an ArcturusDatabase object.
	 * 
	 * @param adb
	 *            the ArcturusDatabase object to which this manager belongs.
	 */

	public TemplateManager(ArcturusDatabase adb) throws SQLException {
		this.adb = adb;

		conn = adb.getConnection();

		String query = "select name,ligation_id from TEMPLATE where template_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select template_id,ligation_id from TEMPLATE where name = ?";
		pstmtByName = conn.prepareStatement(query);

		hashByID = new HashMap();
		hashByName = new HashMap();
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

	public Template getTemplateByName(String name) throws SQLException {
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
			throws SQLException {
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

	public Template getTemplateByID(int id) throws SQLException {
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
			throws SQLException {
		Object obj = hashByID.get(new Integer(id));

		return (obj == null && autoload) ? loadTemplateByID(id)
				: (Template) obj;
	}

	private Template loadTemplateByName(String name) throws SQLException {
		pstmtByName.setString(1, name);
		ResultSet rs = pstmtByName.executeQuery();

		Template template = null;

		if (rs.next()) {
			int id = rs.getInt(1);
			int ligation_id = rs.getInt(2);
			template = createAndRegisterNewTemplate(name, id, ligation_id);
		}

		return template;
	}

	private Template loadTemplateByID(int id) throws SQLException {
		pstmtByID.setInt(1, id);
		ResultSet rs = pstmtByID.executeQuery();

		Template template = null;

		if (rs.next()) {
			String name = rs.getString(1);
			int ligation_id = rs.getInt(2);
			template = createAndRegisterNewTemplate(name, id, ligation_id);
		}

		return template;
	}

	private Template createAndRegisterNewTemplate(String name, int id,
			int ligation_id) throws SQLException {
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

	public void preloadAllTemplates() throws SQLException {
		String query = "select template_id,name,ligation_id from TEMPLATE";

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
