// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

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
