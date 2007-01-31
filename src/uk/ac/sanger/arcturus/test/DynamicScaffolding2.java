package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.scaffold.*;

import java.util.*;
import java.io.*;
import java.sql.*;
import java.util.zip.DataFormatException;

import java.awt.*;
import java.awt.event.*;
import java.awt.geom.*;
import javax.swing.*;

public class DynamicScaffolding2 {
	private String instance = null;
	private String organism = null;

	private int flags = ArcturusDatabase.CONTIG_BASIC_DATA
			| ArcturusDatabase.CONTIG_TAGS;

	private boolean lowmem = false;
	private boolean hamster = false;

	private int seedcontigid = 0;
	private int minlen = 0;
	private int puclimit = 8000;
	private int minbridges = 2;

	protected ArcturusDatabase adb = null;
	protected Connection conn = null;
	protected PreparedStatement pstmtContigData;
	protected PreparedStatement pstmtLeftEndReads;
	protected PreparedStatement pstmtRightEndReads;
	protected PreparedStatement pstmtTemplate;
	protected PreparedStatement pstmtLigation;
	protected PreparedStatement pstmtLinkReads;
	protected PreparedStatement pstmtMappings;

	public static void main(String args[]) {
		DynamicScaffolding2 ds = new DynamicScaffolding2();
		ds.execute(args);
	}

	public void execute(String args[]) {
		System.err.println("DynamicScaffolding2");
		System.err.println("===================");
		System.err.println();

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-minlen"))
				minlen = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-puclimit"))
				puclimit = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-minbridges"))
				minbridges = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-contig"))
				seedcontigid = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-debug")) {
			}

			if (args[i].equalsIgnoreCase("-lowmem"))
				lowmem = true;

			if (args[i].equalsIgnoreCase("-quiet")) {
			}

