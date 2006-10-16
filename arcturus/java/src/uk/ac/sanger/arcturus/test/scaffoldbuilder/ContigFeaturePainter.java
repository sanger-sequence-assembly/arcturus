package uk.ac.sanger.arcturus.test.scaffoldbuilder;

import java.awt.*;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class ContigFeaturePainter implements FeaturePainter {
	protected Font font = new Font("sansserif", Font.PLAIN, 12);
	protected boolean showContigName = false;
	protected int seedprojectid;

	public ContigFeaturePainter(Contig seedcontig) {
		super();

		Project seedproject = seedcontig.getProject();
		seedprojectid = (seedproject == null) ? -1 : seedproject.getID();
	}

	public void paintFeature(Graphics2D g, Feature f, Shape s) {
		if (f instanceof ContigFeature) {
			ContigFeature cf = (ContigFeature) f;

			Color colour = cf.isForward() ? Color.blue : Color.red;

			Contig contig = (Contig) cf.getClientObject();

			Project project = contig.getProject();

			int projectid = (project == null) ? -1 : project.getID();

			Color oldcolour = g.getColor();

			if (projectid != seedprojectid)
				colour = colour.darker();

			g.setColor(colour);

			g.fill(s);

			Rectangle rect = s.getBounds();

			String name = showContigName ? contig.getName() : "Contig "
					+ contig.getID();

			g.setColor(Color.black);

			g.setFont(font);

			g.drawString(name, rect.x, rect.y - 2);

			g.setColor(oldcolour);
		}
	}

	public Shape calculateBoundingShape(Feature f, Transformer t) {
		Point p = f.getPosition();
		Dimension d = f.getSize();

		Rectangle r = new Rectangle(t.worldToView(p), t.worldToView(d));

		return r;
	}
}
