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
	private PreparedStatement pstmtByID, pstmtByName, pstmtByTemplate;

	/**
	 * Creates a new ReadManager to provide read management services to an
	 * ArcturusDatabase object.
	 */

	public ReadManager(ArcturusDatabase adb) throws ArcturusDatabaseException {
		this.adb = adb;

		hashByID = new HashMap<Integer, Read>();
		hashByName = new HashMap<String, Read>();
		
		try {
			setConnection(adb.getDefaultConnection());
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to initialise the read manager", conn, adb);
		}
	}
	
	protected void prepareConnection() throws SQLException {
		String query = "select readname,template_id,asped,strand,primer,chemistry from READINFO where read_id = ?";
		pstmtByID = conn.prepareStatement(query);

		query = "select read_id,template_id,asped,strand,primer,chemistry from READINFO where readname = ?";
		pstmtByName = conn.prepareStatement(query);

		query = "select read_id,readname,asped,strand,primer,chemistry from READINFO where template_id = ?";
		pstmtByTemplate = conn.prepareStatement(query);
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

	public Read findOrCreateRead(int id, String name, Template template,
			java.util.Date asped, String strand, String primer, String chemistry) {
		Read read = (Read) hashByID.get(new Integer(id));

		if (read == null) {
			int iStrand = parseStrand(strand);
			int iPrimer = parsePrimer(primer);
			int iChemistry = parseChemistry(chemistry);

			read = new Read(name, id, template, asped, iStrand, iPrimer,
					iChemistry, adb);

			registerNewRead(read);
		}

		return read;
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
