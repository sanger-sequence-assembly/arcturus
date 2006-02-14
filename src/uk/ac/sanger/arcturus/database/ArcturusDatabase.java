package uk.ac.sanger.arcturus.database;

import java.io.PrintStream;
import java.sql.*;
import javax.sql.*;
import java.util.HashMap;
import java.util.Set;
import java.util.zip.DataFormatException;

import org.apache.log4j.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

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

    public static final int CONTIG_TO_CALCULATE_CONSENSUS =
	CONTIG_BASIC_DATA | CONTIG_MAPPINGS_READS_AND_TEMPLATES | 
	CONTIG_SEQUENCE_DNA_AND_QUALITY | CONTIG_MAPPING_SEGMENTS;

    public static final int CONTIG_TO_GENERATE_CAF =
	CONTIG_BASIC_DATA | CONTIG_MAPPINGS_READS_AND_TEMPLATES |
	CONTIG_SEQUENCE_DNA_AND_QUALITY |CONTIG_CONSENSUS |
	CONTIG_SEQUENCE_AUXILIARY_DATA | CONTIG_MAPPING_SEGMENTS |
	CONTIG_TAGS;

    public static final int CONTIG_TO_DISPLAY_SCAFFOLDS =
	CONTIG_BASIC_DATA | CONTIG_MAPPINGS_READS_AND_TEMPLATES | CONTIG_TAGS;

    public static final int CONTIG_TO_DISPLAY_FAMILY_TREE =
	CONTIG_BASIC_DATA | CONTIG_TAGS;

    public static final int CONTIG_MAPPING_RELATED_DATA =
	CONTIG_MAPPINGS_READS_AND_TEMPLATES | CONTIG_SEQUENCE_DNA_AND_QUALITY |
	CONTIG_SEQUENCE_AUXILIARY_DATA | CONTIG_MAPPING_SEGMENTS;

    protected DataSource ds;
    protected String description;
    protected String name;
    protected Connection defaultConnection;
    protected HashMap namedConnections;
    protected Logger logger = null;

    /**
     * Creates a new ArcturusDatabase object from a DataSource, a description
     * and a name.
     *
     * @param ds the DataSource which will be used to obtain JDBC Connection
     * objects.
     *
     * @param description a text description of the species which this database
     * contains.
     *
     * @param name the short name for this database.
     */

    public ArcturusDatabase(DataSource ds, String description, String name) 
	throws SQLException {
	this.ds = ds;
	this.description = description;
	this.name = name;

	initialise();
    }

    /**
     * Creates a new ArcturusDatabase object from an Organism object.
     *
     * @param organism the Organism from which to create the ArcturusDatabase.
     */

    public ArcturusDatabase(Organism organism) throws SQLException {
	this.name = organism.getName();
	this.description = organism.getDescription();
	this.ds = organism.getDataSource();

	initialise();
    }

    private void initialise() throws SQLException {
	namedConnections = new HashMap();

	createManagers();
    }

    /**
     * Returns the DataSource which was used to create this object.
     *
     * @return the DataSource which was used to create this object.
     */

    public DataSource getDataSource() { return ds; }

    /**
     * Returns the description which was used to create this object.
     *
     * @return the description which was used to create this object.
     */

    public String getDescription() { return description; }

    /**
     * Returns the name which was used to create this object.
     *
     * @return the name which was used to create this object.
     */

    public String getName() { return name; }

    /**
     * Establishes a JDBC connection to a database, using the parameters stored in
     * this object's DataSource, and the specified username and password.
     *
     * @return a java.sql.Connection which can be used to communicate with the database.
     *
     * @throws SQLException in the event of an error when establishing a connection with
     * the database.
     */

    public Connection getConnection() throws SQLException {
	if (defaultConnection == null)
	    defaultConnection = ds.getConnection();

	return defaultConnection;
    }

    /**
     * Establishes a JDBC connection to a database, using the parameters stored in
     * this object's DataSource.
     *
     * @param username the username which should be used to connect to the database.
     * This overrides the username, if any, in the DataSource object.
     *
     * @param password the pasword  which should be used to connect to the database.
     * This overrides the password, if any, in the DataSource object.
     *
     * @return a java.sql.Connection which can be used to communicate with the database.
     *
     * @throws SQLException in the event of an error when establishing a connection with
     * the database.
     */

    public Connection getConnection(String username, String password) throws SQLException {
	Object obj = namedConnections.get(username);

	if (obj != null)
	    return (Connection)obj;

	Connection conn = ds.getConnection(username, password);

	if (conn != null)
	    namedConnections.put(username, conn);

	return conn;
    }

    /**
     * Creates a DataSource object which represents a connection to a MySQL database.
     *
     * @param hostname the hostname of the MySQL instance.
     *
     * @param port the port number on which the MySQL instance is listening for TCP/IP
     * connections.
     *
     * @param database the name of the MySQL database.
     *
     * @param username the default username.
     *
     * @param password the default password.
     *
     * @return a DataSource object which can be used to establish a connection to the
     * MySQL database.
     *
     * @throws SQLException in the event of an error.
     */

    public static DataSource createMysqlDataSource(String hostname, int port, String database,
						   String username, String password)
	throws SQLException {
	com.mysql.jdbc.jdbc2.optional.MysqlDataSource mysqlds =
	    new com.mysql.jdbc.jdbc2.optional.MysqlDataSource();

	mysqlds.setServerName(hostname);
	mysqlds.setDatabaseName(database);
	mysqlds.setPort(port);
	mysqlds.setUser(username);
	mysqlds.setPassword(password);

	return (DataSource)mysqlds;
    }

    /**
     * Creates a DataSource object which represents a connection to a Oracle database.
     *
     * @param hostname the hostname of the Oracle instance.
     *
     * @param port the port number on which the Oracle instance is listening for TCP/IP
     * connections.
     *
     * @param database the name of the Oracle database.
     *
     * @param username the default username.
     *
     * @param password the default password.
     *
     * @return a DataSource object which can be used to establish a connection to the
     * Oracle database.
     *
     * @throws SQLException in the event of an error.
     */

    public static DataSource createOracleDataSource(String hostname, int port, String database,
						    String username, String password)
	throws SQLException {
	oracle.jdbc.pool.OracleDataSource oracleds =
	    new oracle.jdbc.pool.OracleDataSource();

	oracleds.setServerName(hostname);
	oracleds.setDatabaseName(database);
	oracleds.setPortNumber(port);
	oracleds.setUser(username);
	oracleds.setPassword(password);
	oracleds.setDriverType("thin");

	return (DataSource)oracleds;
    }

    /**
     * Creates a DataSource object which represents a connection to a database.
     *
     * @param hostname the hostname of the database instance.
     *
     * @param port the port number on which the database instance is listening for TCP/IP
     * connections.
     *
     * @param database the name of the database.
     *
     * @param username the default username.
     *
     * @param password the default password.
     *
     * @param type specifies the type of database server. It should be one of MYSQL or
     * ORACLE.
     *
     * @return a DataSource object which can be used to establish a connection to the
     * database.
     *
     * @throws SQLException in the event of an error.
     */

    public static DataSource createDataSource(String hostname, int port, String database,
					      String username, String password, int type)
	throws SQLException {
	switch (type) {
	case MYSQL:
	    return createMysqlDataSource(hostname, port, database, username, password);

	case ORACLE:
	    return createOracleDataSource(hostname, port, database, username, password);

	default:
	    return null;
	}
    }

    /**
     * Sets the logger for this object.
     *
     * @param logger the Logger to which logging messages will be sent.
     */

    public void setLogger(Logger logger) {
	this.logger = logger;
    }

    /**
     * Gets the logger for this object.
     *
     * @return the Logger to which logging messages will be sent.
     */

    public Logger getLogger() { return logger; }

    /*
     * This section of code is concerned with the manager objects which
     * provide services to the ArcturusDatabase.
     */

    protected CloneManager cloneManager;
    protected LigationManager ligationManager;
    protected TemplateManager templateManager;
    protected ReadManager readManager;
    protected SequenceManager sequenceManager;
    protected ContigManager contigManager;
    protected ProjectManager projectManager;
    protected AssemblyManager assemblyManager;

    private void createManagers() throws SQLException {
	cloneManager = new CloneManager(this);
	ligationManager = new LigationManager(this);
	templateManager = new TemplateManager(this);
	readManager = new ReadManager(this);
	sequenceManager = new SequenceManager(this);
	contigManager = new ContigManager(this);
	projectManager = new ProjectManager(this);
	assemblyManager = new AssemblyManager(this);
    }

    /**
     * Returns the CloneManager belonging to this ArcturusDatabase.
     *
     * @return the CloneManager belonging to this ArcturusDatabase.
     */

    public CloneManager getCloneManager() { return cloneManager; }

    public Clone getCloneByName(String name) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getCloneByName(" + name + ")");

	return cloneManager.getCloneByName(name);
    }

    public Clone getCloneByID(int id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getCloneByID(" + id + ")");

	return cloneManager.getCloneByID(id);
    }

    public void preloadAllClones() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("preloadAllClones()");

	cloneManager.preloadAllClones();
    }

    public void clearCloneCache() {
	cloneManager.clearCache();
    }

    /**
     * Returns the LigationManager belonging to this ArcturusDatabase.
     *
     * @return the LigationManager belonging to this ArcturusDatabase.
     */

    public LigationManager getLigationManager() { return ligationManager; }

    public Ligation getLigationByName(String name) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getLigationByName(" + name + ")");

	return ligationManager.getLigationByName(name);
    }

    public Ligation getLigationByID(int id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getLigationByID(" + id + ")");

	return ligationManager.getLigationByID(id);
    }

    public void preloadAllLigations() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("preloadAllLigations()");

	ligationManager.preloadAllLigations();
    }

    public void clearLigationCache() {
	ligationManager.clearCache();
    }

    /**
     * Returns the TemplateManager belonging to this ArcturusDatabase.
     *
     * @return the TemplateManager belonging to this ArcturusDatabase.
     */

    public TemplateManager getTemplateManager() { return templateManager; }

    public Template getTemplateByName(String name) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getTemplateByName(" + name + ")");

	return templateManager.getTemplateByName(name);
    }

    public Template getTemplateByName(String name, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getTemplateByName(" + name + ", " + autoload + ")");

	return templateManager.getTemplateByName(name, autoload);
    }

    public Template getTemplateByID(int id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getTemplateByID(" + id + ")");

	return templateManager.getTemplateByID(id);
    }

    public Template getTemplateByID(int id, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getTemplateByID(" + id + ", " + autoload + ")");

	return templateManager.getTemplateByID(id, autoload);
    }

    void registerNewTemplate(Template template) {
	templateManager.registerNewTemplate(template);
    }

    public void preloadAllTemplates() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("preloadAllTemplates()");

	templateManager.preloadAllTemplates();
    }

    public Template findOrCreateTemplate(int id, String name, Ligation ligation) {
	return templateManager.findOrCreateTemplate(id, name, ligation);
    }

    public void clearTemplateCache() {
	templateManager.clearCache();
    }

    /**
     * Returns the ReadManager belonging to this ArcturusDatabase.
     *
     * @return the ReadManager belonging to this ArcturusDatabase.
     */

    public ReadManager getReadManager() { return readManager; }

    public Read getReadByName(String name) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getReadByName(" + name + ")");

	return readManager.getReadByName(name);
    }

    public Read getReadByName(String name, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getReadByName(" + name + ", " + autoload + ")");

	return readManager.getReadByName(name, autoload);
    }

    public Read getReadByID(int id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getReadByID(" + id + ")");

	return readManager.getReadByID(id);
    }

    public Read getReadByID(int id, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getReadByID(" + id + ", " + autoload + ")");

	return readManager.getReadByID(id, autoload);
    }

    public int loadReadsByTemplate(int template_id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("loadReadsByTemplate(" + template_id + ")");

	return readManager.loadReadsByTemplate(template_id);
    }

    void registerNewRead(Read read) {
	readManager.registerNewRead(read);
    }

    public void preloadAllReads() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("preloadAllReads()");

	readManager.preloadAllReads();
    }

    public int parseStrand(String text) {
	return ReadManager.parseStrand(text);
    }

    public int parsePrimer(String text) {
	return ReadManager.parsePrimer(text);
    }

    public int parseChemistry(String text) {
	return ReadManager.parseChemistry(text);
    }

    public Read findOrCreateRead(int id, String name, Template template, java.util.Date asped,
				 String strand, String primer, String chemistry) {
	return readManager.findOrCreateRead(id, name, template, asped, strand, primer, chemistry);
    }

    public int[] getUnassembledReadIDList() throws SQLException {
	return readManager.getUnassembledReadIDList();
    }

    public void clearReadCache() {
	readManager.clearCache();
    }

    /**
     * Returns the SequenceManager belonging to this ArcturusDatabase.
     *
     * @return the SequenceManager belonging to this ArcturusDatabase.
     */

    public SequenceManager getSequenceManager() { return sequenceManager; }

    public Sequence getSequenceByReadID(int readid) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getSequenceByReadID(" + readid + ")");

	return sequenceManager.getSequenceByReadID(readid);
    }

    public Sequence getSequenceByReadID(int readid, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getSequenceByReadID(" + readid + ", " + autoload + ")");

	return sequenceManager.getSequenceByReadID(readid, autoload);
    }

    public Sequence getFullSequenceByReadID(int readid) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getFullSequenceByReadID(" + readid + ")");

	return sequenceManager.getFullSequenceByReadID(readid);
    }

    public Sequence getFullSequenceByReadID(int readid, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getFullSequenceByReadID(" + readid + ", " + autoload + ")");

	return sequenceManager.getFullSequenceByReadID(readid, autoload);
    }

    public Sequence getSequenceBySequenceID(int seqid) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getSequenceBySequenceID(" + seqid + ")");

	return sequenceManager.getSequenceBySequenceID(seqid);
    }

    public Sequence getSequenceBySequenceID(int seqid, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getSequenceBySequenceID(" + seqid + ", " + autoload + ")");

	return sequenceManager.getSequenceBySequenceID(seqid, autoload);
    }

    public Sequence getFullSequenceBySequenceID(int seqid) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getFullSequenceBySequenceID(" + seqid + ")");

	return sequenceManager.getFullSequenceBySequenceID(seqid);
    }

    public Sequence getFullSequenceBySequenceID(int seqid, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getFullSequenceBySequenceID(" + seqid + ", " + autoload + ")");

	return sequenceManager.getFullSequenceBySequenceID(seqid, autoload);
    }

    public void getDNAAndQualityForSequence(Sequence sequence) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getDNAAndQualityForSequence(seqid=" + sequence.getID() + ")");

	sequenceManager.getDNAAndQualityForSequence(sequence);
    }

    void registerNewSequence(Sequence sequence) {
	sequenceManager.registerNewSequence(sequence);
    }

    byte[] decodeCompressedData(byte[] compressed, int length) {
	return sequenceManager.decodeCompressedData(compressed, length);
    }

    public Sequence findOrCreateSequence(int seq_id, int length) {
	return sequenceManager.findOrCreateSequence(seq_id, length);
    }

    public void clearSequenceCache() {
	sequenceManager.clearCache();
    }

    /**
     * Returns the ContigManager belonging to this ArcturusDatabase.
     *
     * @return the ContigManager belonging to this ArcturusDatabase.
     */

    public ContigManager getContigManager() { return contigManager; }

    public Contig getContigByID(int id, int options) throws SQLException, DataFormatException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getContigByID(" + id + ", options = " + options + ")");

	return contigManager.getContigByID(id, options);
    }

    public int[] getCurrentContigIDList() throws SQLException {
	return contigManager.getCurrentContigIDList();
    }

    public int countContigsByProject(int project_id, int minlen) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("countContigsByProject(" + project_id + ", " + minlen + ")");

	return contigManager.countContigsByProject(project_id, minlen);
    }

    public int countContigsByProject(int project_id) throws SQLException {
	return countContigsByProject(project_id, 0);
    }

    public int processContigsByProject(int project_id, int options, int minlen, ContigProcessor processor)
	throws SQLException, DataFormatException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("processContigsByProject(" + project_id + ", options=" + options + ", minlen=" + minlen + ")");

	return contigManager.processContigsByProject(project_id, options, minlen, processor);
    }
	
    public int processContigsByProject(int project_id, int options, ContigProcessor processor)
	throws SQLException, DataFormatException {
	return processContigsByProject(project_id, options, 0, processor);
    }

    public Set getContigsByProject(int project_id, int options, int minlen) throws SQLException, DataFormatException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getContigsByProject(" + project_id + ", options=" + options + ", minlen=" + minlen + ")");

	return contigManager.getContigsByProject(project_id, options, minlen);
    }

    public Set getContigsByProject(int project_id, int options) throws SQLException, DataFormatException {
	return getContigsByProject(project_id, options, 0);
    }

    public void addContigManagerEventListener(ManagerEventListener listener) {
	contigManager.addContigManagerEventListener(listener);
    }

    public void removeContigManagerEventListener(ManagerEventListener listener) {
	contigManager.removeContigManagerEventListener(listener);
    }

    public void clearContigCache() {
	contigManager.clearCache();
    }

     /**
     * Returns the ProjectManager belonging to this ArcturusDatabase.
     *
     * @return the ProjectManager belonging to this ArcturusDatabase.
     */

    public ProjectManager getProjectManager() { return projectManager; }

    public Project getProjectByID(int id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getProjectByID(" + id + ")");

	return projectManager.getProjectByID(id);
    }

    public Project getProjectByID(int id, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getProjectByID(" + id + ", autoload=" + autoload + ")");

	return projectManager.getProjectByID(id, true);
    }

    public Project getProjectByName(Assembly assembly, String name) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getProjectByName(assembly=" + assembly.getName() + ", name=" + name + ")");

	return projectManager.getProjectByName(assembly, name);
    }

    public void preloadAllProjects() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("preloadAllProjects");

	projectManager.preloadAllProjects();
    }

    public Set getAllProjects() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getAllProjects");

	return projectManager.getAllProjects();
    }

    public void refreshProject(Project project) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("refreshProject(" + project + ")");

	projectManager.refreshProject(project);
    }

    public void refreshAllProject() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("refreshAllProjects");

	projectManager.refreshAllProjects();
    }

    public void setAssemblyForProject(Project project, Assembly assembly) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("setAssemblyForProject(" + project + ", " + assembly + ")");

	projectManager.setAssemblyForProject(project, assembly);
    }

    public void getProjectSummary(Project project, int minlen, ProjectSummary summary) throws SQLException {
	projectManager.getProjectSummary(project, minlen, summary);
    }

    public void getProjectSummary(Project project, ProjectSummary summary) throws SQLException {
	projectManager.getProjectSummary(project, summary);
    }

    public ProjectSummary getProjectSummary(Project project, int minlen) throws SQLException {
	return projectManager.getProjectSummary(project, minlen);
    }

    public ProjectSummary getProjectSummary(Project project) throws SQLException {
	return projectManager.getProjectSummary(project);
    }

   public void clearProjectCache() {
	projectManager.clearCache();
    }

     /**
     * Returns the AssemblyManager belonging to this ArcturusDatabase.
     *
     * @return the AssemblyManager belonging to this ArcturusDatabase.
     */

    public AssemblyManager getAssemblyManager() { return assemblyManager; }

    public Assembly getAssemblyByID(int id) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getAssemblyByID(" + id + ")");

	return assemblyManager.getAssemblyByID(id);
    }

    public Assembly getAssemblyByID(int id, boolean autoload) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getAssemblyByID(" + id + ", autoload=" + autoload + ")");

	return assemblyManager.getAssemblyByID(id, true);
    }

    public Assembly getAssemblyByName(String name) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getAssemblyByName(" + name + ")");

	return assemblyManager.getAssemblyByName(name);
    }

    public void preloadAllAssemblies() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("preloadAllProjects");

	assemblyManager.preloadAllAssemblies();
    }

    public Set getAllAssemblies() {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("getAllAssemblies");

	return assemblyManager.getAllAssemblies();
    }

    public void refreshAssembly(Assembly assembly) throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("refreshAssembly(" + assembly + ")");

	assemblyManager.refreshAssembly(assembly);
    }

    public void refreshAllAssemblies() throws SQLException {
	if (logger != null && logger.isDebugEnabled())
	    logger.debug("refreshAllAssemblies");

	assemblyManager.refreshAllAssemblies();
    }

    public void clearAssemblyCache() {
	assemblyManager.clearCache();
    }

   /**
     * Returns a text representation of this object.
     *
     * @return a text representation of this object.
     */

    public String toString() {
	String text = "ArcturusDatabase[name=" + name;

	if (description != null)
	    text += ", description=" + description;

	text += "]";

	return text;
    }
}
