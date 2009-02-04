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

	/**
	 * Closes the connection pool belonging to this object.
	 */

	public abstract void closeConnectionPool();

	/**
	 * Returns the DataSource which was used to create this object.
	 * 
	 * @return the DataSource which was used to create this object.
	 */

	public abstract DataSource getDataSource();

	/**
	 * Returns the description which was used to create this object.
	 * 
	 * @return the description which was used to create this object.
	 */

	public abstract String getDescription();

	/**
	 * Returns the name which was used to create this object.
	 * 
	 * @return the name which was used to create this object.
	 */

	public abstract String getName();

	/**
	 * Returns the instance which created this object.
	 * 
	 * @return the instance which created this object.
	 */

	public abstract ArcturusInstance getInstance();

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

	public abstract Connection getConnection() throws SQLException;

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

	public abstract Connection getPooledConnection(Object owner)
			throws SQLException;

	/**
	 * Sets the logger for this object.
	 * 
	 * @param logger
	 *            the Logger to which logging messages will be sent.
	 */

	public abstract void setLogger(Logger logger);

	/**
	 * Gets the logger for this object.
	 * 
	 * @return the Logger to which logging messages will be sent.
	 */

	public abstract Logger getLogger();
	
	public abstract void setCacheing(int type, boolean cacheing);
	
	public abstract boolean isCacheing(int type);
	
	public abstract void clearCache(int type);

	public abstract Clone getCloneByName(String name) throws SQLException;

	public abstract Clone getCloneByID(int id) throws SQLException;

	public abstract void preloadAllClones() throws SQLException;

	public abstract void clearCloneCache();

	public abstract Ligation getLigationByName(String name) throws SQLException;

	public abstract Ligation getLigationByID(int id) throws SQLException;

	public abstract void preloadAllLigations() throws SQLException;

	public abstract void clearLigationCache();

	public abstract Template getTemplateByName(String name) throws SQLException;

	public abstract Template getTemplateByName(String name, boolean autoload)
			throws SQLException;

	public abstract Template getTemplateByID(int id) throws SQLException;

	public abstract Template getTemplateByID(int id, boolean autoload)
			throws SQLException;

	public abstract void preloadAllTemplates() throws SQLException;

	public abstract Template findOrCreateTemplate(int id, String name,
			Ligation ligation);

	public abstract void clearTemplateCache();

	public abstract void setTemplateCacheing(boolean cacheing);

	public abstract boolean isTemplateCacheing();

	public abstract Read getReadByName(String name) throws SQLException;

	public abstract Read getReadByName(String name, boolean autoload)
			throws SQLException;

	public abstract Read getReadByID(int id) throws SQLException;

	public abstract Read getReadByID(int id, boolean autoload)
			throws SQLException;

	public abstract int loadReadsByTemplate(int template_id)
			throws SQLException;

	public abstract void preloadAllReads() throws SQLException;

	public abstract int parseStrand(String text);

	public abstract int parsePrimer(String text);

	public abstract int parseChemistry(String text);

	public abstract Read findOrCreateRead(int id, String name,
			Template template, java.util.Date asped, String strand,
			String primer, String chemistry);

	public abstract int[] getUnassembledReadIDList() throws SQLException;

	public abstract void clearReadCache();

	public abstract void setReadCacheing(boolean cacheing);

	public abstract boolean isReadCacheing();

	public abstract Sequence getSequenceByReadID(int readid)
			throws SQLException;

	public abstract Sequence getSequenceByReadID(int readid, boolean autoload)
			throws SQLException;

	public abstract Sequence getFullSequenceByReadID(int readid)
			throws SQLException;

	public abstract Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws SQLException;

	public abstract Sequence getSequenceBySequenceID(int seqid)
			throws SQLException;

	public abstract Sequence getSequenceBySequenceID(int seqid, boolean autoload)
			throws SQLException;

	public abstract Sequence getFullSequenceBySequenceID(int seqid)
			throws SQLException;

	public abstract Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws SQLException;

	public abstract void getDNAAndQualityForSequence(Sequence sequence)
			throws SQLException;

	public abstract Sequence findOrCreateSequence(int seq_id, int length);

	public abstract void clearSequenceCache();

	public abstract void setSequenceCacheing(boolean cacheing);

	public abstract boolean isSequenceCacheing();

	public abstract Contig getContigByID(int id, int options)
			throws SQLException, DataFormatException;

	public abstract Contig getContigByID(int id) throws SQLException,
			DataFormatException;

	public abstract Contig getContigByReadName(String readname, int options)
			throws SQLException, DataFormatException;

	public abstract Contig getContigByReadName(String readname)
			throws SQLException, DataFormatException;

	public abstract void updateContig(Contig contig, int options)
			throws SQLException, DataFormatException;

	public abstract boolean isCurrentContig(int contigid) throws SQLException;

	public abstract int[] getCurrentContigIDList() throws SQLException;

	public abstract int countCurrentContigs(int minlen) throws SQLException;

	public abstract int countCurrentContigs() throws SQLException;

	public abstract int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws SQLException, DataFormatException;

	public abstract int processCurrentContigs(int options,
			ContigProcessor processor) throws SQLException, DataFormatException;

	public abstract Set getCurrentContigs(int options, int minlen)
			throws SQLException, DataFormatException;

	public abstract Set getCurrentContigs(int options) throws SQLException,
			DataFormatException;

	public abstract int countContigsByProject(int project_id, int minlen)
			throws SQLException;

	public abstract int countContigsByProject(int project_id)
			throws SQLException;

	public abstract int processContigsByProject(int project_id, int options,
			int minlen, ContigProcessor processor) throws SQLException,
			DataFormatException;

	public abstract int processContigsByProject(int project_id, int options,
			ContigProcessor processor) throws SQLException, DataFormatException;

	public abstract Set<Contig> getContigsByProject(int project_id,
			int options, int minlen) throws SQLException, DataFormatException;

	public abstract Set getContigsByProject(int project_id, int options)
			throws SQLException, DataFormatException;

	public abstract void clearContigCache();

	public abstract Set<Contig> getChildContigs(Contig parent)
			throws SQLException;

	public abstract Project getProjectByID(int id) throws SQLException;

	public abstract Project getProjectByID(int id, boolean autoload)
			throws SQLException;

	public abstract Project getProjectByName(Assembly assembly, String name)
			throws SQLException;

	public abstract void preloadAllProjects() throws SQLException;

	public abstract Set<Project> getAllProjects() throws SQLException;

	public abstract Set<Project> getProjectsForOwner(Person owner)
			throws SQLException;

	public abstract void refreshProject(Project project) throws SQLException;

	public abstract void refreshAllProject() throws SQLException;

	public abstract void setAssemblyForProject(Project project,
			Assembly assembly) throws SQLException;

	public abstract void getProjectSummary(Project project, int minlen,
			int minreads, ProjectSummary summary) throws SQLException;

	public abstract ProjectSummary getProjectSummary(Project project,
			int minlen, int minreads) throws SQLException;

	public abstract void getProjectSummary(Project project, int minlen,
			ProjectSummary summary) throws SQLException;

	public abstract void getProjectSummary(Project project,
			ProjectSummary summary) throws SQLException;

	public abstract ProjectSummary getProjectSummary(Project project, int minlen)
			throws SQLException;

	public abstract ProjectSummary getProjectSummary(Project project)
			throws SQLException;

	public abstract Map getProjectSummary(int minlen, int minreads)
			throws SQLException;

	public abstract Map getProjectSummary(int minlen) throws SQLException;

	public abstract Map getProjectSummary() throws SQLException;

	public abstract void clearProjectCache();

	public abstract boolean canUserUnlockProject(Project project, Person user)
			throws SQLException;

	public abstract boolean canUserLockProjectForSelf(Project project,
			Person user) throws SQLException;

	public abstract boolean canUserLockProject(Project project, Person user)
			throws SQLException;

	public abstract boolean canUserLockProjectForOwner(Project project,
			Person user) throws SQLException;

	public abstract boolean unlockProject(Project project) throws SQLException,
			ProjectLockException;

	public abstract boolean lockProject(Project project) throws SQLException,
			ProjectLockException;

	public abstract boolean unlockProjectForExport(Project project)
			throws SQLException, ProjectLockException;

	public abstract boolean lockProjectForExport(Project project)
			throws SQLException, ProjectLockException;

	public abstract boolean lockProjectForOwner(Project project)
			throws SQLException, ProjectLockException;

	public abstract boolean setProjectLockOwner(Project project, Person person)
			throws SQLException, ProjectLockException;

	public abstract void setProjectOwner(Project project, Person person)
			throws SQLException;

	public abstract boolean createNewProject(Assembly assembly, String name,
			Person owner, String directory) throws SQLException, IOException;

	public abstract boolean canUserChangeProjectStatus(Project project,
			Person user) throws SQLException;

	public abstract boolean canUserChangeProjectStatus(Project project)
			throws SQLException;

	public abstract boolean changeProjectStatus(Project project, int status)
			throws SQLException;

	public abstract boolean retireProject(Project project) throws SQLException;

	public abstract Project getBinForProject(Project project)
			throws SQLException;

	public abstract Assembly getAssemblyByID(int id) throws SQLException;

	public abstract Assembly getAssemblyByID(int id, boolean autoload)
			throws SQLException;

	public abstract Assembly getAssemblyByName(String name) throws SQLException;

	public abstract void preloadAllAssemblies() throws SQLException;

	public abstract Assembly[] getAllAssemblies() throws SQLException;

	public abstract void refreshAssembly(Assembly assembly) throws SQLException;

	public abstract void refreshAllAssemblies() throws SQLException;

	public abstract void clearAssemblyCache();

	public abstract boolean hasFullPrivileges(Person person);

	public abstract boolean hasFullPrivileges() throws SQLException;

	public abstract boolean isCoordinator(Person person);

	public abstract boolean isCoordinator();

	public abstract Person[] getAllUsers(boolean includeNobody)
			throws SQLException;

	public abstract Person[] getAllUsers() throws SQLException;

	public abstract Person findUser(String username);

	public abstract Person findMe();

	public abstract boolean isMe(Person person);

	public abstract ContigTransferRequest[] getContigTransferRequestsByUser(
			Person user, int mode) throws SQLException;

	public abstract ContigTransferRequest createContigTransferRequest(
			Person requester, int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException;

	public abstract ContigTransferRequest createContigTransferRequest(
			int contigId, int toProjectId)
			throws ContigTransferRequestException, SQLException;

	public abstract ContigTransferRequest createContigTransferRequest(
			Person requester, Contig contig, Project project)
			throws ContigTransferRequestException, SQLException;

	public abstract ContigTransferRequest createContigTransferRequest(
			Contig contig, Project project)
			throws ContigTransferRequestException, SQLException;

	public abstract void reviewContigTransferRequest(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException;

	public abstract void reviewContigTransferRequest(int requestId,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, SQLException;

	public abstract void reviewContigTransferRequest(int requestId,
			int newStatus) throws ContigTransferRequestException, SQLException;

	public abstract void executeContigTransferRequest(
			ContigTransferRequest request, Person reviewer,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException;

	public abstract void executeContigTransferRequest(int requestId,
			Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, SQLException;

	public abstract void executeContigTransferRequest(int requestId,
			boolean notifyListeners) throws ContigTransferRequestException,
			SQLException;

	public abstract void setDebugging(boolean debugging);

	public abstract boolean canCancelRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public abstract boolean canRefuseRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public abstract boolean canApproveRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public abstract boolean canExecuteRequest(ContigTransferRequest request,
			Person person) throws SQLException;

	public abstract void moveContigs(Project fromProject, Project toProject)
			throws SQLException;

	public abstract void addProjectChangeEventListener(Project project,
			ProjectChangeEventListener listener);

	public abstract void addProjectChangeEventListener(
			ProjectChangeEventListener listener);

	public abstract void removeProjectChangeEventListener(
			ProjectChangeEventListener listener);

	public abstract void notifyProjectChangeEventListeners(
			ProjectChangeEvent event, Class listenerClass);

	public abstract String getDefaultDirectory();

}