package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

import java.sql.*;
import java.util.*;

/**
 * This class manages Read objects.
 */

public class ReadManager extends AbstractManager {
	private HashMap<Integer, Read> hashByID;
	private HashMap<String, Read> hashByName;
	
	private DictionaryTableManager dictStatus;
	private DictionaryTableManager dictBasecaller;
	
	private PreparedStatement pstmtPreloadReads, pstmtByID, pstmtByName, pstmtByTemplate, pstmtInsertNewRead;
	
	private static final String READ_COLUMNS = "read_id,readname,asped,strand,primer,chemistry,basecaller,status";
	
	private static final String PRELOAD_READS =
		"select " + READ_COLUMNS + " from READINFO";
	
	private static final String GET_READ_BY_ID =
		"select " + READ_COLUMNS + " from READINFO where read_id = ?";
	
	private static final String GET_READ_BY_NAME =
		"select " + READ_COLUMNS + " from READINFO where readname = ?";
	
	private static final String GET_READS_BY_TEMPLATE_ID =
		"select " + READ_COLUMNS + " from READINFO where template_id = ?";
	
	private static final String PUT_READ =
		"insert into READINFO (readname,template_id,asped,strand,primer,chemistry,basecaller,status) VALUES (?,?,?,?,?,?,?,?)";

	/**
	 * Creates a new ReadManager to provide read management services to an
	 * ArcturusDatabase object.
	 */

	public ReadManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		super(adb);

		hashByID = new HashMap<Integer, Read>();
		hashByName = new HashMap<String, Read>();

		dictStatus = new DictionaryTableManager(adb, "STATUS", "status_id", "name");
		
		dictBasecaller = new DictionaryTableManager(adb, "BASECALLER", "basecaller_id", "name");
		
		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the read manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		pstmtByID = prepareStatement(GET_READ_BY_ID);

		pstmtByName = prepareStatement(GET_READ_BY_NAME);

		pstmtByTemplate = prepareStatement(GET_READS_BY_TEMPLATE_ID);
		
		pstmtInsertNewRead = prepareStatement(PUT_READ, Statement.RETURN_GENERATED_KEYS);
		
