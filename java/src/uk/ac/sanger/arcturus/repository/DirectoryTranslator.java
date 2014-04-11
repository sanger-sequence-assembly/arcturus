// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.repository;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class DirectoryTranslator {
	private static final String METADIRECTORY_PATTERN = ":([\\w\\-]+):(.*)";
	
	private static final String ASSEMBLY_PREFIX = "ASSEMBLY";
	
	private static final String PROJECT_PREFIX = "PROJECT";
	
	private final Pattern pattern = Pattern.compile(METADIRECTORY_PATTERN);
	
	private RepositoryManager manager;
	
	public DirectoryTranslator(RepositoryManager manager) {
		this.manager = manager;
	}
	
	public String convertMetaDirectoryToAbsolutePath(String metaDirectory,
			String assemblyName, String projectName) throws RepositoryException {
		if (metaDirectory == null || metaDirectory.startsWith("/"))
			return metaDirectory;
		
		Matcher matcher = pattern.matcher(metaDirectory);
		
		boolean matches = matcher.matches();
		
		System.err.println("matches -> " + matches);
		
		if (!matches)
			return metaDirectory;
		
		String prefix = matcher.group(1);
		String suffix = matcher.group(2);
		
		System.err.println("prefix = \"" + prefix + "\", suffix = \"" + suffix + "\"");
		
		if (prefix.equalsIgnoreCase(ASSEMBLY_PREFIX) && assemblyName != null) {
			Repository r = manager.getRepository(assemblyName);
			
			if (r == null)
				r = manager.getRepository(assemblyName.toLowerCase());
			
			System.err.println("assembly-prefix: repository is " + r);
			
			if (r != null)
				return r.getPath() + suffix;
		}
		
		if (prefix.equalsIgnoreCase(PROJECT_PREFIX) && projectName != null) {
			Repository r = manager.getRepository(projectName);
			
			if (r == null)
				r = manager.getRepository(projectName.toLowerCase());
			
			System.err.println("project-prefix: repository is " + r);
			
			if (r != null)
				return r.getPath() + suffix;			
		}
		
		Repository r = manager.getRepository(prefix);
		
		if (r == null)
			r = manager.getRepository(prefix.toLowerCase());
		
		System.err.println("generic-case: repository is " + r);
		
		if (r != null)
			return r.getPath() + suffix;
		else
			return null;
	}
}
