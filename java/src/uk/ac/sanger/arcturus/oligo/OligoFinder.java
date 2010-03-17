package uk.ac.sanger.arcturus.oligo;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import java.sql.*;
import java.util.zip.*;
import java.io.UnsupportedEncodingException;

import java.util.regex.Pattern;
import java.util.regex.Matcher;

import com.mysql.jdbc.MysqlErrorNumbers;

public class OligoFinder {
	private Connection conn = null;

	private OligoFinderEventListener listener;
	private OligoFinderEvent event;

	private Inflater decompresser = new Inflater();
	
	private int passValue;
	
	private final int RETRY_INTERVAL = 10000;
	private final int RETRY_ATTEMPTS = 5;
	
	//private int oldTransactionIsolationLevel;
	
	// The name of the temporary table for busy reads (reads which are in current contigs)
	private final String BUSY_READS = "tmpBUSYREADS";
	
	// The name of the temporary table for free reads (reads which are not in current contigs)
	private final String FREE_READS = "tmpFREEREADS";
	
	private final String CREATE_BUSY_READS_TABLE =
		"create temporary table if not exists " + BUSY_READS +
			" (read_id int not null primary key) ENGINE=InnoDB";
	
	private final String CREATE_FREE_READS_TABLE =
		"create temporary table if not exists " + FREE_READS +
			" (read_id int not null primary key, readname char(64) not null) ENGINE=InnoDB";
	
	private final String GET_PASS_VALUE = "select status_id from STATUS where name = ?";
	
	private final String EMPTY_BUSY_READS_TABLE = "delete from " + BUSY_READS;
	private PreparedStatement pstmtEmptyBusyReadsTable;
	
	private final String EMPTY_FREE_READS_TABLE = "delete from " + FREE_READS;
	private PreparedStatement pstmtEmptyFreeReadsTable;
	
	private final String POPULATE_BUSY_READS_TABLE = "insert into " + BUSY_READS + "(read_id)" +
		" select distinct read_id from (CURRENTCONTIGS left join MAPPING using(contig_id)) left join SEQ2READ using (seq_id)";
	private PreparedStatement pstmtPopulateBusyReadsTable;
	
	private final String POPULATE_FREE_READS_TABLE = "insert into " + FREE_READS + "(read_id,readname)" +
		" select R.read_id,R.readname from READINFO R left join " + BUSY_READS + " using (read_id)" +
		" where " + BUSY_READS + ".read_id is null and R.status = ?";
	private PreparedStatement pstmtPopulateFreeReadsTable;
	
	private final String SUM_CONTIG_LENGTH_FOR_PROJECT = "select sum(length) from CURRENTCONTIGS where project_id = ?";
	private PreparedStatement pstmtSumContigLengthForProject;
	
	private final String GET_CONTIG_SEQUENCES = "select CC.contig_id,CC.gap4name,CS.length,P.name,CS.sequence" + 
		" from CURRENTCONTIGS CC left join (PROJECT P,CONSENSUS CS) using (contig_id)" +
		" where CC.project_id=P.project_id and CC.project_id = ? order by CC.contig_id asc";
	private PreparedStatement pstmtGetContigSequences;
	
	private final String GET_READ_SEQUENCES = "select R.read_id,R.readname,S.seqlen,null as project,S.sequence" +
		" from " + FREE_READS + " R left join (SEQ2READ SR,SEQUENCE S) using(read_id)" +
		" where SR.version=0 and SR.seq_id=S.seq_id order by R.read_id";
	private PreparedStatement pstmtGetReadSequences;

	public OligoFinder(ArcturusDatabase adb, OligoFinderEventListener listener) {
		event = new OligoFinderEvent(this);

		this.listener = listener;

		try {
			conn = adb.getPooledConnection(this);
			
			//oldTransactionIsolationLevel = conn.getTransactionIsolation();
			
			//conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
			
			createTemporaryTables();
			passValue = getPassValue();
			prepareStatements();
		} catch (SQLException sqle) {
			Arcturus.logWarning("Error when initialising database connection",
					sqle);
		}
	}

	private int getPassValue() throws SQLException {
		PreparedStatement pstmt = conn.prepareStatement(GET_PASS_VALUE);
		
		pstmt.setString(1, "PASS");
		
		ResultSet rs = pstmt.executeQuery();
		
		int rc = rs.next() ? rs.getInt(1) : -1;
		
		rs.close();
		pstmt.close();
		
		return rc;
	}

	private void createTemporaryTables() throws SQLException {
		Statement stmt = conn.createStatement();
		stmt.execute(CREATE_BUSY_READS_TABLE);
		stmt.execute(CREATE_FREE_READS_TABLE);
		stmt.close();
	}
	
