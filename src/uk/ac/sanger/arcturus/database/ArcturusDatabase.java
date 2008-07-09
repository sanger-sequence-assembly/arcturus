package uk.ac.sanger.arcturus.database;

import java.io.IOException;
import java.sql.*;

import javax.sql.*;

import java.util.Map;
import java.util.Set;
import java.util.zip.DataFormatException;

import com.mysql.jdbc.jdbc2.optional.MysqlDataSource;
import oracle.jdbc.pool.OracleDataSource;

import java.util.logging.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

import uk.ac.sanger.arcturus.people.Person;

import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;

import uk.ac.sanger.arcturus.pooledconnection.ConnectionPool;

import uk.ac.sanger.arcturus.projectchange.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.Arcturus;

public class ArcturusDatabase {
	public static final int MYSQL = 1;
	public static final int ORACLE = 2;

	public static final int CONTIG_BASIC_DATA = 1 << 0;
	public static final int CONTIG_MAPPINGS_READS_AND_TEMPLATES = 1 << 1;
	public static final int CONTIG_SEQUENCE_DNA_AND_QUALITY = 1 << 2;
	public static final int CONTIG_CONSENSUS = 1 << 3;
	public static final int CONTIG_SEQUENCE_AUXILIARY_DATA = 1 << 4;
	public static final int CONTIG_MAPPING_SEGMENTS = 1 << 5;
	public static final int CONTIG_TAGS = 1 << 6;

	public static final int CONTIG_TO_CALCULATE_CONSENSUS = CONTIG_BASIC_DATA
			| CONTIG_MAPPINGS_READS_AND_TEMPLATES
			| CONTIG_SEQUENCE_DNA_AND_QUALITY | CONTIG_MAPPING_SEGMENTS;

	public static final int CONTIG_TO_GENERATE_CAF = CONTIG_BASIC_DATA
			| CONTIG_MAPPINGS_READS_AND_TEMPLATES
			| CONTIG_SEQUENCE_DNA_AND_QUALITY | CONTIG_CONSENSUS
			| CONTIG_SEQUENCE_AUXILIARY_DATA | CONTIG_MAPPING_SEGMENTS
			| CONTIG_TAGS;

	public static final int CONTIG_TO_DISPLAY_SCAFFOLDS = CONTIG_BASIC_DATA
			| CONTIG_MAPPINGS_READS_AND_TEMPLATES | CONTIG_TAGS;

	public static final int CONTIG_TO_DISPLAY_FAMILY_TREE = CONTIG_BASIC_DATA
			| CONTIG_TAGS;

	public static final int CONTIG_MAPPING_RELATED_DATA = CONTIG_MAPPINGS_READS_AND_TEMPLATES
			| CONTIG_SEQUENCE_DNA_AND_QUALITY
			| CONTIG_SEQUENCE_AUXILIARY_DATA
			| CONTIG_MAPPING_SEGMENTS;

	public static final int USER_IS_REQUESTER = 1;
	public static final int USER_IS_CONTIG_OWNER = 2;
	public static final int USER_IS_ADMINISTRATOR = 3;

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

