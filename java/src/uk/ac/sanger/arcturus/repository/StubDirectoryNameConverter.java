package uk.ac.sanger.arcturus.repository;

/**
  * This class implement a stub for the DirectoryNameConverter interface.
  * it doesn't do anything except return the directory name without conversion.
  */

public class StubDirectoryNameConverter implements DirectoryNameConverter {

  public String convertMetaDirectoryToAbsolutePath(String organismName, String projectName, String metaDirectoryName) {
    return metaDirectoryName;
  };

  public String convertAbsolutePathToMetaDirectory(String organismName, String projectName, String absolutePath) {
    return absolutePath;
  }
}
