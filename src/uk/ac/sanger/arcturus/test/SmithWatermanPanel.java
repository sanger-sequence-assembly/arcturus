package uk.ac.sanger.arcturus.test;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.util.Vector;
import java.util.Enumeration;

import uk.ac.sanger.arcturus.utils.*;

public class SmithWatermanPanel extends JPanel {
	/**
	 * 
	 */
	private static final long serialVersionUID = 5668421107803713555L;

	private static final int CELL_SIZE = 40;

	private SmithWatermanEntry[][] sw = null;
	private byte[] seqa;
	private byte[] seqb;

	private Font fontSans12 = new Font("SansSerif", Font.PLAIN, 12);
	private Font fontBold12 = new Font("SansSerif", Font.BOLD, 12);
	private Font fontSans8 = new Font("SansSerif", Font.PLAIN, 8);

	private SmithWatermanCanvas canvas = new SmithWatermanCanvas(CELL_SIZE,
			fontSans12, fontBold12);

	private SmithWatermanHeader rowHeader = new SmithWatermanHeader(CELL_SIZE,
			fontSans12, fontSans8, SmithWatermanHeader.VERTICAL);
	private SmithWatermanHeader columnHeader = new SmithWatermanHeader(
			CELL_SIZE, fontSans12, fontSans8, SmithWatermanHeader.HORIZONTAL);

	public SmithWatermanPanel() {
		super(new BorderLayout());

		JScrollPane scrollPane = new JScrollPane(canvas);

		scrollPane.setColumnHeaderView(columnHeader);
		scrollPane.setRowHeaderView(rowHeader);

		add(scrollPane, BorderLayout.CENTER);
	}

	public void display(String sequenceA, String sequenceB, int sMatch,
			int sMismatch, int sGapInit, int sGapExt) {
		rowHeader.setSequence(null);
		columnHeader.setSequence(null);
		canvas.setMatrix(null, null, null);

		sw = null;

		ScoringMatrix smat = new ScoringMatrix(sMatch, sMismatch, sGapInit,
				sGapExt);

		seqa = sequenceA.getBytes();
		seqb = sequenceB.getBytes();

		sw = SmithWaterman.calculateMatrix(seqa, 1, seqa.length, seqb, 1,
				seqb.length, smat);

		traceBack();

		rowHeader.setSequence(seqa);
		columnHeader.setSequence(seqb);
		canvas.setMatrix(sw, seqa, seqb);

		repaint();
	}

	private void traceBack() {
		if (sw == null)
			return;

		int nrows = sw.length;
		int ncols = sw[0].length;

		int maxScore = 0;
		int maxRow = 0;
		int maxCol = 0;

		for (int row = 1; row < nrows; row++) {
			for (int col = 1; col < ncols; col++) {
				int score = sw[row][col].getScore();

				if (score >= maxScore) {
					maxRow = row;
					maxCol = col;
					maxScore = score;
				}
			}
		}

		int col = maxCol;
		int row = maxRow;
		int score = maxScore;

		Vector segments = new Vector();

		int startA = 0, endA = 0, startB = 0, endB = 0;
		boolean inSegment = false;

		while (score > 0 && col > 0 && row > 0) {
			sw[row][col].setOnBestAlignment(true);
			int direction = sw[row][col].getDirection();

			boolean match = seqa[row - 1] == seqb[col - 1];

			if (match) {
				startA = row;
				startB = col;

				if (!inSegment) {
					endA = row;
					endB = col;
					inSegment = true;
				}
			} else {
				if (inSegment) {
					segments.add(new Segment(startA, endA, startB, endB));
					inSegment = false;
				}
			}

			switch (direction) {
				case SmithWatermanEntry.DIAGONAL:
					row--;
					col--;
					break;

				case SmithWatermanEntry.UP:
					row--;
					break;

				case SmithWatermanEntry.LEFT:
					col--;
					break;

				default:
					System.err.println("Undefined direction: " + direction
							+ " -- cannot continue");
					System.exit(1);
			}

			score = sw[row][col].getScore();
		}

		if (inSegment)
			segments.add(new Segment(startA, endA, startB, endB));

		System.err.println("There are " + segments.size() + " segments:");

		int maxlen = 0;
		Segment maxseg = null;

		for (Enumeration e = segments.elements(); e.hasMoreElements();) {
			Segment segment = (Segment) e.nextElement();
			if (segment.getLength() > maxlen) {
				maxlen = segment.getLength();
				maxseg = segment;
			}
			System.out.println(segment);
		}

		System.out.println();
		System.out.println("Largest segment: " + maxseg + " (" + maxlen
				+ " bp)");
	}

