package uk.ac.sanger.arcturus.test.contigdisplay;

import uk.ac.sanger.arcturus.gui.genericdisplay.*;

public class GenericContigDisplayPanel extends GenericDisplay implements
		Transformer, PopupManager {
	/**
	 * 
	 */
	private static final long serialVersionUID = 678937696222890342L;
	protected FeaturePainter contigPainter = new ContigFeaturePainter();
	protected FeaturePainter bridgePainter = new BridgeFeaturePainter();
	protected ContigInfoPanel cip;
	protected BridgeInfoPanel bip;

	public GenericContigDisplayPanel() {
		super();

		cip = new ContigInfoPanel(this);
		bip = new BridgeInfoPanel(this);
	}

	public DrawableFeature addFeature(Feature f, int dragMode) {
		if (f instanceof ContigFeature) {
			DrawableFeature df = new DrawableFeature(this, f, contigPainter,
					dragMode);
			addDrawableFeature(df, false);
			return df;
		} else if (f instanceof BridgeFeature) {
			DrawableFeature df = new DrawableFeature(this, f, bridgePainter,
					dragMode);
			addDrawableFeature(df, false);
			return df;
		} else
			return null;
	}

	public InfoPanel findInfoPanelForFeature(Feature f) {
		if (f instanceof ContigFeature)
			return cip;

		if (f instanceof BridgeFeature)
			return bip;

		return null;
	}
}