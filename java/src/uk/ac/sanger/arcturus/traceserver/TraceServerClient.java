package uk.ac.sanger.arcturus.traceserver;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Date;
import java.util.List;
import java.util.Vector;

public class TraceServerClient {
	protected final static String DEFAULT_BASE_URL = "http://trace3slb.internal.sanger.ac.uk:8888/get_exp";
	
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
		List<String> avLines = new Vector<String>();;
		List<String> sqLines = null;
		
		while ((line = br.readLine()) != null) {
			String[] words = line.split("\\s+", 2);
			
			if (words[0].equalsIgnoreCase("AV"))
				avLines.add(words[1]);
			else {
				System.out.println("Record type: " + words[0]);
			
				if (words.length > 1)
					System.out.println("Record value: \"" + words[1] + "\"");
			}
			
			if (words[0].equalsIgnoreCase("SQ"))
				sqLines = parseSequence(br);		
		}
		
		if (sqLines != null && !sqLines.isEmpty()) {
			System.out.println("Read " + sqLines.size() + " lines of SQ data:\n");
			
			for (String l : sqLines) {
				System.out.println("\"" + l + "\"");
			}
			
			System.out.println();
		}
		
		if (!avLines.isEmpty()) {
			System.out.println("read " + avLines.size() + " lines of AV data:\n");
			
			for (String l : avLines) {
				System.out.println("\"" + l + "\"");
			}
			
			System.out.println();
		}
	}
	
	private List<String> parseSequence(BufferedReader br) throws IOException {
		List<String> lines = new Vector<String>();
		
		String line;
		
		while ((line = br.readLine()) != null) {
			if (line.startsWith("//"))
				break;
			else
				lines.add(line);
		}		
		
		return lines;
	}
	
	public static void main(String[] args) {
		String baseURL = args.length > 0 ? args[0] : DEFAULT_BASE_URL;
		
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
	}
}
