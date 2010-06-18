package uk.ac.sanger.arcturus.jdbc;

import java.io.IOException;

import javax.swing.JOptionPane;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.SQLException;

import javax.sql.DataSource;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.Vector;
import java.util.zip.DataFormatException;

import com.mysql.jdbc.jdbc2.optional.MysqlDataSource;
import oracle.jdbc.pool.OracleDataSource;

import java.util.logging.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.database.ContigProcessor;
import uk.ac.sanger.arcturus.database.ProjectLockException;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

import uk.ac.sanger.arcturus.people.Person;

import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;

import uk.ac.sanger.arcturus.pooledconnection.ConnectionPool;

import uk.ac.sanger.arcturus.projectchange.*;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;

public class ArcturusDatabaseImpl implements ArcturusDatabase {
	protected DataSource ds;
	protected String description;
	protected String name;
	protected Connection defaultConnection;

	protected ArcturusInstance instance;

	protected ConnectionPool connectionPool;

	protected Logger logger = null;

	protected ProjectChangeEventNotifier projectChangeEventNotifier = new ProjectChangeEventNotifier();

	protected String defaultDirectory = null;

	/**
	 * Creates a new ArcturusDatabase object from a DataSource, a description
	 * and a name.
	 * 
	 * @param ds
	 *            the DataSource which will be used to obtain JDBC Connection
	 *            objects.
	 * 
	 * @param description
	 *            a text description of the species which this database
	 *            contains.
	 * 
	 * @param name
	 *            the short name for this database.
	 */

	public ArcturusDatabaseImpl(DataSource ds, String description, String name,
			ArcturusInstance instance) throws ArcturusDatabaseException {
		this.ds = ds;
		this.description = description;
		this.name = name;
		this.instance = instance;

		initialise();
	}

	/**
	 * Creates a new ArcturusDatabase object from an Organism object.
	 * 
	 * @param organism
	 *            the Organism from which to create the ArcturusDatabase.
	 */

	public ArcturusDatabaseImpl(Organism organism) throws ArcturusDatabaseException {
		this.name = organism.getName();
		this.description = organism.getDescription();
		this.ds = organism.getDataSource();
		this.instance = organism.getInstance();

		initialise();
	}

	private void initialise() throws ArcturusDatabaseException {
		connectionPool = new ConnectionPool(ds);

		try {
			defaultConnection = connectionPool.getConnection(this);
		} catch (SQLException e) {
			throw new ArcturusDatabaseException(e, "Failed to obtain default connection", null, this);
		}

		createManagers();
	}

	public synchronized void closeConnectionPool() {
		if (connectionPool != null) {
			connectionPool.close();
			connectionPool = null;
		}
	}

	public synchronized DataSource getDataSource() {
		return ds;
	}

	public synchronized String getDescription() {
		return description;
	}

	public synchronized String getName() {
		return name;
	}

	public ArcturusInstance getInstance() {
		return instance;
	}

	public synchronized Connection getDefaultConnection() throws ArcturusDatabaseException {
		if (defaultConnection == null)
			try {
				defaultConnection = connectionPool.getConnection(this);
			} catch (SQLException e) {
				throw new ArcturusDatabaseException(e, "Failed to obtain default connection", null, this);
			}

		return defaultConnection;
	}

	public synchronized Connection getPooledConnection(Object owner)
			throws ArcturusDatabaseException {
		try {
			return connectionPool.getConnection(owner);
		} catch (SQLException e) {
			throw new ArcturusDatabaseException(e, "Failed to get a pooled connection", null, this);
		}
	}

	/**
	 * Creates a DataSource object which represents a connection to a MySQL
	 * database.
	 * 
	 * @param hostname
	 *            the hostname of the MySQL instance.
	 * 
	 * @param port
	 *            the port number on which the MySQL instance is listening for
	 *            TCP/IP connections.
	 * 
	 * @param database
	 *            the name of the MySQL database.
	 * 
	 * @param username
	 *            the default username.
	 * 
	 * @param password
	 *            the default password.
	 * 
	 * @return a DataSource object which can be used to establish a connection
	 *         to the MySQL database.
	 * 
	 * @throws ArcturusDatabaseException
	 *             in the event of an error.
	 */

	public synchronized static DataSource createMysqlDataSource(
			String hostname, int port, String database, String username,
			String password) throws ArcturusDatabaseException {
		MysqlDataSource mysqlds = new MysqlDataSource();

		mysqlds.setServerName(hostname);
		mysqlds.setDatabaseName(database);
		mysqlds.setPort(port);
		mysqlds.setUser(username);
		mysqlds.setPassword(password);

		return (DataSource) mysqlds;
	}

