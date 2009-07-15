package uk.ac.sanger.arcturus.test;

import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

import javax.swing.JFrame;

import uk.ac.sanger.arcturus.gui.WarningFrame;

public class TestWarningFrame implements Runnable {
	private int count = 0;
	private WarningFrame frame;
	
	public void run() {
		frame = new WarningFrame("TestWarningFrame");
		
		count++;
		
		frame.setText("This is warning message #" + count);
		
		frame.addWindowListener(new WindowAdapter() {
			public void windowClosed(WindowEvent event) {
				count++;
				frame.appendText("\n");
				frame.appendText("This is warning message #" + count);
				
				try {
					Thread.sleep(2000);
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
				
				frame.setVisible(true);
			}
		});
		
		frame.pack();
		
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		
		frame.setVisible(true);
	}
	
	public static void main(String[] args) {
		TestWarningFrame twf = new TestWarningFrame();
		Thread thread = new Thread(twf);
		thread.start();
	}
}
