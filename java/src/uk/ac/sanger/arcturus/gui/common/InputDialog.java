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

package uk.ac.sanger.arcturus.gui.common;

import java.awt.BorderLayout;
import java.awt.Container;
import java.awt.FlowLayout;
import java.awt.Frame;
import java.awt.event.ActionEvent;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

import javax.swing.AbstractAction;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JPanel;

public class InputDialog extends JDialog {
	public enum Status { OK, CANCEL, CLOSED };
	
	private JPanel mainPanel;
	private InputDialogAction okAction;
	
	private Status status;
	
	public InputDialog(Frame frame, String title, Container panel) {
		super(frame, title, true);
		
		mainPanel = new JPanel(new BorderLayout());

		mainPanel.add(panel, BorderLayout.CENTER);

		JPanel buttonpanel = new JPanel(new FlowLayout(FlowLayout.CENTER));
		
		okAction = new InputDialogAction("OK") {
			public void actionPerformed(ActionEvent e) {
				status = Status.OK;
				
				InputDialog.this.setVisible(false);
			}			
		};

		buttonpanel.add(new JButton(okAction));
		
		InputDialogAction cancelAction = new InputDialogAction("Cancel") {
			public void actionPerformed(ActionEvent e) {
				status = Status.CANCEL;
				
				InputDialog.this.setVisible(false);
			}			
		};
		
		buttonpanel.add(new JButton(cancelAction));

		mainPanel.add(buttonpanel, BorderLayout.SOUTH);
		
		setContentPane(mainPanel);
		
		pack();
		
		setModalityType(ModalityType.APPLICATION_MODAL);
		setResizable(false);
		setDefaultCloseOperation(JDialog.HIDE_ON_CLOSE);
		
		addWindowListener(new WindowAdapter() {
			public void windowClosing(WindowEvent e) {
				status = Status.CLOSED;
			}
		});
	}
	
	public void setOKActionEnabled(boolean newValue) {
		okAction.setEnabled(newValue);
	}
	
	public boolean isOKActionEnabled() {
		return okAction.isEnabled();
	}
	
	public Status showDialog() {
		pack();
		
		setVisible(true);
		
		return status;
	}
	
	abstract class InputDialogAction extends AbstractAction {		
		public InputDialogAction(String name) {
			super(name);
		}
	}
}
