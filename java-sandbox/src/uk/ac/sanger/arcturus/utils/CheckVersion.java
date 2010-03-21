package uk.ac.sanger.arcturus.utils;

import java.util.*;

public class CheckVersion {
	public static void main(String[] args) {
		int major = args.length > 0 ? Integer.parseInt(args[0]) : 1;
		int minor = args.length > 1 ? Integer.parseInt(args[1]) : 6;

		if (!CheckVersion.require(major, minor))
			throw new RuntimeException("VM version is " 
					+ System.getProperties().getProperty("java.version")
					+ " but this software requires at least " + major + "."
					+ minor);

		System.exit(0);
	}

	public static boolean require(int major, int minor) {
		Properties props = System.getProperties();

		String java_version = (String) props.get("java.version");

		String words[] = java_version.split("\\.");

		int myMajor = words.length > 0 ? Integer.parseInt(words[0]) : 0;
		int myMinor = words.length > 1 ? Integer.parseInt(words[1]) : 0;

		return (myMajor > major || (myMajor == major && myMinor >= minor));
	}
}
