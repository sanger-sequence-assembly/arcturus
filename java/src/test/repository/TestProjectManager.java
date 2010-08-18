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
import uk.ac.sanger.arcturus.people.Person;

public class TestProjectManager {
  final static String INSTANCE = System.getProperty("test.repository.instance");
  final static String ORGANISM = System.getProperty("test.repository.organism");
  static private ArcturusDatabase adb;
  static private ProjectManager dryPm; // use to get the name without conversion
  static private Assembly assembly;
  static private Person owner;

  @BeforeClass
    public static void setUpBeforeClass() throws Exception {
      adb = getDatabase(INSTANCE, ORGANISM);

      if (adb == null)
        throw new Exception("The ArcturusDatabase object was null");

      // we setup a dry ProjectManager which doesn't do directoryConvertion
      dryPm = new ProjectManager(adb);
      assertNotNull(dryPm);
      dryPm.setDirectoryNameConverter(new StubDirectoryNameConverter());

      assembly = adb.getAssemblyByID(1);
      assertNotNull(assembly);

      owner = adb.findMe();
      assertNotNull(owner);


    }

  @AfterClass
    public static void tearDownAfterClass() throws Exception {
      if (adb != null)
        adb.close();
    }

  @Before
    public void startTransaction() throws Exception {
      adb.getDefaultConnection().setAutoCommit(false);
    }

  @After
    public void rollbackTransaction () throws Exception {
      adb.getDefaultConnection().rollback();
      adb.getDefaultConnection().setAutoCommit(true);
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
    public void checkProjects() throws Exception {
      checkProjectDirectory("zFD381H22", "/nfs/users/nfs_m/mb14/base/tmp/repository/d0014/zFD381H22/tmp", ":PROJECT:/tmp");
      checkProjectDirectory("zFD380D9", "/nfs/users/nfs_m/mb14/base/tmp/repository/d0014/zFD381H22/tmp2", "{zFD381H22}/tmp2");
    }

  // each check need to be in a different test ,to roll back the newly created project
  @Test
    public void newWithProject() throws Exception {
      checkNewProject("zFD380G20", "/nfs/users/nfs_m/mb14/base/tmp/repository/d0002/zFD380G20/test1", ":PROJECT:test1");
    }

  @Test
    public void newWithSchema() throws Exception {
      checkNewProject("zFD380G20", "/nfs/users/nfs_m/mb14/base/tmp/repository/d0050/SHISTO/test2", ":SCHEMA:test2");
    }
  @Test
    public void newBare() throws Exception {
      checkNewProject("zFD380G20", "/nfs/users/nfs_m/mb14/base/bare", "bare");
    }

  public void checkProjectDirectory (String projectName , String expectedDirectory, String expectedRaw) throws Exception {
      Project project = adb.getProjectByName(null,projectName);
      assertNotNull(project);

      String directory = project.getDirectory();
      assertEquals(expectedDirectory, directory);

      Project dryProject = dryPm.getProjectByName(null, projectName);
      String rawDirectory = dryProject.getDirectory();
      assertEquals(expectedRaw, rawDirectory);

  }

  public void checkNewProject(String projectName, String directory, String expectedMetadir) throws Exception {
    adb.createNewProject(assembly, projectName, owner,  directory);

      // check the project is loaded properly - so final directory is the one set at creation
      Project project = adb.getProjectByName(assembly, projectName);
      assertNotNull(project);
      assertEquals(directory, project.getDirectory());

      // check what is stored in the database using the dryPM
      Project dryProject = dryPm.getProjectByName(assembly, projectName);
      assertNotNull(dryProject);
      assertEquals(expectedMetadir, dryProject.getDirectory());

  }


}
