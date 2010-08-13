package uk.ac.sanger.arcturus.repository;

public interface DirectoryNameConverter {
  public String convertMetaDirectoryToAbsolutePath(String organismName, String projectName, String metaDirectoryName);
  public String convertAbsolutePathToMetaDirectory(String organismName, String projectName, String absolutePath);
}
