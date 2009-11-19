package uk.ac.sanger.arcturus.utils;

import java.io.PrintStream;
import java.sql.*;
import java.util.List;
import java.util.Vector;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class ListForeignKeyConstraints {
	public static final int AS_SQL = 1;
	public static final int AS_TABLE = 2;
	
	public static final char TAB = '\t';
	
	public static void main(String[] args) {
		ListForeignKeyConstraints lfkc = new ListForeignKeyConstraints();
		int rc = lfkc.execute(args);
		System.exit(rc);
	}
	
	public int execute(String[] args) {
		String instance = null;
		String organism = null;
		int mode = AS_SQL;
		
		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];
			
			if (args[i].equalsIgnoreCase("-table"))
				mode = AS_TABLE;
			
			if (args[i].equalsIgnoreCase("-sql"))
				mode = AS_SQL;
		}
		

		if (instance == null || organism == null) {
			printUsage(System.err);
			return 1;
		}

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			Connection conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				return 1;
			}
			
			int rc = listForeignKeyConstraints(conn, mode);
			
			conn.close();
			
			return rc;
		}
		catch (Exception e) {
			Arcturus.logSevere(e);
			return 1;
		}
	}
	
	private int listForeignKeyConstraints(Connection conn, int mode) throws SQLException {
		DatabaseMetaData dmd = conn.getMetaData();
		
		Statement stmt = conn.createStatement();
		
		ResultSet rs = stmt.executeQuery("select database()");
		
		String database = rs.next() ? rs.getString(1) : null;
		
		rs.close();
		
		stmt.close();
		
		if (database == null) {
			System.err.println("Unable to determine database name");
			return 1;
		}
		
		String[] types = { "TABLE" };
		
		rs = dmd.getTables(null, database, null, types);
		
		List<String> tables = new Vector<String>();
		
		while (rs.next()) {
			tables.add(rs.getString(3));
		}
		
		rs.close();
		
		if (mode == AS_TABLE)
			System.out.println("#TABLE\tCOLUMN\tREFTABLE\tREFCOLUMN\tONDELETE\tONUPDATE");
		
		for (String table : tables) {
			rs = dmd.getExportedKeys(null, database, table);
			
			reportResults(rs, mode);
			
			rs.close();
		}
		
		return 0;
	}
	
	private void reportResults(ResultSet rs, int mode) throws SQLException {
		while (rs.next()) {
			String table = rs.getString(3);
			String column = rs.getString(4);
			
			String fk_table = rs.getString(7);
			String fk_column = rs.getString(8);
			
			String update_rule = ruleCodeToString(rs.getShort(10));
			String delete_rule = ruleCodeToString(rs.getShort(11));
			
			switch (mode) {								
				case AS_TABLE:
					System.out.println(fk_table + TAB + fk_column + TAB + table + TAB + column + TAB +
							delete_rule + TAB + update_rule);
					break;

				case AS_SQL:
				default:
					System.out.print("alter table " + fk_table + " add constraint foreign key (" +
							fk_column + ")");
					System.out.print(" references " + table + "(" + column + ")");
					System.out.print(" ON UPDATE " + update_rule);
					System.out.println(" ON DELETE " + delete_rule + ";");
					break;

			}
		}		
	}
	
	private String ruleCodeToString(short code) {
		switch (code) {
			case DatabaseMetaData.importedKeyNoAction:
			case DatabaseMetaData.importedKeyRestrict:
				return "RESTRICT";
				
			case DatabaseMetaData.importedKeyCascade:
				return "CASCADE";
				
			case DatabaseMetaData.importedKeySetNull:
				return "SET NULL";
				
			case DatabaseMetaData.importedKeySetDefault:
				return "SET DEFAULT";
				
			default:
				return "UNKNOWN";
		}
	}

	public void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println();
		ps.println("OPTIONAL PARAMETERS:");
		ps.println("\t-sql\t\tOutput in SQL mode");
		ps.println("\t-table\t\tOutput in tabular mode");
	}
}