	/**
	 * Creates a DataSource object which represents a connection to a Oracle
	 * database.
	 * 
	 * @param hostname
	 *            the hostname of the Oracle instance.
	 * 
	 * @param port
	 *            the port number on which the Oracle instance is listening for
	 *            TCP/IP connections.
	 * 
	 * @param database
	 *            the name of the Oracle database.
	 * 
	 * @param username
	 *            the default username.
	 * 
	 * @param password
	 *            the default password.
	 * 
	 * @return a DataSource object which can be used to establish a connection
	 *         to the Oracle database.
	 * 
	 * @throws ArcturusDatabaseException
	 *             in the event of an error.
	 */

	public synchronized static DataSource createOracleDataSource(
			String hostname, int port, String database, String username,
			String password) throws ArcturusDatabaseException {
		OracleDataSource oracleds;
		try {
			oracleds = new OracleDataSource();
		} catch (SQLException e) {
			throw new ArcturusDatabaseException(e, "Failed to create an Oracle data source", null, null);
		}

		oracleds.setServerName(hostname);
		oracleds.setDatabaseName(database);
		oracleds.setPortNumber(port);
		oracleds.setUser(username);
		oracleds.setPassword(password);
		oracleds.setDriverType("thin");

		return (DataSource) oracleds;
	}

	/**
	 * Creates a DataSource object which represents a connection to a database.
	 * 
	 * @param hostname
	 *            the hostname of the database instance.
	 * 
	 * @param port
	 *            the port number on which the database instance is listening
	 *            for TCP/IP connections.
	 * 
	 * @param database
	 *            the name of the database.
	 * 
	 * @param username
	 *            the default username.
	 * 
	 * @param password
	 *            the default password.
	 * 
	 * @param type
	 *            specifies the type of database server. It should be one of
	 *            MYSQL or ORACLE.
	 * 
	 * @return a DataSource object which can be used to establish a connection
	 *         to the database.
	 * 
	 * @throws ArcturusDatabaseException
	 *             in the event of an error.
	 */

	public synchronized static DataSource createDataSource(String hostname,
			int port, String database, String username, String password,
			int type) throws ArcturusDatabaseException {
		switch (type) {
			case MYSQL:
				return createMysqlDataSource(hostname, port, database,
						username, password);

			case ORACLE:
				return createOracleDataSource(hostname, port, database,
						username, password);

			default:
				return null;
		}
	}

	public synchronized void setLogger(Logger logger) {
		this.logger = logger;
	}

	public synchronized Logger getLogger() {
		return logger;
	}

	/*
	 * This section of code is concerned with the manager objects which provide
	 * services to the ArcturusDatabase.
	 */

	protected CloneManager cloneManager;
	protected LigationManager ligationManager;
	protected TemplateManager templateManager;
	protected ReadManager readManager;
	protected SequenceManager sequenceManager;
	protected ContigManager contigManager;
	protected ProjectManager projectManager;
	protected AssemblyManager assemblyManager;
	protected UserManager userManager;
	protected MappingManager mappingManager;
	protected LinkManager linkManager;
	protected ContigTransferRequestManager contigTransferRequestManager;
	
	protected Set<AbstractManager> managers = new HashSet<AbstractManager>();
	
	protected void addManager(AbstractManager manager) {
		managers.add(manager);
	}

	private void createManagers() throws ArcturusDatabaseException {
		cloneManager = new CloneManager(this);
		
		ligationManager = new LigationManager(this);
		
		templateManager = new TemplateManager(this);
		
		readManager = new ReadManager(this);
		
		sequenceManager = new SequenceManager(this);
		
		contigManager = new ContigManager(this);
		
		projectManager = new ProjectManager(this);
		
		assemblyManager = new AssemblyManager(this);
		
		userManager = new UserManager(this);
		
		contigTransferRequestManager = new ContigTransferRequestManager(this);
		
		linkManager = new LinkManager(this);
		
		mappingManager = new MappingManager(this);
	}

	public synchronized CloneManager getCloneManager() {
		return cloneManager;
	}

	public synchronized Clone getCloneByName(String name) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getCloneByName(" + name + ")");

