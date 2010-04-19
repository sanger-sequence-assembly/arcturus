package uk.ac.sanger.arcturus.crossmatch;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.swing.JFileChooser;
import javax.swing.filechooser.FileFilter;
//import javax.swing.filechooser.FileNameExtensionFilter;

public class CrossMatchFilter {
	protected Pattern pattern = Pattern
			.compile("^\\s*\\d+\\s+\\d+\\.\\d+\\s+\\d+\\.\\d+\\s+\\d+\\.\\d+\\s+.*");

	public Match filter(String line, int minscore) throws NumberFormatException {
		Matcher matcher = pattern.matcher(line);

		if (matcher.matches()) {
			String[] words = line.trim().split("\\s+");

			int i = 0;

			int score = Integer.parseInt(words[i++]);

			if (score < minscore)
				return null;

			double subs = Double.parseDouble(words[i++]);
			double dels = Double.parseDouble(words[i++]);
			double inss = Double.parseDouble(words[i++]);

			String name1 = words[i++];

			int start1 = Integer.parseInt(words[i++]);
			int finish1 = Integer.parseInt(words[i++]);

			String word = words[i++];
			int tail1 = Integer.parseInt(word.substring(1, word.length() - 1));

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
				tail2 = Integer.parseInt(word.substring(1, word.length() - 1));

				start2 = Integer.parseInt(words[i++]);
				finish2 = Integer.parseInt(words[i++]);
			} else {
				compl = false;

				name2 = words[i++];

				start2 = Integer.parseInt(words[i++]);
				finish2 = Integer.parseInt(words[i++]);

				word = words[i++];
				tail2 = Integer.parseInt(word.substring(1, word.length() - 1));
			}

			return new Match(score, inss, dels, subs, name1, start1, finish1,
					tail1, name2, start2, finish2, tail2, compl);
		} else
			return null;
	}

	public static void main(String[] args) {
		File file = null;

		if (args.length == 0) {
			JFileChooser chooser = new JFileChooser();
			//FileFilter filter = new FileNameExtensionFilter("CrossMatch files",
			//		"xma");
			//chooser.addChoosableFileFilter(filter);

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

		String line = null;
		
		CrossMatchFilter filter = new CrossMatchFilter();

		try {
			while ((line = br.readLine()) != null) {
				Match match = filter.filter(line, 100);
				
				if (match != null)
					System.out.println(match);
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
}
