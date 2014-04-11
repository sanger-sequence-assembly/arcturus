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

package uk.ac.sanger.arcturus.gui;

import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;
import java.awt.event.*;

public class MinervaFrame extends JFrame implements ChangeListener {
	protected Minerva minerva = null;
	protected JToolBar toolbar;
	protected JComponent component;
	protected String name;

	public MinervaFrame(Minerva minerva, String title, String name) {
		super(title);
		this.minerva = minerva;
		this.name = name;
		
		setDefaultCloseOperation(WindowConstants.DO_NOTHING_ON_CLOSE);
		
		addWindowListener(new WindowAdapter() {
			public void windowClosing(WindowEvent event) {
				handleWindowClosing();
			}
		});
	}
	
	public MinervaFrame(Minerva minerva, String title, String name, JComponent component) {
		this(minerva, title, name);
		setComponent(component);
	}
	
	public String getName() {
		return name;
	}
	
	public void setComponent(JComponent component) {
		this.component = component;
		
		this.getContentPane().setLayout(new BorderLayout());
		this.getContentPane().add(component, BorderLayout.CENTER);
		
		setMenuForComponent(component);

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
				
				Minerva.getInstance().unregisterFrame(this);
				
				setVisible(false);
				dispose();
			}
		}
	}
}
