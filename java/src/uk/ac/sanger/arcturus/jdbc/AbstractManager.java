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

package uk.ac.sanger.arcturus.jdbc;

import java.lang.management.ManagementFactory;

import java.sql.SQLException;

import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;

import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public abstract class AbstractManager extends ArcturusDatabaseClient implements AbstractManagerMBean {
	protected boolean cacheing = true;
	protected ObjectName mbeanName = null;
	
	private static int instanceCounter = 0;
	
	protected AbstractManager(ArcturusDatabase adb) {
		super(adb);
		
		if (adb instanceof ArcturusDatabaseImpl)
			((ArcturusDatabaseImpl)adb).addManager(this);
		
		registerAsMBean();
	}
	
	protected void registerAsMBean() {
		try {
			mbeanName = new ObjectName("AbstractManager:" + getName());
		} catch (MalformedObjectNameException e) {
			Arcturus.logWarning("Failed to create ObjectName", e);
		}
		
		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
		
		try {
			mbs.registerMBean(this, mbeanName);
		} catch (Exception e) {
			Arcturus.logWarning("Failed to register connection pool as MBean", e);
		}
	}
	
	private String getName() {
		int serial = instanceCounter++;
		
		String[] classNameParts = getClass().getName().split("\\.");
		
		String className = classNameParts[classNameParts.length - 1];
		
		return "type=" + className + ",serial=" + serial;
	}
	
	public void close() throws SQLException {
		unregisterAsMBean();
		
		super.close();
	}
		
	protected void unregisterAsMBean() {
		if (mbeanName != null) {
			MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
			
			try {
				mbs.unregisterMBean(mbeanName);
				mbeanName = null;
			} catch (Exception e) {
				Arcturus.logWarning("Failed to unregister connection pool as MBean", e);
			}
		}
	}
	
	public abstract String getCacheStatistics();

	public void setCacheing(boolean cacheing) {
		this.cacheing = cacheing;
	}

	public boolean isCacheing() {
		return cacheing;
	}

	public abstract void clearCache();
	
	public abstract void preload() throws ArcturusDatabaseException;
}
