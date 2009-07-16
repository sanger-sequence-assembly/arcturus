package uk.ac.sanger.arcturus.test.scaffolding;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;

import java.util.Vector;
import java.util.Enumeration;
import java.util.Random;

public class ScaffoldPanel extends JComponent {
	/**
	 * 
	 */
	private static final long serialVersionUID = 614053315151039990L;
	public static final int ZOOM_IN = 1;
	public static final int ZOOM_OUT = 2;
	public static final int SELECT = 3;

	protected int mode;
	protected int bpPerPixel = 128;

	protected Insets margins = new Insets(20, 20, 20, 20);

	protected int interScaffoldGap = 1000;
	protected int contigBarHeight = 15;

	protected ContigBar[] contigBars = null;
	protected ScaffoldBar[] scaffoldBars = null;
	protected LinkLine[] pucLines = null;
	protected LinkLine[] bacLines = null;

	protected Cursor csrZoomIn = null;
	protected Cursor csrZoomOut = null;
	protected Cursor csrSelect = Cursor
			.getPredefinedCursor(Cursor.DEFAULT_CURSOR);

	Random random = new Random();

	public ScaffoldPanel() {
		super();
		setBackground(new Color(0xff, 0xff, 0xee));

		Toolkit tk = Toolkit.getDefaultToolkit();
		Image cursorImage = tk.getImage("zoomin.png");

		csrZoomIn = tk.createCustomCursor(cursorImage, new Point(7, 7),
				"zoom in");

		cursorImage = tk.getImage("zoomout.png");
		csrZoomOut = tk.createCustomCursor(cursorImage, new Point(7, 7),
				"zoom out");

		setAction(SELECT);

		addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				actOnMouseClick(e);
			}
		});

		setPreferredSize(new Dimension(100, 100));
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

	private String getModeAsString() {
		switch (mode) {
			case ZOOM_IN:
				return "ZOOM_IN";
			case ZOOM_OUT:
				return "ZOOM_OUT";
			case SELECT:
				return "SELECT";
			default:
				return "UNKNOWN";
		}
	}

	private void actOnMouseClick(MouseEvent e) {
		System.out.println("Mouse clicked at " + e.getX() + "," + e.getY()
				+ " in " + getModeAsString() + " mode");

		Point click = e.getPoint();

		switch (mode) {
			case ZOOM_IN:
				zoomIn(click);
				break;

			case ZOOM_OUT:
				zoomOut(click);
				break;
		}
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

	private String p2s(Point p) {
		return "[" + p.x + "," + p.y + "]";
	}

	protected void rescale(Point p, int newBpPerPixel) {
		System.err.println("rescale(" + p2s(p) + ", " + newBpPerPixel);
		System.err.println("\tOld bpPerPixel = " + bpPerPixel);

		Point wp = viewToWorld(p);

		System.err.println("\tWorld position = " + p2s(wp));

		JViewport viewport = (JViewport) getParent();
		Point vp = viewport.getViewPosition();

		System.err.println("\tViewport position = " + p2s(vp));

		Point offset = new Point(p.x - vp.x, p.y - vp.y);

		System.err.println("\tOffset = " + p2s(offset));

		bpPerPixel = newBpPerPixel;

		System.err.println("\tSet bpPerPixel to " + bpPerPixel);

		p = worldToView(wp);

		System.err.println("\tNew view position = " + p2s(p));

		vp = new Point(p.x - offset.x, p.y - offset.y);

		System.err.println("\tNew viewport position = " + p2s(vp));

		recalculateLayout();

		setSize(getPreferredSize());
		revalidate();

		Dimension size = getSize();
		System.err.println("\tSize = " + size.width + "x" + size.height);

		viewport.setViewPosition(vp);
		vp = viewport.getViewPosition();
		System.err.println("\tActual vp = " + p2s(vp));
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

	public void setSuperScaffold(SuperScaffold ss) {
		makeBars(ss);

		recalculateLayout();

		setSize(getPreferredSize());

		revalidate();
	}

	public void setScale(int bpPerPixel) {
		this.bpPerPixel = bpPerPixel;

		recalculateLayout();

		setSize(getPreferredSize());

		revalidate();
	}

	protected void makeBars(SuperScaffold ss) {
		Vector ctgbars = new Vector();
		Vector scafbars = new Vector();

		Object[] items = ss.toArray();

		int left = 0;
		int scaffolds = 0;

		for (int i = 0; i < items.length; i++) {
			Object item = items[i];

			if (item instanceof Scaffold) {
				scaffolds++;
				if (scaffolds > 1)
					left += interScaffoldGap;

				Scaffold scaffold = (Scaffold) item;

				int scafleft = left;

				Object[] subitems = scaffold.toArray();

				if (!scaffold.isForward()) {
					int k = subitems.length - 1;

					for (int j = 0; j < subitems.length / 2; j++, k--) {
						Object tmp = subitems[k];
						subitems[k] = subitems[j];
						subitems[j] = tmp;
					}
				}

				for (int j = 0; j < subitems.length; j++) {
					Object subitem = subitems[j];

					if (subitem instanceof Contig) {
						Contig contig = (Contig) subitem;
						boolean forward = scaffold.isForward() ? contig
								.isForward() : !contig.isForward();
						ctgbars.add(new ContigBar(contig.getId(), forward,
								left, contig.getSize()));
						left += contig.getSize();
					} else {
						Gap gap = (Gap) subitem;
						left += gap.getSize();
					}
				}

				scafbars.add(new ScaffoldBar(scafleft, left - scafleft));
			}
		}

		contigBars = (ContigBar[]) ctgbars.toArray(new ContigBar[0]);
		scaffoldBars = (ScaffoldBar[]) scafbars.toArray(new ScaffoldBar[0]);

		Vector pucs = new Vector();
		Vector bacs = new Vector();

		recursiveBridgeSearch(ss, pucs, bacs);

		pucLines = (LinkLine[]) pucs.toArray(new LinkLine[0]);
		bacLines = (LinkLine[]) bacs.toArray(new LinkLine[0]);
	}

	private void recursiveBridgeSearch(Core core, Vector pucs, Vector bacs) {
		if (core instanceof Bridge) {
			addBridge((SuperBridge) core, pucs);
		} else if (core instanceof SuperBridge) {
			addBridge((SuperBridge) core, bacs);
		} else {
			for (Enumeration e = core.elements(); e.hasMoreElements();) {
				Object obj = e.nextElement();

				if (obj instanceof Core)
					recursiveBridgeSearch((Core) obj, pucs, bacs);
			}
		}
	}

	private void addBridge(SuperBridge sb, Vector v) {
		Link linkA = sb.getLinkA();
		Link linkB = sb.getLinkB();

		ContigBar ctgbarA = getContigBar(linkA.getContigId());
		ContigBar ctgbarB = getContigBar(linkB.getContigId());

		if (ctgbarA == null || ctgbarB == null)
			return;

		int leftA, rightA, leftB, rightB;

		if (ctgbarA.isForward()) {
			leftA = ctgbarA.getLeft() + linkA.getCStart();
			rightA = ctgbarA.getLeft() + linkA.getCFinish();
		} else {
			leftA = ctgbarA.getRight() - linkA.getCStart();
			rightA = ctgbarA.getRight() - linkA.getCFinish();
		}

		if (ctgbarB.isForward()) {
			leftB = ctgbarB.getLeft() + linkB.getCStart();
			rightB = ctgbarB.getLeft() + linkB.getCFinish();
		} else {
			leftB = ctgbarB.getRight() - linkB.getCStart();
			rightB = ctgbarB.getRight() - linkB.getCFinish();
		}

		int dy = 3 + random.nextInt(5);

		v.add(new LinkLine(leftA, rightA, leftB, rightB, dy));
	}

	private ContigBar getContigBar(int id) {
		if (contigBars == null)
			return null;

		for (int i = 0; i < contigBars.length; i++)
			if (contigBars[i].getContigId() == id)
				return contigBars[i];

		return null;
	}

	protected void recalculateLayout() {
		int width = margins.left + margins.right;
		int height = margins.top + margins.bottom + 200;

		if (contigBars != null) {
			int k = contigBars.length - 1;
			int left = contigBars[0].getLeft();
			int right = contigBars[k].getRight();
			width += (right - left + 1) / bpPerPixel;
		}

		setPreferredSize(new Dimension(width, height));
	}

	public void paintComponent(Graphics gr) {
		Graphics2D g = (Graphics2D) gr;

		Dimension size = getSize();

		g.setColor(getBackground());

		g.fillRect(0, 0, size.width, size.height);

		if (contigBars == null)
			return;

		g.setColor(Color.black);

		int y = margins.top + 5;

		int widthbp = contigBars[contigBars.length - 1].getRight();
		int widthkb = widthbp / 1000;

		g.drawLine(margins.left, y, margins.left + widthbp / bpPerPixel, y);

		for (int i = 0; i < widthkb; i++) {
			int x = margins.left + (1000 * i) / bpPerPixel;

			int dy = 3;

			if ((i % 10) == 0)
				dy = 5;

			if ((i % 100) == 0)
				dy = 7;

			g.drawLine(x, y, x, y + dy);
		}

		y += 15;

		for (int i = 0; i < scaffoldBars.length; i++) {
			ScaffoldBar sbar = scaffoldBars[i];

			int x = margins.left + sbar.getLeft() / bpPerPixel;

			int w = sbar.getLength() / bpPerPixel;
			int h = 4;

			g.fillRect(x, y, w, h);

			g.drawLine(x, y, x, y + 2 * h);

			x += w;

			g.drawLine(x, y, x, y + 2 * h);
		}

		y += 15;

		for (int i = 0; i < contigBars.length; i++) {
			ContigBar bar = contigBars[i];

			g.setColor(bar.isForward() ? Color.blue : Color.red);

			int x = margins.left + bar.getLeft() / bpPerPixel;

			int w = bar.getLength() / bpPerPixel;

			g.fillRect(x, y, w, contigBarHeight);
		}

		g.setColor(Color.cyan);

		for (int i = 0; i < bacLines.length; i++) {
			LinkLine ll = bacLines[i];

			int xLeft = margins.left + (ll.getLeftA() + ll.getRightA())
					/ (2 * bpPerPixel);
			int xRight = margins.left + (ll.getLeftB() + ll.getRightB())
					/ (2 * bpPerPixel);

			int dy = ll.getDy();

			g.drawLine(xLeft, y, xLeft, y - dy);
			g.drawLine(xLeft, y - dy, xRight, y - dy);
			g.drawLine(xRight, y - dy, xRight, y);
		}

		g.setColor(Color.magenta);

		y += contigBarHeight;

		for (int i = 0; i < pucLines.length; i++) {
			LinkLine ll = pucLines[i];

			int xLeft = margins.left + (ll.getLeftA() + ll.getRightA())
					/ (2 * bpPerPixel);
			int xRight = margins.left + (ll.getLeftB() + ll.getRightB())
					/ (2 * bpPerPixel);

			int dy = ll.getDy();

			g.drawLine(xLeft, y, xLeft, y + dy);
			g.drawLine(xLeft, y + dy, xRight, y + dy);
			g.drawLine(xRight, y + dy, xRight, y);
		}
	}

	class ContigBar {
		protected int contigId;
		protected boolean forward;
		protected int left;
		protected int length;

		public ContigBar(int contigId, boolean forward, int left, int length) {
			this.contigId = contigId;
			this.forward = forward;
			this.left = left;
			this.length = length;
		}

		public int getContigId() {
			return contigId;
		}

		public boolean isForward() {
			return forward;
		}

		public int getLeft() {
			return left;
		}

		public int getLength() {
			return length;
		}

		public int getRight() {
			return left + length;
		}
	}

	class ScaffoldBar {
		protected int left;
		protected int length;

		public ScaffoldBar(int left, int length) {
			this.left = left;
			this.length = length;
		}

		public int getLeft() {
			return left;
		}

		public int getLength() {
			return length;
		}

		public int getRight() {
			return left + length;
		}
	}

	class LinkLine {
		protected int leftA, rightA, leftB, rightB, dy;

		public LinkLine(int leftA, int rightA, int leftB, int rightB, int dy) {
			this.leftA = leftA;
			this.rightA = rightA;
			this.leftB = leftB;
			this.rightB = rightB;
			this.dy = dy;
		}

		public int getLeftA() {
			return leftA;
		}

		public int getRightA() {
			return rightA;
		}

		public int getLeftB() {
			return leftB;
		}

		public int getRightB() {
			return rightB;
		}

		public int getDy() {
			return dy;
		}
	}
}
