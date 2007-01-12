package uk.ac.sanger.arcturus;

import java.io.IOException;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.File;
import java.util.Properties;

public class Arcturus {
	protected static final String PROJECT_PROPERTIES_FILE = ".arcturus.props";
	
	protected static Properties arcturusProps = new Properties(System.getProperties());

	static {
		// Load the properties that are embedded in the JAR file
		
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
		
		// Find the project-specific properties, if they exist, by walking up the
		// directory tree from the application's current working directory, looking
		// for a file named .arcturus.props
		
		String cwd = System.getProperty("user.dir");
		
		File dir = new File(cwd);
		
		boolean found = false;
		
		while (dir != null && !found) {
			File file = new File(dir, PROJECT_PROPERTIES_FILE);
			
			if (file.exists() && file.canRead()) {
				try {
					FileInputStream fis = new FileInputStream(file);
					arcturusProps = new Properties(arcturusProps);
					arcturusProps.load(fis);
					fis.close();
					found = true;
				}
				catch (IOException ioe) {
					ioe.printStackTrace();
				}
			} else
				dir = dir.getParentFile();
		}
	}
	
	public static Properties getProperties() {
		return arcturusProps;
	}
	
	public static String getProperty(String key) {
		return arcturusProps.getProperty(key);
	}
	
	public static String getDefaultInstance() {
		String instance = getProperty("arcturus.instance");
		
		if (instance != null)
			return instance;
		else
			return getProperty("arcturus.default.instance");
	}
}