	public class Segment {
		private int startA, endA, startB, endB;

		public Segment(int startA, int endA, int startB, int endB) {
			this.startA = startA;
			this.endA = endA;
			this.startB = startB;
			this.endB = endB;
		}

		public int getLength() {
			return endA - startA + 1;
		}

		public int getStartA() {
			return startA;
		}

		public int getEndA() {
			return endA;
		}

		public int getStartB() {
			return startB;
		}

		public int getEndB() {
			return endB;
		}

		public String toString() {
			return "Segment[" + startA + ":" + endA + ", " + startB + ":"
					+ endB + "]";
		}
	}

	public class SmithWatermanCanvas extends JPanel implements
			MouseMotionListener, Scrollable {
		/**
		 * 
		 */
		private static final long serialVersionUID = -8438234263788938856L;
		private int cellSize;
		private SmithWatermanEntry[][] sw = null;
		byte[] seqa;
		byte[] seqb;
		Font fontPlain, fontBold;

		public SmithWatermanCanvas(int cellSize, Font fontPlain, Font fontBold) {
			super();
			this.cellSize = cellSize;
			this.fontPlain = fontPlain;
			this.fontBold = fontBold;

			setAutoscrolls(true);
			addMouseMotionListener(this);
		}

		public void setMatrix(SmithWatermanEntry[][] sw, byte[] seqa,
				byte[] seqb) {
			this.sw = sw;
			this.seqa = seqa;
			this.seqb = seqb;
			revalidate();
		}

		public Dimension getPreferredSize() {
			if (sw == null)
				return new Dimension(0, 0);

			int width = cellSize * sw[0].length;
			int height = cellSize * sw.length;

			return new Dimension(width, height);
		}

		protected void paintComponent(Graphics g) {
			if (seqa == null || seqb == null || sw == null)
				return;

			Rectangle bounds = g.getClipBounds();

			g.setColor(getBackground());
			g.fillRect(bounds.x, bounds.y, bounds.width, bounds.height);

			int firstRow = bounds.y / cellSize;
			int firstColumn = bounds.x / cellSize;

			int lastRow = (bounds.y + bounds.height - 1) / cellSize;
			int lastColumn = (bounds.x + bounds.width - 1) / cellSize;

			if (lastRow >= seqa.length)
				lastRow = seqa.length - 1;

			if (lastColumn >= seqb.length)
				lastColumn = seqb.length - 1;

			for (int row = firstRow; row <= lastRow; row++) {
				int y = row * cellSize;

				char baseA = Character.toUpperCase((char) seqa[row]);

				for (int column = firstColumn; column <= lastColumn; column++) {
					int x = column * cellSize;

					char baseB = Character.toUpperCase((char) seqb[column]);

					boolean match = baseA == baseB && baseA != 'N';
					;

					SmithWatermanEntry entry = sw[row + 1][column + 1];

					drawCell(g, x, y, entry, match);
				}
			}
		}

		protected void drawCell(Graphics g, int x, int y,
				SmithWatermanEntry entry, boolean match) {
			if (match) {
				g.setColor(Color.YELLOW);
				g.fillRect(x, y, cellSize - 1, cellSize - 1);
			}

			g.setColor(Color.BLACK);

			g.drawRect(x, y, cellSize - 1, cellSize - 1);

			if (entry.isOnBestAlignment()) {
				g.setColor(Color.RED);
				g.setFont(fontBold);
			} else
				g.setFont(fontPlain);

			String score = "" + entry.getScore();

			FontMetrics fm = g.getFontMetrics();

			int xs = x + (cellSize - fm.stringWidth(score)) / 2;
			int ys = y + (cellSize + fm.getHeight()) / 2;

			g.drawString(score, xs, ys);
		}

		public void mouseMoved(MouseEvent me) {
		}

		public void mouseDragged(MouseEvent me) {
			Rectangle r = new Rectangle(me.getX(), me.getY(), 1, 1);
			scrollRectToVisible(r);
		}

		public boolean getScrollableTracksViewportWidth() {
			return false;
		}

		public boolean getScrollableTracksViewportHeight() {
			return false;
		}

		public Dimension getPreferredScrollableViewportSize() {
			return getPreferredSize();
		}

		public int getScrollableBlockIncrement(Rectangle visibleRect,
				int orientation, int direction) {
			if (orientation == SwingConstants.HORIZONTAL)
				return visibleRect.width - cellSize;
			else
				return visibleRect.height - cellSize;
		}

		public int getScrollableUnitIncrement(Rectangle visibleRect,
				int orientation, int direction) {
			int currentPosition;

			if (orientation == SwingConstants.HORIZONTAL) {
				currentPosition = visibleRect.x;
			} else {
				currentPosition = visibleRect.y;
			}

			if (direction < 0) {
				int newPosition = currentPosition
						- (currentPosition / cellSize) * cellSize;

				return (newPosition == 0) ? cellSize : newPosition;
			} else {
				return ((currentPosition / cellSize) + 1) * cellSize
						- currentPosition;
			}
		}
	}

