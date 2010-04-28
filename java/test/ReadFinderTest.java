package test;

import org.junit.*;
import junit.framework.JUnit4TestAdapter;
import uk.ac.sanger.arcturus.readfinder.ReadFinder;
import uk.ac.sanger.arcturus.readfinder.ReadFinderEventListener;
import uk.ac.sanger.arcturus.jdbc.ArcturusDatabaseImpl;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import static org.mockito.Mockito.*;
import org.mockito.*;


public class ReadFinderTest {

	@Mock private ArcturusDatabaseImpl adb;
	@Mock private ReadFinderEventListener readFinderEventListener;
	
	// Pull in the JDBC things
	@Mock private java.sql.Connection conn;
    @Mock private java.sql.PreparedStatement stmt;
    @Mock private java.sql.ResultSet rs;

    private ReadFinder readFinder;
    
    public static junit.framework.Test suite() {
        return new JUnit4TestAdapter(ReadFinderTest.class);
    }
    
    
    @Before
    public void setUp() throws ArcturusDatabaseException, java.sql.SQLException {
        MockitoAnnotations.initMocks(this);
        
        when(adb.getPooledConnection(anyObject())).thenReturn(conn);
        when(conn.prepareStatement(anyString())).thenReturn(stmt);
        when(stmt.executeQuery()).thenReturn(rs);
        readFinder = new ReadFinder(adb);
    }

    @After
    public void tearDown() {
    }

    @Test
    public void testFindReadNoReads() throws ArcturusDatabaseException, java.sql.SQLException {
        when(rs.next()).thenReturn(false);
	    readFinder.findRead("AAA", false, readFinderEventListener);
    }
}