			if (args[i].equalsIgnoreCase("-hamster"))
				hamster = true;
		}

		if (instance == null || organism == null | seedcontigid == 0) {
			printUsage(System.err);
			System.exit(1);
		}

		String username = System.getProperty("user.name");

		hamster |= username.equalsIgnoreCase("carol")
				|| username.equalsIgnoreCase("klb");

		try {
			System.err.println("Creating an ArcturusInstance for " + instance);
			System.err.println();

			ArcturusInstance ai = ArcturusInstance.getInstance(instance);

			System.err.println("Creating an ArcturusDatabase for " + organism);
			System.err.println();

			adb = ai.findArcturusDatabase(organism);

			if (lowmem)
				adb.getSequenceManager().setCacheing(false);

			conn = adb.getConnection();

			if (conn == null) {
				System.err.println("Connection is undefined");
				printUsage(System.err);
				System.exit(1);
			}

			prepareStatements(conn);

			createScaffold();
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	private void prepareStatements(Connection conn) throws SQLException {
		String query;

		query = "select length,gap4name,project_id"
				+ "  from CONTIG  left join C2CMAPPING"
				+ "    on CONTIG.contig_id = C2CMAPPING.parent_id"
				+ " where CONTIG.contig_id = ? and C2CMAPPING.parent_id is null";

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

		query = "select contig_id,cstart,cfinish,direction from MAPPING where seq_id = ?";

		pstmtMappings = conn.prepareStatement(query);
	}

	protected boolean isCurrentContig(int contigid) throws SQLException {
		pstmtContigData.setInt(1, contigid);

		ResultSet rs = pstmtContigData.executeQuery();

		boolean found = rs.next();

		rs.close();

		return found;
	}

	protected void createScaffold() throws SQLException, DataFormatException {
		Vector contigset = new Vector();

		Contig seedcontig = adb.getContigByID(seedcontigid, flags);

		if (seedcontig == null || !isCurrentContig(seedcontigid))
			return;

		contigset.add(seedcontig);

		BridgeSet bs = processContigSet(contigset);

		bs.dump(System.out, minbridges);

		Set subgraph = bs.getSubgraph(seedcontig, minbridges);

		System.err.println();
		System.err.println("SUBGRAPH");
		for (Iterator iterator = subgraph.iterator(); iterator.hasNext();)
			System.err.println((Bridge) iterator.next());

		Map layout = createLayout(subgraph);

		ContigBox boxes[] = (ContigBox[]) layout.values().toArray(
				new ContigBox[0]);

		Arrays.sort(boxes, new ContigBoxComparator());

		System.out.println("\n\n----- LAYOUT -----\n");
		for (int i = 0; i < boxes.length; i++) {
			ContigBox cb = boxes[i];

			Contig contig = cb.getContig();
			int left = cb.getRange().getStart();
			int right = cb.getRange().getEnd();

			System.out.println("Contig " + contig.getID() + " : row "
					+ cb.getRow() + " from " + left + " to " + right + " in "
					+ (cb.isForward() ? "forward" : "reverse") + " sense");
		}

		displayScaffold(layout, subgraph, seedcontig);
	}

	private void displayScaffold(Map layout, Set bridges, Contig seedcontig) {
		JFrame frame = new JFrame("Scaffold from contig " + seedcontig.getID());

		Container contentpane = frame.getContentPane();

		contentpane.setLayout(new BorderLayout());

		final ScaffoldPanel panel = new ScaffoldPanel(layout, bridges,
				seedcontig);

		JScrollPane scrollpane = new JScrollPane(panel);

		contentpane.add(scrollpane, BorderLayout.CENTER);

		JToolBar toolbar = new JToolBar();

		java.net.URL url = ArcturusDatabase.class
				.getResource("/icons/zoomin.png");

		ImageIcon icon = new ImageIcon(url);

		JButton zoomInButton = new JButton(icon);

		zoomInButton.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setAction(ScaffoldPanel.ZOOM_IN);
			}
		});

		url = ArcturusDatabase.class.getResource("/icons/zoomout.png");

		icon = new ImageIcon(url);

		JButton zoomOutButton = new JButton(icon);

		zoomOutButton.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setAction(ScaffoldPanel.ZOOM_OUT);
			}
		});

		url = ArcturusDatabase.class.getResource("/icons/pick.png");

		icon = new ImageIcon(url);

		JButton selectButton = new JButton(icon);

		selectButton.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setAction(ScaffoldPanel.SELECT);
			}
		});

		ButtonGroup group = new ButtonGroup();

		group.add(zoomInButton);
		group.add(zoomOutButton);
		group.add(selectButton);

		toolbar.add(zoomInButton);
		toolbar.add(zoomOutButton);
		toolbar.add(selectButton);

		if (hamster) {
			toolbar.addSeparator(new Dimension(100, 50));

			final HamsterDance hampton = new HamsterDance(100);
			toolbar.add(hampton);

			final JButton hamsterButton = new JButton("Stop Hampton");

			hamsterButton.addActionListener(new ActionListener() {
				public void actionPerformed(ActionEvent e) {
					if (hampton.isRunning()) {
						hampton.stop();
						hamsterButton.setText("Start Hampton");
					} else {
						hampton.start();
						hamsterButton.setText("Stop Hampton");
					}
				}
			});

			toolbar.add(hamsterButton);
		}

		toolbar.setFloatable(false);

		contentpane.add(toolbar, BorderLayout.NORTH);

		frame.setSize(650, 500);
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		frame.setVisible(true);
	}

	protected BridgeSet processContigSet(Vector contigset) throws SQLException,
			DataFormatException {
		BridgeSet bridgeset = new BridgeSet();

		Set processed = new HashSet();

		while (!contigset.isEmpty()) {
			Contig contig = (Contig) contigset.elementAt(0);
			contigset.removeElementAt(0);

			if (processed.contains(contig))
				continue;

			processed.add(contig);

			if (contig.getLength() < minlen)
				continue;

			if (!isCurrentContig(contig.getID()))
				continue;

			System.err.println("Processing contig " + contig.getID());

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

						pstmtMappings.setInt(1, link_seqid);

						ResultSet rs3 = pstmtMappings.executeQuery();

						while (rs3.next()) {
							int link_contigid = rs3.getInt(1);
							int link_cstart = rs3.getInt(2);
							int link_cfinish = rs3.getInt(3);
							String link_direction = rs3.getString(4);

							ReadMapping link_mapping = new ReadMapping(
									link_readid, link_cstart, link_cfinish,
									link_direction.equalsIgnoreCase("Forward"));

							if (isCurrentContig(link_contigid)) {
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

									linkedContigs.add(link_contig);
								}
							}
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
					if (bridgeset
							.getTemplateCount(contig, link_contig, endcode) >= minbridges
							&& !processed.contains(link_contig))
						contigset.add(link_contig);
			}
		}

		return bridgeset;
	}

	protected void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS:");
		ps.println("\t-instance\tName of instance");
		ps.println("\t-organism\tName of organism");
		ps.println("\t-contig\t\tContig ID");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-minlen\t\tMinimum contig length");
		ps.println("\t-puclimit\tAssumed maximum pUC insert size");
		ps
				.println("\t-minbridges\tMinimum number of pUC bridges for a valid link");
		ps.println();
		ps.println("OPTIONS");
		String[] options = { "-debug", "-lowmem", "-quiet" };
		for (int i = 0; i < options.length; i++)
			ps.println("\t" + options[i]);
	}

	protected Map createLayout(Set bridges) {
		Map layout = new HashMap();
		RowRanges rowranges = new RowRanges();

		Vector bridgevector = new Vector(bridges);

		Collections.sort(bridgevector, new BridgeComparator());

		System.out.println("Sorted graph:");
		for (int j = 0; j < bridgevector.size(); j++)
			System.out.println("\t" + bridgevector.elementAt(j));

		Bridge bridge = (Bridge) bridgevector.firstElement();
		bridgevector.removeElementAt(0);

		Contig contiga = bridge.getContigA();
		Contig contigb = bridge.getContigB();
		int endcode = bridge.getEndCode();
		int gapsize = bridge.getGapSize().getMinimum();

		Range rangea = new Range(0, contiga.getLength());

		int rowa = rowranges.addRange(rangea, 0);

		ContigBox cba = new ContigBox(contiga, rowa, rangea, true);
		layout.put(contiga, cba);

		ContigBox cbb = calculateRelativePosition(cba, contiga, contigb,
				endcode, gapsize, rowranges);
		layout.put(contigb, cbb);

		System.out.println("# Using " + bridge);
		System.out.println("Laid out contig " + contiga.getID() + " at " + cba);
		System.out.println("Laid out contig " + contigb.getID() + " at " + cbb);

		while (bridgevector.size() > 0) {
			bridge = null;

			boolean hasa = false;
			boolean hasb = false;

			for (int i = 0; i < bridgevector.size(); i++) {
				Bridge nextbridge = (Bridge) bridgevector.elementAt(i);

				contiga = nextbridge.getContigA();
				contigb = nextbridge.getContigB();

				hasa = layout.containsKey(contiga);
				hasb = layout.containsKey(contigb);

				if (hasa || hasb) {
					bridge = nextbridge;
					bridgevector.removeElementAt(i);
					break;
				}
			}

			if (bridge != null) {
				System.out.println("# Using " + bridge);
				if (hasa && hasb) {
					System.out.println("INCONSISTENCY : Both contig "
							+ contiga.getID() + " and contig "
							+ contigb.getID() + " have been laid out already.");
				} else {
					endcode = bridge.getEndCode();
					gapsize = bridge.getGapSize().getMinimum();

					if (hasa) {
						cba = (ContigBox) layout.get(contiga);

						cbb = calculateRelativePosition(cba, contiga, contigb,
								endcode, gapsize, rowranges);
						layout.put(contigb, cbb);

						System.out.println("Laid out contig " + contigb.getID()
								+ " at " + cbb);
					} else {
						cbb = (ContigBox) layout.get(contigb);

						if (endcode == 0 || endcode == 3)
							endcode = 3 - endcode;

						cba = calculateRelativePosition(cbb, contigb, contiga,
								endcode, gapsize, rowranges);
						layout.put(contiga, cba);

						System.out.println("Laid out contig " + contiga.getID()
								+ " at " + cba);
					}
				}
			} else {
				System.out.println("INCONSISTENCY : Neither contig "
						+ contiga.getID() + " nor contig " + contigb.getID()
						+ " have been laid out yet.");
				break;
			}
		}

		normaliseLayout(layout);

		return layout;
	}

	private ContigBox calculateRelativePosition(ContigBox cba, Contig contiga,
			Contig contigb, int endcode, int gapsize, RowRanges rowranges) {
		int starta = cba.getRange().getStart();
		boolean forwarda = cba.isForward();
		int lengtha = contiga.getLength();
		int enda = starta + lengtha;
		int rowa = cba.getRow();

		boolean forwardb = (endcode == 0 || endcode == 3) ? forwarda
				: !forwarda;

		int startb;
		int endb;

		if ((endcode > 1) ^ forwarda) {
			startb = enda + gapsize;
			endb = startb + contigb.getLength() - 1;
		} else {
			endb = starta - gapsize;
			startb = endb - contigb.getLength() + 1;
		}

		Range rangeb = new Range(startb, endb);

		int rowb = rowranges.addRange(rangeb, rowa);

		return new ContigBox(contigb, rowb, rangeb, forwardb);
	}

	private void normaliseLayout(Map layout) {
		int xmin = 0;

		for (Iterator iterator = layout.entrySet().iterator(); iterator
				.hasNext();) {
			Map.Entry mapentry = (Map.Entry) iterator.next();
			ContigBox cb = (ContigBox) mapentry.getValue();
			int left = cb.getRange().getStart();
			if (left < xmin)
				xmin = left;
		}

		if (xmin == 0)
			return;

		xmin = -xmin;

		for (Iterator iterator = layout.entrySet().iterator(); iterator
				.hasNext();) {
			Map.Entry mapentry = (Map.Entry) iterator.next();
			ContigBox cb = (ContigBox) mapentry.getValue();
			cb.getRange().shift(xmin);
		}
	}

	class BridgeComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			Bridge bridgea = (Bridge) o1;
			Bridge bridgeb = (Bridge) o2;

			return bridgeb.getLinkCount() - bridgea.getLinkCount();
		}
	}

	class ContigBox {
		protected Contig contig;
		protected int row;
		protected Range range;
		protected boolean forward;

		public ContigBox(Contig contig, int row, Range range, boolean forward) {
			this.contig = contig;
			this.row = row;
			this.range = range;
			this.forward = forward;
		}

		public Contig getContig() {
			return contig;
		}

		public int getRow() {
			return row;
		}

		public Range getRange() {
			return range;
		}

		public int getLeft() {
			return range.getStart();
		}

		public int getRight() {
			return range.getEnd();
		}

		public int getLength() {
			return range.getLength();
		}

		public boolean isForward() {
			return forward;
		}

		public String toString() {
			return "ContigBox[row=" + row + ", range=" + range.getStart()
					+ ".." + range.getEnd() + ", "
					+ (forward ? "forward" : "reverse") + "]";
		}
	}

	class ContigBoxComparator implements Comparator {
		public int compare(Object o1, Object o2) {
			ContigBox box1 = (ContigBox) o1;
			ContigBox box2 = (ContigBox) o2;

			int diff = box1.getLeft() - box2.getLeft();

			if (diff != 0)
				return diff;

			diff = box1.getRight() - box2.getRight();

			if (diff != 0)
				return diff;
			else
				return box1.getRow() - box2.getRow();
		}
	}

	class Range {
		protected int start;
		protected int end;

		public Range(int start, int end) {
			this.start = (start < end) ? start : end;
			this.end = (start < end) ? end : start;
		}

		public int getStart() {
			return start;
		}

		public int getEnd() {
			return end;
		}

		public int getLength() {
			return 1 + end - start;
		}

		public boolean overlaps(Range that) {
			return !(start > that.end || end < that.start);
		}

		public void shift(int offset) {
			start += offset;
			end += offset;
		}
	}

	class RowRanges {
		Vector rangesets = new Vector();

		public int addRange(Range range, int tryrow) {
			for (int row = tryrow; row < rangesets.size(); row++) {
				Set ranges = (Set) rangesets.elementAt(row);

				if (!overlaps(range, ranges)) {
					ranges.add(range);
					return row;
				}
			}

			for (int row = tryrow - 1; row >= 0; row--) {
				Set ranges = (Set) rangesets.elementAt(row);

				if (!overlaps(range, ranges)) {
					ranges.add(range);
					return row;
				}
			}

			Set ranges = new HashSet();
			ranges.add(range);

			rangesets.add(ranges);
			return rangesets.indexOf(ranges);
		}

		private boolean overlaps(Range range, Set ranges) {
			for (Iterator iterator = ranges.iterator(); iterator.hasNext();) {
				Range rangeInRow = (Range) iterator.next();
				if (range.overlaps(rangeInRow))
					return true;
			}

			return false;
		}
	}

	class ContigInfoPanel extends JPanel {
		/**
		 * 
		 */
		private static final long serialVersionUID = -4581239937285251083L;
		protected String[] lines = new String[5];
		protected ScaffoldPanel parent;
		protected Font plainFont = new Font("SansSerif", Font.PLAIN, 14);
		protected Font boldFont = new Font("SansSerif", Font.BOLD, 14);

		protected String[] labels = { "CONTIG", "Name:", "Length:", "Reads:",
				"Project:" };

		protected int valueOffset;

		public ContigInfoPanel(ScaffoldPanel myparent) {
			this.parent = myparent;

			setBackground(new Color(255, 204, 0));

			addMouseListener(new MouseAdapter() {
				public void mousePressed(MouseEvent event) {
					parent.hidePopup();
				}
			});
		}

		public void setContig(Contig contig) {
			createStrings(contig);

			FontMetrics fm = getFontMetrics(boldFont);

			valueOffset = fm.stringWidth(labels[0]) + fm.stringWidth("    ");

			int txtheight = lines.length * fm.getHeight();

			int txtwidth = 0;

			for (int j = 0; j < lines.length; j++) {
				int sw = fm.stringWidth(lines[j]);
				if (sw > txtwidth)
					txtwidth = sw;
				if (j == 0)
					fm = getFontMetrics(boldFont);
			}

			setPreferredSize(new Dimension(valueOffset + txtwidth,
					txtheight + 5));
		}

		private void createStrings(Contig contig) {
			lines[0] = "" + contig.getID();

			lines[1] = contig.getName();

			lines[2] = "" + contig.getLength();

			lines[3] = "" + contig.getReadCount();

			lines[4] = contig.getProject().getName();
		}

		public void paintComponent(Graphics g) {
			Dimension size = getSize();
			g.setColor(getBackground());
			g.fillRect(0, 0, size.width, size.height);

			g.setColor(Color.black);

			FontMetrics fm = getFontMetrics(plainFont);

			int y0 = fm.getAscent();
			int dy = fm.getHeight();

			g.setFont(boldFont);

			for (int j = 0; j < lines.length; j++) {
				int x = 0;
				int y = y0 + j * dy;
				g.drawString(labels[j], x, y);
				g.drawString(lines[j], valueOffset + x, y);
				if (j == 0) {
					g.setFont(plainFont);
					g.drawLine(0, y + 5, size.width, y + 5);
					y0 += 5;
				}
			}
		}
	}

	class BridgeInfoPanel extends JPanel {
		/**
		 * 
		 */
		private static final long serialVersionUID = -941901174344922774L;
		protected String[] lines;
		protected ScaffoldPanel parent;
		protected Font plainFont = new Font("SansSerif", Font.PLAIN, 14);
		protected Font boldFont = new Font("SansSerif", Font.BOLD, 14);

		protected final String RIGHT = "Right";
		protected final String LEFT = "Left";

		public BridgeInfoPanel(ScaffoldPanel myparent) {
			this.parent = myparent;

			setBackground(new Color(255, 204, 0));

			addMouseListener(new MouseAdapter() {
				public void mousePressed(MouseEvent event) {
					parent.hidePopup();
				}
			});
		}

		public void setBridge(Bridge bridge) {
			createStrings(bridge);

			FontMetrics fm = getFontMetrics(boldFont);

			int txtheight = lines.length * fm.getHeight();

			int txtwidth = 0;

			for (int j = 0; j < lines.length; j++) {
				int sw = fm.stringWidth(lines[j]);
				if (sw > txtwidth)
					txtwidth = sw;
				if (j == 0)
					fm = getFontMetrics(boldFont);
			}

			setPreferredSize(new Dimension(txtwidth, txtheight + 10));
		}

		private void createStrings(Bridge bridge) {
			GapSize gapsize = bridge.getGapSize();
			Contig contiga = bridge.getContigA();
			Contig contigb = bridge.getContigB();

			int endcode = bridge.getEndCode();

			String enda = (endcode < 2) ? RIGHT : LEFT;
			String endb = ((endcode % 2) == 0) ? LEFT : RIGHT;

			Template templates[] = (Template[]) bridge.getLinks().keySet()
					.toArray(new Template[0]);

			int linkcount = templates.length;

			lines = new String[linkcount + 5];

			lines[0] = "BRIDGE";

			lines[1] = enda + " end of contig " + contiga.getID();

			lines[2] = endb + " end of contig " + contigb.getID();

			lines[3] = "Gap size " + gapsize.getMinimum() + " to "
					+ gapsize.getMaximum() + " bp";

			lines[4] = "TEMPLATES";

			for (int j = 0; j < linkcount; j++)
				lines[j + 5] = templates[j].getName();
		}

		public void paintComponent(Graphics g) {
			Dimension size = getSize();
			g.setColor(getBackground());
			g.fillRect(0, 0, size.width, size.height);

			g.setColor(Color.black);

			FontMetrics fm = getFontMetrics(plainFont);

			int y0 = fm.getAscent();
			int dy = fm.getHeight();

			g.setFont(boldFont);

			for (int j = 0; j < lines.length; j++) {
				int x = 0;
				int y = y0 + j * dy;
				g.drawString(lines[j], x, y);
				if (j == 0 || j == 3) {
					g.setFont(plainFont);
					g.drawLine(0, y + 5, size.width, y + 5);
					y0 += 5;
				}
			}
		}
	}

	class ScaffoldPanel extends JComponent {
		/**
		 * 
		 */
		private static final long serialVersionUID = -8189985057439118138L;
		public static final int ZOOM_IN = 1;
		public static final int ZOOM_OUT = 2;
		public static final int SELECT = 3;

		protected int mode;
		protected int bpPerPixel = 128;

		protected Insets margins = new Insets(20, 20, 20, 20);

		protected int interScaffoldGap = 1000;
		protected int contigBarHeight = 20;
		protected int contigBarGap = 20;

		protected int xmin;
		protected int xmax;

		protected Map layout;
		protected Set bridgeset;
		protected ContigBox[] contigBoxes;

		protected Map mapBoxes = new HashMap();
		protected Map mapBridges = new HashMap();

		protected Contig seedcontig;

		protected Cursor csrZoomIn = null;
		protected Cursor csrZoomOut = null;
		protected Cursor csrSelect = Cursor
				.getPredefinedCursor(Cursor.DEFAULT_CURSOR);

		protected ContigInfoPanel cip;
		protected BridgeInfoPanel bip;
		protected Popup popup;

		public ScaffoldPanel(Map layout, Set bridgeset, Contig seedcontig) {
			super();
			setBackground(new Color(0xff, 0xff, 0xee));

			Toolkit tk = Toolkit.getDefaultToolkit();

			java.net.URL url = ArcturusDatabase.class
					.getResource("/icons/zoomin.png");

			Image cursorImage = tk.getImage(url);

			csrZoomIn = tk.createCustomCursor(cursorImage, new Point(7, 7),
					"zoom in");

			url = ArcturusDatabase.class.getResource("/icons/zoomout.png");

			cursorImage = tk.getImage(url);

			csrZoomOut = tk.createCustomCursor(cursorImage, new Point(7, 7),
					"zoom out");

			setAction(SELECT);

			cip = new ContigInfoPanel(this);
			bip = new BridgeInfoPanel(this);

			// ToolTipManager.sharedInstance().registerComponent(this);

			addMouseListener(new MouseAdapter() {
				public void mouseClicked(MouseEvent e) {
					actOnMouseClick(e);
				}
			});

			this.layout = layout;
			this.bridgeset = bridgeset;
			this.seedcontig = seedcontig;

			contigBoxes = (ContigBox[]) layout.values().toArray(
					new ContigBox[0]);

			Arrays.sort(contigBoxes, new ContigBoxComparator());

			recalculateLayout();
		}

		public void setAction(int newmode) {
			switch (newmode) {
				case ZOOM_IN:
					mode = newmode;
					setCursor(csrZoomIn);
					break;

				case ZOOM_OUT:
					mode = newmode;
					setCursor(csrZoomOut);
					break;

				case SELECT:
					mode = newmode;
					setCursor(csrSelect);
			}
		}

		private void actOnMouseClick(MouseEvent e) {
			Point click = e.getPoint();

			hidePopup();

			switch (mode) {
				case ZOOM_IN:
					zoomIn(click);
					break;

				case ZOOM_OUT:
					zoomOut(click);
					break;

				case SELECT:
					Object o = getObjectAt(click);

					if (o != null) {
						if (o instanceof Contig) {
							Contig contig = (Contig) o;
							cip.setContig(contig);
							displayPopup(cip, click);
						} else if (o instanceof Bridge) {
							Bridge bridge = (Bridge) o;
							bip.setBridge(bridge);
							displayPopup(bip, click);
						}
					}
					break;
			}
		}

		private Object getObjectAt(Point click) {
			Contig contig = getContigAt(click);

			if (contig != null)
				return contig;

			Bridge bridge = getBridgeAt(click);

			return bridge;
		}

		private ContigBox getContigBoxAt(Point click) {
			for (Iterator iterator = mapBoxes.keySet().iterator(); iterator
					.hasNext();) {
				Rectangle2D.Double rect = (Rectangle2D.Double) iterator.next();
				if (rect.contains(click)) {
					ContigBox cbox = (ContigBox) mapBoxes.get(rect);
					return cbox;
				}
			}

			return null;
		}

		private Contig getContigAt(Point click) {
			ContigBox cbox = getContigBoxAt(click);

			return (cbox != null) ? cbox.getContig() : null;
		}

		private Bridge getBridgeAt(Point click) {
			for (Iterator iterator = mapBridges.keySet().iterator(); iterator
					.hasNext();) {
				Shape shape = (Shape) iterator.next();
				if (shape.contains(click)) {
					Bridge bridge = (Bridge) mapBridges.get(shape);
					return bridge;
				}
			}

			return null;
		}

		private void displayPopup(ContigInfoPanel cip, Point p) {
			SwingUtilities.convertPointToScreen(p, this);

			PopupFactory factory = PopupFactory.getSharedInstance();
			popup = factory.getPopup(this, cip, p.x, p.y);
			popup.show();
		}

		private void displayPopup(BridgeInfoPanel bip, Point p) {
			SwingUtilities.convertPointToScreen(p, this);

			PopupFactory factory = PopupFactory.getSharedInstance();
			popup = factory.getPopup(this, bip, p.x, p.y);
			popup.show();
		}

		public void hidePopup() {
			if (popup != null) {
				popup.hide();
				popup = null;
			}
		}

		public String getToolTipText(MouseEvent event) {
			Object o = getObjectAt(event.getPoint());

			if (o != null) {
				if (o instanceof Contig) {
					Contig contig = (Contig) o;
					Project project = contig.getProject();

					return "Contig "
							+ contig.getID()
							+ " ("
							+ contig.getName()
							+ ") "
							+ contig.getLength()
							+ " bp, "
							+ contig.getReadCount()
							+ " reads"
							+ ((project == null) ? " (project not known)"
									: " in project " + project.getName());
				}

				if (o instanceof Bridge) {
					Bridge bridge = (Bridge) o;
					GapSize gapsize = bridge.getGapSize();
					return "Bridge between contig "
							+ bridge.getContigA().getID() + " and "
							+ bridge.getContigB().getID() + " from "
							+ bridge.getLinkCount() + " templates, gap size "
							+ gapsize.getMinimum() + " to "
							+ gapsize.getMaximum() + " bp";
				}
			}

			return getToolTipText();
		}

		public void zoomIn(Point p) {
			if (bpPerPixel < 4) {
				System.err
						.println("Scale is 1 bp/pixel: Cannot zoom in any further");
				return;
			}

			int newBpPerPixel = bpPerPixel >> 2;

			rescale(p, newBpPerPixel);
		}

		public void zoomOut(Point p) {
			int newBpPerPixel = bpPerPixel << 2;

			rescale(p, newBpPerPixel);
		}

		protected void rescale(Point p, int newBpPerPixel) {
			Point wp = viewToWorld(p);

			JViewport viewport = (JViewport) getParent();
			Point vp = viewport.getViewPosition();

			Point offset = new Point(p.x - vp.x, p.y - vp.y);

			bpPerPixel = newBpPerPixel;

			p = worldToView(wp);

			vp = new Point(p.x - offset.x, p.y - offset.y);

			recalculateLayout();

			setSize(getPreferredSize());
			revalidate();

			viewport.setViewPosition(vp);
			vp = viewport.getViewPosition();
		}

		private Point viewToWorld(Point p) {
			int x = (p.x - margins.left) * bpPerPixel;
			int y = (p.y - margins.top);

			return new Point(x, y);
		}

		private Point worldToView(Point p) {
			int x = margins.left + p.x / bpPerPixel;
			int y = margins.top + p.y;

			return new Point(x, y);
		}

		protected void recalculateLayout() {
			int width = margins.left + margins.right;
			int height = margins.top + margins.bottom;

			int y0 = margins.top + 5 + 2 * contigBarGap;

			if (contigBoxes != null) {
				xmin = contigBoxes[0].getLeft();
				xmax = contigBoxes[0].getRight();

				int maxrow = 0;

				mapBoxes.clear();

				for (int j = 0; j < contigBoxes.length; j++) {
					ContigBox box = contigBoxes[j];

					int row = box.getRow();
					if (row > maxrow)
						maxrow = row;

					int left = box.getLeft();
					int right = box.getRight();

					if (left < xmin)
						xmin = left;

					if (right > xmax)
						xmax = right;

					int x = margins.left + box.getLeft() / bpPerPixel;

					int dy = row * (contigBarHeight + contigBarGap);

					int w = box.getLength() / bpPerPixel;

					Rectangle2D.Double rect = new Rectangle2D.Double(
							(double) x, (double) (y0 + dy), (double) w,
							(double) contigBarHeight);

					mapBoxes.put(rect, box);
				}

				width += (xmax - xmin + 1) / bpPerPixel;

				height += (1 + maxrow) * contigBarHeight + maxrow
						* contigBarGap;
			}

			setPreferredSize(new Dimension(width, height));

			if (bridgeset != null) {
				mapBridges.clear();

				for (Iterator iterator = bridgeset.iterator(); iterator
						.hasNext();) {
					Bridge bridge = (Bridge) iterator.next();

					Contig contiga = bridge.getContigA();
					Contig contigb = bridge.getContigB();

					int endcode = bridge.getEndCode();

					ContigBox boxa = (ContigBox) layout.get(contiga);

					int xa = boxa.getLeft();
					int dxa = -10;

					boolean rightenda = (endcode < 2);

					if (rightenda ^ !boxa.isForward()) {
						xa += boxa.getLength();
						dxa = 10;
					}

					xa = margins.left + xa / bpPerPixel;

					int rowa = boxa.getRow();

					int dya = rowa * (contigBarHeight + contigBarGap)
							+ contigBarHeight / 2;

					ContigBox boxb = (ContigBox) layout.get(contigb);

					int xb = boxb.getLeft();
					int dxb = -10;

					boolean rightendb = (endcode % 2) != 0;

					if (rightendb ^ !boxb.isForward()) {
						xb += boxb.getLength();
						dxb = 10;
					}

					xb = margins.left + xb / bpPerPixel;

					int rowb = boxb.getRow();

					int dyb = rowb * (contigBarHeight + contigBarGap)
							+ contigBarHeight / 2;

					int links = bridge.getLinkCount();

					if (links > 5)
						links = 5;

					Shape path = new CubicCurve2D.Double((double) xa,
							(double) (y0 + dya), (double) (xa + dxa),
							(double) (y0 + dya), (double) (xb + dxb),
							(double) (y0 + dyb), (double) xb,
							(double) (y0 + dyb));

					Stroke stroke = new BasicStroke((float) links);

					Shape outline = stroke.createStrokedShape(path);

					mapBridges.put(outline, bridge);
				}
			}
		}

		public void paintComponent(Graphics gr) {
			Graphics2D g = (Graphics2D) gr;

			g.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
					RenderingHints.VALUE_ANTIALIAS_ON);

			Font font = new Font("SansSerif", Font.PLAIN, 10);

			g.setFont(font);

			Dimension size = getSize();

			g.setColor(getBackground());

			g.fillRect(0, 0, size.width, size.height);

			if (contigBoxes == null)
				return;

			g.setColor(Color.black);

			int y0 = margins.top + 5;

			int widthbp = xmax;
			int widthkb = widthbp / 1000;

			g.drawLine(margins.left, y0, margins.left + widthbp / bpPerPixel,
					y0);

			for (int i = 0; i < widthkb; i++) {
				int x = margins.left + (1000 * i) / bpPerPixel;

				int dy = 3;

				if ((i % 10) == 0)
					dy = 5;

				if ((i % 100) == 0)
					dy = 7;

				g.drawLine(x, y0, x, y0 + dy);
			}

			y0 += 2 * contigBarGap;

			Stroke thinline = new BasicStroke(2.0f, BasicStroke.CAP_ROUND,
					BasicStroke.JOIN_ROUND);

			int seedcontigproject = seedcontig.getProject().getID();

			for (Iterator iterator = mapBoxes.entrySet().iterator(); iterator
					.hasNext();) {
				Map.Entry entry = (Map.Entry) iterator.next();

				ContigBox box = (ContigBox) entry.getValue();
				Rectangle2D.Double rect = (Rectangle2D.Double) entry.getKey();

				Contig contig = box.getContig();

				boolean sameProject = seedcontigproject == contig.getProject()
						.getID();

				Color boxcolor = box.isForward() ? Color.blue : Color.red;

				if (!sameProject)
					boxcolor = boxcolor.darker().darker();

				g.setColor(boxcolor);

				g.fill(rect);

				double x = rect.getX();
				double y = rect.getY();
				double h = rect.getHeight();
				double w = rect.getWidth();

				Vector tags = contig.getTags();

				g.setColor(Color.green);

				for (int j = 0; j < tags.size(); j++) {
					ContigTag tag = (ContigTag) tags.elementAt(j);

					if (tag.getType().equalsIgnoreCase("REPT")) {
						int cstart = tag.getContigStart();
						int cfinish = tag.getContigFinish();

						int taglen = 1 + cfinish - cstart;

						double dx = (double) cstart / (double) bpPerPixel;

						double xtag = box.isForward() ? x + dx : x + w - dx;
						double wtag = (double) taglen / (double) bpPerPixel;

						Rectangle2D.Double rept = new Rectangle2D.Double(xtag,
								y, wtag, h);

						g.fill(rept);
					}
				}

				g.setColor(Color.black);

				if (contig == seedcontig) {
					g.setStroke(thinline);
					g.draw(rect);
				}

				String cid = "" + box.getContig().getName();

				g.drawString(cid, (int) x, (int) y - 2);
			}

			g.setColor(Color.black);

			for (Iterator iterator = mapBridges.entrySet().iterator(); iterator
					.hasNext();) {
				Map.Entry entry = (Map.Entry) iterator.next();

				Shape outline = (Shape) entry.getKey();

				g.fill(outline);
			}
		}
	}

}
