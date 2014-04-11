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

package uk.ac.sanger.arcturus.utils;

import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

/**
 * 
 * @author adh
 *
 * RegexCapillaryReadNameFilter is a read name filter which identifies
 * reads which are likely to be capillary reads.  It uses a regular expression.
 */

public class RegexCapillaryReadNameFilter implements ReadNameFilter {
	private static final String REGEX_PROPERTY = "readnamefilter.regex";
	
	private Pattern pattern;
	
	public RegexCapillaryReadNameFilter(String regex) throws ArcturusDatabaseException {
		try {
			pattern = Pattern.compile(regex);
		}
		catch (PatternSyntaxException e) {
			throw new ArcturusDatabaseException(e, "The " + REGEX_PROPERTY + " property string is invalid");
		}
	}
	
	public boolean accept(String filename) {
		Matcher m = pattern.matcher(filename);
		return m.find();
	}

	public static void main(String[] args) {
		RegexCapillaryReadNameFilter filter = null;
		
		String regex = Arcturus.getProperty(REGEX_PROPERTY);
		
		if (regex == null) {
			System.err.println("Could not find a property with the key " +
				REGEX_PROPERTY + " in the arcturus.props file");
			System.exit(1);
		}
		
		System.err.println("Regex pattern is " + regex);
		
		try {
			filter = new RegexCapillaryReadNameFilter(regex);
		} catch (ArcturusDatabaseException e) {
			e.printStackTrace();
			System.exit(1);
		}
		
		for (String name : args) {
			boolean ok = filter.accept(name);
			System.out.println(name + " --> " + ok);
		}
		
		System.exit(0);
	}
}
