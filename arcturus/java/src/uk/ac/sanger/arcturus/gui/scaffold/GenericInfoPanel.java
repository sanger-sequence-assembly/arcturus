package uk.ac.sanger.arcturus.gui.scaffold;

import java.awt.*;

import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public abstract class GenericInfoPanel extends InfoPanel {
	protected String[] lines;
	protected Font plainFont = new Font("SansSerif", Font.PLAIN, 14);
	protected Font boldFont = new Font("SansSerif", Font.BOLD, 14);

	protected String[] labels;

	protected int valueOffset;

	public GenericInfoPanel(PopupManager myparent) {
		super(myparent);

		setBackground(new Color(255, 204, 0));
	}

	public abstract void setClientObject(Object o)
			throws InvalidClientObjectException;

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
