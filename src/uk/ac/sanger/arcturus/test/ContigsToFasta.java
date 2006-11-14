package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.io.*;

public class ContigsToFasta {
	public static void main(String args[]) {
		ContigsToFasta ctf = new ContigsToFasta();

		try {
			ctf.run(args);
		} catch (IOException ioe) {
			ioe.printStackTrace();
			System.exit(1);
		}
	}

	public void run(String args[]) throws IOException {
		int option = ArcturusDatabase.CONTIG_CONSENSUS;

		System.out.println("ContigsTpFasta");
		System.out.println("==============");
		System.out.println();

		String instance = null;
		String organism = null;
		boolean doClipping = false;
		int threshold = 0;
		String fastafilename = null;
		String qualityfilename = null;
		boolean depad = false;

		for (int i = 0; i < args.length; i++) {
			if (args[i].equalsIgnoreCase("-instance"))
				instance = args[++i];

			if (args[i].equalsIgnoreCase("-organism"))
				organism = args[++i];

			if (args[i].equalsIgnoreCase("-clip"))
				doClipping = true;

			if (args[i].equalsIgnoreCase("-threshold"))
				threshold = Integer.parseInt(args[++i]);

			if (args[i].equalsIgnoreCase("-fasta"))
				fastafilename = args[++i];

			if (args[i].equalsIgnoreCase("-quality"))
				qualityfilename = args[++i];

			if (args[i].equalsIgnoreCase("-depad"))
				depad = true;

			if (args[i].equalsIgnoreCase("-help")) {
				showUsage(System.err);
				System.exit(0);
			}
		}

		if (instance == null || organism == null) {
			showUsage(System.err);
			System.exit(1);
		}

		if (doClipping && threshold == 0)
			threshold = 15;

		if (!doClipping && threshold > 0)
			doClipping = true;

		PrintStream psFasta = (fastafilename != null) ? new PrintStream(
				new FileOutputStream(fastafilename)) : System.out;
		PrintStream psQuality = (qualityfilename != null) ? new PrintStream(
				new FileOutputStream(qualityfilename)) : null;

		try {
			System.out.println("Creating an ArcturusInstance for " + instance);
			System.out.println();

			ArcturusInstance ai = Arcturus.getArcturusInstance(instance);

			System.out.println("Creating an ArcturusDatabase for " + organism);
			System.out.println();

			ArcturusDatabase adb = ai.findArcturusDatabase(organism);

			int[] contigIdList = adb.getCurrentContigIDList();

			for (int i = 0; i < contigIdList.length; i++) {
				int id = contigIdList[i];

				Contig contig = adb.getContigByID(id, option);

				byte[] dna = contig.getDNA();
				byte[] quality = contig.getQuality();

				Bounds bounds = doClipping ? calculateBounds(quality, threshold)
						: new Bounds(0, dna.length);

				writeDNAAndQuality(contig.getName(), dna, quality, bounds,
						psFasta, psQuality, depad);
			}

		} catch (Exception e) {
			e.printStackTrace();
			System.exit(1);
		}
	}

	private Bounds calculateBounds(byte[] quality, int threshold) {
		int q[] = new int[quality.length];

		for (int i = 0; i < quality.length; i++)
			q[i] = (int) quality[i] - threshold;

		int L[] = new int[quality.length];
		int l[] = new int[quality.length];

		L[0] = q[0] > 0 ? q[0] : 0;
		l[0] = 0;
		int lambda = 0;

		for (int i = 1; i < q.length; i++) {
			L[i] = L[i - 1] + q[i];

			if (L[i] <= 0) {
				L[i] = 0;
				lambda = i;
			}

			l[i] = lambda;
		}

		int R[] = new int[quality.length];
		int r[] = new int[quality.length];

		int k = quality.length - 1;

		R[k] = q[k] > 0 ? q[k] : 0;
		r[k] = k;
		int rho = k;

		for (int i = quality.length - 2; i >= 0; i--) {
			R[i] = R[i + 1] + q[i];

			if (R[i] <= 0) {
				R[i] = 0;
				rho = i;
			}

			r[i] = rho;
		}

		int qmax = 0;
		int imax = 0;

		for (int i = 0; i < quality.length; i++) {
			int sum = L[i] + R[i];
			if (sum > qmax) {
				qmax = sum;
				imax = i;
			}
		}

		return new Bounds(l[imax], r[imax]);
	}

	private void writeDNAAndQuality(String seqname, byte[] dna, byte[] quality,
			Bounds bounds, PrintStream psFasta, PrintStream psQuality,
			boolean depad) {
		StringBuffer dnabuf = new StringBuffer();
		StringBuffer qualbuf = (psQuality == null) ? null : new StringBuffer();

		String caption = ">" + seqname + " " + dna.length + " " + bounds.left
				+ ".." + bounds.right;

		int count = 0;

		int len = bounds.right - bounds.left;

		for (int i = 0; i < len; i++) {
			int offset = bounds.left + i;

			if (!depad || dna[offset] != '*') {
				count++;

				dnabuf.append((char) dna[offset]);

				if ((count % 50) == 0)
					dnabuf.append('\n');

				if (qualbuf != null) {
					qualbuf.append((int) quality[offset]);
					qualbuf.append(((count % 25) < 24) ? ' ' : '\n');
				}
			}
		}

		if ((count % 50) != 0)
			dnabuf.append('\n');

		if (qualbuf != null && ((count % 25) != 0))
			qualbuf.append('\n');

		psFasta.println(caption);
		psFasta.println(dnabuf.toString());

		if (psQuality != null) {
			psQuality.println(caption);
			psQuality.println(qualbuf.toString());
		}
	}

	private void showUsage(PrintStream ps) {
		ps.println("You forgot a parameter, stupid");
	}

	class Bounds {
		public int left;
		public int right;

		public Bounds(int left, int right) {
			this.left = left;
			this.right = right;
		}
	}
}
