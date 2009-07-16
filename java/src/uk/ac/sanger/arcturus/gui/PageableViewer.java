package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import javax.swing.event.*;
import java.awt.print.*;
import java.awt.*;
import java.awt.event.*;

public class PageableViewer extends JPanel {
	private static final long serialVersionUID = -5539219950106494954L;
	protected Pageable pageable;
	protected int currentPageNumber;
	protected int maxPageNumber;

	protected JButton btnFirstPage = new JButton("First page");
	protected JButton btnPrevPage = new JButton("Previous page");
	protected JButton btnNextPage = new JButton("Next page");
	protected JButton btnLastPage = new JButton("Last page");
	protected JButton btnPrint = new JButton("Print");
	protected JComboBox cbxZoom;

	protected PageablePanel canvas;

	public PageableViewer() {
		this(null);
	}

	public PageableViewer(Pageable pageable) {
		super(new BorderLayout());
		setupUI();
		setPageable(pageable);
	}

	private void setupUI() {
		JToolBar toolbar = new JToolBar();

		toolbar.add(btnFirstPage);
		toolbar.add(btnPrevPage);
		toolbar.add(btnNextPage);
		toolbar.add(btnLastPage);

		toolbar.addSeparator();

		toolbar.add(btnPrint);

		toolbar.addSeparator();

		toolbar.add(new JLabel("Zoom: "));

		String[] zoomlevels = { "100%", "200%", "400%", "800%", "1600%",
				"3200%" };

		cbxZoom = new JComboBox(zoomlevels);

		cbxZoom.setSelectedIndex(0);

		toolbar.add(cbxZoom);

		btnFirstPage.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ae) {
				actionFirstPage();
			}
		});

		btnPrevPage.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ae) {
				actionPreviousPage();
			}
		});

		btnNextPage.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ae) {
				actionNextPage();
			}
		});

		btnLastPage.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ae) {
				actionLastPage();
			}
		});

		btnPrint.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ae) {
				actionPrint();
			}
		});

		cbxZoom.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent ae) {
				actionChangeZoom();
			}
		});

		add(toolbar, BorderLayout.NORTH);

		canvas = new PageablePanel();

		toolbar.addKeyListener(new KeyAdapter() {
			public void keyTyped(KeyEvent e) {
				int keycode = e.getKeyCode();

				switch (keycode) {
					case KeyEvent.VK_HOME:
						actionFirstPage();
						break;

					case KeyEvent.VK_END:
						actionLastPage();
						break;

					case KeyEvent.VK_PAGE_DOWN:
						actionNextPage();
						break;

					case KeyEvent.VK_PAGE_UP:
						actionPreviousPage();
						break;
				}
			}
		});

		toolbar.setFloatable(false);

		JScrollPane scrollpane = new JScrollPane(canvas);

		add(scrollpane, BorderLayout.CENTER);
	}

	private void actionFirstPage() {
		setCurrentPageNumber(0);
	}

	private void actionPreviousPage() {
		if (currentPageNumber > 0)
			setCurrentPageNumber(currentPageNumber - 1);
	}

	private void actionNextPage() {
		if (currentPageNumber < maxPageNumber - 1)
			setCurrentPageNumber(currentPageNumber + 1);
	}

	private void actionLastPage() {
		setCurrentPageNumber(maxPageNumber - 1);
	}

	private void setCurrentPageNumber(int newpagenumber) {
		currentPageNumber = newpagenumber;

		if (pageable != null) {
			Printable printable = pageable.getPrintable(currentPageNumber);
			PageFormat pageformat = pageable.getPageFormat(currentPageNumber);

			canvas.setPageData(printable, pageformat, currentPageNumber);
		}

		boolean isFirstPage = currentPageNumber == 0;

		btnPrevPage.setEnabled(!isFirstPage);
		btnFirstPage.setEnabled(!isFirstPage);

		boolean isLastPage = currentPageNumber == maxPageNumber - 1;

		btnNextPage.setEnabled(!isLastPage);
		btnLastPage.setEnabled(!isLastPage);
	}

	public void setPageable(Pageable pageable) {
		this.pageable = pageable;
		maxPageNumber = pageable == null ? 0 : pageable.getNumberOfPages();
		setupNewDocument();
	}

	private void setupNewDocument() {
		actionFirstPage();
	}

	private void actionPrint() {
		if (pageable == null)
			return;

		try {
			PrinterJob printerjob = PrinterJob.getPrinterJob();

			printerjob.setPageable(pageable);

			if (printerjob.printDialog())
				printerjob.print();
		} catch (PrinterException pe) {
			pe.printStackTrace();
		}
	}

	private void actionChangeZoom() {
		int zoomLevel = cbxZoom.getSelectedIndex();
		System.err.println("Zoom is zet to " + zoomLevel);
		canvas.setZoomLevel(zoomLevel);
	}

	class PageablePanel extends JPanel {
		private static final long serialVersionUID = 16916319829179157L;
		protected Printable printable;
		protected PageFormat pageformat;
		protected int pageindex;
		protected int zoomLevel = 0;

		public PageablePanel() {
			super(null);
			setBackground(Color.white);

			MouseInputAdapter mia = new MouseInputAdapter() {
				int deltaX, deltaY;
				Container c;

				public void mouseDragged(MouseEvent e) {
					c = PageablePanel.this.getParent();
					if (c instanceof JViewport) {
						JViewport jv = (JViewport) c;
						Point p = jv.getViewPosition();
						int newX = p.x - (e.getX() - deltaX);
						int newY = p.y - (e.getY() - deltaY);

						int maxX = PageablePanel.this.getWidth()
								- jv.getWidth();
						int maxY = PageablePanel.this.getHeight()
								- jv.getHeight();
						if (newX < 0)
							newX = 0;
						if (newX > maxX)
							newX = maxX;
						if (newY < 0)
							newY = 0;
						if (newY > maxY)
							newY = maxY;

						jv.setViewPosition(new Point(newX, newY));
					}
				}

				public void mousePressed(MouseEvent e) {
					setCursor(Cursor.getPredefinedCursor(Cursor.MOVE_CURSOR));
					deltaX = e.getX();
					deltaY = e.getY();
				}

				public void mouseReleased(MouseEvent e) {
					setCursor(Cursor.getPredefinedCursor(Cursor.DEFAULT_CURSOR));
				}
			};

			addMouseMotionListener(mia);
			addMouseListener(mia);
		}

		public void setPageData(Printable printable, PageFormat pageformat,
				int pageindex) {
			this.printable = printable;
			this.pageformat = pageformat;
			this.pageindex = pageindex;

			resizeCanvas();

			repaint();
		}

		private void resizeCanvas() {
			if (pageformat != null) {
				int width = (int) pageformat.getWidth() << zoomLevel;
				int height = (int) pageformat.getHeight() << zoomLevel;

				setPreferredSize(new Dimension(width, height));

				revalidate();
			}
		}

		public void setZoomLevel(int zoomLevel) {
			this.zoomLevel = zoomLevel;
			resizeCanvas();
			repaint();
		}

		protected void paintComponent(Graphics gr) {
			Graphics2D g = (Graphics2D) gr;

			Dimension size = getSize();

			g.setColor(Color.darkGray);
			g.fillRect(0, 0, size.width, size.height);

			if (zoomLevel > 0) {
				double s = Math.pow(2.0, zoomLevel);
				g.scale(s, s);
			}

			int pw = (int) pageformat.getWidth();
			int ph = (int) pageformat.getHeight();

			g.setColor(Color.lightGray);
			g.fillRect(0, 0, pw, ph);

			int x = (int) pageformat.getImageableX();
			int y = (int) pageformat.getImageableY();

			int w = (int) pageformat.getImageableWidth();
			int h = (int) pageformat.getImageableHeight();

			g.setColor(getBackground());

			g.fillRect(x, y, w, h);

			try {
				printable.print(gr, pageformat, pageindex);
			}
			catch (PrinterException pe) {
			}
		}
	}
}
