package contigdisplay;

import java.awt.Container;
import java.awt.BorderLayout;
import java.awt.Point;
import java.awt.Insets;
import java.awt.FlowLayout;
import java.awt.Dimension;
import java.awt.Color;

import java.awt.event.*;
import javax.swing.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class Test extends JFrame {
    protected GenericObjectDisplayPanel panel = new GenericObjectDisplayPanel();

    public Test(String title) {
	super(title);

	JScrollPane scrollpane = new JScrollPane(panel);

	Container contentPane = getContentPane();

	contentPane.setLayout(new BorderLayout());

	JPanel topPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));

	topPanel.add(new JLabel("Mode: "));

	JComboBox cb = new JComboBox();

	cb.addItem(new DisplayMode(DisplayMode.INFO));
	cb.addItem(new DisplayMode(DisplayMode.DRAG));
	cb.addItem(new DisplayMode(DisplayMode.ZOOM_IN));
	cb.addItem(new DisplayMode(DisplayMode.ZOOM_OUT));

	cb.setSelectedIndex(0);

	topPanel.add(cb);

	cb.addActionListener(new ActionListener() {
		public void actionPerformed(ActionEvent e) {
		    JComboBox cb = (JComboBox)e.getSource();
		    DisplayMode dm = (DisplayMode)cb.getSelectedItem();
		    System.err.println("DisplayMode is " + dm.getMode() + " (" +
				       dm.toString() + ")");
		    panel.setDisplayMode(dm.getMode());
		}
	    });

	contentPane.add(topPanel, BorderLayout.NORTH);

	contentPane.add(scrollpane, BorderLayout.CENTER);

	panel.setBackground(Color.white);
	panel.setInsetsAndUserArea(new Insets(20, 20, 20, 20),
				   new Dimension(200000, 1000));

	populate(panel);
    }

    protected void populate(GenericObjectDisplayPanel panel) {
	int dragMode = DrawableFeature.DRAG_XY;

	ContigFeature cf1 = new ContigFeature(new Contig("dinah", 40000),
					      new Point(1000, 100),
					      true);

	panel.addFeature(cf1, dragMode);

	ContigFeature cf2 = new ContigFeature(new Contig("molly", 20000),
					      new Point(15000, 200),
					      false);

	panel.addFeature(cf2, dragMode);

	ContigFeature cf3 = new ContigFeature(new Contig("kitty", 10000),
					      new Point(8000, 150),
					      true);

	panel.addFeature(cf3, dragMode);

	ContigFeature cf4 = new ContigFeature(new Contig("bonnie", 15000),
					      new Point(12000, 180),
					      false);

	panel.addFeature(cf4, dragMode);

	BridgeFeature bf1 = new BridgeFeature(new Bridge(3), cf1, cf2);

	panel.addFeature(bf1, DrawableFeature.DRAG_NONE);

	BridgeFeature bf2 = new BridgeFeature(new Bridge(5), cf1, cf3);

	panel.addFeature(bf2, DrawableFeature.DRAG_NONE);

	BridgeFeature bf3 = new BridgeFeature(new Bridge(2), cf4, cf1);

	panel.addFeature(bf3, DrawableFeature.DRAG_NONE);
    }

    private static void createAndShowGUI() {
        JFrame.setDefaultLookAndFeelDecorated(true);

        JFrame frame = new Test("Test Frame");
        frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);

        frame.pack();
	frame.setSize(800,800);
        frame.setVisible(true);
    }

    public static void main(String[] args) {
        javax.swing.SwingUtilities.invokeLater(new Runnable() {
            public void run() {
		createAndShowGUI();
            }
        });
    }
}
