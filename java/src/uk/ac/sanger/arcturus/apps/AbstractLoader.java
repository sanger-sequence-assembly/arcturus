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

package uk.ac.sanger.arcturus.apps;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.traceserver.TraceServerClient;
import uk.ac.sanger.arcturus.utils.ReadNameFilter;
import uk.ac.sanger.arcturus.utils.RegexCapillaryReadNameFilter;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.samtools.BAMReadLoader;

public abstract class AbstractLoader {
	protected static final String REGEX_PROPERTY = "readnamefilter.regex";
	protected static final String TRACE_SERVER_PROPERTY = "traceserver.baseURL";
	
	protected static BAMReadLoader createBAMReadLoader(ArcturusDatabase adb) throws ArcturusDatabaseException {	
		String traceServerURL = Arcturus.getProperty(TRACE_SERVER_PROPERTY);
		
		TraceServerClient traceServerClient = traceServerURL == null ?
				null : new TraceServerClient(traceServerURL);
		
		String regex = Arcturus.getProperty(REGEX_PROPERTY);
		
		ReadNameFilter readNameFilter = null;
		
		if (regex != null)
			readNameFilter = new RegexCapillaryReadNameFilter(regex);

		return new BAMReadLoader(adb, traceServerClient, readNameFilter);
	}
}
