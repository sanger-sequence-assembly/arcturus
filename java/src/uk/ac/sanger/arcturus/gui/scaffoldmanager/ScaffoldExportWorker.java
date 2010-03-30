package uk.ac.sanger.arcturus.gui.scaffoldmanager;

import java.io.*;
import java.sql.SQLException;
import java.text.DecimalFormat;
import java.util.List;
import java.util.Enumeration;
import java.util.zip.DataFormatException;

import javax.swing.JPanel;
import javax.swing.ProgressMonitor;
import javax.swing.SwingWorker;
import javax.swing.tree.DefaultMutableTreeNode;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.ScaffoldManagerPanel.FastaMode;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.AssemblyNode;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.ContigNode;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.GapNode;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.ScaffoldNode;
import uk.ac.sanger.arcturus.gui.scaffoldmanager.node.SuperscaffoldNode;

public class ScaffoldExportWorker extends
		SwingWorker<Void, ScaffoldExportMessage> {
	private File dir;
	private DefaultMutableTreeNode root;
	
	private ProgressMonitor monitor;
	
	private JPanel parent;
	
	private FastaMode mode;
	
	private DecimalFormat format;

	private int totalScaffolds = 0;
	private int totalContigs = 0;
	private int totalContigLength = 0;
	
	private int countScaffolds = 0;
	private int countContigs = 0;
	private int countContigLength = 0;
	
	private StringBuilder scaffoldSequence;
	private int agpLineNumber;

	public ScaffoldExportWorker(JPanel parent, FastaMode mode, File dir, DefaultMutableTreeNode root) {
		this.dir = dir;
		this.root = root;
		this.parent = parent;
		this.mode = mode;
		
		format = new DecimalFormat("00000000");
	}

	protected Void doInBackground() throws Exception {
		countContigs(root);

		monitor = new ProgressMonitor(parent,
                "Exporting selected scaffolds",
                "Starting...", 0, totalContigLength);
		
		processScaffolds(root);

		return null;
	}

	private void countContigs(DefaultMutableTreeNode node) {
		if (node instanceof ScaffoldNode) {
			totalScaffolds++;

			ScaffoldNode snode = (ScaffoldNode) node;

			List<Contig> contigs = snode.getContigs();

			for (Contig contig : contigs) {
				totalContigs++;
				totalContigLength += contig.getLength();
			}
		} else if (node instanceof AssemblyNode
				|| node instanceof SuperscaffoldNode) {
			Enumeration e = node.children();

			while (e.hasMoreElements()) {
				DefaultMutableTreeNode childNode = (DefaultMutableTreeNode) e
						.nextElement();

				countContigs(childNode);
			}
		}
	}
	
	private void processScaffolds(DefaultMutableTreeNode node) {
		if (monitor.isCanceled())
			cancel(true);
		
		if (node instanceof ScaffoldNode) {			
			try {
				exportScaffold((ScaffoldNode) node);
			} catch (IOException e) {
				Arcturus.logWarning("An I/O error occurred when trying to export a scaffold as FASTA", e);
			} catch (SQLException e) {
				Arcturus.logWarning("A database error occurred when trying to export a scaffold as FASTA", e);
			}
		} else if (node instanceof AssemblyNode
				|| node instanceof SuperscaffoldNode) {
			Enumeration e = node.children();

			while (e.hasMoreElements()) {
				DefaultMutableTreeNode childNode = (DefaultMutableTreeNode) e
						.nextElement();

				processScaffolds(childNode);
			}
		}
	}
	
	private void exportScaffold(ScaffoldNode node) throws IOException, SQLException  {
		countScaffolds++;
		
		String scaffoldName = "scaffold" + format.format(node.getID());
		
		String fastaFilename = scaffoldName + ".fas";
		
		String listFilename = scaffoldName + (mode == FastaMode.SEPARATE_CONTIGS ? ".list" : ".agp"); 
		
		File fastaFile = new File(dir, fastaFilename);
		File listFile = new File(dir, listFilename);
		
		PrintWriter fastaWriter
			   = new PrintWriter(new BufferedWriter(new FileWriter(fastaFile)));
		
		PrintWriter listWriter
		   = new PrintWriter(new BufferedWriter(new FileWriter(listFile)));
		
		if (mode == FastaMode.CONCATENATE_CONTIGS) {
			scaffoldSequence = new StringBuilder();
			agpLineNumber = 0;
		}
		
		Enumeration children = node.children();
		
		while (children.hasMoreElements()) {
			DefaultMutableTreeNode childNode = (DefaultMutableTreeNode) children.nextElement();
			
			if (childNode instanceof ContigNode)
				exportContig((ContigNode)childNode, scaffoldName, fastaWriter, listWriter);
			else if (childNode instanceof GapNode)
				exportGap((GapNode)childNode, scaffoldName, fastaWriter, listWriter);
		}
		
		if (mode == FastaMode.CONCATENATE_CONTIGS) {
			fastaWriter.println(">" + scaffoldName);
			writeFastaSequence(fastaWriter, scaffoldSequence.toString());
		}

		fastaWriter.close();
		listWriter.close();
		
		publish(new ScaffoldExportMessage(countScaffolds, countContigs, countContigLength));
	}

	private void exportGap(GapNode childNode, String scaffoldName,
			PrintWriter fastaWriter, PrintWriter listWriter) {
		if (mode == FastaMode.CONCATENATE_CONTIGS) {
			int gapLength = childNode.length();
			
			int cstart = 1 + scaffoldSequence.length();
			int cend = cstart + gapLength - 1;
			
			for (int i = 0; i < gapLength; i++)
				scaffoldSequence.append('N');
			
			agpLineNumber++;
			
			listWriter.println(scaffoldName + "\t" + cstart + "\t" + cend + "\t" + agpLineNumber +
					"\tN\t" + gapLength + "\tfragment\tyes");
		}
	}

	private void exportContig(ContigNode childNode, String scaffoldName,
			PrintWriter fastaWriter, PrintWriter listWriter) throws IOException, SQLException {
		Contig contig = childNode.getContig();
		
		boolean forward = childNode.isForward();
		
		try {
			contig.update(ArcturusDatabase.CONTIG_CONSENSUS);
		} catch (DataFormatException e) {
			return;
		}			
		
		byte[] dna = depad(contig.getDNA());
		
		String sequence = new String(dna, "US-ASCII");

		if (!forward)
			sequence = reverseComplement(sequence);
		
		String contigName = "contig" + format.format(contig.getID());
		
		switch (mode) {
			case SEPARATE_CONTIGS:
				if (!forward)
					contigName += ".R"; 
				
				fastaWriter.println(">" + contigName + " length=" + contig.getLength() + " reads=" + contig.getReadCount());
				writeFastaSequence(fastaWriter, sequence);
				listWriter.println(contigName + "\t" + scaffoldName);
				break;
				
			case CONCATENATE_CONTIGS:
				int cstart = 1 + scaffoldSequence.length();
				int cend = cstart + sequence.length() - 1;
				agpLineNumber++;
				scaffoldSequence.append(sequence);
				listWriter.println(scaffoldName + "\t" + cstart + "\t" + cend + "\t" + agpLineNumber +
						"\tA\t" + contigName + "\t1\t" + sequence.length() + "\t" + (forward ? '+' : '-'));
				break;
		}
		
		countContigs++;
		countContigLength += contig.getLength();
		
		contig.setConsensus(null, null);
	}
	
	private void writeFastaSequence(PrintWriter fastaWriter, String sequence) {	
		for (int j = 0; j < sequence.length(); j += 50) {
			int sublen = (j + 50 < sequence.length()) ? 50 : sequence.length() - j;
			fastaWriter.println(sequence.substring(j, j + sublen));
		}
	}
	
	private String reverseComplement(String str) {
		int strlen = str.length();
		
		char[] revchars = new char[strlen];
		
		for (int i = 0; i < strlen; i++) {
			char src = str.charAt(i);
			
			char dst;
			
			switch (src) {
				case 'a': case 'A': dst = 'T'; break;
				case 'c': case 'C': dst = 'G'; break;
				case 'g': case 'G': dst = 'C'; break;
				case 't': case 'T': dst = 'A'; break;
				default: dst = 'N'; break;
			}
			
			revchars[strlen - 1 - i] = dst;
		}
		
		return new String(revchars);
	}

	private byte[] depad(byte[] input) {
		if (input == null)
			return null;
		
		int pads = 0;
		
		for (int i = 0; i < input.length; i++)
			if (input[i] == '*' || input[i] == '-')
				pads++;
		
		if (pads == 0)
			return input;
		
		byte[] output = new byte[input.length - pads];
		
		int j = 0;
		
		for (int i = 0; i < input.length; i++)
			if (input[i] != '*' && input[i] != '-')
				output[j++] = input[i];
		
		return output;
	}

	protected void process(List<ScaffoldExportMessage> messages) {
		ScaffoldExportMessage msg = messages.get(messages.size() - 1);
		
		monitor.setProgress(msg.getContigLength());
		
		String message = "Exported " + msg.getContigCount() + " contigs out of " + totalContigs;
		
		monitor.setNote(message);
	}

	protected void done() {

	}
}