		return cloneManager.getCloneByName(name);
	}

	public synchronized Clone getCloneByID(int id) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getCloneByID(" + id + ")");

		return cloneManager.getCloneByID(id);
	}
	
	public synchronized Clone findOrCreateClone(Clone clone) throws ArcturusDatabaseException {
		return cloneManager.findOrCreateClone(clone);
	}
	
	public synchronized Clone putClone(Clone clone) throws ArcturusDatabaseException {
		return cloneManager.putClone(clone);
	}

	public synchronized Ligation getLigationByName(String name)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getLigationByName(" + name + ")");

		return ligationManager.getLigationByName(name);
	}

	public synchronized Ligation getLigationByID(int id) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getLigationByID(" + id + ")");

		return ligationManager.getLigationByID(id);
	}
	
	public Ligation findOrCreateLigation(Ligation ligation)
		throws ArcturusDatabaseException {
		return ligationManager.findOrCreateLigation(ligation);
	}
	
	public Ligation putLigation(Ligation ligation)
		throws ArcturusDatabaseException {
		return ligationManager.putLigation(ligation);
	}

	public synchronized Template getTemplateByName(String name)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByName(" + name + ")");

		return templateManager.getTemplateByName(name);
	}

	public synchronized Template getTemplateByName(String name, boolean autoload)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByName(" + name + ", " + autoload + ")");

		return templateManager.getTemplateByName(name, autoload);
	}

	public synchronized Template getTemplateByID(int id) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByID(" + id + ")");

		return templateManager.getTemplateByID(id);
	}

	public synchronized Template getTemplateByID(int id, boolean autoload)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByID(" + id + ", " + autoload + ")");

		return templateManager.getTemplateByID(id, autoload);
	}

	void registerNewTemplate(Template template, int template_id) {
		templateManager.registerNewTemplate(template, template_id);
	}

	public synchronized Template findOrCreateTemplate(Template template) throws ArcturusDatabaseException {
		return templateManager.findOrCreateTemplate(template);
	}

	public synchronized Template putTemplate(Template template) throws ArcturusDatabaseException {
		return templateManager.putTemplate(template);
	}

	public synchronized Read getReadByName(String name) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByName(" + name + ")");

		return readManager.getReadByName(name);
	}

	public synchronized Read getReadByName(String name, boolean autoload)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByName(" + name + ", " + autoload + ")");

		return readManager.getReadByName(name, autoload);
	}

	public synchronized Read getReadByNameAndFlags(String name, int flags)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByNameAndFlags(" + name + ", " + flags + ")");

		return readManager.getReadByNameAndFlags(name, flags);
	}

	public synchronized Read getReadByID(int id) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByID(" + id + ")");

		return readManager.getReadByID(id);
	}

	public synchronized Read getReadByID(int id, boolean autoload)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByID(" + id + ", " + autoload + ")");

		return readManager.getReadByID(id, autoload);
	}

	public synchronized int loadReadsByTemplate(int template_id)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("loadReadsByTemplate(" + template_id + ")");

		return readManager.loadReadsByTemplate(template_id);
	}

	void registerNewRead(Read read) {
		readManager.cacheNewRead(read);
	}

	public synchronized Read findOrCreateRead(Read read) throws ArcturusDatabaseException {
		return readManager.findOrCreateRead(read);
	}

	public synchronized Read putRead(Read read) throws ArcturusDatabaseException {
		return readManager.findOrCreateRead(read);
	}

	public synchronized int[] getUnassembledReadIDList() throws ArcturusDatabaseException {
		return readManager.getUnassembledReadIDList();
	}
	
	public String getBaseCallerByID(int basecaller_id) {
		return readManager.getBaseCallerByID(basecaller_id);
	}
	
	public String getReadStatusByID(int status_id) {
		return readManager.getReadStatusByID(status_id);
	}

	public synchronized Sequence getSequenceByReadID(int readid)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getSequenceByReadID(" + readid + ")");

		return sequenceManager.getSequenceByReadID(readid);
	}

	public synchronized Sequence getSequenceByReadID(int readid,
			boolean autoload) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger
					.info("getSequenceByReadID(" + readid + ", " + autoload
							+ ")");

		return sequenceManager.getSequenceByReadID(readid, autoload);
	}

	public synchronized Sequence getFullSequenceByReadID(int readid)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceByReadID(" + readid + ")");

		return sequenceManager.getFullSequenceByReadID(readid);
	}

	public synchronized Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceByReadID(" + readid + ", " + autoload
					+ ")");

		return sequenceManager.getFullSequenceByReadID(readid, autoload);
	}

	public synchronized Sequence getSequenceBySequenceID(int seqid)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getSequenceBySequenceID(seqid);
	}

	public synchronized Sequence getSequenceBySequenceID(int seqid,
			boolean autoload) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getSequenceBySequenceID(" + seqid + ", " + autoload
					+ ")");

		return sequenceManager.getSequenceBySequenceID(seqid, autoload);
	}

	public synchronized Sequence getFullSequenceBySequenceID(int seqid)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid);
	}

	public synchronized Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceBySequenceID(" + seqid + ", "
					+ autoload + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid, autoload);
	}

	public synchronized void getDNAAndQualityForSequence(Sequence sequence)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getDNAAndQualityForSequence(seqid=" + sequence.getID()
					+ ")");

		sequenceManager.getDNAAndQualityForSequence(sequence);
	}

	void registerNewSequence(Sequence sequence) {
		sequenceManager.cacheNewSequence(sequence);
	}

	byte[] decodeCompressedData(byte[] compressed, int length) throws DataFormatException {
		return sequenceManager.decodeCompressedData(compressed, length);
	}

	public synchronized Sequence findOrCreateSequence(Sequence sequence) throws ArcturusDatabaseException {
		return sequenceManager.findOrCreateSequence(sequence);
	}
	public synchronized Sequence findSequenceByReadnameFlagsAndHash(Sequence sequence)
		throws ArcturusDatabaseException {
		return sequenceManager.findSequenceByReadnameFlagsAndHash(sequence);
	}
	
	public Sequence putSequence(Sequence sequence) throws ArcturusDatabaseException {
		return sequenceManager.putSequence(sequence);
	}

	public synchronized Contig getContigByID(int id, int options)
			throws ArcturusDatabaseException {
		return contigManager.getContigByID(id, options);
	}

	public synchronized Contig getContigByID(int id) throws ArcturusDatabaseException {
		return contigManager.getContigByID(id);
	}

	public synchronized Contig getContigByReadName(String readname, int options)
			throws ArcturusDatabaseException {
		return contigManager.getContigByReadName(readname, options);
	}

	public synchronized Contig getContigByReadName(String readname)
			throws ArcturusDatabaseException {
		return contigManager.getContigByReadName(readname);
	}

	public synchronized void updateContig(Contig contig, int options)
			throws ArcturusDatabaseException {
		contigManager.updateContig(contig, options);
	}

	public synchronized boolean isCurrentContig(int contigid)
			throws ArcturusDatabaseException {
		return contigManager.isCurrentContig(contigid);
	}

	public synchronized int[] getCurrentContigIDList() throws ArcturusDatabaseException {
		return contigManager.getCurrentContigIDList();
	}

	public synchronized int countCurrentContigs(int minlen) throws ArcturusDatabaseException {
		return contigManager.countCurrentContigs(minlen);
	}

	public synchronized int countCurrentContigs() throws ArcturusDatabaseException {
		return contigManager.countCurrentContigs(0);
	}

	public synchronized int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws ArcturusDatabaseException {
		return contigManager.processCurrentContigs(options, minlen, processor);
	}

	public synchronized int processCurrentContigs(int options,
			ContigProcessor processor) throws ArcturusDatabaseException {
		return contigManager.processCurrentContigs(options, 0, processor);
	}

	public synchronized Set getCurrentContigs(int options, int minlen)
			throws ArcturusDatabaseException {
		return contigManager.getCurrentContigs(options, minlen);
	}

	public synchronized Set getCurrentContigs(int options) throws ArcturusDatabaseException {
		return contigManager.getCurrentContigs(options, 0);
	}

	public synchronized int countContigsByProject(int project_id, int minlen)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("countContigsByProject(" + project_id + ", " + minlen
					+ ")");

		return contigManager.countContigsByProject(project_id, minlen);
	}

	public synchronized int countContigsByProject(int project_id)
			throws ArcturusDatabaseException {
		return countContigsByProject(project_id, 0);
	}

	public synchronized int processContigsByProject(int project_id,
			int options, int minlen, ContigProcessor processor)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("processContigsByProject(" + project_id + ", options="
					+ options + ", minlen=" + minlen + ")");

		return contigManager.processContigsByProject(project_id, options,
				minlen, processor);
	}

	public synchronized int processContigsByProject(int project_id,
			int options, ContigProcessor processor) throws ArcturusDatabaseException {
		return processContigsByProject(project_id, options, 0, processor);
	}

	public synchronized Set<Contig> getContigsByProject(int project_id,
			int options, int minlen) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getContigsByProject(" + project_id + ", options="
					+ options + ", minlen=" + minlen + ")");

		return contigManager.getContigsByProject(project_id, options, minlen);
	}

	public synchronized Set getContigsByProject(int project_id, int options)
			throws ArcturusDatabaseException {
		return getContigsByProject(project_id, options, 0);
	}

	public synchronized void addContigManagerEventListener(
			ManagerEventListener listener) {
		contigManager.addContigManagerEventListener(listener);
	}

	public synchronized void removeContigManagerEventListener(
			ManagerEventListener listener) {
		contigManager.removeContigManagerEventListener(listener);
	}

	public synchronized void clearContigCache() {
		contigManager.clearCache();
	}
	
	public synchronized Set<Contig> getChildContigs(Contig parent) throws ArcturusDatabaseException {
		return contigManager.getChildContigs(parent);
	}

	public synchronized Project getProjectByID(int id) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getProjectByID(" + id + ")");

		return projectManager.getProjectByID(id);
	}

	public synchronized Project getProjectByID(int id, boolean autoload)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger
					.info("getProjectByID(" + id + ", autoload=" + autoload
							+ ")");

		return projectManager.getProjectByID(id, true);
	}

	public synchronized Project getProjectByName(Assembly assembly, String name)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getProjectByName(assembly=" + assembly.getName()
					+ ", name=" + name + ")");

		return projectManager.getProjectByName(assembly, name);
	}

	public synchronized Set<Project> getAllProjects() throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAllProjects");

		return projectManager.getAllProjects();
	}

	public synchronized Set<Project> getProjectsForOwner(Person owner)
			throws ArcturusDatabaseException {
		return projectManager.getProjectsForOwner(owner);
	}

	public synchronized Set<Project> getBinProjects()
			throws ArcturusDatabaseException {
		return projectManager.getBinProjects();
	}

	public synchronized void refreshProject(Project project)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshProject(" + project + ")");

		projectManager.refreshProject(project);
	}

	public synchronized void refreshAllProject() throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshAllProjects");

		projectManager.refreshAllProjects();
	}

	public synchronized void setAssemblyForProject(Project project,
			Assembly assembly) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("setAssemblyForProject(" + project + ", " + assembly
					+ ")");

		projectManager.setAssemblyForProject(project, assembly);
	}

	public synchronized void getProjectSummary(Project project, int minlen,
			int minreads, ProjectSummary summary) throws ArcturusDatabaseException {
		projectManager.getProjectSummary(project, minlen, minreads, summary);
	}

	public synchronized ProjectSummary getProjectSummary(Project project,
			int minlen, int minreads) throws ArcturusDatabaseException {
		return projectManager.getProjectSummary(project, minlen, minreads);
	}

	public synchronized void getProjectSummary(Project project, int minlen,
			ProjectSummary summary) throws ArcturusDatabaseException {
		projectManager.getProjectSummary(project, minlen, 0, summary);
	}

	public synchronized void getProjectSummary(Project project,
			ProjectSummary summary) throws ArcturusDatabaseException {
		projectManager.getProjectSummary(project, summary);
	}

	public synchronized ProjectSummary getProjectSummary(Project project,
			int minlen) throws ArcturusDatabaseException {
		return projectManager.getProjectSummary(project, minlen);
	}

	public synchronized ProjectSummary getProjectSummary(Project project)
			throws ArcturusDatabaseException {
		return projectManager.getProjectSummary(project);
	}

	public synchronized Map getProjectSummary(int minlen, int minreads)
			throws ArcturusDatabaseException {
		return projectManager.getProjectSummary(minlen, minreads);
	}

	public synchronized Map getProjectSummary(int minlen) throws ArcturusDatabaseException {
		return projectManager.getProjectSummary(minlen);
	}

	public synchronized Map getProjectSummary() throws ArcturusDatabaseException {
		return projectManager.getProjectSummary();
	}

	public synchronized boolean canUserUnlockProject(Project project,
			Person user) throws ArcturusDatabaseException {
		return projectManager.canUserUnlockProject(project, user);
	}

	public synchronized boolean canUserLockProjectForSelf(Project project, Person user)
			throws ArcturusDatabaseException {
		return projectManager.canUserLockProjectForSelf(project, user);
	}

	public synchronized boolean canUserLockProject(Project project, Person user)
			throws ArcturusDatabaseException {
		return projectManager.canUserLockProject(project, user);
	}

	public synchronized boolean canUserLockProjectForOwner(Project project,
			Person user) throws ArcturusDatabaseException {
		return projectManager.canUserLockProjectForOwner(project, user);
	}

	public synchronized boolean unlockProject(Project project)
			throws ArcturusDatabaseException, ProjectLockException {
		return projectManager.unlockProject(project);
	}

	public synchronized boolean lockProject(Project project)
			throws ArcturusDatabaseException, ProjectLockException {
		return projectManager.lockProject(project);
	}

	public synchronized boolean unlockProjectForExport(Project project)
			throws ArcturusDatabaseException, ProjectLockException {
		return projectManager.unlockProjectForExport(project);
	}

	public synchronized boolean lockProjectForExport(Project project)
			throws ArcturusDatabaseException, ProjectLockException {
		return projectManager.lockProjectForExport(project);
	}

	public synchronized boolean lockProjectForOwner(Project project)
			throws ArcturusDatabaseException, ProjectLockException {
		return projectManager.lockProjectForOwner(project);
	}

	public synchronized boolean setProjectLockOwner(Project project,
			Person person) throws ArcturusDatabaseException, ProjectLockException {
		return (person == null || person.isNobody()) ?
				projectManager.unlockProject(project) :
				projectManager.setProjectLockOwner(project, person);
	}

	public synchronized void setProjectOwner(Project project, Person person)
			throws ArcturusDatabaseException {
		projectManager.setProjectOwner(project, person);
	}

	public synchronized boolean createNewProject(Assembly assembly,
			String name, Person owner, String directory) throws ArcturusDatabaseException, IOException {
		return projectManager
				.createNewProject(assembly, name, owner, directory);
	}

	public boolean canUserChangeProjectStatus(Project project, Person user)
			throws ArcturusDatabaseException {
		return projectManager.canUserChangeProjectStatus(project, user);
	}

	public boolean canUserChangeProjectStatus(Project project)
			throws ArcturusDatabaseException {
		return projectManager.canUserChangeProjectStatus(project);
	}

	public boolean changeProjectStatus(Project project, int status)
			throws ArcturusDatabaseException {
		return projectManager.changeProjectStatus(project, status);
	}

	public boolean retireProject(Project project) throws ArcturusDatabaseException {
		return projectManager.retireProject(project);
	}

	public Project getBinForProject(Project project) throws ArcturusDatabaseException {
		return projectManager.getBinForProject(project);
	}

	public synchronized Assembly getAssemblyByID(int id) throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAssemblyByID(" + id + ")");

		return assemblyManager.getAssemblyByID(id);
	}

	public synchronized Assembly getAssemblyByID(int id, boolean autoload)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAssemblyByID(" + id + ", autoload=" + autoload
					+ ")");

		return assemblyManager.getAssemblyByID(id, true);
	}

	public synchronized Assembly getAssemblyByName(String name)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAssemblyByName(" + name + ")");

		return assemblyManager.getAssemblyByName(name);
	}

	public synchronized Assembly[] getAllAssemblies() throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAllAssemblies");

		return assemblyManager.getAllAssemblies();
	}

	public synchronized void refreshAssembly(Assembly assembly)
			throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshAssembly(" + assembly + ")");

		assemblyManager.refreshAssembly(assembly);
	}

	public synchronized void refreshAllAssemblies() throws ArcturusDatabaseException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshAllAssemblies");

		assemblyManager.refreshAllAssemblies();
	}

	public synchronized boolean hasFullPrivileges(Person person) {
		return userManager.hasFullPrivileges(person);
	}

	public synchronized boolean hasFullPrivileges() throws ArcturusDatabaseException {
		return userManager.hasFullPrivileges();
	}

	public synchronized boolean isCoordinator(Person person) throws ArcturusDatabaseException {
		return userManager.isCoordinator(person);
	}

	public synchronized boolean isCoordinator() throws ArcturusDatabaseException {
		return userManager.isCoordinator();
	}

	public synchronized Person[] getAllUsers(boolean includeNobody)
			throws ArcturusDatabaseException {
		return userManager.getAllUsers(includeNobody);
	}

	public synchronized Person[] getAllUsers() throws ArcturusDatabaseException {
		return userManager.getAllUsers(false);
	}

	public Person findUser(String username) throws ArcturusDatabaseException {
		return userManager.findUser(username);
	}
	
	public Person findMe() throws ArcturusDatabaseException {
		return userManager.findMe();
	}
	
	public boolean isMe(Person person) {
		return userManager.isMe(person);
	}
	
	public synchronized ContigTransferRequestManager getContigTransferRequestManager() {
		return contigTransferRequestManager;
	}

	public synchronized ContigTransferRequest[] getContigTransferRequestsByUser(
			Person user, int mode) throws ArcturusDatabaseException {
		return contigTransferRequestManager.getContigTransferRequestsByUser(
				user, mode);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			Person requester, int contigId, int toProjectId)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		return contigTransferRequestManager.createContigTransferRequest(
				requester, contigId, toProjectId);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			int contigId, int toProjectId)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		return contigTransferRequestManager.createContigTransferRequest(
				contigId, toProjectId);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			Person requester, Contig contig, Project project)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		return contigTransferRequestManager.createContigTransferRequest(
				requester, contig, project);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			Contig contig, Project project)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		return contigTransferRequestManager.createContigTransferRequest(contig,
				project);
	}

	public synchronized void reviewContigTransferRequest(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		contigTransferRequestManager.reviewContigTransferRequest(request,
				reviewer, newStatus);
	}

	public synchronized void reviewContigTransferRequest(int requestId,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		contigTransferRequestManager.reviewContigTransferRequest(requestId,
				reviewer, newStatus);
	}

	public synchronized void reviewContigTransferRequest(int requestId,
			int newStatus) throws ContigTransferRequestException, ArcturusDatabaseException {
		contigTransferRequestManager.reviewContigTransferRequest(requestId,
				newStatus);
	}

	public synchronized void executeContigTransferRequest(
			ContigTransferRequest request, Person reviewer,
			boolean notifyListeners) throws ContigTransferRequestException,
			ArcturusDatabaseException {
		contigTransferRequestManager.executeContigTransferRequest(request,
				reviewer, notifyListeners);
	}

	public synchronized void executeContigTransferRequest(int requestId,
			Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, ArcturusDatabaseException {
		contigTransferRequestManager.executeContigTransferRequest(requestId,
				reviewer, notifyListeners);
	}

	public synchronized void executeContigTransferRequest(int requestId,
			boolean notifyListeners) throws ContigTransferRequestException,
			ArcturusDatabaseException {
		contigTransferRequestManager.executeContigTransferRequest(requestId,
				notifyListeners);
	}

	public synchronized void setDebugging(boolean debugging) {
		contigTransferRequestManager.setDebugging(debugging);
	}

	public synchronized boolean canCancelRequest(ContigTransferRequest request,
			Person person) throws ArcturusDatabaseException {
		return contigTransferRequestManager.canCancelRequest(request, person);
	}

	public synchronized boolean canRefuseRequest(ContigTransferRequest request,
			Person person) throws ArcturusDatabaseException {
		return contigTransferRequestManager.canRefuseRequest(request, person);
	}

	public synchronized boolean canApproveRequest(
			ContigTransferRequest request, Person person) throws ArcturusDatabaseException {
		return contigTransferRequestManager.canApproveRequest(request, person);
	}

	public synchronized boolean canExecuteRequest(
			ContigTransferRequest request, Person person) throws ArcturusDatabaseException {
		return contigTransferRequestManager.canExecuteRequest(request, person);
	}

	public synchronized void moveContigs(Project fromProject, Project toProject)
			throws ArcturusDatabaseException {
		contigTransferRequestManager.moveContigs(fromProject, toProject);
	}

	/**
	 * Returns a text representation of this object.
	 * 
	 * @return a text representation of this object.
	 */

	public synchronized String toString() {
		String text = "ArcturusDatabase[name=" + name;

		if (description != null)
			text += ", description=" + description;

		text += "]";

		return text;
	}

	/*
	 * ******************************************************************************
	 */

	public void addProjectChangeEventListener(Project project,
			ProjectChangeEventListener listener) {
		projectChangeEventNotifier.addProjectChangeEventListener(project,
				listener);
	}

	public void addProjectChangeEventListener(
			ProjectChangeEventListener listener) {
		projectChangeEventNotifier.addProjectChangeEventListener(listener);
	}

	public void removeProjectChangeEventListener(
			ProjectChangeEventListener listener) {
		projectChangeEventNotifier.removeProjectChangeEventListener(listener);
	}

	public void notifyProjectChangeEventListeners(ProjectChangeEvent event,
			Class listenerClass) {
		projectChangeEventNotifier.notifyProjectChangeEventListeners(event,
				listenerClass);
	}

	/*
	 * ******************************************************************************
	 */
	
	public String[] getAllDirectories() throws ArcturusDatabaseException {
		String query = "select distinct directory from PROJECT where directory is not null" +
			" order by directory asc";

		try {
			Vector<String> dirs = new Vector<String>();
			
			Statement stmt = defaultConnection.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				String dirname = rs.getString(1);
			
				dirs.add(dirname);
			}

			rs.close();
			stmt.close();
			
			String[] dirArray = dirs.toArray(new String[0]);
			
			return dirArray;
		} catch (SQLException e) {
			throw new ArcturusDatabaseException(e, "Failed to get all project directories", defaultConnection, this);
		}
	}

	public boolean isCacheing(int type) {
		AbstractManager manager = getManagerForType(type);
		
		return manager == null ? false : manager.isCacheing();
	}

	public void setCacheing(int type, boolean cacheing) {
		AbstractManager manager = getManagerForType(type);

		if (manager != null)
			manager.setCacheing(cacheing);
	}
	
	public void clearCache(int type) {
		AbstractManager manager = getManagerForType(type);

		if (manager != null)
			manager.clearCache();	
	}

	public void preload(int type) throws ArcturusDatabaseException {
		AbstractManager manager = getManagerForType(type);

		if (manager != null)
			manager.preload();			
	}
	
	public AbstractManager getManager(int type) {
		return getManagerForType(type);
	}

	private AbstractManager getManagerForType(int type) {
		switch (type) {
			case READ:
				return readManager;
				
			case SEQUENCE:
				return sequenceManager;
				
			case CONTIG:
				return contigManager;
				
			case TEMPLATE:
				return templateManager;
				
			case LIGATION:
				return ligationManager;
				
			case CLONE:
				return cloneManager;
				
			case ASSEMBLY:
				return assemblyManager;
				
			case PROJECT:
				return projectManager;
				
			case MAPPING:
				return mappingManager;
				
			case LINK:
				return linkManager;
		}
		
		return null;
	}

	/*
	 * ******************************************************************************
	 */

	/**
	 * Handle an SQLException thrown within the code of an auxiliary object such as a manager.
	 * 
	 * @param e the SQLException which was thrown in the auxiliary object.
	 * @param message an explanatory message provided by the method in which the exception was thrown.
	 * @param conn the Connection object associated with the exception.
	 * @source the auxiliary object whose method caused the exception to be thrown. 
	 *
	 * @throws ArcturusDatabaseException if it is not possible to recover from the underlying SQLException.
	 */
	
	public void handleSQLException(SQLException e, String message,
			Connection conn, Object source) throws ArcturusDatabaseException {
		// Handle a non-transient communications problem thrown by one of the client manager
		// objects.		
		if (isClientManager(source) && isNonTransientCommunicationProblem(e)) {
			resetDefaultConnection();
		} else
			throw new ArcturusDatabaseException(e, message, conn, this);
	}

	private void resetDefaultConnection() {
		if (defaultConnection != null)
			try {
				defaultConnection.close();
			} catch (SQLException e) {
				Arcturus.logSevere("Failed to close the default connection whilst resetting it", e);
			}

		defaultConnection = null;
		
		JOptionPane.showMessageDialog(null,
				"The application has lost its connection to the database.\nIt will try to re-connect.\nPlease refresh your display by pressing F5.",
				"Trying to re-connect to the database", JOptionPane.WARNING_MESSAGE);
		
		try {
			defaultConnection = connectionPool.getConnection(this);
		} catch (SQLException e) {
			Arcturus.logSevere("Failed to get a connection from the pool.  This is a serious error.", e);
		}
		
		if (defaultConnection != null) {
			for (AbstractManager manager : managers) {
				try {
					manager.setConnection(defaultConnection);
				} catch (SQLException e) {
					Arcturus.logSevere("Failed to set the database connection for the " +
							manager.getClass().getName() + 
							".  This is a serious error.", e);
					return;
				}
			}
		}
	}

	private boolean isClientManager(Object source) {
		return managers.contains(source);
	}

	private boolean isNonTransientCommunicationProblem(SQLException e) {
		if (e instanceof com.mysql.jdbc.CommunicationsException)
			return true;
		
		if (e instanceof com.mysql.jdbc.exceptions.jdbc4.MySQLNonTransientConnectionException)
			return true;
		
		String sqlState = e.getSQLState();
		
		if (sqlState.equalsIgnoreCase("08003") || sqlState.equalsIgnoreCase("08S01"))
			return true;
		
		return false;
	}
	
