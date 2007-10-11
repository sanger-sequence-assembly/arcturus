package uk.ac.sanger.arcturus.utils;

import java.io.*;
import uk.ac.sanger.arcturus.smithwaterman.*;

public class RunSmithWaterman {
	private static final int DEFAULT_SUBJECT_OFFSET = 0;
	private static final int DEFAULT_QUERY_OFFSET = 0;
	private static final int DEFAULT_BANDWIDTH = 10;

	public static void main(String[] args) {
		String subjectFilename = null;
		String queryFilename = null;
		int subjectOffset = DEFAULT_SUBJECT_OFFSET;
		int subjectLength = 0;
		int queryOffset = DEFAULT_QUERY_OFFSET;
		int queryLength = 0;
		int bandwidth = DEFAULT_BANDWIDTH;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-subject"))
				subjectFilename = args[++i];
			else if (args[i].equalsIgnoreCase("-query"))
				queryFilename = args[++i];
			else if (args[i].equalsIgnoreCase("-subjectoffset"))
				subjectOffset = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-queryoffset"))
				queryOffset = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-subjectlength"))
				subjectLength = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-querylength"))
				queryLength = Integer.parseInt(args[++i]);
			else if (args[i].equalsIgnoreCase("-bandwidth"))
				bandwidth = Integer.parseInt(args[++i]);
		}

		if (subjectFilename == null || queryFilename == null) {
			printUsage(System.err);
			System.exit(1);
		}
		
		char[] subjectSequence = loadFromFile(subjectFilename);
		char[] querySequence = loadFromFile(queryFilename);
		
		ScoringMatrix smat = new ScoringMatrix();
		
		if (subjectLength == 0)
			subjectLength = subjectSequence.length - subjectOffset;
		
		if (queryLength == 0)
			queryLength = querySequence.length - queryOffset;
		
		SmithWatermanArrayModel sw = SmithWaterman.calculateMatrix(subjectSequence,
				subjectOffset, subjectLength,
				querySequence, queryOffset, queryLength, smat, bandwidth);
		
		int[] best = sw.getMaximalEntry();
		
		Alignment al = null;
		
		try {
			al = SmithWaterman.getAlignment(sw, best[0], best[1]);
		} catch (SmithWatermanException e) {
			e.printStackTrace();
		}
		
		System.out.println("Row: " + (subjectOffset + al.getRow()));
		System.out.println("Col: " + (queryOffset + al.getColumn()));
		
		EditEntry[] edits = al.getEdits();
		
		for (int i = 0; i < edits.length; i++)
			System.out.println((i > 0 ? "," :"") + edits[i]);
	}
	
	private static char[] loadFromFile(String filename) {
		StringBuilder sb = new StringBuilder();

		try {
			BufferedReader br = new BufferedReader(new FileReader(filename));

			boolean headerseen = false;

			String line = null;

			while ((line = br.readLine()) != null) {
				if (line.startsWith(">")) {
					if (headerseen)
						break;

					headerseen = true;
				} else {
					sb.append(line);
					sb.append('\n');
				}
			}

			br.close();
		} catch (IOException ioe) {
			ioe.printStackTrace();
		}
		
		char[] chars = new char[sb.length()];
		
		sb.getChars(0, sb.length(), chars, 0);
		
		return chars;
	}

	private static void printUsage(PrintStream ps) {
		ps.println("MANDATORY PARAMETERS");
		ps.println("\t-subject\tName of subject FASTA file");
		ps.println("\t-query\t\tName of query FASTA file");
		ps.println();
		ps.println("OPTIONAL PARAMETERS");
		ps.println("\t-subjectoffset\tOffset into subject [default: "
				+ DEFAULT_SUBJECT_OFFSET + "]");
		ps.println("\t-queryoffset\tOffset into query [default: "
				+ DEFAULT_QUERY_OFFSET + "]");
		ps.println("\t-subjectlength\tLength in subject [default: entire sequence]");
		ps.println("\t-querylength\tLength in query [default: entire sequence]");
		ps.println("\t-bandwidth\tSemi-bandwidth for banded Smith-Waterman [default:"
						+ DEFAULT_BANDWIDTH + "]");
	}
}
