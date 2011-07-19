package uk.ac.sanger.arcturus.database;

import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Map;
import java.util.Set;
import java.util.List;
import java.util.logging.Logger;

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
import uk.ac.sanger.arcturus.data.Tag;
import net.sf.samtools.SAMReadGroupRecord;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.data.CanonicalMapping;
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
	public static final int MAPPING = 9;
	public static final int LINK = 10;
	
	/**
	 * Closes this object.
	 */
	
	public void close() throws ArcturusDatabaseException;

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
	 * @throws ArcturusDatabaseException
	 *             in the event of an error when establishing a connection with
	 *             the database.
	 */

	public Connection getDefaultConnection() throws ArcturusDatabaseException;

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
	 * @throws ArcturusDatabaseException
	 *             in the event of an error when establishing a connection with
	 *             the database.
	 */

	public Connection getPooledConnection(Object owner)
			throws ArcturusDatabaseException;

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
	
	public void preload(int type) throws ArcturusDatabaseException;

	public Clone getCloneByName(String name) throws ArcturusDatabaseException;

	public Clone getCloneByID(int id) throws ArcturusDatabaseException;
	
	public Clone findOrCreateClone(Clone clone) throws ArcturusDatabaseException;
	
	public Clone putClone(Clone clone) throws ArcturusDatabaseException;

	public Ligation getLigationByName(String name) throws ArcturusDatabaseException;

	public Ligation getLigationByID(int id) throws ArcturusDatabaseException;
	
	public Ligation findOrCreateLigation(Ligation ligation)
			throws ArcturusDatabaseException;
	
	public Ligation putLigation(Ligation ligation)
			throws ArcturusDatabaseException;

	public Template getTemplateByName(String name) throws ArcturusDatabaseException;

	public Template getTemplateByName(String name, boolean autoload)
			throws ArcturusDatabaseException;

	public Template getTemplateByID(int id) throws ArcturusDatabaseException;

	public Template getTemplateByID(int id, boolean autoload)
			throws ArcturusDatabaseException;

	public Template findOrCreateTemplate(Template template) throws ArcturusDatabaseException;

	public Template putTemplate(Template template) throws ArcturusDatabaseException;

	public Read getReadByName(String name) throws ArcturusDatabaseException;

	public Read getReadByName(String name, boolean autoload)
			throws ArcturusDatabaseException;

	public Read getReadByNameAndFlags(String name, int flags)
			throws ArcturusDatabaseException;

	public Read getReadByID(int id) throws ArcturusDatabaseException;

	public Read getReadByID(int id, boolean autoload)
			throws ArcturusDatabaseException;

	public int loadReadsByTemplate(int template_id)
			throws ArcturusDatabaseException;

	public Read findOrCreateRead(Read read) throws ArcturusDatabaseException;

	public Read putRead(Read read) throws ArcturusDatabaseException;
	
	public void addReadGroupsFromThisImport(List<SAMReadGroupRecord> readGroups, int import_id) throws ArcturusDatabaseException;
		
	public List<SAMReadGroupRecord> findReadGroupsFromLastImport(Project project) throws ArcturusDatabaseException;

	public int[] getUnassembledReadIDList() throws ArcturusDatabaseException;
	
	public String getBaseCallerByID(int basecaller_id);
	
	public String getReadStatusByID(int status_id);

	public Sequence getSequenceByReadID(int readid)
			throws ArcturusDatabaseException;

	public Sequence getSequenceByReadID(int readid, boolean autoload)
			throws ArcturusDatabaseException;

	public Sequence getFullSequenceByReadID(int readid)
			throws ArcturusDatabaseException;

	public Sequence getFullSequenceByReadID(int readid,
			boolean autoload) throws ArcturusDatabaseException;

	public Sequence getSequenceBySequenceID(int seqid)
			throws ArcturusDatabaseException;

	public Sequence getSequenceBySequenceID(int seqid, boolean autoload)
			throws ArcturusDatabaseException;

	public Sequence getFullSequenceBySequenceID(int seqid)
			throws ArcturusDatabaseException;

	public Sequence getFullSequenceBySequenceID(int seqid,
			boolean autoload) throws ArcturusDatabaseException;

	public void getDNAAndQualityForSequence(Sequence sequence)
			throws ArcturusDatabaseException;

	public Sequence findOrCreateSequence(Sequence sequence) throws ArcturusDatabaseException;
	
	public Sequence findSequenceByReadnameFlagsAndHash(Sequence sequence) throws ArcturusDatabaseException;
	
	public Sequence putSequence(Sequence sequence) throws ArcturusDatabaseException;

	public Contig getContigByID(int id, int options)
			throws ArcturusDatabaseException;

	public Contig getContigByID(int id) throws ArcturusDatabaseException;

	public Contig getContigByName(String name, int options)
			throws ArcturusDatabaseException;

	public Contig getContigByName(String name)
			throws ArcturusDatabaseException;

	public Contig getContigByReadName(String readname, int options)
			throws ArcturusDatabaseException;

	public Contig getContigByReadName(String readname)
			throws ArcturusDatabaseException;

	public void updateContig(Contig contig, int options)
			throws ArcturusDatabaseException;

	public boolean isCurrentContig(int contigid) throws ArcturusDatabaseException;

	public int[] getCurrentContigIDList() throws ArcturusDatabaseException;

	public int countCurrentContigs(int minlen) throws ArcturusDatabaseException;

	public int countCurrentContigs() throws ArcturusDatabaseException;

	public int processCurrentContigs(int options, int minlen,
			ContigProcessor processor) throws ArcturusDatabaseException;

	public int processCurrentContigs(int options,
			ContigProcessor processor) throws ArcturusDatabaseException;

	public Set getCurrentContigs(int options, int minlen)
			throws ArcturusDatabaseException;

	public Set getCurrentContigs(int options) throws ArcturusDatabaseException;

	public int countContigsByProject(int project_id, int minlen)
			throws ArcturusDatabaseException;

	public int countContigsByProject(int project_id)
			throws ArcturusDatabaseException;

	public int processContigsByProject(int project_id, int options,
			int minlen, ContigProcessor processor) throws ArcturusDatabaseException;

	public int processContigsByProject(int project_id, int options,
			ContigProcessor processor) throws ArcturusDatabaseException;

	public Set<Contig> getContigsByProject(int project_id,
			int options, int minlen) throws ArcturusDatabaseException;

	public Set<Contig> getContigsByProject(int project_id, int options)
			throws ArcturusDatabaseException;

	public Set<Contig> getChildContigs(Contig parent)
			throws ArcturusDatabaseException;
	
	public int setChildContig(Contig parent, Contig child)
			throws ArcturusDatabaseException;
	
	public void putContigConsensus(Contig contig) throws ArcturusDatabaseException;

	public Project getProjectByID(int id) throws ArcturusDatabaseException;

	public Project getProjectByID(int id, boolean autoload)
			throws ArcturusDatabaseException;

	public Project getProjectByName(Assembly assembly, String name)
			throws ArcturusDatabaseException;

	public Set<Project> getAllProjects() throws ArcturusDatabaseException;

	public Set<Project> getProjectsForOwner(Person owner)
			throws ArcturusDatabaseException;
	
	public Set<Project>getBinProjects() throws ArcturusDatabaseException;

	public void refreshProject(Project project) throws ArcturusDatabaseException;

	public void refreshAllProject() throws ArcturusDatabaseException;

	public void setAssemblyForProject(Project project,
			Assembly assembly) throws ArcturusDatabaseException;

	public void getProjectSummary(Project project, int minlen,
			int minreads, ProjectSummary summary) throws ArcturusDatabaseException;

	public ProjectSummary getProjectSummary(Project project,
			int minlen, int minreads) throws ArcturusDatabaseException;

	public void getProjectSummary(Project project, int minlen,
			ProjectSummary summary) throws ArcturusDatabaseException;

	public void getProjectSummary(Project project,
			ProjectSummary summary) throws ArcturusDatabaseException;

	public ProjectSummary getProjectSummary(Project project, int minlen)
			throws ArcturusDatabaseException;

	public ProjectSummary getProjectSummary(Project project)
			throws ArcturusDatabaseException;

	public Map getProjectSummary(int minlen, int minreads)
			throws ArcturusDatabaseException;

	public Map getProjectSummary(int minlen) throws ArcturusDatabaseException;

	public Map getProjectSummary() throws ArcturusDatabaseException;

	public boolean canUserUnlockProject(Project project, Person user)
			throws ArcturusDatabaseException;

	public boolean canUserLockProjectForSelf(Project project,
			Person user) throws ArcturusDatabaseException;

	public boolean canUserLockProject(Project project, Person user)
			throws ArcturusDatabaseException;

	public boolean canUserLockProjectForOwner(Project project,
			Person user) throws ArcturusDatabaseException;

	public boolean unlockProject(Project project) throws ArcturusDatabaseException,
			ProjectLockException;

	public boolean lockProject(Project project) throws ArcturusDatabaseException,
			ProjectLockException;

	public boolean unlockProjectForExport(Project project)
			throws ArcturusDatabaseException, ProjectLockException;

	public boolean lockProjectForExport(Project project)
			throws ArcturusDatabaseException, ProjectLockException;

	public boolean lockProjectForOwner(Project project)
			throws ArcturusDatabaseException, ProjectLockException;

	public boolean setProjectLockOwner(Project project, Person person)
			throws ArcturusDatabaseException, ProjectLockException;

	public void setProjectOwner(Project project, Person person)
			throws ArcturusDatabaseException;

	public boolean createNewProject(Assembly assembly, String name,
			Person owner, String directory) throws ArcturusDatabaseException, IOException;

	public boolean canUserChangeProjectStatus(Project project,
			Person user) throws ArcturusDatabaseException;

	public boolean canUserChangeProjectStatus(Project project)
			throws ArcturusDatabaseException;

	public boolean changeProjectStatus(Project project, int status)
			throws ArcturusDatabaseException;

	public boolean retireProject(Project project) throws ArcturusDatabaseException;

	public Project getBinForProject(Project project)
			throws ArcturusDatabaseException;

	public Assembly getAssemblyByID(int id) throws ArcturusDatabaseException;

	public Assembly getAssemblyByID(int id, boolean autoload)
			throws ArcturusDatabaseException;

	public Assembly getAssemblyByName(String name) throws ArcturusDatabaseException;

	public Assembly[] getAllAssemblies() throws ArcturusDatabaseException;

	public void refreshAssembly(Assembly assembly) throws ArcturusDatabaseException;

	public void refreshAllAssemblies() throws ArcturusDatabaseException;

	public boolean hasFullPrivileges(Person person);

	public boolean hasFullPrivileges() throws ArcturusDatabaseException;

	public boolean isCoordinator(Person person) throws ArcturusDatabaseException;

	public boolean isCoordinator() throws ArcturusDatabaseException;

	public Person[] getAllUsers(boolean includeNobody)
			throws ArcturusDatabaseException;

	public Person[] getAllUsers() throws ArcturusDatabaseException;

	public Person findUser(String username) throws ArcturusDatabaseException;

	public Person findMe() throws ArcturusDatabaseException;

	public boolean isMe(Person person);

	public ContigTransferRequest[] getContigTransferRequestsByUser(
			Person user, int mode) throws ArcturusDatabaseException;

	public ContigTransferRequest createContigTransferRequest(
			Person requester, int contigId, int toProjectId)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public ContigTransferRequest createContigTransferRequest(
			int contigId, int toProjectId)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public ContigTransferRequest createContigTransferRequest(
			Person requester, Contig contig, Project project)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public ContigTransferRequest createContigTransferRequest(
			Contig contig, Project project)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public void reviewContigTransferRequest(
			ContigTransferRequest request, Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public void reviewContigTransferRequest(int requestId,
			Person reviewer, int newStatus)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public void reviewContigTransferRequest(int requestId,
			int newStatus) throws ContigTransferRequestException, ArcturusDatabaseException;

	public void executeContigTransferRequest(
			ContigTransferRequest request, Person reviewer,
			boolean notifyListeners) throws ContigTransferRequestException,
			ArcturusDatabaseException;

	public void executeContigTransferRequest(int requestId,
			Person reviewer, boolean notifyListeners)
			throws ContigTransferRequestException, ArcturusDatabaseException;

	public void executeContigTransferRequest(int requestId,
			boolean notifyListeners) throws ContigTransferRequestException,
			ArcturusDatabaseException;

	public boolean canCancelRequest(ContigTransferRequest request,
			Person person) throws ArcturusDatabaseException;

	public boolean canRefuseRequest(ContigTransferRequest request,
			Person person) throws ArcturusDatabaseException;

	public boolean canApproveRequest(ContigTransferRequest request,
			Person person) throws ArcturusDatabaseException;

	public boolean canExecuteRequest(ContigTransferRequest request,
			Person person) throws ArcturusDatabaseException;

	public void moveContigs(Project fromProject, Project toProject)
			throws ArcturusDatabaseException;

	public void addProjectChangeEventListener(Project project,
			ProjectChangeEventListener listener);

	public void addProjectChangeEventListener(
			ProjectChangeEventListener listener);

	public void removeProjectChangeEventListener(
			ProjectChangeEventListener listener);

	public void notifyProjectChangeEventListeners(
			ProjectChangeEvent event, Class listenerClass);

	public String[] getAllDirectories() throws ArcturusDatabaseException;
	
	public void handleSQLException(SQLException e, String message, Connection conn, Object source)
			throws ArcturusDatabaseException;

// caching of read-contig-link lookup and canonical mappings
	
	public void prepareToLoadAllProjects() throws ArcturusDatabaseException;
	
	public void prepareToLoadProject(Project project) throws ArcturusDatabaseException;
	
	public int getCurrentContigIDForRead(Read read) throws ArcturusDatabaseException; // TBD

	public Contig getCurrentContigForRead(Read read) throws ArcturusDatabaseException;

	public void preloadCanonicalMappings() throws ArcturusDatabaseException;	
	
	public CanonicalMapping findOrCreateCanonicalMapping(CanonicalMapping cm) throws ArcturusDatabaseException;

    public void putContig(Contig contig) throws ArcturusDatabaseException;
    
	public boolean putSequenceToContigMappings(Contig contig) throws ArcturusDatabaseException;

	public boolean putContigToParentMappings(Contig contig) throws ArcturusDatabaseException;

	public int getLastImportId(Project p);

	public boolean putTags(Contig contig)throws ArcturusDatabaseException;

	public void loadTagsForContig(Contig contig) throws ArcturusDatabaseException;
}