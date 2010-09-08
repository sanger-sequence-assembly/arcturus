package uk.ac.sanger.arcturus.repository;

import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.Properties;

public class RepositoryManagerFactory {
	public static final String MANAGER_CLASS_NAME = "uk.ac.sanger.arcturus.repository.managerclassname";
	
	@SuppressWarnings("unchecked")
	public static RepositoryManager createRepositoryManager(Properties props)
		throws ClassNotFoundException, SecurityException, NoSuchMethodException,
			IllegalArgumentException, InstantiationException, IllegalAccessException,
			InvocationTargetException {
		String className = props.getProperty(MANAGER_CLASS_NAME);
		
		if (className == null)
			throw new IllegalArgumentException("No factory class name was specified in the properties");
		
		Class<? extends RepositoryManager> factoryClass = (Class<? extends RepositoryManager>) Class.forName(className);
		
		Constructor<RepositoryManager> constructor = (Constructor<RepositoryManager>) factoryClass.getConstructor(Properties.class);
		
		return constructor.newInstance(props);
	}
}
