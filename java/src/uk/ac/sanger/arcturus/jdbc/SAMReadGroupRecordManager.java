package uk.ac.sanger.arcturus.jdbc;

import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import net.sf.samtools.SAMReadGroupRecord;

public class SAMReadGroupRecordManager  extends AbstractManager{

	protected PreparedStatement pstmtCreateReadGroup = null;
	protected PreparedStatement pstmtGetReadGroupByImportId = null;
	protected PreparedStatement pstmtGetReadGroupByReadTag = null;
	protected PreparedStatement pstmtGetReadGroupById = null;
	protected PreparedStatement pstmtGetReadGroupByLineId = null;
	protected PreparedStatement pstmtGetLastImportId = null;
	
	protected ManagerEvent event = null;

	private HashMap<Integer, SAMReadGroupRecord> hashById;
	private HashMap<Integer, SAMReadGroupRecord> hashByImportId;
	private HashMap<Integer, SAMReadGroupRecord> hashByLineId;
	private HashMap<String, SAMReadGroupRecord> hashByReadTag;
	
	private boolean testing;
	
	/**
	 * Creates a new ReadGroupManager to provide read tag group management services to an
	 * ArcturusDatabase object.  Called to process or produce a SAMFileHeader record 
	 */

		public SAMReadGroupRecordManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		event = new ManagerEvent(this);

		hashById = new HashMap<Integer, SAMReadGroupRecord>();
		hashByImportId = new HashMap<Integer, SAMReadGroupRecord>();
		hashByLineId = new  HashMap<Integer,SAMReadGroupRecord>();
		hashByReadTag = new HashMap<String, SAMReadGroupRecord>();
		
