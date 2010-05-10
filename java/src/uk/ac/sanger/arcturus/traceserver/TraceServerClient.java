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

	public void fetchRead(String readname) {
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
				
				parseRead(is);

				is.close();
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	private void parseRead(InputStream is) throws IOException {
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
		
		createRead(map);
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
	
	private void createRead(Map<String, String> map) {
		String readName = map.get(ExperimentFile.KEY_READ_NAME);
		
		System.err.println("PROCESSING " + readName);
		
		String cloneName = map.get(ExperimentFile.KEY_CLONE_NAME);
		
		Clone clone = (cloneName != null) ? new Clone(cloneName) : null;
		
		if (clone != null)
			System.err.println("Got clone " + clone);
		
		String ligationName = map.get(ExperimentFile.KEY_LIGATION_NAME);
		
		Ligation ligation = (ligationName != null) ? new Ligation(ligationName) : null;
		
		if (ligation != null && clone != null)
			ligation.setClone(clone);
		
		if (ligation != null)
			System.err.println("Got ligation " + ligation);
		
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
		
		if (template != null)
			System.err.println("Got template " + template);
		
		Read read = new Read(readName);
		
		byte[] dna = parseDNA(map.get(ExperimentFile.KEY_SEQUENCE));
		
		byte[] quality = parseQuality(map.get(ExperimentFile.KEY_ACCURACY_VALUES));
		
		Sequence sequence = new Sequence(0, read, dna, quality, 0);
		
		
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
		
		BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

		while (true) {
			try {
				System.out.print("> ");
				
				String line = br.readLine();
			
				if (line == null || line.length() == 0 || line.equalsIgnoreCase("quit"))
					break;
				
				client.fetchRead(line);
			}
			catch (IOException ioe) {
				ioe.printStackTrace();
			}
		}
		
		System.exit(0);
	}
}