		pstmtPreloadReads = prepareStatement(PRELOAD_READS);
	}

	public void clearCache() {
		hashByID.clear();
		hashByName.clear();
	}

	public Read getReadByName(String name) throws ArcturusDatabaseException {
		return getReadByName(name, true);
	}

	public Read getReadByName(String name, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByName.get(name);

		return (obj == null && autoload) ? loadReadByName(name) : (Read) obj;
	}

	public Read getReadByID(int id) throws ArcturusDatabaseException {
		return getReadByID(id, true);
	}

	public Read getReadByID(int id, boolean autoload) throws ArcturusDatabaseException {
		Object obj = hashByID.get(new Integer(id));

		return (obj == null && autoload) ? loadReadByID(id) : (Read) obj;
	}
	
	private Read createReadFromResultSet(ResultSet rs) throws SQLException, ArcturusDatabaseException {
		int index = 1;
		
		int read_id = rs.getInt(index++);
		String name = rs.getString(index++);
		int template_id = rs.getInt(index++);
		java.util.Date asped = rs.getTimestamp(index++);
		int strand = parseStrand(rs.getString(index++));
		int primer = parsePrimer(rs.getString(index++));
		int chemistry = parseChemistry(rs.getString(index++));
		
		int basecaller_id = rs.getInt(index++);
		int status_id = rs.getInt(index++);
		
		String basecaller = dictBasecaller.getValue(basecaller_id);
		String status = dictStatus.getValue(status_id);
		
		return createAndRegisterNewRead(name, read_id, template_id, asped,
				strand, primer, chemistry, basecaller, status);
	}

	private Read loadReadByName(String name) throws ArcturusDatabaseException {
		Read read = null;

		try {
			pstmtByName.setString(1, name);
			ResultSet rs = pstmtByName.executeQuery();

			if (rs.next())
				read = createReadFromResultSet(rs);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load read by name=\"" + name + "\"", conn, this);
		}

		return read;
	}

	private Read loadReadByID(int id) throws ArcturusDatabaseException {
		Read read = null;

		try {
			pstmtByID.setInt(1, id);
			ResultSet rs = pstmtByID.executeQuery();

			if (rs.next())
				read = createReadFromResultSet(rs);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load read by ID=" + id, conn, this);
		}

		return read;
	}

	public int loadReadsByTemplate(int template_id) throws ArcturusDatabaseException {
		int newreads = 0;

		try {
			pstmtByTemplate.setInt(1, template_id);
			ResultSet rs = pstmtByTemplate.executeQuery();

			while (rs.next()) {
				int read_id = rs.getInt(1);

				if (hashByID.containsKey(new Integer(read_id)))
					continue;

				createReadFromResultSet(rs);

				newreads++;
			}

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load reads by template ID=" + template_id, conn, this);
		}

		return newreads;
	}

	public static int parseStrand(String text) {
		if (text == null)
			return Read.UNKNOWN;
		
		if (text.equals(Read.FORWARD_STRING))
			return Read.FORWARD;

		if (text.equals(Read.REVERSE_STRING))
			return Read.REVERSE;

		return Read.UNKNOWN;
	}
	
	public static String strandToString(int value) {
		switch (value) {
			case Read.FORWARD:
				return Read.FORWARD_STRING;
				
			case Read.REVERSE:
				return Read.REVERSE_STRING;
				
			default:
				return Read.UNKNOWN_STRING;
		}
	}

	public static int parsePrimer(String text) {
		if (text == null)
			return Read.UNKNOWN;
		
		if (text.equals(Read.UNIVERSAL_PRIMER_STRING))
			return Read.UNIVERSAL_PRIMER;

		if (text.equals(Read.CUSTOM_PRIMER_STRING))
			return Read.CUSTOM_PRIMER;

		return Read.UNKNOWN;
	}
	
	public static String primerToString(int value) {
		switch (value) {
			case Read.UNIVERSAL_PRIMER:
				return Read.UNIVERSAL_PRIMER_STRING;
				
			case Read.CUSTOM_PRIMER:
				return Read.CUSTOM_PRIMER_STRING;
				
			default:
				return Read.UNKNOWN_STRING;
		}
	}

	public static int parseChemistry(String text) {
		if (text == null)
			return Read.UNKNOWN;
		
		if (text.equals(Read.DYE_TERMINATOR_STRING))
			return Read.DYE_TERMINATOR;

		if (text.equals(Read.DYE_PRIMER_STRING))
			return Read.DYE_PRIMER;

		return Read.UNKNOWN;
	}
	
	public static String chemistryToString(int value) {
		switch (value) {
			case Read.DYE_PRIMER:
				return Read.DYE_PRIMER_STRING;
				
			case Read.DYE_TERMINATOR:
				return Read.DYE_TERMINATOR_STRING;
				
			default:
				return Read.UNKNOWN_STRING;
		}
	}

	private Read createAndRegisterNewRead(String name, int id, int template_id,
			java.util.Date asped, int strand, int primer, int chemistry, String basecaller, String status)
			throws ArcturusDatabaseException {
		Template template = adb.getTemplateByID(template_id);

		Read read = new Read(name, id, template, asped, strand, primer,
				chemistry, basecaller, status, adb);

		registerNewRead(read);

		return read;
	}

	void registerNewRead(Read read) {
		if (cacheing) {
			hashByName.put(read.getName(), read);
			hashByID.put(new Integer(read.getID()), read);
		}
	}

	public void preload() throws ArcturusDatabaseException {

		try {
			ResultSet rs = pstmtPreloadReads.executeQuery();

			while (rs.next())
				createReadFromResultSet(rs);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload reads", conn, this);
		}
	}
	
	public String getBaseCallerByID(int basecaller_id) {
		return dictBasecaller.getValue(basecaller_id);
	}
	
	public String getReadStatusByID(int status_id) {
		return dictStatus.getValue(status_id);
	}
	
	public Read findOrCreateRead(String name, Template template,
			java.util.Date asped, String strand, String primer, String chemistry, String basecaller, String status)
		throws ArcturusDatabaseException {
		Read read = getReadByName(name);
		
		if (read != null)
			return read;

		try {
			int template_id = (template == null) ? 0 : template.getID();
			
			int iStrand = parseStrand(strand);
			int iPrimer = parsePrimer(primer);
			int iChemistry = parseChemistry(chemistry);
			
			java.sql.Date dAsped = asped == null ? null : new java.sql.Date(asped.getTime());
			
			int status_id = dictStatus.getID(status);
			int basecaller_id = dictBasecaller.getID(basecaller);

			pstmtInsertNewRead.setString(1, name);
			pstmtInsertNewRead.setInt(2, template_id);
			
			if (dAsped == null)
				pstmtInsertNewRead.setNull(3, Types.DATE);
			else
				pstmtInsertNewRead.setDate(3, dAsped);
			
			pstmtInsertNewRead.setInt(4, iStrand);
			pstmtInsertNewRead.setInt(5, iPrimer);
			pstmtInsertNewRead.setInt(6, iChemistry);
			
			pstmtInsertNewRead.setInt(7, basecaller_id);
			pstmtInsertNewRead.setInt(8, status_id);
			
			int rc = pstmtInsertNewRead.executeUpdate();
			
			if (rc == 1) {
				ResultSet rs = pstmtInsertNewRead.getGeneratedKeys();
				
				int read_id = rs.next() ? rs.getInt(1) : -1;
				
				if (read_id > 0)
					return createAndRegisterNewRead(name, read_id, template_id,
							asped, iStrand, iPrimer, iChemistry, basecaller, status);
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find or create read by name=\"" + name + "\"", conn, this);
		}
		
		return null;
	}
	
	public Read findOrCreateRead(Read read) throws ArcturusDatabaseException {
		return null;
	}

	public int[] getUnassembledReadIDList() throws ArcturusDatabaseException {
		int[] ids = null;
		
		try {
			Statement stmt = conn.createStatement();

			String[] queries = {
					"create temporary table CURSEQ as"
							+ " select seq_id from CURRENTCONTIGS left join MAPPING using(contig_id)",

					"create temporary table CURREAD"
							+ " (read_id integer not null, seq_id integer not null, key (read_id)) as"
							+ " select read_id,SEQ2READ.seq_id from CURSEQ left join SEQ2READ using(seq_id)",

					"create temporary table FREEREAD as"
							+ " select READINFO.read_id from READINFO left join CURREAD using(read_id)"
							+ " where seq_id is null" };

			for (int i = 0; i < queries.length; i++) {
				stmt.executeUpdate(queries[i]);
			}

			String query = "select count(*) from FREEREAD";

			ResultSet rs = stmt.executeQuery(query);

			int nreads = 0;

			if (rs.next())
				nreads = rs.getInt(1);

			rs.close();

			if (nreads == 0)
				return null;

			query = "select read_id from FREEREAD";

			rs = stmt.executeQuery(query);

			ids = new int[nreads];

			int j = 0;

			while (rs.next() && j < nreads)
				ids[j++] = rs.getInt(1);

			rs.close();

			stmt.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to get unassembled read ID lists", conn, this);
		}

		return ids;
	}
}
