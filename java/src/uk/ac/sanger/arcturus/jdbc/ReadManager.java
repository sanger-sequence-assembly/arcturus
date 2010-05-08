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
	private ArcturusDatabase adb;
	private HashMap<Integer, Read> hashByID;
	private HashMap<String, Read> hashByName;
	private HashMap<String, Integer> hashStatusNameToID;
	private HashMap<String, Integer> hashBasecallerNameToID;
	
	private PreparedStatement pstmtByID, pstmtByName, pstmtByTemplate, pstmtInsertNewRead;
	private PreparedStatement pstmtStatusByName, pstmtInsertStatus;
	private PreparedStatement pstmtBasecallerByName, pstmtInsertBasecaller;
	
	private static final String GET_READ_BY_ID =
		"select readname,template_id,asped,strand,primer,chemistry from READINFO where read_id = ?";
	
	private static final String GET_READ_BY_NAME =
		"select read_id,template_id,asped,strand,primer,chemistry from READINFO where readname = ?";
	
	private static final String GET_READS_BY_TEMPLATE_ID =
		"select read_id,readname,asped,strand,primer,chemistry from READINFO where template_id = ?";
	
	private static final String PUT_READ =
		"insert into READINFO (readname,template_id,asped,strand,primer,chemistry,basecaller,status) VALUES (?,?,?,?,?,?,?,?)";
	
	private static final String GET_BASECALLER_BY_NAME =
		"select basecaller_id from BASECALLER where name = ?";
	
	private static final String PUT_BASECALLER =
		"insert into BASECALLER (name) VALUES (?)";
	
	private static final String GET_STATUS_BY_NAME =
		"select status_id from STATUS where name = ?";
	
	private static final String PUT_STATUS =
		"insert into STATUS (name) VALUES (?)";

	/**
	 * Creates a new ReadManager to provide read management services to an
	 * ArcturusDatabase object.
	 */

	public ReadManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;

		hashByID = new HashMap<Integer, Read>();
		hashByName = new HashMap<String, Read>();
		hashStatusNameToID = new HashMap<String, Integer>();
		hashBasecallerNameToID = new HashMap<String, Integer>();
	
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
		
		pstmtStatusByName = prepareStatement(GET_STATUS_BY_NAME);
		
		pstmtInsertStatus = prepareStatement(PUT_STATUS, Statement.RETURN_GENERATED_KEYS);
		
		pstmtBasecallerByName = prepareStatement(GET_BASECALLER_BY_NAME);
		
		pstmtInsertBasecaller = prepareStatement(PUT_BASECALLER, Statement.RETURN_GENERATED_KEYS);
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

	private Read loadReadByName(String name) throws ArcturusDatabaseException {
		Read read = null;

		try {
			pstmtByName.setString(1, name);
			ResultSet rs = pstmtByName.executeQuery();

			if (rs.next()) {
				int id = rs.getInt(1);
				int template_id = rs.getInt(2);
				java.util.Date asped = rs.getTimestamp(3);
				int strand = parseStrand(rs.getString(4));
				int primer = parsePrimer(rs.getString(5));
				int chemistry = parseChemistry(rs.getString(6));
				read = createAndRegisterNewRead(name, id, template_id, asped,
						strand, primer, chemistry);
			}

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

			if (rs.next()) {
				String name = rs.getString(1);
				int template_id = rs.getInt(2);
				java.util.Date asped = rs.getTimestamp(3);
				int strand = parseStrand(rs.getString(4));
				int primer = parsePrimer(rs.getString(5));
				int chemistry = parseChemistry(rs.getString(6));
				read = createAndRegisterNewRead(name, id, template_id, asped,
						strand, primer, chemistry);
			}

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

				String name = rs.getString(2);
				java.util.Date asped = rs.getTimestamp(3);
				int strand = parseStrand(rs.getString(4));
				int primer = parsePrimer(rs.getString(5));
				int chemistry = parseChemistry(rs.getString(6));

				createAndRegisterNewRead(name, read_id, template_id, asped,
						strand, primer, chemistry);

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
		
		if (text.equals("Forward"))
			return Read.FORWARD;

		if (text.equals("Reverse"))
			return Read.REVERSE;

		return Read.UNKNOWN;
	}

	public static int parsePrimer(String text) {
		if (text == null)
			return Read.UNKNOWN;
		
		if (text.equals("Universal_primer"))
			return Read.UNIVERSAL_PRIMER;

		if (text.equals("Custom"))
			return Read.CUSTOM_PRIMER;

		return Read.UNKNOWN;
	}

	public static int parseChemistry(String text) {
		if (text == null)
			return Read.UNKNOWN;
		
		if (text.equals("Dye_terminator"))
			return Read.DYE_TERMINATOR;

		if (text.equals("Dye_primer"))
			return Read.DYE_PRIMER;

		return Read.UNKNOWN;
	}

	private Read createAndRegisterNewRead(String name, int id, int template_id,
			java.util.Date asped, int strand, int primer, int chemistry)
			throws ArcturusDatabaseException {
		Template template = adb.getTemplateByID(template_id);

		Read read = new Read(name, id, template, asped, strand, primer,
				chemistry, adb);

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
		String query = "select read_id,readname,template_id,asped,strand,primer,chemistry from READINFO";

		try {
			Statement stmt = conn.createStatement();

			ResultSet rs = stmt.executeQuery(query);

			while (rs.next()) {
				int id = rs.getInt(1);
				String name = rs.getString(2);
				int template_id = rs.getInt(3);
				java.util.Date asped = rs.getTimestamp(4);
				int strand = parseStrand(rs.getString(5));
				int primer = parsePrimer(rs.getString(6));
				int chemistry = parseChemistry(rs.getString(7));
				createAndRegisterNewRead(name, id, template_id, asped, strand,
						primer, chemistry);
			}

			rs.close();
			stmt.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to preload reads", conn, this);
		}
	}
	
	private int findOrCreateDictionaryEntry(String name, Map<String, Integer> dictionary, PreparedStatement pstmtFind, PreparedStatement pstmtPut)
		throws ArcturusDatabaseException {
		Integer iValue = dictionary.get(name);
		
		if (iValue!= null)
			return iValue.intValue();
		
		int value = -1;
		
		try {
			pstmtFind.setString(1, name);
			
			ResultSet rs = pstmtFind.executeQuery();
			
			if (rs.next()) {
				value = rs.getInt(1);
				dictionary.put(name, value);
			}
			
			rs.close();
			
			if (value >= 0)
				return value;
			
			pstmtPut.setString(1, name);
			
			int rc = pstmtPut.executeUpdate();
			
			if (rc == 1) {
				rs = pstmtPut.getGeneratedKeys();
				
				if (rs.next()) {
					value = rs.getInt(1);
					dictionary.put(name, value);
				}
				
				rs.close();
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find or create dictionary value by name=\"" + name + "\"", conn, this);
		}
		
		return value;
	}
	
	private int findOrCreateStatus(String name) throws ArcturusDatabaseException {
		return findOrCreateDictionaryEntry(name, hashStatusNameToID, pstmtStatusByName, pstmtInsertStatus);
	}
	
	private int findOrCreateBasecaller(String name) throws ArcturusDatabaseException {
		return findOrCreateDictionaryEntry(name, hashBasecallerNameToID, pstmtBasecallerByName, pstmtInsertBasecaller);
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
			
			int status_id = findOrCreateStatus(status);
			int basecaller_id = findOrCreateBasecaller(basecaller);

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
							asped, iStrand, iPrimer, iChemistry);
			}
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to find or create read by name=\"" + name + "\"", conn, this);
		}
		
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
