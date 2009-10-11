package uk.ac.sanger.arcturus.gui.scaffold;

import javax.swing.JMenu;

import java.awt.BorderLayout;
import java.awt.Point;
import java.awt.Insets;
import java.awt.FlowLayout;
import java.awt.Dimension;
import java.awt.Color;

import java.awt.event.ActionListener;
import java.awt.event.ActionEvent;

import java.util.*;

import javax.swing.*;
import javax.swing.border.*;

import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

import uk.ac.sanger.arcturus.scaffold.*;

import uk.ac.sanger.arcturus.gui.MinervaPanel;
import uk.ac.sanger.arcturus.gui.MinervaTabbedPane;

import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ScaffoldPanel extends MinervaPanel {
	protected final GenericContigDisplayPanel panel;
	
	public ScaffoldPanel(MinervaTabbedPane mtp, ArcturusDatabase adb,
			ContigBox[] contigboxes, Set bridgeset,
			Contig seedcontig) {
		super(mtp, adb);
		
		panel = new GenericContigDisplayPanel(seedcontig);

		JScrollPane scrollpane = new JScrollPane(panel);

		JPanel topPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));

		ButtonGroup group = new ButtonGroup();
		
		JRadioButton btnInfo = new JRadioButton("Info");
		
		btnInfo.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setDisplayMode(DisplayMode.INFO);
			}
		});
		
		group.add(btnInfo);
				
		JRadioButton btnDrag= new JRadioButton("Drag contigs");
		
		btnDrag.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setDisplayMode(DisplayMode.DRAG);
			}
		});
		
		group.add(btnDrag);
		
		JRadioButton btnZoomIn= new JRadioButton("Zoom in");
		
		btnZoomIn.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setDisplayMode(DisplayMode.ZOOM_IN);
			}
		});
		
		group.add(btnZoomIn);
		
		JRadioButton btnZoomOut= new JRadioButton("Zoom out");
		
		btnZoomOut.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				panel.setDisplayMode(DisplayMode.ZOOM_OUT);
			}
		});
		
		group.add(btnZoomOut);
		
		Border loweredetched = BorderFactory.createEtchedBorder(EtchedBorder.LOWERED);
		TitledBorder border = BorderFactory.createTitledBorder(
			       loweredetched, "Mode");
		border.setTitleJustification(TitledBorder.LEFT);
		
		JPanel modePanel = new JPanel(new FlowLayout(FlowLayout.LEFT));
		modePanel.setBorder(border);
		
		modePanel.add(btnInfo);
		modePanel.add(btnDrag);
		modePanel.add(btnZoomIn);
		modePanel.add(btnZoomOut);
		
		topPanel.add(modePanel);
		
		btnInfo.setSelected(true);
		
		add(topPanel, BorderLayout.NORTH);

		add(scrollpane, BorderLayout.CENTER);

		panel.setBackground(Color.white);

		Dimension userarea = calculateUserArea(contigboxes);

		panel.setInsetsAndUserArea(new Insets(20, 20, 20, 20), userarea);

		populate(contigboxes, bridgeset, seedcontig);
		
		createMenus();
		
		setPreferredSize(new Dimension(800, 600));
	}

	protected void populate(ContigBox[] contigboxes, Set bridgeset, Contig seedcontig) {
		int dragMode = DrawableFeature.DRAG_XY;

		HashMap<Contig, ContigFeature> contigmap = new HashMap<Contig, ContigFeature>();

		for (int i = 0; i < contigboxes.length; i++) {
			ContigBox cb = contigboxes[i];

			Contig contig = cb.getContig();

			boolean isSeedContig = contig.equals(seedcontig);
			
			ContigFeature cf = new ContigFeature(contig, new Point(cb
					.getLeft(), (1 + cb.getRow()) * 30), cb.isForward(), isSeedContig);

			contigmap.put(contig, cf);

			panel.addFeature(cf, dragMode);
		}

		dragMode = DrawableFeature.DRAG_NONE;

		for (Iterator iter = bridgeset.iterator(); iter.hasNext();) {
			Bridge bridge = (Bridge) iter.next();

			Contig contiga = bridge.getContigA();
			Contig contigb = bridge.getContigB();

			ContigFeature cfa = (ContigFeature) contigmap.get(contiga);
			ContigFeature cfb = (ContigFeature) contigmap.get(contigb);

			BridgeFeature bf = new BridgeFeature(bridge, cfa, cfb);

			panel.addFeature(bf, dragMode);
		}
	}

	protected Dimension calculateUserArea(ContigBox[] contigboxes) {
		int width = 0;
		int height = 0;

		for (int i = 0; i < contigboxes.length; i++) {
			int right = contigboxes[i].getRight();

			if (right > width)
				width = right;

			int row = contigboxes[i].getRow();

			if (row > height)
				height = row;
		}

		height += 1;
		height *= 30;

		return new Dimension(width, height);
	}

	protected Map createLayout(Set<Bridge> bridges) {
		Map<Contig, ContigBox> layout = new HashMap<Contig, ContigBox>();
		RowRanges rowranges = new RowRanges();

		Vector<Bridge> bridgevector = new Vector<Bridge>(bridges);

		Collections.sort(bridgevector, new BridgeComparator());

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
				if (hasa && hasb) {
				} else {
					endcode = bridge.getEndCode();
					gapsize = bridge.getGapSize().getMinimum();

					if (hasa) {
						cba = (ContigBox) layout.get(contiga);

						cbb = calculateRelativePosition(cba, contiga, contigb,
								endcode, gapsize, rowranges);
						layout.put(contigb, cbb);
					} else {
						cbb = (ContigBox) layout.get(contigb);

						if (endcode == 0 || endcode == 3)
							endcode = 3 - endcode;

						cba = calculateRelativePosition(cbb, contigb, contiga,
								endcode, gapsize, rowranges);
						layout.put(contiga, cba);
					}
				}
			} else {
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

	protected boolean addClassSpecificFileMenuItems(JMenu menu) {
		return false;
	}

	protected void addClassSpecificViewMenuItems(JMenu menu) {
	}

	public void closeResources() {
	}

	protected void createActions() {
	}

	protected void createClassSpecificMenus() {
	}

	protected void doPrint() {
	}

	protected boolean isRefreshable() {
		return false;
	}

	public void refresh() {		
	}

}
