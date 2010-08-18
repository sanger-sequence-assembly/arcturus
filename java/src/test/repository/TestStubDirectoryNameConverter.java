package test.repository;

import static org.junit.Assert.*;
import org.junit.Test;
import uk.ac.sanger.arcturus.repository.*;

public class TestStubDirectoryNameConverter {
  final private DirectoryNameConverter directoryNameConverter = new StubDirectoryNameConverter();

  @Test
    public void testConvertAbsolutePathToMetaDirectory() throws Exception {
      final String directory = "path";

      assertEquals(directory, directoryNameConverter.convertAbsolutePathToMetaDirectory("", "", directory));
    }

  @Test
    public void testConvertMetaDirectoryToAbsolutePath() throws Exception {
      final String metadir = "path";
      assertEquals(metadir, directoryNameConverter.convertMetaDirectoryToAbsolutePath("", "", metadir));
    }

}
