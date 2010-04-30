package uk.ac.sanger.arcturus.database;

import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Map;
import java.util.Set;
import java.util.logging.Logger;
import java.util.zip.DataFormatException;

import javax.sql.DataSource;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequest;
import uk.ac.sanger.arcturus.contigtransfer.ContigTransferRequestException;
import uk.ac.sanger.arcturus.data.Assembly;
import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.people.Person;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEvent;
import uk.ac.sanger.arcturus.projectchange.ProjectChangeEventListener;
import uk.ac.sanger.arcturus.utils.ProjectSummary;

public interface ArcturusDatabase {
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
	
	public static final int READ = 1;
	public static final int SEQUENCE = 2;
	public static final int CONTIG = 3;
	public static final int TEMPLATE = 4;
	public static final int LIGATION = 5;
	public static final int CLONE = 6;
	public static final int PROJECT = 7;
	public static final int ASSEMBLY = 8;

	/**
	 * Closes the connection pool belonging to this object.
	 */

	public void closeConnectionPool();

	/**
	 * Returns the DataSource which was used to create this object.
	 * 
	 * @return the DataSource which was used to create this object.
	 */

	public DataSource getDataSource();

	/**
	 * Returns the description which was used to create this object.
	 * 
	 * @return the description which was used to create this object.
	 */

	public String getDescription();

	/**
	 * Returns the name which was used to create this object.
	 * 
	 * @return the name which was used to create this object.
	 */

	public String getName();

	/**
	 * Returns the instance which created this object.
	 * 
	 * @return the instance which created this object.
	 */

	public ArcturusInstance getInstance();

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

	public Connection getConnection() throws SQLException;

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

	public Connection getPooledConnection(Object owner)
			throws SQLException;

	/**
	 * Sets the logger for this object.
	 * 
	 * @param logger
	 *            the Logger to which logging messages will be sent.
	 */

	public void setLogger(Logger logger);

	/**
	 * Gets the logger for this object.
	 * 
	 * @return the Logger to which logging messages will be sent.
	 */

	public Logger getLogger();
	
	public void setCacheing(int type, boolean cacheing);
	
	public boolean isCacheing(int type);
	
	public void clearCache(int type);
	
	public void preload(int type) throws SQLException;

	public Clone getCloneByName(String name) throws SQLException;

	public Clone getCloneByID(int id) throws SQLException;

	public Ligation getLigationByName(String name) throws SQLException;

	public Ligation getLigationByID(int id) throws SQLException;

	public Template getTemplateByName(String name) throws SQLException;

	public Template getTemplateByName(String name, boolean autoload)
			throws SQLException;

	public Template getTemplateByID(int id) throws SQLException;

	public Template getTemplateByID(int id, boolean autoload)
			throws SQLException;

	public Template findOrCreateTemplate(int id, String name,
			Ligation ligation);

	public Read getReadByName(String name) throws SQLException;

	public Read getReadByName(String name, boolean autoload)
			throws SQLException;

	public Read getReadByID(int id) throws SQLException;

	public Read getReadByID(int id, boolean autoload)
			throws SQLException;

	public int loadReadsByTemplate(int template_id)
			throws SQLException;

	public Read findOrCreateRead(int id, String name,
			Template template, java.util.Date asped, String strand,
			String primer, String chemistry);

	public int[] getUnassembledReadIDList() throws SQLException;

	public Sequence getSequenceByReadID(int readid)
			throws SQLException;

	public Sequence getSequenceByReadID(int readid, boolean autoload)
			throws SQLException;

	public Sequence getFullSequenceByReadID(int readid)
			throws SQLException;

	public Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws SQLException;

	public Sequence getSequenceBySequenceID(int seqid)
			throws SQLException;

	public Sequence getSequenceBySequenceID(int seqid, boolean autoload)
			throws SQLException;

	public Sequence getFullSequenceBySequenceID(int seqid)
			throws SQLException;

	public Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException;

	public void getDNAAndQualityForSequence(Sequence sequence)
			throws SQLException;

	public Sequence findOrCreateSequence(int seq_id, int length);

	public Contig getContigByID(int id, int options)
			throws SQLException, DataFormatException;

	public Contig getContigByID(int id) throws SQLException,
			DataFormatException;

	public Contig getContigByReadName(String readname, int options)
			throws SQLException, DataFormatException;

	public Contig getContigByReadName(String readname)
			throws SQLException, DataFormatException;

	public void updateContig(Contig contig, int options)
			throws SQLException, DataFormatException;

	public boolean isCurrentContig(int contigid) throws SQLException;

	public int[] getCurrentContigIDList() throws SQLException;

	public int countCurrentContigs(int minlen) throws SQLException;

	public int countCurrentContigs() throws SQLException;

	public int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws SQLException, DataFormatException;

	public int processCurrentContigs(int options,
			ContigProcessor processor) throws SQLException, DataFormatException;

	public Set getCurrentContigs(int options, int minlen)
			throws SQLException, DataFormatException;

	public Set getCurrentContigs(int options) throws SQLException,
			DataFormatException;

	public int countContigsByProject(int project_id, int minlen)
			throws SQLException;

	public int countContigsByProject(int project_id)
			throws SQLException;

	public int processContigsByProject(int project_id, int options,
			int minlen, ContigProcessor processor) throws SQLException,
			DataFormatException;

	public int processContigsByProject(int project_id, int options,
			ContigProcessor processor) throws SQLException, DataFormatException;