		try {
			setConnection(adb.getDefaultConnection());
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the SAMReadGroupRecord manager", conn, adb);
		}

	}

	public void clearCache() {
		hashById.clear();
		hashByImportId.clear();
		hashByLineId.clear();
		hashByReadTag.clear();
	}


	protected void prepareConnection() throws SQLException {
		String query;

		query = "insert into SAMREADGROUPRECORD(read_group_line_id, import_id, IDvalue, SMvalue, LBvalue, DSvalue, PUvalue, PIvalue, CNvalue, DTvalue, PLvalue) " + 
		"values ( ?, ? , ?, ?, ?, ?, ?, ?, ?, ?, ?)";

		pstmtCreateReadGroup = prepareStatement(query);
		
		query = "select * from SAMREADGROUPRECORD where import_id = ? order by read_group_line_id ASC";
		
		pstmtGetReadGroupByImportId = prepareStatement(query);
		
		query = "select * from SAMREADGROUPRECORD where read_group_id = ?"; 
			
		pstmtGetReadGroupById = prepareStatement(query);
		
		query = "select * from SAMREADGROUPRECORD where read_group_line_id = ? and import_id = ?";

		pstmtGetReadGroupByLineId = prepareStatement(query);
		
	}
	
	protected void addReadGroup(SAMReadGroupRecord readGroup, int line_no, int import_id) throws SQLException, ArcturusDatabaseException{
		

		pstmtCreateReadGroup.setInt(1, line_no);
		pstmtCreateReadGroup.setInt(2, import_id);
	
		try {
			pstmtCreateReadGroup.setString(3, readGroup.getId());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Read Group Identifier(ID) tag");
		}
		
		try {
			pstmtCreateReadGroup.setString(4, readGroup.getSample());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Sample(SM) tag");
		}
		
		try {
			pstmtCreateReadGroup.setString(5, readGroup.getLibrary());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Library(LB) tag");
		}
		
		try {
			pstmtCreateReadGroup.setString(6, readGroup.getDescription());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Description(DS) tag");
		}
		
		try {
			pstmtCreateReadGroup.setString(7, readGroup.getPlatformUnit());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Platform Unit(PU) tag");
		}
		
		try {
			//pstmtCreateReadGroup.setInt(8, readGroup.getPredictedMedianInsertSize());
			pstmtCreateReadGroup.setInt(8, 0);
		}
		catch (NullPointerException e){
			reportProgress("Failed to read the the Predicted Median Insert Size(PI) tag");
			SQLException s = new SQLException("Failed to read the the Predicted Median Insert Size(PI) tag");
			throw s;
		}
		
		try {
			pstmtCreateReadGroup.setString(9, readGroup.getSequencingCenter());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Sequencing Center(CN) tag");
		}
		
		try {
			pstmtCreateReadGroup.setDate(10, (Date) readGroup.getRunDate());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Run Date(DT) tag");
		}

		try {
			pstmtCreateReadGroup.setString(11, readGroup.getPlatform());
		}
		catch (NullPointerException e){
			Arcturus.logSevere("Failed to read the the Platform(PL) tag");
		}
		
		try {
			pstmtCreateReadGroup.executeQuery();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to add ReadGroup", conn, this);
		}
	}
	
	protected void reportProgress(String message) {
		if (testing) {
			System.out.println(message);
		}
    	Arcturus.logInfo(message);
	}
	
	protected void addReadGroupsFromThisImport(List<SAMReadGroupRecord> readGroups, int import_id) throws SQLException, ArcturusDatabaseException {
		
		Iterator it = readGroups.iterator();
		int line_no = 0;
		int readGroupsToLoad = readGroups.size();
		
		reportProgress("\tLoading " + readGroupsToLoad + " read groups for import id " + import_id);
		
		while (it.hasNext()) {
			line_no ++;
			SAMReadGroupRecord  readGroup = (SAMReadGroupRecord) it.next();
			reportProgress("\tAdding read group " + line_no + ": " + readGroup.getId());
			addReadGroup(readGroup, line_no, import_id);
		}
		
		if (readGroups.size() != line_no ) {
			Arcturus.logSevere("*** Mismatch between read groups loaded (" + line_no + ") and read groups found to load (" + readGroupsToLoad + ")");
		}
	}
	
	protected List<SAMReadGroupRecord> findReadGroupsFromLastImport(Project project) throws SQLException, ArcturusDatabaseException {
		
		int last_import_id = 0;
		
		List<SAMReadGroupRecord> readGroups = new LinkedList();
		
		try {
			last_import_id = adb.getLastImportId(project);
			pstmtGetReadGroupByImportId.setInt(1, last_import_id);

			ResultSet rs = pstmtGetReadGroupByImportId.executeQuery();

			//+---------------+--------------------+-----------+---------------+---------+---------------+---------+---------+---------+---------+---------+---------+
			//| read_group_id | read_group_line_id | import_id | IDvalue       | SMvalue | LBvalue       | DSvalue | PUvalue | PIvalue | CNvalue | DTvalue | PLvalue |
			//+---------------+--------------------+-----------+---------------+---------+---------------+---------+---------+---------+---------+---------+---------+
			//|             2 |                  2 |        52 | GWSHH1C01.sff | unknown | GWSHH1C01.sff | NULL    | NULL    | NULL    | NULL    | NULL    | NULL    | 
			//+---------------+--------------------+-----------+---------------+---------+---------------+---------+---------+---------+---------+---------+---------+

			while (rs.next()) {
				int read_group_line_id = rs.getInt(2);
				int import_id = rs.getInt(3);
				String IDvalue = rs.getString(4);

				SAMReadGroupRecord readGroup = new SAMReadGroupRecord(IDvalue);
				readGroup.setSample( rs.getString(5));
				readGroup.setLibrary(rs.getString(6));
				readGroup.setDescription( rs.getString(7));
				readGroup.setPlatformUnit(rs.getString(8));
				readGroup.setPredictedMedianInsertSize(rs.getInt(9));
				readGroup.setSequencingCenter(rs.getString(10));
				readGroup.setRunDate( rs.getDate(11));
				readGroup.setPlatform(rs.getString(12));
				reportProgress("/tFound read group " + read_group_line_id + ": " + readGroup.getId());
				readGroups.add(readGroup);
			} 

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get read group for last import " + last_import_id, conn, this);
		}

			return readGroups;
	}

	@Override
	public String getCacheStatistics() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public void preload() throws ArcturusDatabaseException {
		// TODO Auto-generated method stub
		
	}
}
