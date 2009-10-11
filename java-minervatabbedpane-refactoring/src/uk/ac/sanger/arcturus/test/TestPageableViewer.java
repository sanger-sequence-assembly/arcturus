package uk.ac.sanger.arcturus.test;

import java.awt.*;
import java.awt.print.*;
import java.awt.geom.*;
import java.text.DecimalFormat;
import javax.swing.JFrame;

import uk.ac.sanger.arcturus.gui.PageableViewer; 

public class TestPageableViewer implements Pageable, Printable {
	protected Font bigbold = new Font("serif", Font.BOLD, 24);
	protected Font normal = new Font("serif", Font.PLAIN, 14);
	protected PageFormat pfPortrait = new PageFormat();
	protected PageFormat pfLandscape = new PageFormat();

	protected static final int PAGES = 10;

	protected DecimalFormat format = new DecimalFormat("####.00");

	public TestPageableViewer() {
		boolean debug = Boolean.getBoolean("debug");

		Paper paper = new Paper();

		double width = 72.0 * (210.0 / 25.4);
		double height = 72.0 * (297.0 / 25.4);

		double inch = 72.0;

		double imgwidth = width - 2.0 * inch;
		double imgheight = height - 2.0 * inch;

		paper.setSize(width, height);
		paper.setImageableArea(inch, inch, imgwidth, imgheight);

		pfPortrait.setPaper(paper);

		if (debug)
			dumpPageFormat("Portrait", pfPortrait);

		Paper paper2 = (Paper) paper.clone();

		pfLandscape.setPaper(paper2);

		pfLandscape.setOrientation(PageFormat.LANDSCAPE);

		if (debug)
			dumpPageFormat("Landscape", pfLandscape);
	}

	protected void dumpPageFormat(String caption, PageFormat pf) {
		System.err.println("PageFormat \"" + caption + "\"");

		System.err.println("\theight          = "
				+ format.format(pf.getHeight()));
		System.err.println("\twidth           = "
				+ format.format(pf.getWidth()));
		System.err.println("\timageableX      = "
				+ format.format(pf.getImageableX()));
		System.err.println("\timageableY      = "
				+ format.format(pf.getImageableY()));
		System.err.println("\timageableWidth  = "
				+ format.format(pf.getImageableWidth()));
		System.err.println("\timageableHeight = "
				+ format.format(pf.getImageableHeight()));

		System.err.print("\torientation     = ");
		switch (pf.getOrientation()) {
			case PageFormat.PORTRAIT:
				System.err.println("PORTRAIT");
				break;

			case PageFormat.LANDSCAPE:
				System.err.println("LANDSCAPE");
				break;

			case PageFormat.REVERSE_LANDSCAPE:
				System.err.println("REVERSE_LANDSCAPE");
				break;

			default:
				System.err.println("UNKNOWN");
				break;
		}
	}

	public int getNumberOfPages() {
		return PAGES;
	}

	public PageFormat getPageFormat(int page) {
		return (page % 2 == 0) ? pfPortrait : pfLandscape;
	}

	public Printable getPrintable(int page) {
		return this;
	}

	public int print(Graphics gr, PageFormat pageformat, int pagenumber) {
		if (pagenumber < 0 || pagenumber >= PAGES)
			return NO_SUCH_PAGE;

		drawContent(gr, pageformat, pagenumber);

		return PAGE_EXISTS;
	}

	protected void drawContent(Graphics gr, PageFormat pageformat,
			int pagenumber) {
		Graphics2D g = (Graphics2D) gr;

		g.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
				RenderingHints.VALUE_ANTIALIAS_ON);

		g.setFont(bigbold);

		String title = "Page " + (pagenumber + 1) + " of " + PAGES;

		FontMetrics fm = g.getFontMetrics();

		int sw = fm.stringWidth(title);

		int x0 = (int) pageformat.getImageableX();
		int y0 = (int) pageformat.getImageableY();

		int w = (int) pageformat.getImageableWidth();
		int h = (int) pageformat.getImageableHeight();

		g.setColor(Color.blue);

		g.drawRect(x0, y0, w - 1, h - 1);

		g.setColor(Color.black);

		int x = x0 + (w - sw) / 2;
		int y = y0 + fm.getHeight();

		g.drawString(title, x, y);

		g.setFont(normal);

		fm = g.getFontMetrics();

		GeneralPath luna;

		AffineTransform xform = new AffineTransform();

		double radius = 40.0;
		double margin = 5.0;

		int moonsPerRow = (pageformat.getOrientation() == PageFormat.PORTRAIT) ? 4
				: 6;

		for (int D = 0; D <= 18; D++) {
			double elongation = 10.0 * (double) D * Math.PI / 180.0;

			luna = newGlyph(radius, elongation);

			x = x0 + 50 + 100 * (D % moonsPerRow);
			y = y0 + 80 + 100 * (D / moonsPerRow);

			double rotation = elongation / 2.0;

			xform.setToTranslation((double) x, (double) y);
			xform.rotate(rotation);

			luna.transform(xform);

			Rectangle2D rect = new Rectangle2D.Double(x - radius - margin, y
					- radius - margin, 2.0 * (radius + margin),
					2.0 * (radius + margin));

			g.setColor(Color.black);
			g.fill(rect);

			g.setColor(Color.white);
			g.fill(luna);
		}
	}

	private GeneralPath newGlyph(double radius, double elongation) {
		GeneralPath path = new GeneralPath(GeneralPath.WIND_NON_ZERO);

		double s = radius;

		double ce = Math.cos(elongation);

		double dtheta = Math.PI / 2.0;

		double q = dtheta / 3.0;

		q *= 1.0538;

		q *= s;

		path.moveTo((float) 0.0, (float) s);

		CubicCurve2D.Double sega = new CubicCurve2D.Double(0.0, s, q, s, s, q,
				s, 0.0), segb = new CubicCurve2D.Double(s, 0.0, s, -q, q, -s,
				0, -s), segc = new CubicCurve2D.Double(0.0, -s, q * ce, -s, s
				* ce, -q, s * ce, 0.0), segd = new CubicCurve2D.Double(s * ce,
				0.0, s * ce, q, q * ce, s, 0.0, s);

		path.append(sega, true);
		path.append(segb, true);

		path.append(segc, true);
		path.append(segd, true);

		path.closePath();

		return path;
	}

	public static void main(String args[]) {
		JFrame frame = new JFrame("PageableViewer test");

		TestPageableViewer testdoc = new TestPageableViewer();

		PageableViewer pv = new PageableViewer(testdoc);

		frame.setContentPane(pv);

		frame.setSize(800, 800);
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		frame.show();
	}

}
