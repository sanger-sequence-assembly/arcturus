package uk.ac.sanger.arcturus.jdbc;

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
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ContigProcessor;
import uk.ac.sanger.arcturus.database.ProjectLockException;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

import uk.ac.sanger.arcturus.people.Person;

import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;

import uk.ac.sanger.arcturus.pooledconnection.ConnectionPool;

import uk.ac.sanger.arcturus.projectchange.*;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.Arcturus;

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

	public ArcturusDatabaseImpl(Organism organism) throws SQLException {
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

	public synchronized Connection getConnection() throws SQLException {
		if (defaultConnection == null || defaultConnection.isClosed())
			defaultConnection = connectionPool.getConnection(this);

		return defaultConnection;
	}

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

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setLogger(java.util.logging.Logger)
	 */

	public synchronized void setLogger(Logger logger) {
		this.logger = logger;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getLogger()
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

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getCloneManager()
	 */

	public synchronized CloneManager getCloneManager() {
		return cloneManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getCloneByName(java.lang.String)
	 */
	public synchronized Clone getCloneByName(String name) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getCloneByName(" + name + ")");

		return cloneManager.getCloneByName(name);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getCloneByID(int)
	 */
	public synchronized Clone getCloneByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getCloneByID(" + id + ")");

		return cloneManager.getCloneByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#preloadAllClones()
	 */
	public synchronized void preloadAllClones() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllClones()");

		cloneManager.preloadAllClones();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearCloneCache()
	 */
	public synchronized void clearCloneCache() {
		cloneManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getLigationManager()
	 */

	public synchronized LigationManager getLigationManager() {
		return ligationManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getLigationByName(java.lang.String)
	 */
	public synchronized Ligation getLigationByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getLigationByName(" + name + ")");

		return ligationManager.getLigationByName(name);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getLigationByID(int)
	 */
	public synchronized Ligation getLigationByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getLigationByID(" + id + ")");

		return ligationManager.getLigationByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#preloadAllLigations()
	 */
	public synchronized void preloadAllLigations() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllLigations()");

		ligationManager.preloadAllLigations();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearLigationCache()
	 */
	public synchronized void clearLigationCache() {
		ligationManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getTemplateManager()
	 */

	public synchronized TemplateManager getTemplateManager() {
		return templateManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getTemplateByName(java.lang.String)
	 */
	public synchronized Template getTemplateByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByName(" + name + ")");

		return templateManager.getTemplateByName(name);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getTemplateByName(java.lang.String, boolean)
	 */
	public synchronized Template getTemplateByName(String name, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByName(" + name + ", " + autoload + ")");

		return templateManager.getTemplateByName(name, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getTemplateByID(int)
	 */
	public synchronized Template getTemplateByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByID(" + id + ")");

		return templateManager.getTemplateByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getTemplateByID(int, boolean)
	 */
	public synchronized Template getTemplateByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getTemplateByID(" + id + ", " + autoload + ")");

		return templateManager.getTemplateByID(id, autoload);
	}

	void registerNewTemplate(Template template) {
		templateManager.registerNewTemplate(template);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#preloadAllTemplates()
	 */
	public synchronized void preloadAllTemplates() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllTemplates()");

		templateManager.preloadAllTemplates();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#findOrCreateTemplate(int, java.lang.String, uk.ac.sanger.arcturus.data.Ligation)
	 */
	public synchronized Template findOrCreateTemplate(int id, String name,
			Ligation ligation) {
		return templateManager.findOrCreateTemplate(id, name, ligation);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearTemplateCache()
	 */
	public synchronized void clearTemplateCache() {
		templateManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setTemplateCacheing(boolean)
	 */
	public synchronized void setTemplateCacheing(boolean cacheing) {
		templateManager.setCacheing(cacheing);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isTemplateCacheing()
	 */
	public synchronized boolean isTemplateCacheing() {
		return templateManager.isCacheing();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getReadManager()
	 */

	public synchronized ReadManager getReadManager() {
		return readManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getReadByName(java.lang.String)
	 */
	public synchronized Read getReadByName(String name) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByName(" + name + ")");

		return readManager.getReadByName(name);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getReadByName(java.lang.String, boolean)
	 */
	public synchronized Read getReadByName(String name, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByName(" + name + ", " + autoload + ")");

		return readManager.getReadByName(name, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getReadByID(int)
	 */
	public synchronized Read getReadByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByID(" + id + ")");

		return readManager.getReadByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getReadByID(int, boolean)
	 */
	public synchronized Read getReadByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getReadByID(" + id + ", " + autoload + ")");

		return readManager.getReadByID(id, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#loadReadsByTemplate(int)
	 */
	public synchronized int loadReadsByTemplate(int template_id)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("loadReadsByTemplate(" + template_id + ")");

		return readManager.loadReadsByTemplate(template_id);
	}

	void registerNewRead(Read read) {
		readManager.registerNewRead(read);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#preloadAllReads()
	 */
	public synchronized void preloadAllReads() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllReads()");

		readManager.preloadAllReads();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#parseStrand(java.lang.String)
	 */
	public synchronized int parseStrand(String text) {
		return ReadManager.parseStrand(text);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#parsePrimer(java.lang.String)
	 */
	public synchronized int parsePrimer(String text) {
		return ReadManager.parsePrimer(text);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#parseChemistry(java.lang.String)
	 */
	public synchronized int parseChemistry(String text) {
		return ReadManager.parseChemistry(text);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#findOrCreateRead(int, java.lang.String, uk.ac.sanger.arcturus.data.Template, java.util.Date, java.lang.String, java.lang.String, java.lang.String)
	 */
	public synchronized Read findOrCreateRead(int id, String name,
			Template template, java.util.Date asped, String strand,
			String primer, String chemistry) {
		return readManager.findOrCreateRead(id, name, template, asped, strand,
				primer, chemistry);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getUnassembledReadIDList()
	 */
	public synchronized int[] getUnassembledReadIDList() throws SQLException {
		return readManager.getUnassembledReadIDList();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearReadCache()
	 */
	public synchronized void clearReadCache() {
		readManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setReadCacheing(boolean)
	 */
	public synchronized void setReadCacheing(boolean cacheing) {
		readManager.setCacheing(cacheing);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isReadCacheing()
	 */
	public synchronized boolean isReadCacheing() {
		return readManager.isCacheing();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getSequenceManager()
	 */

	public synchronized SequenceManager getSequenceManager() {
		return sequenceManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getSequenceByReadID(int)
	 */
	public synchronized Sequence getSequenceByReadID(int readid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getSequenceByReadID(" + readid + ")");

		return sequenceManager.getSequenceByReadID(readid);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getSequenceByReadID(int, boolean)
	 */
	public synchronized Sequence getSequenceByReadID(int readid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger
					.info("getSequenceByReadID(" + readid + ", " + autoload
							+ ")");

		return sequenceManager.getSequenceByReadID(readid, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getFullSequenceByReadID(int)
	 */
	public synchronized Sequence getFullSequenceByReadID(int readid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceByReadID(" + readid + ")");

		return sequenceManager.getFullSequenceByReadID(readid);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getFullSequenceByReadID(int, boolean)
	 */
	public synchronized Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceByReadID(" + readid + ", " + autoload
					+ ")");

		return sequenceManager.getFullSequenceByReadID(readid, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getSequenceBySequenceID(int)
	 */
	public synchronized Sequence getSequenceBySequenceID(int seqid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getSequenceBySequenceID(seqid);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getSequenceBySequenceID(int, boolean)
	 */
	public synchronized Sequence getSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getSequenceBySequenceID(" + seqid + ", " + autoload
					+ ")");

		return sequenceManager.getSequenceBySequenceID(seqid, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getFullSequenceBySequenceID(int)
	 */
	public synchronized Sequence getFullSequenceBySequenceID(int seqid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getFullSequenceBySequenceID(int, boolean)
	 */
	public synchronized Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getFullSequenceBySequenceID(" + seqid + ", "
					+ autoload + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid, autoload);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getDNAAndQualityForSequence(uk.ac.sanger.arcturus.data.Sequence)
	 */
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

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#findOrCreateSequence(int, int)
	 */
	public synchronized Sequence findOrCreateSequence(int seq_id, int length) {
		return sequenceManager.findOrCreateSequence(seq_id, length);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearSequenceCache()
	 */
	public synchronized void clearSequenceCache() {
		sequenceManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setSequenceCacheing(boolean)
	 */
	public synchronized void setSequenceCacheing(boolean cacheing) {
		sequenceManager.setCacheing(cacheing);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isSequenceCacheing()
	 */
	public synchronized boolean isSequenceCacheing() {
		return sequenceManager.isCacheing();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigManager()
	 */

	public synchronized ContigManager getContigManager() {
		return contigManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigByID(int, int)
	 */
	public synchronized Contig getContigByID(int id, int options)
			throws SQLException, DataFormatException {
		return contigManager.getContigByID(id, options);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigByID(int)
	 */
	public synchronized Contig getContigByID(int id) throws SQLException,
			DataFormatException {
		return contigManager.getContigByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigByReadName(java.lang.String, int)
	 */
	public synchronized Contig getContigByReadName(String readname, int options)
			throws SQLException, DataFormatException {
		return contigManager.getContigByReadName(readname, options);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigByReadName(java.lang.String)
	 */
	public synchronized Contig getContigByReadName(String readname)
			throws SQLException, DataFormatException {
		return contigManager.getContigByReadName(readname);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#updateContig(uk.ac.sanger.arcturus.data.Contig, int)
	 */
	public synchronized void updateContig(Contig contig, int options)
			throws SQLException, DataFormatException {
		contigManager.updateContig(contig, options);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isCurrentContig(int)
	 */
	public synchronized boolean isCurrentContig(int contigid)
			throws SQLException {
		return contigManager.isCurrentContig(contigid);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getCurrentContigIDList()
	 */
	public synchronized int[] getCurrentContigIDList() throws SQLException {
		return contigManager.getCurrentContigIDList();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#countCurrentContigs(int)
	 */
	public synchronized int countCurrentContigs(int minlen) throws SQLException {
		return contigManager.countCurrentContigs(minlen);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#countCurrentContigs()
	 */
	public synchronized int countCurrentContigs() throws SQLException {
		return contigManager.countCurrentContigs(0);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#processCurrentContigs(int, int, uk.ac.sanger.arcturus.jdbc.ContigProcessor)
	 */
	public synchronized int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws SQLException, DataFormatException {
		return contigManager.processCurrentContigs(options, minlen, processor);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#processCurrentContigs(int, uk.ac.sanger.arcturus.jdbc.ContigProcessor)
	 */
	public synchronized int processCurrentContigs(int options,
			ContigProcessor processor) throws SQLException, DataFormatException {
		return contigManager.processCurrentContigs(options, 0, processor);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getCurrentContigs(int, int)
	 */
	public synchronized Set getCurrentContigs(int options, int minlen)
			throws SQLException, DataFormatException {
		return contigManager.getCurrentContigs(options, minlen);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getCurrentContigs(int)
	 */
	public synchronized Set getCurrentContigs(int options) throws SQLException,
			DataFormatException {
		return contigManager.getCurrentContigs(options, 0);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#countContigsByProject(int, int)
	 */
	public synchronized int countContigsByProject(int project_id, int minlen)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("countContigsByProject(" + project_id + ", " + minlen
					+ ")");

		return contigManager.countContigsByProject(project_id, minlen);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#countContigsByProject(int)
	 */
	public synchronized int countContigsByProject(int project_id)
			throws SQLException {
		return countContigsByProject(project_id, 0);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#processContigsByProject(int, int, int, uk.ac.sanger.arcturus.jdbc.ContigProcessor)
	 */
	public synchronized int processContigsByProject(int project_id,
			int options, int minlen, ContigProcessor processor)
			throws SQLException, DataFormatException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("processContigsByProject(" + project_id + ", options="
					+ options + ", minlen=" + minlen + ")");

		return contigManager.processContigsByProject(project_id, options,
				minlen, processor);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#processContigsByProject(int, int, uk.ac.sanger.arcturus.jdbc.ContigProcessor)
	 */
	public synchronized int processContigsByProject(int project_id,
			int options, ContigProcessor processor) throws SQLException,
			DataFormatException {
		return processContigsByProject(project_id, options, 0, processor);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigsByProject(int, int, int)
	 */
	public synchronized Set<Contig> getContigsByProject(int project_id,
			int options, int minlen) throws SQLException, DataFormatException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getContigsByProject(" + project_id + ", options="
					+ options + ", minlen=" + minlen + ")");

		return contigManager.getContigsByProject(project_id, options, minlen);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigsByProject(int, int)
	 */
	public synchronized Set getContigsByProject(int project_id, int options)
			throws SQLException, DataFormatException {
		return getContigsByProject(project_id, options, 0);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#addContigManagerEventListener(uk.ac.sanger.arcturus.jdbc.ManagerEventListener)
	 */
	public synchronized void addContigManagerEventListener(
			ManagerEventListener listener) {
		contigManager.addContigManagerEventListener(listener);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#removeContigManagerEventListener(uk.ac.sanger.arcturus.jdbc.ManagerEventListener)
	 */
	public synchronized void removeContigManagerEventListener(
			ManagerEventListener listener) {
		contigManager.removeContigManagerEventListener(listener);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearContigCache()
	 */
	public synchronized void clearContigCache() {
		contigManager.clearCache();
	}
	
	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getChildContigs(uk.ac.sanger.arcturus.data.Contig)
	 */
	public synchronized Set<Contig> getChildContigs(Contig parent) throws SQLException {
		return contigManager.getChildContigs(parent);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectManager()
	 */

	public synchronized ProjectManager getProjectManager() {
		return projectManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectByID(int)
	 */
	public synchronized Project getProjectByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getProjectByID(" + id + ")");

		return projectManager.getProjectByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectByID(int, boolean)
	 */
	public synchronized Project getProjectByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger
					.info("getProjectByID(" + id + ", autoload=" + autoload
							+ ")");

		return projectManager.getProjectByID(id, true);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectByName(uk.ac.sanger.arcturus.data.Assembly, java.lang.String)
	 */
	public synchronized Project getProjectByName(Assembly assembly, String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getProjectByName(assembly=" + assembly.getName()
					+ ", name=" + name + ")");

		return projectManager.getProjectByName(assembly, name);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#preloadAllProjects()
	 */
	public synchronized void preloadAllProjects() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllProjects");

		projectManager.preloadAllProjects();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAllProjects()
	 */
	public synchronized Set<Project> getAllProjects() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAllProjects");

		return projectManager.getAllProjects();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectsForOwner(uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized Set<Project> getProjectsForOwner(Person owner)
			throws SQLException {
		return projectManager.getProjectsForOwner(owner);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#refreshProject(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized void refreshProject(Project project)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshProject(" + project + ")");

		projectManager.refreshProject(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#refreshAllProject()
	 */
	public synchronized void refreshAllProject() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshAllProjects");

		projectManager.refreshAllProjects();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setAssemblyForProject(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.data.Assembly)
	 */
	public synchronized void setAssemblyForProject(Project project,
			Assembly assembly) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("setAssemblyForProject(" + project + ", " + assembly
					+ ")");

		projectManager.setAssemblyForProject(project, assembly);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(uk.ac.sanger.arcturus.data.Project, int, int, uk.ac.sanger.arcturus.utils.ProjectSummary)
	 */
	public synchronized void getProjectSummary(Project project, int minlen,
			int minreads, ProjectSummary summary) throws SQLException {
		projectManager.getProjectSummary(project, minlen, minreads, summary);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(uk.ac.sanger.arcturus.data.Project, int, int)
	 */
	public synchronized ProjectSummary getProjectSummary(Project project,
			int minlen, int minreads) throws SQLException {
		return projectManager.getProjectSummary(project, minlen, minreads);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(uk.ac.sanger.arcturus.data.Project, int, uk.ac.sanger.arcturus.utils.ProjectSummary)
	 */
	public synchronized void getProjectSummary(Project project, int minlen,
			ProjectSummary summary) throws SQLException {
		projectManager.getProjectSummary(project, minlen, 0, summary);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.utils.ProjectSummary)
	 */
	public synchronized void getProjectSummary(Project project,
			ProjectSummary summary) throws SQLException {
		projectManager.getProjectSummary(project, summary);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(uk.ac.sanger.arcturus.data.Project, int)
	 */
	public synchronized ProjectSummary getProjectSummary(Project project,
			int minlen) throws SQLException {
		return projectManager.getProjectSummary(project, minlen);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized ProjectSummary getProjectSummary(Project project)
			throws SQLException {
		return projectManager.getProjectSummary(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(int, int)
	 */
	public synchronized Map getProjectSummary(int minlen, int minreads)
			throws SQLException {
		return projectManager.getProjectSummary(minlen, minreads);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary(int)
	 */
	public synchronized Map getProjectSummary(int minlen) throws SQLException {
		return projectManager.getProjectSummary(minlen);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getProjectSummary()
	 */
	public synchronized Map getProjectSummary() throws SQLException {
		return projectManager.getProjectSummary();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearProjectCache()
	 */
	public synchronized void clearProjectCache() {
		projectManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canUserUnlockProject(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canUserUnlockProject(Project project,
			Person user) throws SQLException {
		return projectManager.canUserUnlockProject(project, user);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canUserLockProjectForSelf(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canUserLockProjectForSelf(Project project, Person user)
			throws SQLException {
		return projectManager.canUserLockProjectForSelf(project, user);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canUserLockProject(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canUserLockProject(Project project, Person user)
			throws SQLException {
		return projectManager.canUserLockProject(project, user);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canUserLockProjectForOwner(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canUserLockProjectForOwner(Project project,
			Person user) throws SQLException {
		return projectManager.canUserLockProjectForOwner(project, user);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#unlockProject(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized boolean unlockProject(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.unlockProject(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#lockProject(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized boolean lockProject(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.lockProject(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#unlockProjectForExport(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized boolean unlockProjectForExport(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.unlockProjectForExport(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#lockProjectForExport(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized boolean lockProjectForExport(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.lockProjectForExport(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#lockProjectForOwner(uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized boolean lockProjectForOwner(Project project)
			throws SQLException, ProjectLockException {
		return projectManager.lockProjectForOwner(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setProjectLockOwner(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean setProjectLockOwner(Project project,
			Person person) throws SQLException, ProjectLockException {
		return (person == null || person.isNobody()) ?
				projectManager.unlockProject(project) :
				projectManager.setProjectLockOwner(project, person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setProjectOwner(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized void setProjectOwner(Project project, Person person)
			throws SQLException {
		projectManager.setProjectOwner(project, person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#createNewProject(uk.ac.sanger.arcturus.data.Assembly, java.lang.String, uk.ac.sanger.arcturus.people.Person, java.lang.String)
	 */
	public synchronized boolean createNewProject(Assembly assembly,
			String name, Person owner, String directory) throws SQLException,
			IOException {
		return projectManager
				.createNewProject(assembly, name, owner, directory);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canUserChangeProjectStatus(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.people.Person)
	 */
	public boolean canUserChangeProjectStatus(Project project, Person user)
			throws SQLException {
		return projectManager.canUserChangeProjectStatus(project, user);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canUserChangeProjectStatus(uk.ac.sanger.arcturus.data.Project)
	 */
	public boolean canUserChangeProjectStatus(Project project)
			throws SQLException {
		return projectManager.canUserChangeProjectStatus(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#changeProjectStatus(uk.ac.sanger.arcturus.data.Project, int)
	 */
	public boolean changeProjectStatus(Project project, int status)
			throws SQLException {
		return projectManager.changeProjectStatus(project, status);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#retireProject(uk.ac.sanger.arcturus.data.Project)
	 */
	public boolean retireProject(Project project) throws SQLException {
		return projectManager.retireProject(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getBinForProject(uk.ac.sanger.arcturus.data.Project)
	 */
	public Project getBinForProject(Project project) throws SQLException {
		return projectManager.getBinForProject(project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAssemblyManager()
	 */

	public synchronized AssemblyManager getAssemblyManager() {
		return assemblyManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAssemblyByID(int)
	 */
	public synchronized Assembly getAssemblyByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAssemblyByID(" + id + ")");

		return assemblyManager.getAssemblyByID(id);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAssemblyByID(int, boolean)
	 */
	public synchronized Assembly getAssemblyByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAssemblyByID(" + id + ", autoload=" + autoload
					+ ")");

		return assemblyManager.getAssemblyByID(id, true);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAssemblyByName(java.lang.String)
	 */
	public synchronized Assembly getAssemblyByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAssemblyByName(" + name + ")");

		return assemblyManager.getAssemblyByName(name);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#preloadAllAssemblies()
	 */
	public synchronized void preloadAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("preloadAllProjects");

		assemblyManager.preloadAllAssemblies();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAllAssemblies()
	 */
	public synchronized Assembly[] getAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("getAllAssemblies");

		return assemblyManager.getAllAssemblies();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#refreshAssembly(uk.ac.sanger.arcturus.data.Assembly)
	 */
	public synchronized void refreshAssembly(Assembly assembly)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshAssembly(" + assembly + ")");

		assemblyManager.refreshAssembly(assembly);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#refreshAllAssemblies()
	 */
	public synchronized void refreshAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.INFO))
			logger.info("refreshAllAssemblies");

		assemblyManager.refreshAllAssemblies();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#clearAssemblyCache()
	 */
	public synchronized void clearAssemblyCache() {
		assemblyManager.clearCache();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getUserManager()
	 */

	public synchronized UserManager getUserManager() {
		return userManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#hasFullPrivileges(uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean hasFullPrivileges(Person person) {
		return userManager.hasFullPrivileges(person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#hasFullPrivileges()
	 */
	public synchronized boolean hasFullPrivileges() throws SQLException {
		return userManager.hasFullPrivileges();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isCoordinator(uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean isCoordinator(Person person) {
		return userManager.isCoordinator(person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isCoordinator()
	 */
	public synchronized boolean isCoordinator() {
		return userManager.isCoordinator();
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAllUsers(boolean)
	 */
	public synchronized Person[] getAllUsers(boolean includeNobody)
			throws SQLException {
		return userManager.getAllUsers(includeNobody);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getAllUsers()
	 */
	public synchronized Person[] getAllUsers() throws SQLException {
		return userManager.getAllUsers(false);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#findUser(java.lang.String)
	 */
	public Person findUser(String username) {
		return userManager.findUser(username);
	}
	
	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#findMe()
	 */
	public Person findMe() {
		return userManager.findMe();
	}
	
	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#isMe(uk.ac.sanger.arcturus.people.Person)
	 */
	public boolean isMe(Person person) {
		return userManager.isMe(person);
	}
	
	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigTransferRequestManager()
	 */

	public synchronized ContigTransferRequestManager getContigTransferRequestManager() {
		return contigTransferRequestManager;
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#getContigTransferRequestsByUser(uk.ac.sanger.arcturus.people.Person, int)
	 */
	public synchronized ContigTransferRequest[] getContigTransferRequestsByUser(
			Person user, int mode) throws SQLException {
		return contigTransferRequestManager.getContigTransferRequestsByUser(
				user, mode);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#createContigTransferRequest(uk.ac.sanger.arcturus.people.Person, int, int)
	 */
	public synchronized ContigTransferRequest createContigTransferRequest(
			Person requester, int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(
				requester, contigId, toProjectId);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#createContigTransferRequest(int, int)
	 */
	public synchronized ContigTransferRequest createContigTransferRequest(
			int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(
				contigId, toProjectId);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#createContigTransferRequest(uk.ac.sanger.arcturus.people.Person, uk.ac.sanger.arcturus.data.Contig, uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized ContigTransferRequest createContigTransferRequest(
			Person requester, Contig contig, Project project)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(
				requester, contig, project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#createContigTransferRequest(uk.ac.sanger.arcturus.data.Contig, uk.ac.sanger.arcturus.data.Project)
	 */
	public synchronized ContigTransferRequest createContigTransferRequest(
			Contig contig, Project project)
			throws ContigTransferRequestException, SQLException {
		return contigTransferRequestManager.createContigTransferRequest(contig,
				project);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#reviewContigTransferRequest(uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest, uk.ac.sanger.arcturus.people.Person, int)
	 */
	public synchronized void reviewContigTransferRequest(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.reviewContigTransferRequest(request,
				reviewer, newStatus);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#reviewContigTransferRequest(int, uk.ac.sanger.arcturus.people.Person, int)
	 */
	public synchronized void reviewContigTransferRequest(int requestId,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.reviewContigTransferRequest(requestId,
				reviewer, newStatus);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#reviewContigTransferRequest(int, int)
	 */
	public synchronized void reviewContigTransferRequest(int requestId,
			int newStatus) throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.reviewContigTransferRequest(requestId,
				newStatus);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#executeContigTransferRequest(uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest, uk.ac.sanger.arcturus.people.Person, boolean)
	 */
	public synchronized void executeContigTransferRequest(
			ContigTransferRequest request, Person reviewer,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException {
		contigTransferRequestManager.executeContigTransferRequest(request,
				reviewer, notifyListeners);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#executeContigTransferRequest(int, uk.ac.sanger.arcturus.people.Person, boolean)
	 */
	public synchronized void executeContigTransferRequest(int requestId,
			Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, SQLException {
		contigTransferRequestManager.executeContigTransferRequest(requestId,
				reviewer, notifyListeners);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#executeContigTransferRequest(int, boolean)
	 */
	public synchronized void executeContigTransferRequest(int requestId,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException {
		contigTransferRequestManager.executeContigTransferRequest(requestId,
				notifyListeners);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#setDebugging(boolean)
	 */
	public synchronized void setDebugging(boolean debugging) {
		contigTransferRequestManager.setDebugging(debugging);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canCancelRequest(uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canCancelRequest(ContigTransferRequest request,
			Person person) throws SQLException {
		return contigTransferRequestManager.canCancelRequest(request, person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canRefuseRequest(uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canRefuseRequest(ContigTransferRequest request,
			Person person) throws SQLException {
		return contigTransferRequestManager.canRefuseRequest(request, person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canApproveRequest(uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canApproveRequest(
			ContigTransferRequest request, Person person) throws SQLException {
		return contigTransferRequestManager.canApproveRequest(request, person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#canExecuteRequest(uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest, uk.ac.sanger.arcturus.people.Person)
	 */
	public synchronized boolean canExecuteRequest(
			ContigTransferRequest request, Person person) throws SQLException {
		return contigTransferRequestManager.canExecuteRequest(request, person);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#moveContigs(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.data.Project)
	 */
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

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#addProjectChangeEventListener(uk.ac.sanger.arcturus.data.Project, uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener)
	 */
	public void addProjectChangeEventListener(Project project,
			ProjectChangeEventListener listener) {
		projectChangeEventNotifier.addProjectChangeEventListener(project,
				listener);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#addProjectChangeEventListener(uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener)
	 */
	public void addProjectChangeEventListener(
			ProjectChangeEventListener listener) {
		projectChangeEventNotifier.addProjectChangeEventListener(listener);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#removeProjectChangeEventListener(uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener)
	 */
	public void removeProjectChangeEventListener(
			ProjectChangeEventListener listener) {
		projectChangeEventNotifier.removeProjectChangeEventListener(listener);
	}

	/* (non-Javadoc)
	 * @see uk.ac.sanger.arcturus.jdbc.ArcturusDatabase#notifyProjectChangeEventListeners(uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent, java.lang.Class)
	 */
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

			// String separator = System.getProperty("file.separator");
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
		}
		
		return null;
	}
}
