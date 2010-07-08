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