	public class SmithWatermanHeader extends JComponent {
		/**
		 * 
		 */
		private static final long serialVersionUID = 5579583640914404053L;
		public static final int HORIZONTAL = 1;
		public static final int VERTICAL = 2;

		private int orientation;
		private int cellWidth;
		private int cellHeight;
		private Font fontLarge;
		private Font fontSmall;
		private byte[] dna;

		public SmithWatermanHeader(int cellSize, Font fontLarge,
				Font fontSmall, int orientation) {
			if (orientation == HORIZONTAL) {
				this.cellWidth = cellSize;
				this.cellHeight = (3 * cellSize) / 2;
			} else {
				this.cellWidth = (3 * cellSize) / 2;
				this.cellHeight = cellSize;
			}

			this.fontLarge = fontLarge;
			this.fontSmall = fontSmall;
			this.orientation = orientation;
		}

		public Dimension getPreferredSize() {
			if (dna == null)
				return new Dimension(0, 0);

			if (orientation == HORIZONTAL)
				return new Dimension(cellWidth * dna.length, cellHeight);
			else
				return new Dimension(cellWidth, cellHeight * dna.length);
		}

		public void setSequence(byte[] dna) {
			this.dna = dna;
			revalidate();
		}

		public void paintComponent(Graphics g) {
			if (dna == null)
				return;

			Rectangle bounds = g.getClipBounds();

			g.setColor(getBackground());
			g.fillRect(bounds.x, bounds.y, bounds.width, bounds.height);

			int firstCell, lastCell;

			if (orientation == HORIZONTAL) {
				firstCell = bounds.x / cellWidth;
				lastCell = (bounds.x + bounds.width - 1) / cellWidth;
			} else {
				firstCell = bounds.y / cellHeight;
				lastCell = (bounds.y + bounds.height - 1) / cellHeight;
			}

			if (lastCell >= dna.length)
				lastCell = dna.length - 1;

			for (int cell = firstCell; cell <= lastCell; cell++) {
				char base = Character.toUpperCase((char) dna[cell]);

				int x, y;

				if (orientation == HORIZONTAL) {
					x = cell * cellWidth;
					y = 0;
				} else {
					x = 0;
					y = cell * cellHeight;
				}

				drawCell(g, x, y, base, cell + 1, orientation);
			}
		}

		private void drawCell(Graphics g, int x, int y, char base,
				int cellnumber, int orientation) {
			g.setColor(Color.BLACK);
			g.setFont(fontLarge);

			int xs, ys;

			String string = "" + base;

			FontMetrics fm = g.getFontMetrics();

			if (orientation == HORIZONTAL) {
				xs = x + (cellWidth - fm.stringWidth(string)) / 2;
				ys = y + cellHeight - 5;
			} else {
				xs = x + cellWidth - fm.stringWidth(string) - 5;
				ys = y + (cellHeight + fm.getHeight()) / 2;
			}

			g.drawString(string, xs, ys);

			if (orientation == HORIZONTAL)
				ys -= fm.getHeight() + 3;

			g.setFont(fontSmall);

			fm = g.getFontMetrics();

			string = "" + cellnumber;

			if (orientation == HORIZONTAL) {
				xs = x + (cellWidth - fm.stringWidth(string)) / 2;
			} else {
				xs = x + 5 + 4 * fm.charWidth('0') - fm.stringWidth(string);
				ys = y + (cellHeight + fm.getHeight()) / 2;
			}

			g.drawString(string, xs, ys);
		}
	}
}