	public ArcturusDatabase(DataSource ds, String description, String name,
			ArcturusInstance instance) throws SQLException {
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

	public ArcturusDatabase(Organism organism) throws SQLException {
		this.name = organism.getName();
		this.description = organism.getDescription();
		this.ds = organism.getDataSource();
		this.instance = organism.getInstance();

		initialise();
	}

	private void initialise() throws SQLException {
		connectionPool = new ConnectionPool(ds);

		defaultConnection = connectionPool.getConnection(this);

		createManagers();

		inferDefaultDirectory();
	}

	/**
	 * Closes the connection pool belonging to this object.
	 */

	public synchronized void closeConnectionPool() {
		if (connectionPool != null) {
			connectionPool.close();
			connectionPool = null;
		}
	}

	/**
	 * Returns the DataSource which was used to create this object.
	 * 
	 * @return the DataSource which was used to create this object.
	 */

	public synchronized DataSource getDataSource() {
		return ds;
	}

	/**
	 * Returns the description which was used to create this object.
	 * 
	 * @return the description which was used to create this object.
	 */

	public synchronized String getDescription() {
		return description;
	}

	/**
	 * Returns the name which was used to create this object.
	 * 
	 * @return the name which was used to create this object.
	 */

	public synchronized String getName() {
		return name;
	}

	/**
	 * Returns the instance which created this object.
	 * 
	 * @return the instance which created this object.
	 */

	public ArcturusInstance getInstance() {
		return instance;
	}

	/**
	 * Establishes a JDBC connection to a database, using the parameters stored
	 * in this object's DataSource. After the first call to this method, the
	 * Connection object will be cached. The second and subsequent calls will
	 * return the cached object.
	 * 
	 * @return a java.sql.Connection which can be used to communicate with the
	 *         database.
	 * 
	 * @throws SQLException
	 *             in the event of an error when establishing a connection with
	 *             the database.
	 */

	public synchronized Connection getConnection() throws SQLException {
		if (defaultConnection == null || defaultConnection.isClosed())
			defaultConnection = connectionPool.getConnection(this);

		return defaultConnection;
	}

	/**
	 * Establishes a unique (non-cached) JDBC connection to a database, using
	 * the parameters stored in this object's DataSource.
	 * 
	 * @param owner
	 *            the object which will own the connection.
	 * 
	 * @return a java.sql.Connection which can be used to communicate with the
	 *         database.
	 * 
	 * @throws SQLException
	 *             in the event of an error when establishing a connection with
	 *             the database.
	 */

	public synchronized Connection getPooledConnection(Object owner)
			throws SQLException {
		return connectionPool.getConnection(owner);
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
	 * @throws SQLException
	 *             in the event of an error.
	 */

	public synchronized static DataSource createMysqlDataSource(
			String hostname, int port, String database, String username,
			String password) throws SQLException {
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
	 * @throws SQLException
	 *             in the event of an error.
	 */

	public synchronized static DataSource createOracleDataSource(
			String hostname, int port, String database, String username,
			String password) throws SQLException {
		OracleDataSource oracleds = new OracleDataSource();

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
	 * @throws SQLException
	 *             in the event of an error.
	 */

	public synchronized static DataSource createDataSource(String hostname,
			int port, String database, String username, String password,
			int type) throws SQLException {
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

	/**
	 * Sets the logger for this object.
	 * 
	 * @param logger
	 *            the Logger to which logging messages will be sent.
	 */

	public synchronized void setLogger(Logger logger) {
		this.logger = logger;
	}

	/**
	 * Gets the logger for this object.
	 * 
	 * @return the Logger to which logging messages will be sent.
	 */

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
	protected ContigTransferRequestManager contigTransferRequestManager;

	private void createManagers() throws SQLException {
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
	}

	/**
	 * Returns the CloneManager belonging to this ArcturusDatabase.
	 * 
	 * @return the CloneManager belonging to this ArcturusDatabase.
	 */

	public synchronized CloneManager getCloneManager() {
		return cloneManager;
	}

	public synchronized Clone getCloneByName(String name) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getCloneByName(" + name + ")");

		return cloneManager.getCloneByName(name);
	}

	public synchronized Clone getCloneByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getCloneByID(" + id + ")");

		return cloneManager.getCloneByID(id);
	}

	public synchronized void preloadAllClones() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllClones()");

		cloneManager.preloadAllClones();
	}

	public synchronized void clearCloneCache() {
		cloneManager.clearCache();
	}

	/**
	 * Returns the LigationManager belonging to this ArcturusDatabase.
	 * 
	 * @return the LigationManager belonging to this ArcturusDatabase.
	 */

	public synchronized LigationManager getLigationManager() {
		return ligationManager;
	}

	public synchronized Ligation getLigationByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getLigationByName(" + name + ")");

		return ligationManager.getLigationByName(name);
	}

	public synchronized Ligation getLigationByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getLigationByID(" + id + ")");

		return ligationManager.getLigationByID(id);
	}

	public synchronized void preloadAllLigations() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllLigations()");

