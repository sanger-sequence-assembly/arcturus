package test.repository;

import static org.junit.Assert.*;
import org.junit.*;
import org.junit.Test;
import uk.ac.sanger.arcturus.jdbc.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;
import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.repository.*;

public class TestProjectManager {
  final static String INSTANCE = System.getProperty("test.repository.instance");
  final static String ORGANISM = System.getProperty("test.repository.organism");
  static private ArcturusDatabase adb;
  static private ProjectManager dryPm; // use to get the name without conversion

  @BeforeClass
    public static void setUpBeforeClass() throws Exception {
      adb = getDatabase(INSTANCE, ORGANISM);

      if (adb == null)
        throw new Exception("The ArcturusDatabase object was null");

      dryPm = new ProjectManager(adb);
      assertNotNull(dryPm);
      //dryPm.setDirectoryNameConverter(null);//(DirectoryNameConverter) new StubDirectoryNameConverter());
      dryPm.xx(null);//(DirectoryNameConverter) new StubDirectoryNameConverter());
    }

  @AfterClass
    public static void tearDownAfterClass() throws Exception {
      if (adb != null)
        adb.closeConnectionPool();
    }

  private static ArcturusDatabase  getDatabase(String instance, String organism) {
    try {
    ArcturusInstance ai = ArcturusInstance.getInstance(instance);
    assertNotNull(ai);

    ArcturusDatabase adb = ai.findArcturusDatabase(organism);
    return adb;

    } catch (Exception e) {
    // we don't do anything at the moment.
    }

    return null;
  }

 @Test
    public void testProjectManager() {
      assertNotNull(adb);
    }

  @Test
    public void getProject() throws Exception {
      checkProjectDirectory("zFD381H22", "/nfs/repository", "#PROJECT#/tmp");
    }


  public void checkProjectDirectory (String projectName , String expectedDirectory, String expectedRaw) throws Exception {
      Project project = adb.getProjectByName(null,projectName);
      assertNotNull(project);

      String directory = project.getDirectory();
//      assertEquals(expectedDirectory, directory);

      Project dryProject = dryPm.getProjectByName(null, projectName);
      String rawDirectory = dryProject.getDirectory();
      assertEquals(expectedRaw, rawDirectory);

  }


}