	public Set<Contig> getContigsByProject(int project_id,
			int options, int minlen) throws SQLException, DataFormatException;

	public Set getContigsByProject(int project_id, int options)
			throws SQLException, DataFormatException;

	public Set<Contig> getChildContigs(Contig parent)
			throws SQLException;

	public Project getProjectByID(int id) throws SQLException;

	public Project getProjectByID(int id, boolean autoload)
			throws SQLException;

	public Project getProjectByName(Assembly assembly, String name)
			throws SQLException;

	public Set<Project> getAllProjects() throws SQLException;

	public Set<Project> getProjectsForOwner(Person owner)
			throws SQLException;
	
	public Set<Project>getBinProjects() throws SQLException;

	public void refreshProject(Project project) throws SQLException;

	public void refreshAllProject() throws SQLException;

	public void setAssemblyForProject(Project project,
			Assembly assembly) throws SQLException;

	public void getProjectSummary(Project project, int minlen,
			int minreads, ProjectSummary summary) throws SQLException;

	public ProjectSummary getProjectSummary(Project project,
			int minlen, int minreads) throws SQLException;

	public void getProjectSummary(Project project, int minlen,
			ProjectSummary summary) throws SQLException;

	public void getProjectSummary(Project project,
			ProjectSummary summary) throws SQLException;

	public ProjectSummary getProjectSummary(Project project, int minlen)
			throws SQLException;

	public ProjectSummary getProjectSummary(Project project)
			throws SQLException;

	public Map getProjectSummary(int minlen, int minreads)
			throws SQLException;

	public Map getProjectSummary(int minlen) throws SQLException;

	public Map getProjectSummary() throws SQLException;

	public boolean canUserUnlockProject(Project project, Person user)
			throws SQLException;

	public boolean canUserLockProjectForSelf(Project project,
			Person user) throws SQLException;

	public boolean canUserLockProject(Project project, Person user)
			throws SQLException;

	public boolean canUserLockProjectForOwner(Project project,
			Person user) throws SQLException;

	public boolean unlockProject(Project project) throws SQLException,
			ProjectLockException;

	public boolean lockProject(Project project) throws SQLException,
			ProjectLockException;

	public boolean unlockProjectForExport(Project project)
			throws SQLException, ProjectLockException;

	public boolean lockProjectForExport(Project project)
			throws SQLException, ProjectLockException;

	public boolean lockProjectForOwner(Project project)
			throws SQLException, ProjectLockException;

	public boolean setProjectLockOwner(Project project, Person person)
			throws SQLException, ProjectLockException;

	public void setProjectOwner(Project project, Person person)
			throws SQLException;

	public boolean createNewProject(Assembly assembly, String name,
			Person owner, String directory) throws SQLException, IOException;

	public boolean canUserChangeProjectStatus(Project project,
			Person user) throws SQLException;

	public boolean canUserChangeProjectStatus(Project project)
			throws SQLException;

	public boolean changeProjectStatus(Project project, int status)
			throws SQLException;

	public boolean retireProject(Project project) throws SQLException;

	public Project getBinForProject(Project project)
			throws SQLException;

	public Assembly getAssemblyByID(int id) throws SQLException;

	public Assembly getAssemblyByID(int id, boolean autoload)
			throws SQLException;

	public Assembly getAssemblyByName(String name) throws SQLException;

	public Assembly[] getAllAssemblies() throws SQLException;

	public void refreshAssembly(Assembly assembly) throws SQLException;

	public void refreshAllAssemblies() throws SQLException;

	public boolean hasFullPrivileges(Person person);

	public boolean hasFullPrivileges() throws SQLException;

	public boolean isCoordinator(Person person);

	public boolean isCoordinator();

	public Person[] getAllUsers(boolean includeNobody)
			throws SQLException;

	public Person[] getAllUsers() throws SQLException;

	public Person findUser(String username);

	public Person findMe();

	public boolean isMe(Person person);

	public ContigTransferRequest[] getContigTransferRequestsByUser(
			Person user, int mode) throws SQLException;

	public ContigTransferRequest createContigTransferRequest(
			Person requester, int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException;

	public ContigTransferRequest createContigTransferRequest(
			int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException;

	public ContigTransferRequest createContigTransferRequest(
			Person requester, Contig contig, Project project)
			throws ContigTransferRequestException, SQLException;

	public ContigTransferRequest createContigTransferRequest(
			Contig contig, Project project)
			throws ContigTransferRequestException, SQLException;

	public void reviewContigTransferRequest(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException;

	public void reviewContigTransferRequest(int requestId,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException;

	public void reviewContigTransferRequest(int requestId,
			int newStatus) throws ContigTransferRequestException, SQLException;

	public void executeContigTransferRequest(
			ContigTransferRequest request, Person reviewer,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException;

	public void executeContigTransferRequest(int requestId,
			Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, SQLException;

	public void executeContigTransferRequest(int requestId,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException;

	public void setDebugging(boolean debugging);

	public boolean canCancelRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public boolean canRefuseRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public boolean canApproveRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public boolean canExecuteRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public void moveContigs(Project fromProject, Project toProject)
			throws SQLException;

	public void addProjectChangeEventListener(Project project,
			ProjectChangeEventListener listener);

	public void addProjectChangeEventListener(
			ProjectChangeEventListener listener);

	public void removeProjectChangeEventListener(
			ProjectChangeEventListener listener);

	public void notifyProjectChangeEventListeners(
			ProjectChangeEvent event, Class listenerClass);

	public String[] getAllDirectories();
}