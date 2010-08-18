package uk.ac.sanger.arcturus.repository;

import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public interface DirectoryNameConverter {
  public String convertMetaDirectoryToAbsolutePath (String organismName, String projectName, String metaDirectoryName)
                  throws ArcturusDatabaseException ;
  public String convertAbsolutePathToMetaDirectory(String organismName, String projectName, String absolutePath)
                 throws ArcturusDatabaseException ;
}
