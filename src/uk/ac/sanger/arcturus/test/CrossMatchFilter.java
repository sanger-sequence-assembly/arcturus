package uk.ac.sanger.arcturus.test;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;

import java.util.regex.Pattern;
import java.util.regex.Matcher;

import javax.swing.JFileChooser;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;

public class CrossMatchFilter {
	public static void main(String[] args) {
		File file = null;

		if (args.length == 0) {
			JFileChooser chooser = new JFileChooser();
			FileFilter filter = new FileNameExtensionFilter("CrossMatch files",
					"xma");
			chooser.addChoosableFileFilter(filter);

			int rc = chooser.showOpenDialog(null);

			if (rc == JFileChooser.APPROVE_OPTION)
				file = chooser.getSelectedFile();
		} else
			file = new File(args[0]);

		if (file == null) {
			System.err.println("No file to read!");
			System.exit(1);
		}

		BufferedReader br = null;

		try {
			br = new BufferedReader(new FileReader(file));
		} catch (FileNotFoundException e) {
			e.printStackTrace();
			System.exit(1);
		}

		Pattern pattern = Pattern
				.compile("^\\s*\\d+\\s+\\d+\\.\\d+\\s+\\d+\\.\\d+\\s+\\d+\\.\\d+\\s+.*");

		String line = null;

		try {
			while ((line = br.readLine()) != null) {
				Matcher matcher = pattern.matcher(line);

				if (matcher.matches()) {
					String[] words = line.trim().split("\\s+");

					int i = 0;

					int score = Integer.parseInt(words[i++]);

					double subs = Double.parseDouble(words[i++]);
					double dels = Double.parseDouble(words[i++]);
					double inss = Double.parseDouble(words[i++]);

					String name1 = words[i++];

					int start1 = Integer.parseInt(words[i++]);
					int finish1 = Integer.parseInt(words[i++]);

					String word = words[i++];
					int tail1 = Integer.parseInt(word.substring(1, word
							.length() - 1));

					String name2;
					int start2;
					int finish2;
					int tail2;
					boolean compl;

					if (words[i].equalsIgnoreCase("C")) {
						compl = true;
						i++;

						name2 = words[i++];

						word = words[i++];
						tail2 = Integer.parseInt(word.substring(1, word
								.length() - 1));

						start2 = Integer.parseInt(words[i++]);
						finish2 = Integer.parseInt(words[i++]);
					} else {
						compl = false;

						name2 = words[i++];

						start2 = Integer.parseInt(words[i++]);
						finish2 = Integer.parseInt(words[i++]);

						word = words[i++];
						tail2 = Integer.parseInt(word.substring(1, word
								.length() - 1));
					}

					if (score >= 100) {
						System.out.println("Score: " + score);
						System.out.println("Subs: " + subs + ", dels: " + dels
								+ ", inss: " + inss);
						System.out.println("Sequence #1: " + name1);
						System.out.println("Alignment: " + start1 + " "
								+ finish1 + " " + tail1);
						System.out.println("Sequence #2: " + name2
								+ (compl ? " [REVERSED]" : ""));
						System.out.println("Alignment: " + start2 + " "
								+ finish2 + " " + tail2);
						System.out.println();
					}
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

}
