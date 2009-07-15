package uk.ac.sanger.arcturus.scaffold;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.Arcturus;

import java.util.*;
import java.sql.*;
import java.util.zip.DataFormatException;

public class ScaffoldBuilder {
	protected ArcturusDatabase adb;
	protected PreparedStatement pstmtContigData;
	protected PreparedStatement pstmtLeftEndReads;
	protected PreparedStatement pstmtRightEndReads;
	protected PreparedStatement pstmtTemplate;
	protected PreparedStatement pstmtLigation;
	protected PreparedStatement pstmtLinkReads;
	protected PreparedStatement pstmtMapping;

	protected int minlen = 0;
	protected int puclimit = 8000;
	protected int minbridges = 2;

	protected int flags = ArcturusDatabase.CONTIG_BASIC_DATA
			| ArcturusDatabase.CONTIG_TAGS;

	public ScaffoldBuilder(ArcturusDatabase adb) {
		this.adb = adb;
		
		String str = Arcturus.getProperty("scaffoldbuilder.puclimit");
		if (str != null) {
			try {
				puclimit = Integer.parseInt(str);
			}
			catch (NumberFormatException nfe) {
				Arcturus.logWarning("Error parsing value of scaffoldbuilder.puclimit", nfe);
			}
		}

		try {
			Connection conn = adb.getConnection();
			prepareStatements(conn);
		} catch (SQLException sqle) {
			sqle.printStackTrace();
		}
	}

	public void setMinimumLength(int minlen) {
		this.minlen = minlen;
	}

	public int getMinimumLength() {
		return minlen;
	}

	public void setPucLimit(int puclimit) {
		this.puclimit = puclimit;
	}

	public int getPucLimit() {
		return puclimit;
	}

	public void setMinimumBridges(int minbridges) {
		this.minbridges = minbridges;
	}

	public int getMinimumBridges() {
		return minbridges;
	}

	private void prepareStatements(Connection conn) throws SQLException {
		String query;

		query = "select length,gap4name,project_id"
				+ " from CURRENTCONTIGS"
				+ " where contig_id = ?";

		pstmtContigData = conn.prepareStatement(query);

		query = "select read_id,MAPPING.seq_id,cstart,cfinish,direction from"
				+ " MAPPING left join SEQ2READ using(seq_id) where contig_id = ?"
				+ " and cfinish < ? and direction = 'Reverse'";

		pstmtLeftEndReads = conn.prepareStatement(query);

		query = "select read_id,MAPPING.seq_id,cstart,cfinish,direction from"
				+ " MAPPING left join SEQ2READ using(seq_id) where contig_id = ?"
				+ " and cstart > ? and direction = 'Forward'";

		pstmtRightEndReads = conn.prepareStatement(query);

		query = "select template_id,strand from READINFO where read_id = ?";

		pstmtTemplate = conn.prepareStatement(query);

		query = "select silow,sihigh from TEMPLATE left join LIGATION using(ligation_id)"
				+ " where template_id = ?";

		pstmtLigation = conn.prepareStatement(query);

		query = "select READINFO.read_id,seq_id from READINFO left join SEQ2READ using(read_id)"
				+ " where template_id = ? and strand != ?";

		pstmtLinkReads = conn.prepareStatement(query);

		query = "select MAPPING.contig_id,MAPPING.cstart,MAPPING.cfinish,MAPPING.direction"
				+ " from MAPPING left join C2CMAPPING on MAPPING.contig_id = C2CMAPPING.parent_id"
				+ " where seq_id = ? and C2CMAPPING.parent_id is null";

		pstmtMapping = conn.prepareStatement(query);
	}

	protected boolean isCurrentContig(int contigid) throws SQLException {
		pstmtContigData.setInt(1, contigid);

		ResultSet rs = pstmtContigData.executeQuery();

		boolean found = rs.next();

		rs.close();

		return found;
	}

	private void fireEvent(ScaffoldBuilderListener listener, int mode, String message) {
		fireEvent(listener, mode, message, -1);
	}
	
	private void fireEvent(ScaffoldBuilderListener listener, int mode, String message, int value) {
		if (listener == null)
			return;
		
		ScaffoldEvent event = new ScaffoldEvent(this, mode, message, value);
		
		listener.scaffoldUpdate(event);
	}
	
	public Set createScaffold(int seedcontigid, ScaffoldBuilderListener listener)
			throws SQLException, DataFormatException {
		if (!adb.isCurrentContig(seedcontigid)) {
			fireEvent(listener, ScaffoldEvent.FINISH, "Not a current contig");

			return null;
		}

		SortedSet contigset = new TreeSet(new ContigLengthComparator());

		fireEvent(listener, ScaffoldEvent.START, "Initialising scaffold");

		Contig seedcontig = adb.getContigByID(seedcontigid, flags);

		Set subgraph = null;

		if (seedcontig != null) {
			contigset.add(seedcontig);

			BridgeSet bs = processContigSet(contigset, listener);

			subgraph = bs.getSubgraph(seedcontig, minbridges);
		}

		fireEvent(listener, ScaffoldEvent.FINISH, "Scaffold is complete");

		return subgraph;
	}

