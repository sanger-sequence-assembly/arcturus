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
	private PreparedStatement pstmtByID, pstmtByName, pstmtInsertNewTemplate;
	
	private static final String GET_TEMPLATE_BY_ID =
		"select name,ligation_id from TEMPLATE where template_id = ?";
	
	private static final String GET_TEMPLATE_BY_NAME =
		"select template_id,ligation_id from TEMPLATE where name = ?";
	
	private static final String PUT_TEMPLATE =
		"insert into TEMPLATE (name,ligation_id) VALUES (?,?)";

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
		pstmtByID = prepareStatement(GET_TEMPLATE_BY_ID);

		pstmtByName = prepareStatement(GET_TEMPLATE_BY_NAME);
		
		pstmtInsertNewTemplate = prepareStatement(PUT_TEMPLATE, Statement.RETURN_GENERATED_KEYS);
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

	protected Template createAndRegisterNewTemplate(String name, int id,
			int ligation_id) throws ArcturusDatabaseException {
		Ligation ligation = adb.getLigationByID(ligation_id);

		Template template = new Template(name, id, ligation, adb);

		registerNewTemplate(template, id);

		return template;
	}

	Template registerNewTemplate(Template template, int id) {
		template.setID(id);
		template.setArcturusDatabase(adb);
		
	    if (cacheing) {
	    	hashByName.put(template.getName(), template);
	    	hashByID.put(new Integer(template.getID()), template);
	    }
	    
	    return template;
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
	 * supplied, stored in the database and added to the cache, and this object
	 * is returned.
	 * 
	 * @param name
	 *            the name of the template.
	 * @param ligation
	 *            the ligation of the template.
	 * 
	 * @return the template with the specified identifer. This template is
	 *         returned from the cache if it exists, otherwise a new template is
	 *         created from the information supplied, stored in the database,
	 *         and added to the cache.
	 */

	public Template findOrCreateTemplate(Template template)
	 	throws ArcturusDatabaseException {
		if (template == null)
			throw new ArcturusDatabaseException("Cannot find/create a null template");
		
		if (template.getName() == null)
			throw new ArcturusDatabaseException("Cannot find/create a template with no name");
	
		String templateName = template.getName();

		Template cachedTemplate = getTemplateByName(templateName);
		
		if (cachedTemplate != null)
			return cachedTemplate;
		
		return putTemplate(template);
	}
	
	public Template putTemplate(Template template) throws ArcturusDatabaseException {
		if (template == null)
			throw new ArcturusDatabaseException("Cannot put a null template");
		
		if (template.getName() == null)
			throw new ArcturusDatabaseException("Cannot put a template with no name");
	
		String templateName = template.getName();

		try {
			Ligation ligation = template.getLigation();
			
			if (ligation != null)
				ligation = adb.findOrCreateLigation(ligation);
			
			int ligation_id = (ligation == null) ? 0 : ligation.getID();
			
			pstmtInsertNewTemplate.setString(1, templateName);
			pstmtInsertNewTemplate.setInt(2, ligation_id);
			
			int rc = pstmtInsertNewTemplate.executeUpdate();
			
			if (rc == 1) {
				ResultSet rs = pstmtInsertNewTemplate.getGeneratedKeys();
				
				int template_id = rs.next() ? rs.getInt(1) : -1;
				
				rs.close();
				
				return registerNewTemplate(template, template_id);
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find or create template by name=" + templateName +
					"\"", conn, this);
		}

		return null;
	}
}