	private void prepareStatements() throws SQLException {
		pstmtEmptyBusyReadsTable = conn.prepareStatement(EMPTY_BUSY_READS_TABLE);
		pstmtPopulateBusyReadsTable = conn.prepareStatement(POPULATE_BUSY_READS_TABLE);
		
		pstmtEmptyFreeReadsTable = conn.prepareStatement(EMPTY_FREE_READS_TABLE);
		pstmtPopulateFreeReadsTable = conn.prepareStatement(POPULATE_FREE_READS_TABLE);

		pstmtSumContigLengthForProject = conn.prepareStatement(SUM_CONTIG_LENGTH_FOR_PROJECT);
		
		pstmtGetContigSequences = conn.prepareStatement(GET_CONTIG_SEQUENCES, ResultSet.TYPE_FORWARD_ONLY,
	              ResultSet.CONCUR_READ_ONLY);
		
		pstmtGetContigSequences.setFetchSize(Integer.MIN_VALUE);
		
		pstmtGetReadSequences = conn.prepareStatement(GET_READ_SEQUENCES, ResultSet.TYPE_FORWARD_ONLY,
	              ResultSet.CONCUR_READ_ONLY);
		
		pstmtGetReadSequences.setFetchSize(Integer.MIN_VALUE);
	}
	
	private void closeStatements() throws SQLException {
		pstmtEmptyBusyReadsTable.close();
		pstmtPopulateBusyReadsTable.close();
		
		pstmtEmptyFreeReadsTable.close();
		pstmtPopulateFreeReadsTable.close();

		pstmtSumContigLengthForProject.close();
		
		pstmtGetContigSequences.close();
		
		pstmtGetReadSequences.close();		
	}
	
	public synchronized int findMatches(Oligo[] oligos, int[] projectIDs,
			boolean searchFreeReads)
			throws SQLException {
		int found = 0;
		
		if (projectIDs != null && projectIDs.length > 0)
			found += findContigMatches(oligos, projectIDs);
		
		if (searchFreeReads)
			found += findFreeReadMatches(oligos);

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH, null, null, -1, false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}
	
	private int findContigMatches(Oligo[] oligos, int[] projectIDs) throws SQLException {
		int totlen = getTotalContigLength(projectIDs);

		if (listener != null) {
			event.setEvent(OligoFinderEvent.START_CONTIGS, null, null,
					totlen, false);
			listener.oligoFinderUpdate(event);
		}

		int found = 0;
		
		for (int i = 0; i < projectIDs.length; i++)
			found += findContigMatches(oligos, projectIDs[i]);

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH_CONTIGS, null, null, -1,
					false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}
	
	private int findContigMatches(Oligo[] oligos, int projectID) throws SQLException {
		pstmtGetContigSequences.setInt(1, projectID);
		
		ResultSet rs = pstmtGetContigSequences.executeQuery();
		
		int rc = processResultSet(rs, oligos, DNASequence.CONTIG);
		
		rs.close();
		
		return rc;
	}
	
	private int getTotalContigLength(int[] projectIDs) throws SQLException {
		int total = 0;
		
		for (int i = 0; i < projectIDs.length; i++)
			total += getTotalContigLength(projectIDs[i]);
		
		return total;
	}
	
	private int getTotalContigLength(int projectID) throws SQLException {
		pstmtSumContigLengthForProject.setInt(1, projectID);
		
		ResultSet rs = pstmtSumContigLengthForProject.executeQuery();
		
		int totlen = rs.next() ? rs.getInt(1) : 0;
		
		rs.close();
		
		return totlen;
	}

	private int findFreeReadMatches(Oligo[] oligos) throws SQLException {
		if (listener != null) {
			event.setEvent(OligoFinderEvent.ENUMERATING_FREE_READS, null, null,
					0, false);
			listener.oligoFinderUpdate(event);
		}
		
		int nreads = countFreeReads();
		
		if (listener != null) {
			event.setEvent(OligoFinderEvent.START_READS, null, null,
					nreads, false);
			listener.oligoFinderUpdate(event);
		}
		
		int found = 0;
		
		if (nreads > 0)
			found = scanFreeReads(oligos);

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH_READS, null, null,
					-1, false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}

	private int countFreeReads() throws SQLException {
		int busyreads = updateBusyReadsTable();
		
		if (busyreads < 0)
			return -1;
		else
			return updateFreeReadsTable();
	}
	
	private int retryDatabaseOperation(PreparedStatement emptyStatement, PreparedStatement populateStatement, int retryInterval, int retryAttempts)
		throws SQLException {
		int rows = -1;
		
		int tries = 1;
		
		while (tries <= retryAttempts) {
			try {
				logMessage("Attempt #" + tries);
				
				rows = emptyStatement.executeUpdate();
				
				logMessage("Deleted " + rows + " rows");
				
				long ticks = System.currentTimeMillis();

				rows = populateStatement.executeUpdate();

				ticks = System.currentTimeMillis() - ticks;
				
				logMessage("Table populated with " + rows + " rows in " + ticks + " ms");
				
				return rows;
			}
			catch (SQLException sqle) {
				boolean nonfatal = sqle instanceof SQLTransactionRollbackException || 
					sqle.getErrorCode() == MysqlErrorNumbers.ER_LOCK_WAIT_TIMEOUT;
				
				if (nonfatal && tries < retryAttempts) {
					try {
						tries++;
						Thread.sleep(retryInterval);
					} catch (InterruptedException ie) {
						return rows;
					}				
				} else
					throw sqle;
			}
		}
		
		return rows;
	}
	
