package uk.ac.sanger.arcturus.gui.genericdisplay;

public class DisplayMode {
	public static final int ZOOM_IN = 1;
	public static final int ZOOM_OUT = 2;
	public static final int DRAG = 3;
	public static final int INFO = 4;

	protected final int mode;

	public DisplayMode(int mode) {
		this.mode = mode;
	}

	public int getMode() {
		return mode;
	}

	public String toString() {
		switch (mode) {
			case ZOOM_IN:
				return "Zoom in";
			case ZOOM_OUT:
				return "Zoom out";
			case DRAG:
				return "Drag objects";
			case INFO:
				return "Show object info";
			default:
				return "(Nothing)";
		}
	}
}
