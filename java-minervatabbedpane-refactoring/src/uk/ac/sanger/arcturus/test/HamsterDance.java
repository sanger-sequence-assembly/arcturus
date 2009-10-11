package uk.ac.sanger.arcturus.test;

import javax.swing.*;
import javax.imageio.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.image.*;
import java.net.*;

import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class HamsterDance extends JComponent {
	/**
	 * 
	 */
	private static final long serialVersionUID = -3903270377582651379L;
	protected BufferedImage[] frames;
	protected Timer timer;
	protected int counter;

	public HamsterDance(int delay) {
		super();

		BufferedImage image = null;

		try {
			URL url = ArcturusDatabase.class
					.getResource("/resources/icons/hamsterdance.jpg");

			image = ImageIO.read(url);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}

		int height = image.getHeight();

		frames = new BufferedImage[3];

		for (int i = 0; i < 3; i++)
			frames[i] = image.getSubimage(44 * i, 0, 44, height);

		setPreferredSize(new Dimension(frames[0].getWidth(), frames[0]
				.getHeight()));

		counter = 0;

		ActionListener taskPerformer = new ActionListener() {
			public void actionPerformed(ActionEvent evt) {
				counter = (counter + 1) % 3;
				repaint();
			}
		};

		timer = new Timer(delay, taskPerformer);

		timer.start();
	}

	public void paintComponent(Graphics g) {
		g.drawImage(frames[counter], 0, 0, Color.black, null);
	}

	public void stop() {
		timer.stop();
	}

	public void start() {
		timer.restart();
	}

	public boolean isRunning() {
		return timer.isRunning();
	}

	public static void main(String args[]) {
		JFrame frame = new JFrame("Hamsters!");

		frame.getContentPane().add(new HamsterDance(100), BorderLayout.CENTER);

		frame.setSize(100, 100);
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
		frame.setVisible(true);
	}
}
