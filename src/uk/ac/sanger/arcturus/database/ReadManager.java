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
    private PreparedStatement pstmtByID, pstmtByName;

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
	    
	hashByID = new HashMap();
	hashByName = new HashMap();
    }

    public Read getReadByName(String name) throws SQLException {
	Object obj = hashByName.get(name);

	return (obj == null) ? loadReadByName(name) : (Read)obj;
    }

    public Read getReadByID(int id) throws SQLException {
	Object obj = hashByID.get(new Integer(id));

	return (obj == null) ? loadReadByID(id) : (Read)obj;
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
	    read = registerNewRead(name, id, template_id, asped, strand, primer, chemistry);
	}

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
	    read = registerNewRead(name, id, template_id, asped, strand, primer, chemistry);
	}

	return read;
    }

    private int parseStrand(String text) {
	if (text.equals("Forward"))
	    return Read.FORWARD;

	if (text.equals("Reverse"))
	    return Read.REVERSE;

	return Read.UNKNOWN;
    }

    private int parsePrimer(String text) {
	if (text.equals("Universal_primer"))
	    return Read.UNIVERSAL_PRIMER;

	if (text.equals("Custom"))
	    return Read.CUSTOM_PRIMER;

	return Read.UNKNOWN;
    }

    private int parseChemistry(String text) {
	if (text.equals("Dye_terminator"))
	    return Read.DYE_TERMINATOR;

	if (text.equals("Dye_primer"))
	    return Read.DYE_PRIMER;

	return Read.UNKNOWN;
    }

    private Read registerNewRead(String name, int id, int template_id, java.sql.Date asped,
					 int strand, int primer, int chemistry) throws SQLException {
	Template template = adb.getTemplateManager().getTemplateByID(template_id);

	Read read = new Read(name, id, template, asped, strand, primer, chemistry, adb);

	hashByName.put(name, read);
	hashByID.put(new Integer(id), read);

	return read;
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
	    registerNewRead(name, id, template_id, asped, strand, primer, chemistry);
	}

	rs.close();
	stmt.close();
    }
}
