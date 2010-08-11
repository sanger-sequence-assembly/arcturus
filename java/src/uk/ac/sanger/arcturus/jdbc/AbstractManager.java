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
