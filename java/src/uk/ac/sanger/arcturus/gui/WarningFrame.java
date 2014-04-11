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

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.FlowLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.*;

public class WarningFrame extends JFrame {
	private JTextArea textarea = new JTextArea(25, 80);
	
	public WarningFrame(String title) {
		super(title);
		
		createUI();
	}
	
	private void createUI() {
		JPanel mainpanel = new JPanel(new BorderLayout());

		textarea.setForeground(Color.red);
		JScrollPane sp = new JScrollPane(textarea);

		mainpanel.add(sp, BorderLayout.CENTER);

		JPanel buttonpanel = new JPanel(new FlowLayout());

		JButton btnClose = new JButton("Close");
		
		btnClose.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				closeAndDispose();
			}			
		});

		buttonpanel.add(btnClose);

		mainpanel.add(buttonpanel, BorderLayout.SOUTH);

		getContentPane().add(mainpanel);

		pack();
	}
	
	private void closeAndDispose() {
		setVisible(false);
		dispose();
	}
	
	public void setText(String text) {
		textarea.setText(text);
	}
	
	public void clearText() {
		textarea.setText("");
	}
	
	public void appendText(String text) {
		textarea.append(text);
	}
}