/**
 * preloading readname - contig hash
 */
	
	public synchronized void prepareToLoadProject(Project project) throws ArcturusDatabaseException {
        if (linkManager == null)
        	linkManager = new LinkManager(this);
        linkManager.preload(project);
	}
	
	public synchronized void prepareToLoadAllProjects() throws ArcturusDatabaseException {
        if (linkManager == null)
        	linkManager = new LinkManager(this);
        linkManager.preload();
	}

	public synchronized int getCurrentContigIDForRead(Read read) throws ArcturusDatabaseException {
        if (linkManager == null)
        	return 0;
        return linkManager.getCurrentContigIDForRead(read);
	}
	
	/**
	 * pre-loading canonical mapping hash
	 */
	
	public synchronized void preloadCanonicalMappings() throws ArcturusDatabaseException {
        mappingManager.preload();
	}
	
	public synchronized CanonicalMapping findOrCreateCanonicalMapping(CanonicalMapping cm) throws ArcturusDatabaseException {
        return mappingManager.findOrCreateCanonicalMapping(cm);			
	}
	
	/**
	 * loading a contig and its mappings
	 */
	
	public synchronized void putContig(Contig contig) throws ArcturusDatabaseException {
		contigManager.putContig(contig);
	}
	
	public synchronized boolean putSequenceToContigMappings(Contig contig) throws ArcturusDatabaseException {
		return mappingManager.putSequenceToContigMappings(contig);
	}
	
	public synchronized boolean putContigToParentMappings(Contig contig) throws ArcturusDatabaseException {
		return mappingManager.putContigToParentMappings(contig);
	}
}
