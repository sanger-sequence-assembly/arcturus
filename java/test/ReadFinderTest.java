package test;

import org.junit.*;
import junit.framework.JUnit4TestAdapter;
import uk.ac.sanger.arcturus.readfinder.ReadFinder;
import uk.ac.sanger.arcturus.readfinder.ReadFinderEventListener;
import uk.ac.sanger.arcturus.jdbc.ArcturusDatabaseImpl;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import static org.mockito.Mockito.*;



public class ReadFinderTest {

    ReadFinder readFinder;
	ArcturusDatabaseImpl adb;
	ReadFinderEventListener readFinderEventListener;
    
    public static junit.framework.Test suite() {
        return new JUnit4TestAdapter(ReadFinderTest.class);
    }
    
    
    @Before
    public void setUp() throws ArcturusDatabaseException, java.sql.SQLException {
        adb = mock(ArcturusDatabaseImpl.class);
        readFinderEventListener = mock(ReadFinderEventListener.class);
        readFinder = new ReadFinder(adb);
    }

    @After
    public void tearDown() {
    }

    @Test
    public void testFindRead() throws ArcturusDatabaseException {
	    readFinder.findRead("AAA", false, readFinderEventListener);
	    verify(adb).getContigByID(1, 1);
	    verify(readFinderEventListener).readFinderUpdate(null);
        
    }
}