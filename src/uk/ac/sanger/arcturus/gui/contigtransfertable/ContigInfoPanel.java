package uk.ac.sanger.arcturus.gui.contigtransfertable;

import java.awt.*;
import java.text.SimpleDateFormat;
import java.text.DecimalFormat;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

import uk.ac.sanger.arcturus.gui.genericdisplay.InfoPanel;

public class ContigInfoPanel extends InfoPanel {
	protected String[] lines;
	protected String[] labels;

	protected SimpleDateFormat dateformat = new SimpleDateFormat(
	"yyyy MMM dd HH:mm");
	protected DecimalFormat decimalformat = new DecimalFormat();

	protected Font plainFont = new Font("SansSerif", Font.PLAIN, 14);
	protected Font boldFont = new Font("SansSerif", Font.BOLD, 14);

	protected int valueOffset;

	public ContigInfoPanel(PopupManager myparent) {
		super(myparent);

		labels = new String[] { "CONTIG", "Name:", "Length:", "Reads:",
				"Created:", "Project:" };
		lines = new String[labels.length];

		setBackground(new Color(255, 204, 0));
	}

	public void setClientObject(Object o) throws InvalidClientObjectException {
		if (o instanceof Contig)
			setContig((Contig)o);
		else
			throw new InvalidClientObjectException(
					"Expecting a Contig, got "
							+ ((o == null) ? "null" : o.getClass().getName()));
	}

	protected void setContig(Contig contig) {
		createStrings(contig);

		FontMetrics fm = getFontMetrics(boldFont);

		valueOffset = 0;

		for (int i = 1; i < labels.length; i++) {
			int k = fm.stringWidth(labels[i]);
			if (k > valueOffset)
				valueOffset = k;
		}

		valueOffset += fm.stringWidth("    ");

		int txtheight = lines.length * fm.getHeight();

		int txtwidth = 0;

		for (int j = 0; j < lines.length; j++) {
			int sw = fm.stringWidth(lines[j]);
			if (sw > txtwidth)
				txtwidth = sw;
			if (j == 0)
				fm = getFontMetrics(boldFont);
		}

		setPreferredSize(new Dimension(valueOffset + txtwidth, txtheight + 5));
	}

	private void createStrings(Contig contig) {
		lines[0] = "" + contig.getID();

		lines[1] = contig.getName();

		lines[2] = decimalformat.format(contig.getLength());

		lines[3] = decimalformat.format(contig.getReadCount());

		lines[4] = dateformat.format(contig.getCreated());

		Project project = contig.getProject();

		lines[5] = (project == null) ? "(unknown)" : project.getName();
	}

	public void paintComponent(Graphics g) {
		Dimension size = getSize();
		g.setColor(getBackground());
		g.fillRect(0, 0, size.width, size.height);

		if (lines == null)
			return;

		g.setColor(Color.black);

		FontMetrics fm = getFontMetrics(plainFont);

		int y0 = fm.getAscent();
		int dy = fm.getHeight();

		g.setFont(boldFont);

		for (int j = 0; j < lines.length; j++) {
			int x = 0;
			int y = y0 + j * dy;

			if (labels != null && j < labels.length)
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
