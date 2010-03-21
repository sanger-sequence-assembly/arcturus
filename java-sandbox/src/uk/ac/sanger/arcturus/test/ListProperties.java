package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.Arcturus;
import java.util.Properties;
import java.util.Arrays;
import java.io.PrintStream;

public class ListProperties {
	public static void main(String args[]) {
		Properties props = Arcturus.getProperties();
		listProperties(props, System.out, "Arcturus global properties");
	}

	private static void listProperties(Properties props, PrintStream ps, String title) {
		ps.println(title);
		ps.println();

		Object[] keys = props.keySet().toArray();

		Arrays.sort(keys);

		for (int i = 0; i < keys.length; i++)
			ps.println(keys[i] + "=" + props.get(keys[i]));

		ps.println();
	}
}
