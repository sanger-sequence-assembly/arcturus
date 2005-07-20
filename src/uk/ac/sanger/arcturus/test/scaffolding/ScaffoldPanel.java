package scaffolding;

import javax.swing.*;
import java.awt.*;
import java.util.Vector;

public class ScaffoldPanel extends JPanel {
    protected int bpPerPixel = 100;
    protected int leftPadding = 20;
    protected int rightPadding = 20;
    protected int interScaffoldGap = 1000;

    protected ContigBar[] contigBars = null;
    protected ScaffoldBar[] scaffoldBars = null;

    protected Dimension preferredSize = new Dimension(100, 100);

    public void setSuperScaffold(SuperScaffold ss) {
	makeBars(ss);
	recalculateLayout();
    }

    public void setScale(int bpPerPixel) {
	this.bpPerPixel = bpPerPixel;
	recalculateLayout();
    }

    public void setPadding(int leftPadding, int rightPadding) {
	this.leftPadding = leftPadding;
	this.rightPadding = rightPadding;
	recalculateLayout();
    }

    public void setInterScaffoldGap(int interScaffoldGap) {
	this.interScaffoldGap = interScaffoldGap;
	recalculateLayout();
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

		Scaffold scaffold = (Scaffold)item;

		int scafleft = left;

		Object[] subitems = scaffold.toArray();

		if (!scaffold.isForward()) {
		    int k = subitems.length - 1;

		    for (int j = 0; j < subitems.length/2; j++,k--) {
			Object tmp = subitems[k];
			subitems[k] = subitems[j];
			subitems[j] = tmp;
		    }
		}

		for (int j = 0; j < subitems.length; j++) {
		    Object subitem = subitems[j];

		    if (subitem instanceof Contig) {
			Contig contig = (Contig)subitem;
			boolean forward = scaffold.isForward() ? contig.isForward() : !contig.isForward();
			ctgbars.add(new ContigBar(contig.getId(), forward, left, contig.getSize()));
			left += contig.getSize();
		    } else {
			Gap gap = (Gap)subitem;
			left += gap.getSize();
		    }
		}

		scafbars.add(new ScaffoldBar(scafleft, left - scafleft));
	    }
	}

	contigBars = (ContigBar[])ctgbars.toArray(new ContigBar[0]);
	scaffoldBars = (ScaffoldBar[])scafbars.toArray(new ScaffoldBar[0]);
    }

    protected void recalculateLayout() {
	int width = leftPadding + rightPadding;
	int height = 200;

	if (contigBars != null) {
	    int k = contigBars.length - 1;
	    int left = contigBars[0].getLeft();
	    int right = contigBars[k].getRight();
	    width += (right - left + 1)/bpPerPixel;
	}

	preferredSize = new Dimension(width, height);

	revalidate();
    }

    public Dimension getPreferredSize() { return preferredSize; }

    public void paintComponent(Graphics gr) {
	if (contigBars == null)
	    return;

	Graphics2D g = (Graphics2D)gr;

	Dimension size = getSize();

	g.setColor(getBackground());

	g.fillRect(0, 0, size.width, size.height);

	g.setColor(Color.black);

	for (int i = 0; i < scaffoldBars.length; i++) {
	    ScaffoldBar sbar = scaffoldBars[i];

	    int x = leftPadding + sbar.getLeft()/bpPerPixel;
	    int y = 10;

	    int w = sbar.getLength()/bpPerPixel;
	    int h = 4;

	    g.fillRect(x, y, w, h);

	    g.drawLine(x, y, x, y + 2 * h);

	    x += w;

	    g.drawLine(x, y, x, y + 2 * h);
	}

	for (int i = 0; i < contigBars.length; i++) {
	    ContigBar bar = contigBars[i];

	    g.setColor(bar.isForward() ? Color.blue : Color.red);

	    int x = leftPadding + bar.getLeft()/bpPerPixel;
	    int y = 20;

	    int w = bar.getLength()/bpPerPixel;
	    int h = 20;

	    g.fillRect(x, y, w, h);
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

	public int getContigId() { return contigId; }

	public boolean isForward() { return forward; }

	public int getLeft() { return left; }

	public int getLength() { return length; }

	public int getRight() { return left + length; }
    }

    class ScaffoldBar {
	protected int left;
	protected int length;

	public ScaffoldBar(int left, int length) {
	    this.left = left;
	    this.length = length;
	}

	public int getLeft() { return left; }

	public int getLength() { return length; }

	public int getRight() { return left + length; }
    }
}