		ligationManager.preloadAllLigations();
	}

	public synchronized void clearLigationCache() {
		ligationManager.clearCache();
	}

	/**
	 * Returns the TemplateManager belonging to this ArcturusDatabase.
	 * 
	 * @return the TemplateManager belonging to this ArcturusDatabase.
	 */

	public synchronized TemplateManager getTemplateManager() {
		return templateManager;
	}

	public synchronized Template getTemplateByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByName(" + name + ")");

		return templateManager.getTemplateByName(name);
	}

	public synchronized Template getTemplateByName(String name, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByName(" + name + ", " + autoload + ")");

		return templateManager.getTemplateByName(name, autoload);
	}

	public synchronized Template getTemplateByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByID(" + id + ")");

		return templateManager.getTemplateByID(id);
	}

	public synchronized Template getTemplateByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByID(" + id + ", " + autoload + ")");

		return templateManager.getTemplateByID(id, autoload);
	}

	void registerNewTemplate(Template template) {
		templateManager.registerNewTemplate(template);
	}

	public synchronized void preloadAllTemplates() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllTemplates()");

		templateManager.preloadAllTemplates();
	}

	public synchronized Template findOrCreateTemplate(int id, String name,
			Ligation ligation) {
		return templateManager.findOrCreateTemplate(id, name, ligation);
	}

	public synchronized void clearTemplateCache() {
		templateManager.clearCache();
	}

	/**
	 * Returns the ReadManager belonging to this ArcturusDatabase.
	 * 
	 * @return the ReadManager belonging to this ArcturusDatabase.
	 */

	public synchronized ReadManager getReadManager() {
		return readManager;
	}

	public synchronized Read getReadByName(String name) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByName(" + name + ")");

		return readManager.getReadByName(name);
	}

	public synchronized Read getReadByName(String name, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByName(" + name + ", " + autoload + ")");

		return readManager.getReadByName(name, autoload);
	}

	public synchronized Read getReadByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByID(" + id + ")");

		return readManager.getReadByID(id);
	}

	public synchronized Read getReadByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByID(" + id + ", " + autoload + ")");

		return readManager.getReadByID(id, autoload);
	}

	public synchronized int loadReadsByTemplate(int template_id)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("loadReadsByTemplate(" + template_id + ")");

		return readManager.loadReadsByTemplate(template_id);
	}

	void registerNewRead(Read read) {
		readManager.registerNewRead(read);
	}

	public synchronized void preloadAllReads() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllReads()");

		readManager.preloadAllReads();
	}

	public synchronized int parseStrand(String text) {
		return ReadManager.parseStrand(text);
	}

	public synchronized int parsePrimer(String text) {
		return ReadManager.parsePrimer(text);
	}

	public synchronized int parseChemistry(String text) {
		return ReadManager.parseChemistry(text);
	}

	public synchronized Read findOrCreateRead(int id, String name,
			Template template, java.util.Date asped, String strand,
			String primer, String chemistry) {
		return readManager.findOrCreateRead(id, name, template, asped, strand,
				primer, chemistry);
	}

	public synchronized int[] getUnassembledReadIDList() throws SQLException {
		return readManager.getUnassembledReadIDList();
	}

	public synchronized void clearReadCache() {
		readManager.clearCache();
	}

	public synchronized void setReadCacheing(boolean cacheing) {
		readManager.setCacheing(cacheing);
	}

	public synchronized boolean isReadCacheing() {
		return readManager.isCacheing();
	}

	/**
	 * Returns the SequenceManager belonging to this ArcturusDatabase.
	 * 
	 * @return the SequenceManager belonging to this ArcturusDatabase.
	 */

	public synchronized SequenceManager getSequenceManager() {
		return sequenceManager;
	}

	public synchronized Sequence getSequenceByReadID(int readid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getSequenceByReadID(" + readid + ")");

		return sequenceManager.getSequenceByReadID(readid);
	}

	public synchronized Sequence getSequenceByReadID(int readid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger
					.info("getSequenceByReadID(" + readid + ", " + autoload
							+ ")");

		return sequenceManager.getSequenceByReadID(readid, autoload);
	}

	public synchronized Sequence getFullSequenceByReadID(int readid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceByReadID(" + readid + ")");

		return sequenceManager.getFullSequenceByReadID(readid);
	}

	public synchronized Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceByReadID(" + readid + ", " + autoload
					+ ")");

		return sequenceManager.getFullSequenceByReadID(readid, autoload);
	}

	public synchronized Sequence getSequenceBySequenceID(int seqid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getSequenceBySequenceID(seqid);
	}

	public synchronized Sequence getSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getSequenceBySequenceID(" + seqid + ", " + autoload
					+ ")");

		return sequenceManager.getSequenceBySequenceID(seqid, autoload);
	}

	public synchronized Sequence getFullSequenceBySequenceID(int seqid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid);
	}

	public synchronized Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceBySequenceID(" + seqid + ", "
					+ autoload + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid, autoload);
	}

	public synchronized void getDNAAndQualityForSequence(Sequence sequence)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getDNAAndQualityForSequence(seqid=" + sequence.getID()
					+ ")");

		sequenceManager.getDNAAndQualityForSequence(sequence);
	}

	void registerNewSequence(Sequence sequence) {
		sequenceManager.registerNewSequence(sequence);
	}

	byte[] decodeCompressedData(byte[] compressed, int length) {
		return sequenceManager.decodeCompressedData(compressed, length);
	}

	public synchronized Sequence findOrCreateSequence(int seq_id, int length) {
		return sequenceManager.findOrCreateSequence(seq_id, length);
	}

	public synchronized void clearSequenceCache() {
		sequenceManager.clearCache();
	}

	public synchronized void setSequenceCacheing(boolean cacheing) {
		sequenceManager.setCacheing(cacheing);
	}

	public synchronized boolean isSequenceCacheing() {
		return sequenceManager.isCacheing();
	}

	/**
	 * Returns the ContigManager belonging to this ArcturusDatabase.
	 * 
	 * @return the ContigManager belonging to this ArcturusDatabase.
	 */

	public synchronized ContigManager getContigManager() {
		return contigManager;
	}

	public synchronized Contig getContigByID(int id, int options)
			throws SQLException, DataFormatException {
		return contigManager.getContigByID(id, options);
	}

	public synchronized Contig getContigByID(int id) throws SQLException,
			DataFormatException {
		return contigManager.getContigByID(id);
	}

	public synchronized Contig getContigByReadName(String readname, int options)
			throws SQLException, DataFormatException {
		return contigManager.getContigByReadName(readname, options);
	}

	public synchronized Contig getContigByReadName(String readname)
			throws SQLException, DataFormatException {
		return contigManager.getContigByReadName(readname);
	}

	public synchronized void updateContig(Contig contig, int options)
			throws SQLException, DataFormatException {
		contigManager.updateContig(contig, options);
	}

	public synchronized boolean isCurrentContig(int contigid)
			throws SQLException {
		return contigManager.isCurrentContig(contigid);
	}

	public synchronized int[] getCurrentContigIDList() throws SQLException {
		return contigManager.getCurrentContigIDList();
	}

	public synchronized int countCurrentContigs(int minlen) throws SQLException {
		return contigManager.countCurrentContigs(minlen);
	}

	public synchronized int countCurrentContigs() throws SQLException {
		return contigManager.countCurrentContigs(0);
	}

	public synchronized int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws SQLException, DataFormatException {
		return contigManager.processCurrentContigs(options, minlen, processor);
	}

	public synchronized int processCurrentContigs(int options,
			ContigProcessor processor) throws SQLException, DataFormatException {
		return contigManager.processCurrentContigs(options, 0, processor);
	}

	public synchronized Set getCurrentContigs(int options, int minlen)
			throws SQLException, DataFormatException {
		return contigManager.getCurrentContigs(options, minlen);
	}

	public synchronized Set getCurrentContigs(int options) throws SQLException,
			DataFormatException {
		return contigManager.getCurrentContigs(options, 0);
	}

	public synchronized int countContigsByProject(int project_id, int minlen)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("countContigsByProject(" + project_id + ", " + minlen
					+ ")");

		return contigManager.countContigsByProject(project_id, minlen);
	}

	public synchronized int countContigsByProject(int project_id)
			throws SQLException {
		return countContigsByProject(project_id, 0);
	}

	public synchronized int processContigsByProject(int project_id,
			int options, int minlen, ContigProcessor processor)
			throws SQLException, DataFormatException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("processContigsByProject(" + project_id + ", options="
					+ options + ", minlen=" + minlen + ")");

		return contigManager.processContigsByProject(project_id, options,
				minlen, processor);
	}

	public synchronized int processContigsByProject(int project_id,
			int options, ContigProcessor processor) throws SQLException,
			DataFormatException {
		return processContigsByProject(project_id, options, 0, processor);
	}

	public synchronized Set<Contig> getContigsByProject(int project_id,
			int options, int minlen) throws SQLException, DataFormatException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getContigsByProject(" + project_id + ", options="
					+ options + ", minlen=" + minlen + ")");

		return contigManager.getContigsByProject(project_id, options, minlen);
	}

	public synchronized Set getContigsByProject(int project_id, int options)
			throws SQLException, DataFormatException {
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

	/**
	 * Returns the ProjectManager belonging to this ArcturusDatabase.
	 * 
	 * @return the ProjectManager belonging to this ArcturusDatabase.
	 */

	public synchronized ProjectManager getProjectManager() {
		return projectManager;
	}

	public synchronized Project getProjectByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getProjectByID(" + id + ")");

		return projectManager.getProjectByID(id);
	}

	public synchronized Project getProjectByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger
					.info("getProjectByID(" + id + ", autoload=" + autoload
							+ ")");

		return projectManager.getProjectByID(id, true);
	}

	public synchronized Project getProjectByName(Assembly assembly, String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getProjectByName(assembly=" + assembly.getName()
					+ ", name=" + name + ")");

		return projectManager.getProjectByName(assembly, name);
	}

	public synchronized void preloadAllProjects() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllProjects");

		projectManager.preloadAllProjects();
	}

	public synchronized Set<Project> getAllProjects() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAllProjects");

		return projectManager.getAllProjects();
	}

	public synchronized Set<Project> getProjectsForOwner(Person owner)
			throws SQLException {
		return projectManager.getProjectsForOwner(owner);
	}

	public synchronized void refreshProject(Project project)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshProject(" + project + ")");

		projectManager.refreshProject(project);
	}

	public synchronized void refreshAllProject() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshAllProjects");

		projectManager.refreshAllProjects();
	}

	public synchronized void setAssemblyForProject(Project project,
			Assembly assembly) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("setAssemblyForProject(" + project + ", " + assembly
					+ ")");

		projectManager.setAssemblyForProject(project, assembly);
	}

	public synchronized void getProjectSummary(Project project, int minlen,
			int minreads, ProjectSummary summary) throws SQLException {
		projectManager.getProjectSummary(project, minlen, minreads, summary);
	}

	public synchronized ProjectSummary getProjectSummary(Project project,
			int minlen, int minreads) throws SQLException {
		return projectManager.getProjectSummary(project, minlen, minreads);
	}

	public synchronized void getProjectSummary(Project project, int minlen,
			ProjectSummary summary) throws SQLException {
		projectManager.getProjectSummary(project, minlen, 0, summary);
	}

	public synchronized void getProjectSummary(Project project,
			ProjectSummary summary) throws SQLException {
		projectManager.getProjectSummary(project, summary);
	}

	public synchronized ProjectSummary getProjectSummary(Project project,
			int minlen) throws SQLException {
		return projectManager.getProjectSummary(project, minlen);
	}

	public synchronized ProjectSummary getProjectSummary(Project project)
			throws SQLException {
		return projectManager.getProjectSummary(project);
	}

	public synchronized Map getProjectSummary(int minlen, int minreads)
			throws SQLException {
		return projectManager.getProjectSummary(minlen, minreads);
	}

	public synchronized Map getProjectSummary(int minlen) throws SQLException {
		return projectManager.getProjectSummary(minlen);
	}

	public synchronized Map getProjectSummary() throws SQLException {
		return projectManager.getProjectSummary();
	}

	public synchronized void clearProjectCache() {
		projectManager.clearCache();
	}

	public synchronized boolean canUserUnlockProject(Project project,
			Person user) throws SQLException {
		return projectManager.canUserUnlockProject(project, user);
	}

	public synchronized boolean canUserLockProject(Project project, Person user)
			throws SQLException {
		return projectManager.canUserLockProject(project, user);
	}

	public synchronized boolean canUserLockProjectForOwner(Project project,
			Person user) throws SQLException {
		return projectManager.canUserLockProjectForOwner(project, user);
	}

	public synchronized boolean unlockProject(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.unlockProject(project);
	}

	public synchronized boolean lockProject(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.lockProject(project);
	}

	public synchronized boolean unlockProjectForExport(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.unlockProjectForExport(project);
	}

	public synchronized boolean lockProjectForExport(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.lockProjectForExport(project);
	}

	public synchronized boolean lockProjectForOwner(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.lockProjectForOwner(project);
	}

	public synchronized void setProjectOwner(Project project, Person person)
			throws SQLException {
		projectManager.setProjectOwner(project, person);
	}

	public synchronized boolean createNewProject(Assembly assembly,
			String name, Person owner, String directory) throws SQLException,
			IOException {
		return projectManager
				.createNewProject(assembly, name, owner, directory);
	}

	public boolean canUserChangeProjectStatus(Project project, Person user)
			throws SQLException {
		return projectManager.canUserChangeProjectStatus(project, user);
	}

	public boolean canUserChangeProjectStatus(Project project)
			throws SQLException {
		return projectManager.canUserChangeProjectStatus(project);
	}

	public boolean changeProjectStatus(Project project, int status)
			throws SQLException {
		return projectManager.changeProjectStatus(project, status);
	}

	public boolean retireProject(Project project) throws SQLException {
		return projectManager.retireProject(project);
	}

	public Project getBinForProject(Project project) throws SQLException {
		return projectManager.getBinForProject(project);
	}

	/**
	 * Returns the AssemblyManager belonging to this ArcturusDatabase.
	 * 
	 * @return the AssemblyManager belonging to this ArcturusDatabase.
	 */

	public synchronized AssemblyManager getAssemblyManager() {
		return assemblyManager;
	}

	public synchronized Assembly getAssemblyByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAssemblyByID(" + id + ")");

		return assemblyManager.getAssemblyByID(id);
	}

	public synchronized Assembly getAssemblyByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAssemblyByID(" + id + ", autoload=" + autoload
					+ ")");

		return assemblyManager.getAssemblyByID(id, true);
	}

	public synchronized Assembly getAssemblyByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAssemblyByName(" + name + ")");

		return assemblyManager.getAssemblyByName(name);
	}

	public synchronized void preloadAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllProjects");

		assemblyManager.preloadAllAssemblies();
	}

	public synchronized Assembly[] getAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAllAssemblies");

		return assemblyManager.getAllAssemblies();
	}

	public synchronized void refreshAssembly(Assembly assembly)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshAssembly(" + assembly + ")");

		assemblyManager.refreshAssembly(assembly);
	}

	public synchronized void refreshAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshAllAssemblies");

		assemblyManager.refreshAllAssemblies();
	}

	public synchronized void clearAssemblyCache() {
		assemblyManager.clearCache();
	}

	/**
	 * Returns the UserManager belonging to this ArcturusDatabase.
	 * 
	 * @return the UserManager belonging to this ArcturusDatabase.
	 */

	public synchronized UserManager getUserManager() {
		return userManager;
	}

	public synchronized String getRoleForUser(String username) {
		return userManager.getRoleForUser(username);
	}

	public synchronized String getRoleForUser(Person person) {
		return userManager.getRoleForUser(person);
	}

	public synchronized String[] getPrivilegesForUser(String username)
			throws SQLException {
		return userManager.getPrivilegesForUser(username);
	}

	public synchronized String[] getPrivilegesForUser(Person person)
			throws SQLException {
		return userManager.getPrivilegesForUser(person);
	}

	public synchronized boolean hasPrivilege(String username, String privilege)
			throws SQLException {
		return userManager.hasPrivilege(username, privilege);
	}

	public synchronized boolean hasPrivilege(Person person, String privilege)
			throws SQLException {
		return userManager.hasPrivilege(person, privilege);
	}

	public synchronized boolean hasFullPrivileges(Person person) {
		return userManager.hasFullPrivileges(person);
	}

	public synchronized boolean hasFullPrivileges() {
		return userManager.hasFullPrivileges();
	}

	public synchronized boolean isCoordinator(Person person) {
		return userManager.isCoordinator(person);
	}

	public synchronized boolean isCoordinator() {
		return userManager.isCoordinator();
	}

	public synchronized Person[] getAllUsers() throws SQLException {
		return userManager.getAllUsers();
	}

	/**
	 * Returns the ContigTransferRequestManager belonging to this
	 * ArcturusDatabase.
	 * 
	 * @return the ContigTransferRequestManager belonging to this
	 *         ArcturusDatabase.
	 */

	public synchronized ContigTransferRequestManager getContigTransferRequestManager() {
		return contigTransferRequestManager;
	}

	public synchronized ContigTransferRequest[] getContigTransferRequestsByUser(
			Person user, int mode) throws SQLException {
		return contigTransferRequestManager.getContigTransferRequestsByUser(
				user, mode);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			Person requester, int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(
				requester, contigId, toProjectId);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(
				contigId, toProjectId);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			Person requester, Contig contig, Project project)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(
				requester, contig, project);
	}

	public synchronized ContigTransferRequest createContigTransferRequest(
			Contig contig, Project project)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(contig,
				project);
	}

	public synchronized void reviewContigTransferRequest(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.reviewContigTransferRequest(request,
				reviewer, newStatus);
	}

	public synchronized void reviewContigTransferRequest(int requestId,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.reviewContigTransferRequest(requestId,
				reviewer, newStatus);
	}

	public synchronized void reviewContigTransferRequest(int requestId,
			int newStatus) throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.reviewContigTransferRequest(requestId,
				newStatus);
	}

	public synchronized void executeContigTransferRequest(
			ContigTransferRequest request, Person reviewer,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException {
		contigTransferRequestManager.executeContigTransferRequest(request,
				reviewer, notifyListeners);
	}

	public synchronized void executeContigTransferRequest(int requestId,
			Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.executeContigTransferRequest(requestId,
				reviewer, notifyListeners);
	}

	public synchronized void executeContigTransferRequest(int requestId,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException {
		contigTransferRequestManager.executeContigTransferRequest(requestId,
				notifyListeners);
	}

	public synchronized void setDebugging(boolean debugging) {
		contigTransferRequestManager.setDebugging(debugging);
	}

	public synchronized boolean canCancelRequest(ContigTransferRequest request,
			Person person) throws SQLException {
		return contigTransferRequestManager.canCancelRequest(request, person);
	}

	public synchronized boolean canRefuseRequest(ContigTransferRequest request,
			Person person) throws SQLException {
		return contigTransferRequestManager.canRefuseRequest(request, person);
	}

	public synchronized boolean canApproveRequest(
			ContigTransferRequest request, Person person) throws SQLException {
		return contigTransferRequestManager.canApproveRequest(request, person);
	}

	public synchronized boolean canExecuteRequest(
			ContigTransferRequest request, Person person) throws SQLException {
		return contigTransferRequestManager.canExecuteRequest(request, person);
	}

	public synchronized void moveContigs(Project fromProject, Project toProject)
			throws SQLException {
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

	private void inferDefaultDirectory() {
		String query = "select directory from PROJECT where directory is not null"
				+ " order by project_id asc limit 1";

		try {
			Statement stmt = defaultConnection.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			String dirname = rs.next() ? rs.getString(1) : null;

			rs.close();
			stmt.close();

			//String separator = System.getProperty("file.separator");
			String separator = "/";

			if (dirname != null) {
				String[] parts = dirname.split(separator);

				for (int i = parts.length - 1; i >= 0; i--) {
					if (parts[i].equalsIgnoreCase(name)) {
						dirname = "";

						for (int j = 0; j <= i; j++)
							if (parts[j].length() > 0)
								dirname += separator + parts[j];

						defaultDirectory = dirname;

						return;
					}
				}
			}
		} catch (SQLException e) {
			Arcturus
					.logSevere(
							"An error occurred whilst trying to infer the default directory",
							e);
		}
	}

	public String getDefaultDirectory() {
		return defaultDirectory;
	}
}