	public BridgeSet processContigSet(SortedSet contigset,
			ScaffoldBuilderListener listener) throws SQLException,
			DataFormatException {
		BridgeSet bridgeset = new BridgeSet();

		Set processed = new HashSet();
		
		int linksExamined = 0;
		int contigsExamined = 0;

		while (!contigset.isEmpty()) {
			fireEvent(listener, ScaffoldEvent.CONTIG_SET_INFO, "Contig set size",
					contigset.size());
			
			Contig contig = null;
			
			synchronized (contigset) {
				contig = (Contig) contigset.first();
				contigset.remove(contig);
			}
			
			if (processed.contains(contig))
				continue;

			processed.add(contig);

			if (contig.getLength() < minlen) {
				continue;
			}

			if (!isCurrentContig(contig.getID())) {
				System.err.println("Contig " + contig.getID() + " is no longer current");
			
				continue;
			}
			
			int contigid = contig.getID();
				
			fireEvent(listener, ScaffoldEvent.BEGIN_CONTIG,
					"Processing contig", contigid);

			int contiglength = contig.getLength();

			Set linkedContigs = new HashSet();

			for (int iEnd = 0; iEnd < 2; iEnd++) {
				int endcode = 2 * iEnd;

				PreparedStatement pstmt = (iEnd == 0) ? pstmtRightEndReads
						: pstmtLeftEndReads;

				int limit = (iEnd == 0) ? contig.getLength() - puclimit
						: puclimit;

				pstmt.setInt(1, contig.getID());
				pstmt.setInt(2, limit);

				ResultSet rs = pstmt.executeQuery();

				while (rs.next()) {
					int readid = rs.getInt(1);
					// int seqid = rs.getInt(2);
					int cstart = rs.getInt(3);
					int cfinish = rs.getInt(4);
					String direction = rs.getString(5);

					ReadMapping mappinga = new ReadMapping(readid, cstart,
							cfinish, direction.equalsIgnoreCase("Forward"));

					pstmtTemplate.setInt(1, readid);

					ResultSet rs2 = pstmtTemplate.executeQuery();

					int templateid = 0;
					String strand = null;

					if (rs2.next()) {
						templateid = rs2.getInt(1);
						strand = rs2.getString(2);
					}

					rs2.close();

					Template template = adb.getTemplateByID(templateid);

					int sihigh = 0;

					pstmtLigation.setInt(1, templateid);

					rs2 = pstmtLigation.executeQuery();

					if (rs2.next())
						sihigh = rs2.getInt(2);

					rs2.close();

					int overhang = (iEnd == 0) ? cstart + sihigh - contiglength
							: sihigh - cfinish;

					if (overhang < 1 || sihigh > puclimit)
						continue;

					pstmtLinkReads.setInt(1, templateid);
					pstmtLinkReads.setString(2, strand);

					rs2 = pstmtLinkReads.executeQuery();

					while (rs2.next()) {
						int link_readid = rs2.getInt(1);
						int link_seqid = rs2.getInt(2);

						pstmtMapping.setInt(1, link_seqid);

						ResultSet rs3 = pstmtMapping.executeQuery();

						if (rs3.next()) {
							int link_contigid = rs3.getInt(1);
							int link_cstart = rs3.getInt(2);
							int link_cfinish = rs3.getInt(3);
							String link_direction = rs3.getString(4);

							ReadMapping link_mapping = new ReadMapping(
									link_readid, link_cstart, link_cfinish,
									link_direction.equalsIgnoreCase("Forward"));

							Contig link_contig = adb.getContigByID(
									link_contigid, flags);

							int link_contiglength = link_contig.getLength();

							boolean link_forward = link_direction
									.equalsIgnoreCase("Forward");

							int gapsize = link_forward ? overhang
									- (link_contiglength - link_cstart)
									: overhang - link_cfinish;

							int myendcode = endcode;

							if (link_forward)
								myendcode++;

							if (contig != link_contig && gapsize > 0) {
								bridgeset.addBridge(contig, link_contig,
										myendcode, template, mappinga,
										link_mapping, new GapSize(gapsize));

								if (!linkedContigs.contains(link_contig)) {
									linkedContigs.add(link_contig);
									contigsExamined++;
									fireEvent(listener, ScaffoldEvent.CONTIGS_EXAMINED, null, contigsExamined);
								}
							}
							
							linksExamined++;
							fireEvent(listener, ScaffoldEvent.LINKS_EXAMINED, null, linksExamined);
						}

						rs3.close();
					}

					rs2.close();
				}

				rs.close();
			}

			for (Iterator iterator = linkedContigs.iterator(); iterator
					.hasNext();) {
				Contig link_contig = (Contig) iterator.next();

				for (int endcode = 0; endcode < 4; endcode++)
					if (bridgeset.getTemplateCount(contig, link_contig, endcode) >= minbridges
							&& !processed.contains(link_contig))
						contigset.add(link_contig);
			}
		}

		return bridgeset;
	}

	class ContigLengthComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			Contig c1 = (Contig) o1;
			Contig c2 = (Contig) o2;

			return c2.getLength() - c1.getLength();
		}
	}

}
