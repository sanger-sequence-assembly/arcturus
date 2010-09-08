package uk.ac.sanger.arcturus.repository;

public interface RepositoryManager {
	public Repository getRepository(String name) throws RepositoryException;
	
	public boolean updateRepository(Repository repository) throws RepositoryException;
	
	public void close() throws RepositoryException;
}