	private int updateBusyReadsTable() throws SQLException {
		logMessage("Updating busy reads table ...");
		return retryDatabaseOperation(pstmtEmptyBusyReadsTable, pstmtPopulateBusyReadsTable, RETRY_INTERVAL, RETRY_ATTEMPTS);
	}
	
	private int updateFreeReadsTable() throws SQLException {
		logMessage("Updating free reads table ...");

		pstmtPopulateFreeReadsTable.setInt(1, passValue);

		return retryDatabaseOperation(pstmtEmptyFreeReadsTable, pstmtPopulateFreeReadsTable, RETRY_INTERVAL, RETRY_ATTEMPTS);
	}
	
	private void logMessage(String message) {
		if (listener != null) {
			event.setEvent(OligoFinderEvent.MESSAGE, message);
			listener.oligoFinderUpdate(event);
		}
	}
	
	private int scanFreeReads(Oligo[] oligos) throws SQLException {
		ResultSet rs = pstmtGetReadSequences.executeQuery();
		
		int rc = processResultSet(rs, oligos, DNASequence.READ);
		
		rs.close();
		
		return rc;
	}
	
	private int processResultSet(ResultSet rs, Oligo[] oligos, int type) throws SQLException {
		int total = 0;

		while (rs.next()) {
			int ID = rs.getInt(1);
			String sequenceName = rs.getString(2);
			int sequenceLength = rs.getInt(3);
			String projectName = rs.getString(4);
			byte[] sequence = rs.getBytes(5);
			
			sequence = inflate(sequence, sequenceLength);
			
			String dna = null;

			try {
				dna = new String(sequence, "US-ASCII");
			} catch (UnsupportedEncodingException e) {
				Arcturus.logWarning("Error whilst converting DNA sequence data to string", e);
			}
			
			DNASequence dnaseq = (type == DNASequence.READ) ? DNASequence.createReadInstance(ID, sequenceName) :
				DNASequence.createContigInstance(ID, sequenceName, sequenceLength, projectName);
			
			total += findMatches(oligos, dnaseq, dna);
		}
		
		return total;
	}
	
	private int findMatches(Oligo[] oligos, DNASequence dnaSequence, String sequence) {
		if (sequence == null)
			return 0;
		
		int found = 0;

		if (listener != null) {
			event.setEvent(OligoFinderEvent.START_SEQUENCE, null, dnaSequence,
					0, false);
			listener.oligoFinderUpdate(event);
		}

		if (sequence != null) {
			event.setDNASequence(dnaSequence);
			
			found += findMatchesByRegex(oligos, sequence);
		}

		int sequencelen = sequence == null ? 0 : sequence.length();

		if (listener != null) {
			event.setEvent(OligoFinderEvent.FINISH_SEQUENCE, null,
					sequencelen, false);
			listener.oligoFinderUpdate(event);
		}

		return found;
	}
	
	private int findMatchesByRegex(Oligo[] oligos, String sequence) {
		int hits = 0;
		
		for (Oligo oligo : oligos) {
			hits += findRegexMatch(oligo, true, sequence);
			
			if (!oligo.isPalindrome())
				hits += findRegexMatch(oligo, false, sequence);
		}
		
		return hits;
	}
	
	private int findRegexMatch(Oligo oligo, boolean forward, String sequence) {
		int hits = 0;
		
		Pattern pattern = forward ? oligo.getForwardPattern() : oligo.getReversePattern();
		
		Matcher matcher = pattern.matcher(sequence);
		
		while (matcher.find()) {
			int offset = matcher.start();
			reportMatch(oligo, offset, forward);
			hits++;
		}
		
		return hits;
	}
	
	private void reportMatch(Oligo oligo, int offset, boolean forward) {
		if (listener != null) {
			event.setEvent(OligoFinderEvent.FOUND_MATCH, oligo,
					offset, forward);
			listener.oligoFinderUpdate(event);
		}

	}

	private byte[] inflate(byte[] cdata, int length) {
		if (cdata == null)
			return null;

		if (cdata.length == length)
			return cdata;

		byte[] data = new byte[length];

		decompresser.setInput(cdata, 0, cdata.length);
		
		try {
			decompresser.inflate(data, 0, data.length);
		} catch (DataFormatException dfe) {
			Arcturus.logWarning(
					"An error occurred whilst decompressing consensus data",
					dfe);
			data = null;
		}

		decompresser.reset();

		return data;
	}

	public void close() throws SQLException {
		closeConnection();
	}

	private void closeConnection() throws SQLException {
		if (conn != null) {
			closeStatements();
			//conn.setTransactionIsolation(oldTransactionIsolationLevel);
			conn.close();
			conn = null;
		}
	}
}
