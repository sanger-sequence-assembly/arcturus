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
