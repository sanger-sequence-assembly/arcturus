package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;

public class MinervaFrame extends JFrame implements ChangeListener {
	protected Minerva minerva = null;
	protected JToolBar toolbar;

	public MinervaFrame(Minerva minerva, String title, JComponent component) {
		super(title);
		this.minerva = minerva;
		this.getContentPane().setLayout(new BorderLayout());
		this.getContentPane().add(component, BorderLayout.CENTER);

		if (component instanceof JTabbedPane)
			((JTabbedPane) component).addChangeListener(this);
	}

	public void setToolBar(JToolBar toolbar) {
		if (toolbar == null && this.toolbar != null)
			this.getContentPane().remove(this.toolbar);

		if (toolbar != null)
			this.getContentPane().add(toolbar, BorderLayout.NORTH);

		this.toolbar = toolbar;
	}

	public void stateChanged(ChangeEvent event) {
		Component source = (Component) event.getSource();

		if (source instanceof JTabbedPane) {
			Component selected = ((JTabbedPane) source).getSelectedComponent();

			if (selected instanceof MinervaClient) {
				JMenuBar menubar = ((MinervaClient) selected).getMenuBar();
				JToolBar toolbar = ((MinervaClient) selected).getToolBar();

				if (menubar != null)
					setJMenuBar(menubar);

				setToolBar(toolbar);
			}
		}
	}
}
