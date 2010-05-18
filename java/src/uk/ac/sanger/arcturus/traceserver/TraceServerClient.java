package uk.ac.sanger.arcturus.traceserver;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Vector;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.data.Clipping;
import uk.ac.sanger.arcturus.data.Clone;
import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.data.Read;
import uk.ac.sanger.arcturus.data.Sequence;
import uk.ac.sanger.arcturus.data.Template;

public class TraceServerClient {
	protected final String traceServerURL;
	
	public TraceServerClient(String traceServerURL) {
		this.traceServerURL = traceServerURL;
	}

	public Sequence fetchRead(String readname) {
		try {
			String urlstring = traceServerURL + "?name=" + readname;
			
			URL url = new URL(urlstring);

			HttpURLConnection conn = (HttpURLConnection)url.openConnection();
			
			conn.setRequestMethod("GET");
			
			conn.connect();

			String contentType = conn.getContentType();
			int contentLength = conn.getContentLength();
			long lm= conn.getLastModified();
			Date lastModified = new Date(lm);
			int rc = conn.getResponseCode();

			System.err.println("Response code:    " + rc);
			
			if (rc == HttpURLConnection.HTTP_OK) {
				System.err.println("Content type:     " + contentType);
				System.err.println("Content length:   " + contentLength);
				System.err.println("Last modified:    " + lastModified);

				InputStream is = conn.getInputStream();
				
				Sequence sequence = parseRead(is);

				is.close();
				
				return sequence;
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
		
		return null;
	}
	
	private Sequence parseRead(InputStream is) throws IOException {
		BufferedReader br = new BufferedReader(new InputStreamReader(is, "US-ASCII"));
		
		String line;
		StringBuilder sb = new StringBuilder();
		String sqData = null;
		
		Map<String, String> map = new HashMap<String, String>();
		
		while ((line = br.readLine()) != null) {
			String[] words = line.split("\\s+", 2);
			
			if (words[0].equalsIgnoreCase("AV")) {
				if (sb.length() > 0)
					sb.append(' ');
				
				sb.append(words[1]);
			} else if (words[0].equalsIgnoreCase("SQ")) {
				sqData = parseSequence(br);
			} else {
				map.put(words[0], words[1]);
			}
		}
		
		map.put("SQ", sqData);
			
		map.put("AV", sb.toString());
		
		return createSequence(map);
	}
	
	private String parseSequence(BufferedReader br) throws IOException {
		StringBuilder sb = new StringBuilder();
		
		String line;
		
		while ((line = br.readLine()) != null) {
			if (line.startsWith("//"))
				break;
			else
				sb.append(line);
		}		
		
		return sb.toString().replaceAll("\\s+", "").replaceAll("\\-", "N");
	}
	
	private Sequence createSequence(Map<String, String> map) {
		String readName = map.get(ExperimentFile.KEY_READ_NAME);
		
		System.err.println("PROCESSING " + readName);
		
		String cloneName = map.get(ExperimentFile.KEY_CLONE_NAME);
		
		Clone clone = (cloneName != null) ? new Clone(cloneName) : null;
		
		String ligationName = map.get(ExperimentFile.KEY_LIGATION_NAME);
		
		Ligation ligation = (ligationName != null) ? new Ligation(ligationName) : null;
		
		if (ligation != null && clone != null)
			ligation.setClone(clone);
		
		String insertSizeRange = map.get(ExperimentFile.KEY_INSERT_SIZE_RANGE);
		
		if (ligation != null && insertSizeRange != null) {
			String[] words = insertSizeRange.split("\\.\\.");
			
			int silow = Integer.parseInt(words[0]);
			int sihigh = Integer.parseInt(words[1]);
			
			ligation.setInsertSizeRange(silow, sihigh);
		}
		
		String templateName = map.get(ExperimentFile.KEY_TEMPLATE_NAME);
		
		Template template = (templateName != null) ? new Template(templateName) : null;
		
		if (template != null && ligation != null)
			template.setLigation(ligation);
		
		Read read = new Read(readName);
		
		int primerType = parsePrimerType(map.get(ExperimentFile.KEY_PRIMER));
		
		read.setPrimer(primerType);
		
		int chemistryType = parseChemistryType(map.get(ExperimentFile.KEY_CHEMISTRY));
		
		read.setChemistry(chemistryType);
		
		int strand = parseStrand(map.get(ExperimentFile.KEY_DIRECTION));
		
		read.setStrand(strand);
		
		byte[] dna = parseDNA(map.get(ExperimentFile.KEY_SEQUENCE));
		
		byte[] quality = parseQuality(map.get(ExperimentFile.KEY_ACCURACY_VALUES));
		
		Sequence sequence = new Sequence(0, read, dna, quality, 0);
		
		int seqlen = dna.length;
		
		String qls = map.get(ExperimentFile.KEY_QUALITY_CLIP_LEFT);
		String qrs = map.get(ExperimentFile.KEY_QUALITY_CLIP_RIGHT);
		
		if (qls != null && qrs != null) {
			int ql = Integer.parseInt(qls);
			int qr = Integer.parseInt(qrs);
			
			Clipping qclip = new Clipping(Clipping.QUAL, null, ql, qr);
			
			sequence.setQualityClipping(qclip);
		}
		
		String svname = map.get(ExperimentFile.KEY_SEQUENCING_VECTOR_NAME);
		
		String svls = map.get(ExperimentFile.KEY_SEQUENCING_VECTOR_LEFT);
		
		if (svls != null) {
			int svl = Integer.parseInt(svls);
			
			Clipping svlclip = new Clipping(Clipping.SVEC, svname, 1, svl);
			
			sequence.setSequenceVectorClippingLeft(svlclip);
		}
		
		String svrs = map.get(ExperimentFile.KEY_SEQUENCING_VECTOR_RIGHT);
		
		if (svrs != null) {
			int svr = Integer.parseInt(svrs);
			
			Clipping svrclip = new Clipping(Clipping.SVEC, svname, svr, seqlen);
			
			sequence.setSequenceVectorClippingRight(svrclip);
		}
		
		return sequence;
	}
	
	private int parsePrimerType(String primer) {
		if (primer == null)
			return Read.UNKNOWN;
		
		int iPrimer = Integer.parseInt(primer);
		
		switch (iPrimer) {
			case 1:
			case 2:
				return Read.UNIVERSAL_PRIMER;
				
			case 3:
			case 4:
				return Read.CUSTOM_PRIMER;
				
			default:
				return Read.UNKNOWN;
		}
	}
	
	private int parseChemistryType(String chemistry) {
		if (chemistry == null)
			return Read.UNKNOWN;
		
		int iChemistry = Integer.parseInt(chemistry) % 2;
		
		return iChemistry == 0 ? Read.DYE_PRIMER : Read.DYE_TERMINATOR;
	}
	
	private int parseStrand(String strand) {
		if (strand == null)
			return Read.UNKNOWN;
		
		if (strand.equals("+"))
			return Read.FORWARD;
		else if (strand.equals("-"))
			return Read.REVERSE;
		else
			return Read.UNKNOWN;
	}
	
	private byte[] parseDNA(String value) {
		if (value == null)
			return null;
		
		try {
			return value.getBytes("US-ASCII");
		} catch (UnsupportedEncodingException e) {
			Arcturus.logSevere("Failed to convert DNA string to byte array", e);
			return null;
		}
	}
	
	private byte[] parseQuality(String value) {
		if (value == null)
			return null;

		String[] words = value.split("\\s+");
		
		byte[] quality = new byte[words.length];
		
		for (int i = 0; i < words.length; i++)
			quality[i] = (byte) Integer.parseInt(words[i]);
		
		return quality;
	}
	
	public static void main(String[] args) {
		String baseURL = args.length > 0 ? args[0] : Arcturus.getProperty("traceserver.baseURL");
		
		if (baseURL == null) {
			System.err.println("Unable to determine the trace server's base URL");
			System.exit(1);
		}
		
		TraceServerClient client = new TraceServerClient(baseURL);
		
		String[] readnames = { "wibble", "1027_emuFOS1_1a01.p1kpIBF", "1016Tviv_FOS41g09.q1kpIBR",
				"Tviv1035d12.p1k", "Tviv1066e07.p1k"
		};
		
		for (String readname : readnames) {
			System.err.println("FETCHING " + readname + "\n");
			
			Sequence sequence = client.fetchRead(readname);
			
			if (sequence == null) {
				System.err.println(" --- NOT FOUND ---");
			} else {
				Read read = sequence.getRead();
			
				System.err.println(read.toCAFString());
			
				System.err.println(sequence.toCAFString());
			}
		}
		
		System.exit(0);
	}
}
