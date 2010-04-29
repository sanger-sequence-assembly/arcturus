package uk.ac.sanger.arcturus.sequencingproject;

import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.Iterator;
import java.util.Properties;

public abstract class SequencingProjectFactory {
	public static final String FACTORY_CLASS_NAME = "uk.ac.sanger.arcturus.sequencingproject.factoryclassname";
	
	public abstract SequencingProject lookup(String instance, String path, String name) throws Exception ;
	
	public abstract Iterator<SequencingProject> list(String instance, String path) throws Exception;
	
	@SuppressWarnings("unchecked")
	public static SequencingProjectFactory createFactory(Properties props)
		throws ClassNotFoundException, SecurityException, NoSuchMethodException,
			IllegalArgumentException, InstantiationException, IllegalAccessException, InvocationTargetException {
		String className = props.getProperty(FACTORY_CLASS_NAME);
		
		if (className == null)
			throw new IllegalArgumentException("No factory class name was specified in the properties");
		
		Class<? extends SequencingProjectFactory> factoryClass = (Class<? extends SequencingProjectFactory>) Class.forName(className);
		
		Constructor<SequencingProjectFactory> constructor = (Constructor<SequencingProjectFactory>) factoryClass.getConstructor(Properties.class);
		
		return constructor.newInstance(props);
	}
}
