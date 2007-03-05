package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;
import java.awt.event.*;

public class MinervaFrame extends JFrame implements ChangeListener {
	protected Minerva minerva = null;
	protected JToolBar toolbar;
	protected JComponent component;

	public MinervaFrame(Minerva minerva, String title, JComponent component) {
		super(title);
		this.minerva = minerva;
		this.component = component;
		
		this.getContentPane().setLayout(new BorderLayout());
		this.getContentPane().add(component, BorderLayout.CENTER);
		
		setMenuForComponent(component);

		if (component instanceof JTabbedPane)
			((JTabbedPane) component).addChangeListener(this);
		
		addWindowListener(new WindowAdapter() {
			public void windowClosing(WindowEvent event) {
				handleWindowClosing();
			}
		});
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
			
			if (selected == null)
				selected = source;

			setMenuForComponent(selected);
		}
	}
	
	private void setMenuForComponent(Component c) {
		if (c instanceof MinervaClient) {
			JMenuBar menubar = ((MinervaClient) c).getMenuBar();
			JToolBar toolbar = ((MinervaClient) c).getToolBar();

			if (menubar != null)
				setJMenuBar(menubar);
			
			setToolBar(toolbar);
		}
	}
	
	private void handleWindowClosing() {
		if (component instanceof MinervaClient) {
			int rc = JOptionPane.showOptionDialog(this,
					"Do you REALLY want to close this window?",
		    		 "Warning",
		    		 JOptionPane.OK_CANCEL_OPTION,
		    		 JOptionPane.WARNING_MESSAGE,
		    		 null, null, null);

			if (rc == JOptionPane.OK_OPTION) {
				MinervaClient client = (MinervaClient)component;
				client.closeResources();
				
				setVisible(false);
				dispose();
			}
		}
	}
}
