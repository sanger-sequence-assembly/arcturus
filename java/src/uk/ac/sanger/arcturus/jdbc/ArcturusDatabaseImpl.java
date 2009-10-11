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

	public synchronized CloneManager getCloneManager() {
		return cloneManager;
	}

	public synchronized Clone getCloneByName(String name) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getCloneByName(" + name + ")");

		return cloneManager.getCloneByName(name);
	}

	public synchronized Clone getCloneByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getCloneByID(" + id + ")");

		return cloneManager.getCloneByID(id);
	}

	public synchronized Ligation getLigationByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getLigationByName(" + name + ")");

		return ligationManager.getLigationByName(name);
	}

	public synchronized Ligation getLigationByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getLigationByID(" + id + ")");

		return ligationManager.getLigationByID(id);
	}

	public synchronized Template getTemplateByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByName(" + name + ")");

		return templateManager.getTemplateByName(name);
	}

	public synchronized Template getTemplateByName(String name, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByName(" + name + ", " + autoload + ")");

		return templateManager.getTemplateByName(name, autoload);
	}

	public synchronized Template getTemplateByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByID(" + id + ")");

		return templateManager.getTemplateByID(id);
	}

	public synchronized Template getTemplateByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getTemplateByID(" + id + ", " + autoload + ")");

		return templateManager.getTemplateByID(id, autoload);
	}

	void registerNewTemplate(Template template) {
		templateManager.registerNewTemplate(template);
	}

	public synchronized Template findOrCreateTemplate(int id, String name,
			Ligation ligation) {
		return templateManager.findOrCreateTemplate(id, name, ligation);
	}

	public synchronized Read getReadByName(String name) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByName(" + name + ")");

		return readManager.getReadByName(name);
	}

	public synchronized Read getReadByName(String name, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByName(" + name + ", " + autoload + ")");

		return readManager.getReadByName(name, autoload);
	}

	public synchronized Read getReadByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByID(" + id + ")");

		return readManager.getReadByID(id);
	}

	public synchronized Read getReadByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getReadByID(" + id + ", " + autoload + ")");

		return readManager.getReadByID(id, autoload);
	}

	public synchronized int loadReadsByTemplate(int template_id)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("loadReadsByTemplate(" + template_id + ")");

		return readManager.loadReadsByTemplate(template_id);
	}

	void registerNewRead(Read read) {
		readManager.registerNewRead(read);
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

	public synchronized Sequence getSequenceByReadID(int readid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getSequenceByReadID(" + readid + ")");

		return sequenceManager.getSequenceByReadID(readid);
	}

	public synchronized Sequence getSequenceByReadID(int readid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger
					.info("getSequenceByReadID(" + readid + ", " + autoload
							+ ")");

		return sequenceManager.getSequenceByReadID(readid, autoload);
	}

	public synchronized Sequence getFullSequenceByReadID(int readid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceByReadID(" + readid + ")");

		return sequenceManager.getFullSequenceByReadID(readid);
	}

	public synchronized Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceByReadID(" + readid + ", " + autoload
					+ ")");

		return sequenceManager.getFullSequenceByReadID(readid, autoload);
	}

	public synchronized Sequence getSequenceBySequenceID(int seqid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getSequenceBySequenceID(seqid);
	}

	public synchronized Sequence getSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getSequenceBySequenceID(" + seqid + ", " + autoload
					+ ")");

		return sequenceManager.getSequenceBySequenceID(seqid, autoload);
	}

	public synchronized Sequence getFullSequenceBySequenceID(int seqid)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceBySequenceID(" + seqid + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid);
	}

	public synchronized Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getFullSequenceBySequenceID(" + seqid + ", "
					+ autoload + ")");

		return sequenceManager.getFullSequenceBySequenceID(seqid, autoload);
	}

	public synchronized void getDNAAndQualityForSequence(Sequence sequence)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
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
		if (logger != null && logger.isLoggable(Level.FINE))
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
		if (logger != null && logger.isLoggable(Level.FINE))
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
		if (logger != null && logger.isLoggable(Level.FINE))
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
	
	public synchronized Set<Contig> getChildContigs(Contig parent) throws SQLException {
		return contigManager.getChildContigs(parent);
	}

	public synchronized Project getProjectByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getProjectByID(" + id + ")");

		return projectManager.getProjectByID(id);
	}

	public synchronized Project getProjectByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger
					.info("getProjectByID(" + id + ", autoload=" + autoload
							+ ")");

		return projectManager.getProjectByID(id, true);
	}

	public synchronized Project getProjectByName(Assembly assembly, String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getProjectByName(assembly=" + assembly.getName()
					+ ", name=" + name + ")");

		return projectManager.getProjectByName(assembly, name);
	}

	public synchronized Set<Project> getAllProjects() throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAllProjects");

		return projectManager.getAllProjects();
	}

	public synchronized Set<Project> getProjectsForOwner(Person owner)
			throws SQLException {
		return projectManager.getProjectsForOwner(owner);
	}

	public synchronized Set<Project> getBinProjects()
			throws SQLException {
		return projectManager.getBinProjects();
	}

	public synchronized void refreshProject(Project project)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshProject(" + project + ")");

		projectManager.refreshProject(project);
	}

	public synchronized void refreshAllProject() throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshAllProjects");

		projectManager.refreshAllProjects();
	}

	public synchronized void setAssemblyForProject(Project project,
			Assembly assembly) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
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

	public synchronized boolean canUserUnlockProject(Project project,
			Person user) throws SQLException {
		return projectManager.canUserUnlockProject(project, user);
	}

	public synchronized boolean canUserLockProjectForSelf(Project project, Person user)
			throws SQLException {
		return projectManager.canUserLockProjectForSelf(project, user);
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

	public synchronized boolean setProjectLockOwner(Project project,
			Person person) throws SQLException, ProjectLockException {
		return (person == null || person.isNobody()) ?
				projectManager.unlockProject(project) :
				projectManager.setProjectLockOwner(project, person);
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

	public synchronized Assembly getAssemblyByID(int id) throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAssemblyByID(" + id + ")");

		return assemblyManager.getAssemblyByID(id);
	}

	public synchronized Assembly getAssemblyByID(int id, boolean autoload)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAssemblyByID(" + id + ", autoload=" + autoload
					+ ")");

		return assemblyManager.getAssemblyByID(id, true);
	}

	public synchronized Assembly getAssemblyByName(String name)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAssemblyByName(" + name + ")");

		return assemblyManager.getAssemblyByName(name);
	}

	public synchronized Assembly[] getAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("getAllAssemblies");

		return assemblyManager.getAllAssemblies();
	}

	public synchronized void refreshAssembly(Assembly assembly)
			throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshAssembly(" + assembly + ")");

		assemblyManager.refreshAssembly(assembly);
	}

	public synchronized void refreshAllAssemblies() throws SQLException {
		if (logger != null && logger.isLoggable(Level.FINE))
			logger.info("refreshAllAssemblies");

		assemblyManager.refreshAllAssemblies();
	}

	public synchronized boolean hasFullPrivileges(Person person) {
		return userManager.hasFullPrivileges(person);
	}

	public synchronized boolean hasFullPrivileges() throws SQLException {
		return userManager.hasFullPrivileges();
	}

	public synchronized boolean isCoordinator(Person person) {
		return userManager.isCoordinator(person);
	}

	public synchronized boolean isCoordinator() {
		return userManager.isCoordinator();
	}

	public synchronized Person[] getAllUsers(boolean includeNobody)
			throws SQLException {
		return userManager.getAllUsers(includeNobody);
	}

	public synchronized Person[] getAllUsers() throws SQLException {
		return userManager.getAllUsers(false);
	}

	public Person findUser(String username) {
		return userManager.findUser(username);
	}
	
	public Person findMe() {
		return userManager.findMe();
	}
	
	public boolean isMe(Person person) {
		return userManager.isMe(person);
	}
	
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

			if (dirname != null) {
				int lastSlash = dirname.lastIndexOf("/");
				
				if (lastSlash > -1)
					dirname = dirname.substring(0, lastSlash);
				
				defaultDirectory = dirname;
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

	public void preload(int type) throws SQLException {
		AbstractManager manager = getManagerForType(type);

		if (manager != null)
			manager.preload();			
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
		}
		
		return null;
	}
}
