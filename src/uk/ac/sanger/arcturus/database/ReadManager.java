package uk.ac.sanger.arcturus.database;

import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Template;

import java.sql.*;
import java.util.*;

/**
 * This class manages Read objects.
 */

public class ReadManager {
    private ArcturusDatabase adb;
    private Connection conn;
    private HashMap hashByID, hashByName;
    private PreparedStatement pstmtByID, pstmtByName, pstmtByTemplate;

    /**
     * Creates a new ReadManager to provide read management
     * services to an ArcturusDatabase object.
     */

    public ReadManager(ArcturusDatabase adb) throws SQLException {
	this.adb = adb;

	conn = adb.getConnection();

	String query = "select readname,template_id,asped,strand,primer,chemistry from READS where read_id = ?";
	pstmtByID = conn.prepareStatement(query);

	query = "select read_id,template_id,asped,strand,primer,chemistry from READS where readname = ?";
	pstmtByName = conn.prepareStatement(query);

	query = "select read_id,readname,asped,strand,primer,chemistry from READS where template_id = ?";
	pstmtByTemplate = conn.prepareStatement(query);

	hashByID = new HashMap();
	hashByName = new HashMap();
    }

    public Read getReadByName(String name) throws SQLException {
	return getReadByName(name, true);
    }

    public Read getReadByName(String name, boolean autoload) throws SQLException {
	Object obj = hashByName.get(name);

	return (obj == null && autoload) ? loadReadByName(name) : (Read)obj;
    }

    public Read getReadByID(int id) throws SQLException {
	return getReadByID(id, true);
    }

    public Read getReadByID(int id, boolean autoload) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	return (obj == null && autoload) ? loadReadByID(id) : (Read)obj;
    }

    private Read loadReadByName(String name) throws SQLException {
	pstmtByName.setString(1, name);
	ResultSet rs = pstmtByName.executeQuery();

	Read read = null;

	if (rs.next()) {
	    int id = rs.getInt(1);
	    int template_id = rs.getInt(2);
	    java.sql.Date asped = rs.getDate(3);
	    int strand = parseStrand(rs.getString(4));
	    int primer = parsePrimer(rs.getString(5));
	    int chemistry = parseChemistry(rs.getString(6));
	    read = createAndRegisterNewRead(name, id, template_id, asped, strand, primer, chemistry);
	}

	rs.close();

	return read;
    }

    private Read loadReadByID(int id) throws SQLException {
	pstmtByID.setInt(1, id);
	ResultSet rs = pstmtByID.executeQuery();

	Read read = null;

	if (rs.next()) {
	    String name = rs.getString(1);
	    int template_id = rs.getInt(2);
	    java.sql.Date asped = rs.getDate(3);
	    int strand = parseStrand(rs.getString(4));
	    int primer = parsePrimer(rs.getString(5));
	    int chemistry = parseChemistry(rs.getString(6));
	    read = createAndRegisterNewRead(name, id, template_id, asped, strand, primer, chemistry);
	}

	rs.close();

	return read;
    }

    public int loadReadsByTemplate(int template_id) throws SQLException {
	pstmtByTemplate.setInt(1, template_id);
	ResultSet rs = pstmtByTemplate.executeQuery();

	int newreads = 0;

	while (rs.next()) {
	    int read_id = rs.getInt(1);

	    if (hashByID.containsKey(new Integer(read_id)))
		continue;

	    String name = rs.getString(2);
	    java.sql.Date asped = rs.getDate(3);
	    int strand = parseStrand(rs.getString(4));
	    int primer = parsePrimer(rs.getString(5));
	    int chemistry = parseChemistry(rs.getString(6));

	    createAndRegisterNewRead(name, read_id, template_id, asped, strand, primer, chemistry);

	    newreads++;
	}

	rs.close();

	return newreads;
    }

    public static int parseStrand(String text) {
	if (text.equals("Forward"))
	    return Read.FORWARD;

	if (text.equals("Reverse"))
	    return Read.REVERSE;

	return Read.UNKNOWN;
    }

    public static int parsePrimer(String text) {
	if (text.equals("Universal_primer"))
	    return Read.UNIVERSAL_PRIMER;

	if (text.equals("Custom"))
	    return Read.CUSTOM_PRIMER;

	return Read.UNKNOWN;
    }

    public static int parseChemistry(String text) {
	if (text.equals("Dye_terminator"))
	    return Read.DYE_TERMINATOR;

	if (text.equals("Dye_primer"))
	    return Read.DYE_PRIMER;

	return Read.UNKNOWN;
    }

    private Read createAndRegisterNewRead(String name, int id, int template_id, java.sql.Date asped,
					 int strand, int primer, int chemistry) throws SQLException {
	Template template = adb.getTemplateByID(template_id);

	Read read = new Read(name, id, template, asped, strand, primer, chemistry, adb);

	registerNewRead(read);

	return read;
    }

    void registerNewRead(Read read) {
	hashByName.put(read.getName(), read);
	hashByID.put(new Integer(read.getID()), read);
    }

    public void preloadAllReads() throws SQLException {
	String query = "select read_id,readname,template_id,asped,strand,primer,chemistry from READS";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int id = rs.getInt(1);
	    String name = rs.getString(2);
	    int template_id = rs.getInt(3);
	    java.sql.Date asped = rs.getDate(4);
	    int strand = parseStrand(rs.getString(5));
	    int primer = parsePrimer(rs.getString(6));
	    int chemistry = parseChemistry(rs.getString(7));
	    createAndRegisterNewRead(name, id, template_id, asped, strand, primer, chemistry);
	}

	rs.close();
	stmt.close();
    }
}
