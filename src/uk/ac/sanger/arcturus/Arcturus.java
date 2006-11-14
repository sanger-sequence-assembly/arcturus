package uk.ac.sanger.arcturus;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import javax.naming.NamingException;

public class Arcturus {
	protected static Properties arcturusProps = new Properties(System.getProperties());

	static {
		InputStream is = Arcturus.class.getResourceAsStream("/resources/arcturus.props");
		
		if (is != null) {
			try {
				arcturusProps.load(is);
				is.close();
			}
			catch (IOException ioe) {
				ioe.printStackTrace();
			}
		} else
			System.err.println("Unable to open resource /resources/arcturus.props as stream");
	}
	
	public static Properties getProperties() {
		return arcturusProps;
	}
	
	public static String getProperty(String key) {
		return arcturusProps.getProperty(key);
	}

	public static ArcturusInstance getArcturusInstance(String instance) throws NamingException {
		return new ArcturusInstance(arcturusProps, instance);
	}
}
