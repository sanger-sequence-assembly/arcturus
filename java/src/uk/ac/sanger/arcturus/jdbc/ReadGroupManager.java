package uk.ac.sanger.arcturus.jdbc;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.data.Project;
import uk.ac.sanger.arcturus.data.ReadGroup;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class ReadGroupManager  extends AbstractManager{

	protected PreparedStatement pstmtCreateReadGroup = null;
	protected PreparedStatement pstmtGetReadGroupByImportId = null;
	protected PreparedStatement pstmtGetReadGroupByReadTag = null;
	protected PreparedStatement pstmtGetReadGroupById = null;
	protected PreparedStatement pstmtGetReadGroupByLineId = null;
	protected PreparedStatement pstmtGetLastImportId = null;
	
	protected ManagerEvent event = null;

	private HashMap<Integer, ReadGroup> hashById;
	private HashMap<Integer, ReadGroup> hashByImportId;
	private HashMap<Integer, ReadGroup> hashByLineId;
	private HashMap<String, ReadGroup> hashByReadTag;
	
	/**
	 * Creates a new ReadGroupManager to provide read tag group management services to an
	 * ArcturusDatabase object.  Called to process or produce a SAMFileHeader record 
	 */

		public ReadGroupManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		event = new ManagerEvent(this);

		hashById = new HashMap<Integer, ReadGroup>();
		hashByImportId = new HashMap<Integer, ReadGroup>();
		hashByLineId = new  HashMap<Integer, ReadGroup>();
		hashByReadTag = new HashMap<String, ReadGroup>();

		try {
			setConnection(adb.getDefaultConnection());

			findReadGroupsFromLastImport();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the read group manager", conn, adb);
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

		query = "insert into READGROUP(read_group_line_id, import_id, tag_name, tag_value) values ( ?, ?, ?, ?)";

		pstmtCreateReadGroup = prepareStatement(query);
		
		query = "select read_group_line_id, tag_name, tag_value from READGROUP where import_id = ?";
		
		pstmtGetReadGroupByImportId = prepareStatement(query);
		
		query = "select read_group_line_id, tag_name, tag_value from READGROUP where tag_name = ?";
		
		pstmtGetReadGroupByReadTag = prepareStatement(query);
		
		query = "select read_group_line_id, tag_name, tag_value from READGROUP where tag_name = 'ID' and tag_value = ?"; 
			
		pstmtGetReadGroupById = prepareStatement(query);
		
		query = "select tag_name, tag_value from READGROUP where read_group_line_id = ?";
		
		pstmtGetReadGroupByLineId = prepareStatement(query);
		
		query = "select max(id) from IMPORTEXPORT where action = 'import'";
		
		pstmtGetLastImportId = prepareStatement(query);

	}
	
	protected void addReadGroup(ReadGroup readGroup) throws SQLException, ArcturusDatabaseException{
		
		pstmtCreateReadGroup.setInt(1, readGroup.getRead_group_id());
		pstmtCreateReadGroup.setInt(2, readGroup.getRead_group_line_id());
		pstmtCreateReadGroup.setInt(3, readGroup.getImport_id());
		pstmtCreateReadGroup.setString(3, readGroup.getTag_name());
		pstmtCreateReadGroup.setString(3, readGroup.getTag_value());
		
		try {
			pstmtCreateReadGroup.executeQuery();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to add ReadGroup", conn, this);
		}
	}
	
	protected void addReadGroupsFromThisImport(HashMap<Integer, ReadGroup> readGroups) throws SQLException, ArcturusDatabaseException {
		
		ReadGroup thisReadGroup;
		
		for (int i = 0; i< readGroups.size(); i++) {
			addReadGroup( readGroups.get(i));
		}
		
	}
	
	protected HashMap<Integer, ReadGroup> findReadGroupsFromLastImport() throws SQLException, ArcturusDatabaseException {
		
		int last_import_id = 0;
		
		try {
			ResultSet rs = pstmtGetLastImportId.executeQuery();
			last_import_id = rs.next() ? rs.getInt(1) : -1;
			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get last import id", conn, this);
		}
		
		try {
			pstmtGetReadGroupByImportId.setInt(1, last_import_id);

			ResultSet rs = pstmtGetReadGroupByImportId.executeQuery();

			/*
+--------------------+----------+---------------+
| read_group_line_id | tag_name | tag_value     |
+--------------------+----------+---------------+
|                  1 | ID       | GE6QGXJ01.sff | 
|                  1 | SM       | unknown       | 
|                  1 | LB       | GE6QGXJ01.sff | 
|                  2 | ID       | GI1YXNO01.sff | 
|                  2 | SM       | unknown       | 
|                  2 | LB       | GI1YXNO01.sff | 
|                  3 | ID       | GWSHH1C01.sff | 
|                  3 | SM       | unknown       | 
|                  3 | LB       | GWSHH1C01.sff | 
+--------------------+----------+---------------+

			 */

			while (rs.next()) {
				int read_group_id = rs.getInt(1);
				int read_group_line_id = rs.getInt(2);
				int import_id = rs.getInt(3);
				String tag_name = rs.getString(4);
				String tag_value = rs.getString(5);

				ReadGroup readGroup = new ReadGroup( read_group_id, read_group_line_id, import_id, tag_name, tag_value);
				this.hashById.put(read_group_id, readGroup);
			} 

			rs.close();
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get read group for last import", conn, this);
		}

			return this.hashById;
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
