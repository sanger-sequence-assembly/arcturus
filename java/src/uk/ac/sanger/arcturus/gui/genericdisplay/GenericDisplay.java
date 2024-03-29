// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.gui.genericdisplay;

import java.awt.*;
import java.awt.event.*;
import java.util.*;
import javax.swing.*;
import java.net.URL;

public abstract class GenericDisplay extends JPanel implements Transformer,
		PopupManager {
	protected Set drawables = new HashSet();
	protected Insets insets = new Insets(0, 0, 0, 0);
	protected Dimension userarea = new Dimension(0, 0);
	protected int bpPerPixel = 128;
	protected DrawableFeature draggingFeature;
	protected Point dragLastPoint;
	protected int displayMode;

	protected Cursor csrDefault = Cursor
			.getPredefinedCursor(Cursor.DEFAULT_CURSOR);
	protected Cursor csrDrag;
	protected Cursor csrCross = Cursor
			.getPredefinedCursor(Cursor.CROSSHAIR_CURSOR);
	protected Cursor csrZoomIn;
	protected Cursor csrZoomOut;
	protected Cursor csrInfo;

	protected Popup popup;

	public GenericDisplay() {
		super(null);

		addMouseListener(new MouseAdapter() {
			public void mouseClicked(MouseEvent e) {
				actOnMouseClick(e);
			}

			public void mousePressed(MouseEvent e) {
				actOnMousePressed(e);
			}

			public void mouseReleased(MouseEvent e) {
				actOnMouseReleased(e);
			}
		});

		addMouseMotionListener(new MouseMotionAdapter() {
			public void mouseDragged(MouseEvent e) {
				actOnMouseDragged(e);
			}
		});

		csrZoomIn = findCursor("/resources/icons/zoomin.png", new Point(7, 7), "zoom in");
		csrZoomOut = findCursor("/resources/icons/zoomout.png", new Point(7, 7), "zoom out");
		csrDrag = findCursor("/resources/icons/white_fleur.gif", new Point(7, 7), "drag");
		csrInfo = findCursor("/resources/icons/help-cursor.gif", new Point(1, 1), "info");

		setDisplayMode(DisplayMode.INFO);
	}
	
	private Cursor findCursor(String path, Point hotspot, String name) {
		URL url = getClass().getResource(path);
		
		Toolkit tk = Toolkit.getDefaultToolkit();
		
		Image cursorImage = (url == null) ? null : tk.getImage(url);

		if (cursorImage != null)
			return tk.createCustomCursor(cursorImage, hotspot, name);
		else {
			System.err.println("Unable to create cursor from image at " + path);
			return null;
		}
	}

	public abstract DrawableFeature addFeature(Feature f, int dragMode);

	public DrawableFeature addFeature(Feature f) {
		return addFeature(f, DrawableFeature.DRAG_NONE);
	}

	protected void addDrawableFeature(DrawableFeature df, boolean redraw) {
		drawables.add(df);

		if (redraw)
			repaint();
	}

	protected void addDrawableFeature(DrawableFeature df) {
		addDrawableFeature(df, false);
	}

	public void setDisplayMode(int displayMode) {
		this.displayMode = displayMode;

		switch (displayMode) {
			case DisplayMode.DRAG:
				setCursor(csrDrag);
				break;

			case DisplayMode.INFO:
				setCursor(csrInfo);
				break;

			case DisplayMode.ZOOM_IN:
				if (csrZoomIn != null)
					setCursor(csrZoomIn);
				else
					setCursor(csrCross);
				break;

			case DisplayMode.ZOOM_OUT:
				if (csrZoomOut != null)
					setCursor(csrZoomOut);
				else
					setCursor(csrCross);
				break;

			default:
				setCursor(csrDefault);
				break;
		}
	}

	public int getDisplayMode() {
		return displayMode;
	}

	public void setInsets(Insets insets) {
		this.insets = insets;
		resize();
	}

	public void setUserArea(Dimension userarea) {
		this.userarea = userarea;
		resize();
	}

	public void setInsetsAndUserArea(Insets insets, Dimension userarea) {
		this.insets = insets;
		this.userarea = userarea;
		resize();
	}

	protected void resize() {
		if (insets == null)
			insets = new Insets(0, 0, 0, 0);

		if (userarea == null)
			userarea = new Dimension(0, 0);

		Dimension viewarea = worldToView(userarea);

		setPreferredSize(new Dimension(insets.left + viewarea.width
				+ insets.right, insets.top + viewarea.height + insets.bottom));

		setSize(getPreferredSize());

		revalidate();
	}

	protected void paintComponent(Graphics gr) {
		Graphics2D g = (Graphics2D) gr;

		g.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
				RenderingHints.VALUE_ANTIALIAS_ON);

		Color oldcolour = g.getColor();

		Dimension size = getSize();

		g.setColor(Color.lightGray);

		g.fillRect(0, 0, size.width, size.height);

		g.setColor(getBackground());

		g.fillRect(insets.left, insets.top, size.width
				- (insets.left + insets.right), size.height
				- (insets.top + insets.bottom));

		Rectangle cliprect = g.getClipBounds();

		for (Iterator iter = drawables.iterator(); iter.hasNext();) {
			DrawableFeature df = (DrawableFeature) iter.next();
			Rectangle rect = df.getBoundingRectangle();
			if (rect.intersects(cliprect)) {
				Feature f = df.getFeature();
				Shape s = df.getBoundingShape();
				FeaturePainter fp = df.getFeaturePainter();
				fp.paintFeature(g, f, s);
			}
		}

		g.setColor(oldcolour);
	}

	public Point worldToView(Point p) {
		int x = insets.left + p.x / bpPerPixel;
		int y = insets.top + p.y;

		return new Point(x, y);
	}

	public Point viewToWorld(Point p) {
		int x = (p.x - insets.left) * bpPerPixel;
		int y = (p.y - insets.top);

		return new Point(x, y);
	}

	public Dimension worldToView(Dimension d) {
		int width = d.width / bpPerPixel;
		int height = d.height;

		return new Dimension(width, height);
	}

	public Dimension viewToWorld(Dimension d) {
		int width = d.width * bpPerPixel;
		int height = d.height;

		return new Dimension(width, height);
	}

	protected DrawableFeature getFeatureAt(Point p, Class[] classes) {
		if (classes != null && classes.length > 1) {
			for (int i = 0; i < classes.length; i++) {
				DrawableFeature df = getFeatureForClassAt(p, classes[i]);
				if (df != null)
					return df;
			}
		}

		return null;
	}

	protected DrawableFeature getFeatureAt(Point p, Class c) {
		return getFeatureForClassAt(p, c);
	}

	protected DrawableFeature getFeatureAt(Point p) {
		return getFeatureForClassAt(p, null);
	}

	protected DrawableFeature getFeatureForClassAt(Point p, Class c) {
		for (Iterator iter = drawables.iterator(); iter.hasNext();) {
			DrawableFeature df = (DrawableFeature) iter.next();

			Object obj = df.getFeature();

			if (c == null || c.isInstance(obj)) {
				Shape shape = df.getBoundingShape();

				if (shape.contains(p))
					return df;
			}
		}

		return null;
	}

	public abstract InfoPanel findInfoPanelForFeature(Feature f);

	protected void actOnMouseClick(MouseEvent e) {
		Point click = e.getPoint();

		hidePopup();

		switch (displayMode) {
			case DisplayMode.INFO:
				DrawableFeature df = getFeatureAt(click);

				if (df != null) {
					Feature f = df.getFeature();

					InfoPanel ip = findInfoPanelForFeature(f);

					if (ip != null) {
						try {
							ip.setClientObject(f);
							displayPopup(ip, click);
						} catch (InvalidClientObjectException icoe) {
							icoe.printStackTrace();
						}
					}
				}
				break;

			case DisplayMode.ZOOM_IN:
				zoomIn(click);
				break;

			case DisplayMode.ZOOM_OUT:
				zoomOut(click);
				break;
		}
	}

	protected void actOnMousePressed(MouseEvent e) {
		if (displayMode != DisplayMode.DRAG)
			return;

		Point click = e.getPoint();

		DrawableFeature df = getFeatureAt(click);

		if (df == null)
			return;

		int dm = df.getDragMode();

		if (dm == DrawableFeature.DRAG_NONE)
			return;

		draggingFeature = df;
		dragLastPoint = click;
	}

	protected void actOnMouseReleased(MouseEvent e) {
		draggingFeature = null;
	}

	protected void actOnMouseDragged(MouseEvent e) {
		if (draggingFeature == null)
			return;

		Point click = e.getPoint();

		int dm = draggingFeature.getDragMode();

		boolean canDragX = (dm & DrawableFeature.DRAG_X) != 0;
		boolean canDragY = (dm & DrawableFeature.DRAG_Y) != 0;

		int dx = canDragX ? click.x - dragLastPoint.x : 0;
		int dy = canDragY ? click.y - dragLastPoint.y : 0;

		draggingFeature.translate(dx, dy);

		Point p = draggingFeature.getPosition();

		p = viewToWorld(p);

		draggingFeature.getFeature().setPosition(p);

		repaint();

		dragLastPoint = click;
	}

	public void zoomIn(Point p) {
		if (bpPerPixel < 4) {
			System.err
					.println("Scale is 1 bp/pixel: Cannot zoom in any further");
			return;
		}

		int newBpPerPixel = bpPerPixel >> 2;

		rescale(p, newBpPerPixel);
	}

	public void zoomOut(Point p) {
		int newBpPerPixel = bpPerPixel << 2;

		rescale(p, newBpPerPixel);
	}

	protected void rescale(Point p, int newBpPerPixel) {
		Point wp = viewToWorld(p);

		JViewport viewport = (JViewport) getParent();
		Point vp = viewport.getViewPosition();

		Point offset = new Point(p.x - vp.x, p.y - vp.y);

		bpPerPixel = newBpPerPixel;

		p = worldToView(wp);

		vp = new Point(p.x - offset.x, p.y - offset.y);

		recalculateLayout();

		resize();

		viewport.setViewPosition(vp);
	}

	protected void recalculateLayout() {
		for (Iterator iter = drawables.iterator(); iter.hasNext();) {
			DrawableFeature df = (DrawableFeature) iter.next();
			df.calculateBoundingShape();
		}
	}

	public void hidePopup() {
		if (popup != null) {
			popup.hide();
			popup = null;
		}
	}

	private void displayPopup(InfoPanel ip, Point p) {
		SwingUtilities.convertPointToScreen(p, this);

		PopupFactory factory = PopupFactory.getSharedInstance();
		popup = factory.getPopup(this, ip, p.x - 5, p.y - 5);
		popup.show();
	}
}
