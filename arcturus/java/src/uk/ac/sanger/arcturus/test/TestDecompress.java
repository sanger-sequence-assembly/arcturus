import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;

import javax.naming.*;
import javax.sql.*;
import java.sql.*;
import java.util.*;
import java.util.zip.*;

public class TestDecompress {
    public static void main(String args[]) {
	System.out.println("TestDecompress");
	System.out.println("==============");
	System.out.println();

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	try {
	    ArcturusInstance ai = new ArcturusInstance(props, "dev");

	    ArcturusDatabase adb = ai.findArcturusDatabase("EIMER");

	    testArcturusDatabase(adb);
	}
	catch (SQLException sqle) {
	    sqle.printStackTrace();
	}
	catch (DataFormatException dfe) {
	    dfe.printStackTrace();
	}
	catch (NamingException ne) {
	    ne.printStackTrace();
	}
    }

    public static void testArcturusDatabase(ArcturusDatabase adb)
	throws SQLException, DataFormatException {
	Inflater decompresser = new Inflater();	System.out.println(adb);
	Connection conn = adb.getConnection();

	String query = "select contig_id,length,sequence,quality from CONSENSUS where length < 40 order by contig_id asc";

	Statement stmt = conn.createStatement();

	ResultSet rs = stmt.executeQuery(query);

	while (rs.next()) {
	    int contig_id = rs.getInt(1);
	    int seqlen = rs.getInt(2);
	    byte[] cdna = rs.getBytes(3);
	    byte[] cqual = rs.getBytes(4);

	    System.out.println("CONTIG " + contig_id + ": " + seqlen + " bp");

	    byte[] dna = new byte[seqlen];

	    decompresser.setInput(cdna, 0, cdna.length);
	    int dnalen = decompresser.inflate(dna, 0, dna.length);
	    decompresser.reset();

	    System.out.println("  Sequence: " + cdna.length + " compressed, " + dnalen + " uncompressed");

	    byte[] qual = new byte[seqlen];
	
	    decompresser.setInput(cqual, 0, cqual.length);
	    int quallen = decompresser.inflate(qual, 0, qual.length);
	    decompresser.reset();

	    System.out.println("  Quality: " + cqual.length + " compressed, " + quallen + " uncompresed");

	    for (int i = 0; i < cqual.length; i++) {
		int j = (int)cqual[i];
		if (j < 0)
		    j += 256;

		System.out.print(j);
		System.out.print(' ');
	    }

	    System.out.println();

	    for (int i = 0; i < qual.length; i++) {
		System.out.print((int)qual[i]);
		System.out.print(' ');
	    }

	    System.out.println();
	    System.out.println();
	}

	rs.close();
	stmt.close();
	conn.close();
    }
}
