package uk.ac.sanger.arcturus.smithwaterman;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.io.PrintStream;

public class SmithWatermanPanel extends JPanel {
	private static final int CELL_SIZE = 40;

	private SmithWatermanArrayModel sw = null;

	private Font fontSans12 = new Font("SansSerif", Font.PLAIN, 12);
	private Font fontBold16 = new Font("SansSerif", Font.BOLD, 16);
	private Font fontSans8 = new Font("SansSerif", Font.PLAIN, 8);

	private SmithWatermanCanvas canvas = new SmithWatermanCanvas(CELL_SIZE,
			fontSans12, fontBold16);

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

	public void display(String subjectSequence, String querySequence,
			int sMatch, int sMismatch, int sGapInit, int sGapExt,
			boolean banded, int bandwidth) {
		rowHeader.setSequence(null);
		columnHeader.setSequence(null);
		canvas.setMatrix(null, null, null);

		sw = null;

		ScoringMatrix smat = new ScoringMatrix(sMatch, sMismatch, sGapInit,
				sGapExt);

		sw = SmithWaterman.calculateMatrix(subjectSequence.toCharArray(),
				querySequence.toCharArray(), smat, bandwidth);

		try {
			Alignment alignment = SmithWaterman.getAlignment(sw);
			
			printAlignment(alignment, System.err);
		} catch (SmithWatermanException e) {
			e.printStackTrace();
		}

		rowHeader.setSequence(subjectSequence);
		columnHeader.setSequence(querySequence);
		canvas.setMatrix(sw, subjectSequence, querySequence);

		repaint();
	}
	
	private void printAlignment(Alignment alignment, PrintStream ps) {
		EditEntry[] edits = alignment.getEdits();

		if (edits != null) {
			ps.println("Edit string starting at row "
					+ alignment.getRow() + ", column "
					+ alignment.getColumn() + ":");

			for (int i = 0; i < edits.length; i++)
				ps.println(edits[i]);
		}	
	}

	public class SmithWatermanCanvas extends JPanel implements
			MouseMotionListener, Scrollable {
		private int cellSize;
		private SmithWatermanArrayModel sw = null;
		String subjectSequence;
		String querySequence;
		Font fontPlain, fontBold;

		public SmithWatermanCanvas(int cellSize, Font fontPlain, Font fontBold) {
			super();
			this.cellSize = cellSize;
			this.fontPlain = fontPlain;
			this.fontBold = fontBold;

			setAutoscrolls(true);
			addMouseMotionListener(this);
			addMouseListener(new MouseAdapter() {
				public void mouseClicked(MouseEvent e) {
					if (e.getButton() == MouseEvent.BUTTON1
							&& e.getClickCount() == 2)
						doMouseClicked(e);
				}
			});
		}

		public void setMatrix(SmithWatermanArrayModel sw,
				String subjectSequence, String querySequence) {
			this.sw = sw;
			this.subjectSequence = subjectSequence;
			this.querySequence = querySequence;
			revalidate();
		}

		public Dimension getPreferredSize() {
			if (sw == null)
				return new Dimension(0, 0);

			int width = cellSize * sw.getColumnCount();
			int height = cellSize * sw.getRowCount();

			return new Dimension(width, height);
		}

		protected void paintComponent(Graphics g) {
			if (subjectSequence == null || querySequence == null || sw == null)
				return;

			Rectangle bounds = g.getClipBounds();

			g.setColor(getBackground());
			g.fillRect(bounds.x, bounds.y, bounds.width, bounds.height);

			int firstRow = bounds.y / cellSize;
			int firstColumn = bounds.x / cellSize;

			int lastRow = (bounds.y + bounds.height - 1) / cellSize;
			int lastColumn = (bounds.x + bounds.width - 1) / cellSize;

			if (lastRow >= subjectSequence.length())
				lastRow = subjectSequence.length() - 1;

			if (lastColumn >= querySequence.length())
				lastColumn = querySequence.length() - 1;

			for (int row = firstRow; row <= lastRow; row++) {
				int y = row * cellSize;

				char baseA = Character.toUpperCase(subjectSequence.charAt(row));

				for (int column = firstColumn; column <= lastColumn; column++) {
					int x = column * cellSize;

					char baseB = Character.toUpperCase(querySequence
							.charAt(column));

					boolean match = baseA == baseB && baseA != 'N';

					SmithWatermanEntry entry = sw.getEntry(row, column);

					drawCell(g, x, y, entry, match);
				}
			}
		}

		protected void drawCell(Graphics g, int x, int y,
				SmithWatermanEntry entry, boolean match) {
			if (entry == null) {
				g.setColor(Color.BLACK);
				g.fillRect(x, y, cellSize - 1, cellSize - 1);
				return;
			}

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

		private void doMouseClicked(MouseEvent e) {
			int x = e.getX();
			int y = e.getY();

			int row = y / cellSize;
			int col = x / cellSize;

			System.err.println("Mouse clicked at column " + (col + 1) + ", row"
					+ (row + 1));

			if (sw.exists(row, col)) {
				try {
					Alignment alignment = SmithWaterman.getAlignment(sw, row, col);

					printAlignment(alignment, System.err);
				} catch (SmithWatermanException swe) {
					swe.printStackTrace();
				}

				repaint();
			}
		}
	}

	public class SmithWatermanHeader extends JComponent {
		public static final int HORIZONTAL = 1;
		public static final int VERTICAL = 2;

		private int orientation;
		private int cellWidth;
		private int cellHeight;
		private Font fontLarge;
		private Font fontSmall;
		private String dna;

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
				return new Dimension(cellWidth * dna.length(), cellHeight);
			else
				return new Dimension(cellWidth, cellHeight * dna.length());
		}

		public void setSequence(String dna) {
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

			if (lastCell >= dna.length())
				lastCell = dna.length() - 1;

			for (int cell = firstCell; cell <= lastCell; cell++) {
				char base = Character.toUpperCase(dna.charAt(cell));

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
