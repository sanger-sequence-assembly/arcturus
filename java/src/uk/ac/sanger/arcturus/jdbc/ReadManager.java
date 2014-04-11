// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.jdbc;

import uk.ac.sanger.arcturus.data.CapillaryRead;
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
	
	private PreparedStatement pstmtPreloadReads, pstmtByID, pstmtByName, pstmtByTemplate;
	private PreparedStatement pstmtByNameAndFlags;
	private PreparedStatement pstmtInsertNewReadName, pstmtInsertNewReadMetadata;
	
	private static final String READ_COLUMNS = "RN.read_id,readname,flags,RI.read_id,template_id,asped,strand,primer,chemistry,basecaller,status";
	
	private static final String READ_TABLES = "READNAME RN left join READINFO RI using(read_id)";
	
	private static final String READ_TABLES_REVERSED = "READINFO RI left join READNAME RN using(read_id)"; 
	
	private static final String PRELOAD_READS =
		"select " + READ_COLUMNS + " from " + READ_TABLES;
	
	private static final String GET_READ_BY_ID =
		"select " + READ_COLUMNS + " from " + READ_TABLES + " where RN.read_id = ?";
	
	private static final String GET_READ_BY_NAME =
		"select " + READ_COLUMNS + " from " + READ_TABLES + " where readname = ?";
	
	private static final String GET_READ_BY_NAME_AND_FLAGS =
		"select " + READ_COLUMNS + " from " + READ_TABLES + " where readname = ? and flags = ?";
	
	private static final String GET_READS_BY_TEMPLATE_ID =
		"select " + READ_COLUMNS + " from " + READ_TABLES_REVERSED + " where template_id = ?";
	
	private static final String PUT_READ_NAME =
		"insert into READNAME (readname, flags) VALUES (?,?)";
	
	private static final String PUT_READ_METADATA =
		"insert into READINFO (read_id,template_id,asped,strand,primer,chemistry,basecaller,status) VALUES (?,?,?,?,?,?,?,?)";

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

		pstmtByNameAndFlags = prepareStatement(GET_READ_BY_NAME_AND_FLAGS);

		pstmtByTemplate = prepareStatement(GET_READS_BY_TEMPLATE_ID);
		
		pstmtInsertNewReadName = prepareStatement(PUT_READ_NAME, Statement.RETURN_GENERATED_KEYS);
		
		pstmtInsertNewReadMetadata = prepareStatement(PUT_READ_METADATA);
		
		pstmtPreloadReads = prepareStatement(PRELOAD_READS, ResultSet.TYPE_FORWARD_ONLY,
	              ResultSet.CONCUR_READ_ONLY);
		
		pstmtPreloadReads.setFetchSize(Integer.MIN_VALUE);
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

	public Read getReadByNameAndFlags(String name, int flags) throws ArcturusDatabaseException {
		return getReadByNameAndFlags(name, flags, true);
	}

	public Read getReadByNameAndFlags(String name, int flags, boolean autoload)
			throws ArcturusDatabaseException {
		Object obj = hashByName.get(name);

		return (obj == null && autoload) ? loadReadByNameAndFlags(name, flags) : (Read) obj;
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
		int flags = rs.getInt(index++);
		
		rs.getInt(index++);
		
		if (rs.wasNull()) {
			return createAndRegisterNewRead(read_id, name, flags);
		} else {
			int template_id = rs.getInt(index++);
			java.util.Date asped = rs.getTimestamp(index++);
			int strand = parseStrand(rs.getString(index++));
			int primer = parsePrimer(rs.getString(index++));
			int chemistry = parseChemistry(rs.getString(index++));

			int basecaller_id = rs.getInt(index++);
			int status_id = rs.getInt(index++);

			String basecaller = dictBasecaller.getValue(basecaller_id);
			String status = dictStatus.getValue(status_id);

			return createAndRegisterNewCapillaryRead(name, read_id, template_id, asped,
					strand, primer, chemistry, basecaller, status);
		}
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

	private Read loadReadByNameAndFlags(String name, int flags) throws ArcturusDatabaseException {
		Read read = null;

		try {
			pstmtByNameAndFlags.setString(1, name);
			pstmtByNameAndFlags.setInt(2, flags);
			
			ResultSet rs = pstmtByNameAndFlags.executeQuery();

			if (rs.next())
				read = createReadFromResultSet(rs);

			rs.close();
		} catch (SQLException e) {
			adb.handleSQLException(e, "Failed to load read by name=\"" + name + "\" and flags=" + flags,
					conn, this);
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
			return CapillaryRead.UNKNOWN;
		
		if (text.equals(CapillaryRead.FORWARD_STRING))
			return CapillaryRead.FORWARD;

		if (text.equals(CapillaryRead.REVERSE_STRING))
			return CapillaryRead.REVERSE;

		return CapillaryRead.UNKNOWN;
	}
	
	public static String strandToString(int value) {
		switch (value) {
			case CapillaryRead.FORWARD:
				return CapillaryRead.FORWARD_STRING;
				
			case CapillaryRead.REVERSE:
				return CapillaryRead.REVERSE_STRING;
				
			default:
				return CapillaryRead.UNKNOWN_STRING;
		}
	}

	public static int parsePrimer(String text) {
		if (text == null)
			return CapillaryRead.UNKNOWN;
		
		if (text.equals(CapillaryRead.UNIVERSAL_PRIMER_STRING))
			return CapillaryRead.UNIVERSAL_PRIMER;

		if (text.equals(CapillaryRead.CUSTOM_PRIMER_STRING))
			return CapillaryRead.CUSTOM_PRIMER;

		return CapillaryRead.UNKNOWN;
	}
	
	public static String primerToString(int value) {
		switch (value) {
			case CapillaryRead.UNIVERSAL_PRIMER:
				return CapillaryRead.UNIVERSAL_PRIMER_STRING;
				
			case CapillaryRead.CUSTOM_PRIMER:
				return CapillaryRead.CUSTOM_PRIMER_STRING;
				
			default:
				return CapillaryRead.UNKNOWN_STRING;
		}
	}

	public static int parseChemistry(String text) {
		if (text == null)
			return CapillaryRead.UNKNOWN;
		
		if (text.equals(CapillaryRead.DYE_TERMINATOR_STRING))
			return CapillaryRead.DYE_TERMINATOR;

		if (text.equals(CapillaryRead.DYE_PRIMER_STRING))
			return CapillaryRead.DYE_PRIMER;

		return CapillaryRead.UNKNOWN;
	}
	
	public static String chemistryToString(int value) {
		switch (value) {
			case CapillaryRead.DYE_PRIMER:
				return CapillaryRead.DYE_PRIMER_STRING;
				
			case CapillaryRead.DYE_TERMINATOR:
				return CapillaryRead.DYE_TERMINATOR_STRING;
				
			default:
				return CapillaryRead.UNKNOWN_STRING;
		}
	}

	private Read createAndRegisterNewCapillaryRead(String name, int id, int template_id,
			java.util.Date asped, int strand, int primer, int chemistry, String basecaller, String status)
			throws ArcturusDatabaseException {
		Template template = adb.getTemplateByID(template_id);

		Read read = new CapillaryRead(name, id, template, asped, strand, primer,
				chemistry, basecaller, status, adb);

		cacheNewRead(read);

		return read;
	}
	
	private Read createAndRegisterNewRead(int id, String name, int flags) {
		Read read = new Read(id, name, flags);
		
		cacheNewRead(read);
		
		return read;
	}

	void cacheNewRead(Read read) {
		if (cacheing) {
			hashByName.put(read.getUniqueName(), read);
			hashByID.put(new Integer(read.getID()), read);
		}
	}

	public void preload() throws ArcturusDatabaseException {

		try {
			ResultSet rs = pstmtPreloadReads.executeQuery();
			
			int count = 0;

			while (rs.next()) {
				createReadFromResultSet(rs);
				
				count++;
				if ((count%1000000) == 0)
					System.err.println("ReadManager.preload: loaded " + count + " reads");
			}

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
	
	public Read findOrCreateRead(Read read)
		throws ArcturusDatabaseException {
		if (read == null)
			throw new ArcturusDatabaseException("Cannot find/create a null read");
		
		if (read.getName() == null)
			throw new ArcturusDatabaseException("Cannot find/create a read with no name");
	
		String readName = read.getUniqueName();
		
		Read cachedRead = hashByName.get(readName);
		
		if (cachedRead != null)
			return cachedRead;
		
		Read storedRead = getReadByNameAndFlags(read.getName(), read.getFlags());
		
		if (storedRead != null)
			return storedRead;
		
		return putRead(read);
	}
	
	private boolean storeCapillaryData(CapillaryRead read) throws ArcturusDatabaseException {
		Template template = read.getTemplate();
		
		if (template != null)
			template = adb.findOrCreateTemplate(template);
		
		int template_id = (template == null) ? 0 : template.getID();
		
		String strand = strandToString(read.getStrand());
		String primer = primerToString(read.getPrimer());
		String chemistry = chemistryToString(read.getChemistry());
					
		java.util.Date asped = read.getAsped();
		
		java.sql.Date asped2 = asped == null ? null : new java.sql.Date(asped.getTime());
		
		int status_id = dictStatus.getID(read.getStatus());
		int basecaller_id = dictBasecaller.getID(read.getBasecaller());
		
		try {
			pstmtInsertNewReadMetadata.setInt(1, read.getID());

			pstmtInsertNewReadMetadata.setInt(2, template_id);

			if (asped2 == null)
				pstmtInsertNewReadMetadata.setNull(3, Types.DATE);
			else
				pstmtInsertNewReadMetadata.setDate(3, asped2);

			pstmtInsertNewReadMetadata.setString(4, strand);
			pstmtInsertNewReadMetadata.setString(5, primer);
			pstmtInsertNewReadMetadata.setString(6, chemistry);

			if (basecaller_id > 0)
				pstmtInsertNewReadMetadata.setInt(7, basecaller_id);
			else
				pstmtInsertNewReadMetadata.setNull(7, Types.INTEGER);
			
			if (status_id > 0)
				pstmtInsertNewReadMetadata.setInt(8, status_id);
			else
				pstmtInsertNewReadMetadata.setNull(8, Types.INTEGER);
			
			int rc = pstmtInsertNewReadMetadata.executeUpdate();
			
			return rc == 1;
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to put capillary read data for name=\"" + read.getName() + "\"", conn, this);
		}
		
		return false;
	}
	
	public Read putRead(Read read) throws ArcturusDatabaseException {
		if (read == null)
			throw new ArcturusDatabaseException("Cannot put a null read");
		
		if (read.getName() == null)
			throw new ArcturusDatabaseException("Cannot put a read with no name");
		
		String readName = read.getName();

		try {
			int read_id = -1;
			
			pstmtInsertNewReadName.setString(1, readName);
			pstmtInsertNewReadName.setInt(2, read.getFlags());

			int rc = pstmtInsertNewReadName.executeUpdate();
			
			if (rc == 1) {
				ResultSet rs = pstmtInsertNewReadName.getGeneratedKeys();
				
				if (rs.next())
					read_id = rs.getInt(1);
				
				rs.close();
			}
			
			boolean success = read_id > 0;
			
			if (success && read instanceof CapillaryRead) {
				read.setID(read_id);
				success = storeCapillaryData((CapillaryRead)read);
			}
			
			if (success)
				return registerNewRead(read, read_id);
		}
		catch (SQLException e) {
			adb.handleSQLException(e, "Failed to put read name=\"" + readName + "\"", conn, this);
		}
		
		return null;
	}
	
	private Read registerNewRead(Read read, int read_id) {
		read.setID(read_id);
		read.setArcturusDatabase(adb);
		
		cacheNewRead(read);
		
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

	public String getCacheStatistics() {
		return "ByID: " + hashByID.size() + ", ByName: " + hashByName.size();
	}
}
