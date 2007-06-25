package uk.ac.sanger.arcturus.projectchange;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;

import uk.ac.sanger.arcturus.data.Project;

public class ProjectChangeEventNotifier {
	protected HashMap<Project, Set<ProjectChangeEventListener>> listenerMap =
		new HashMap<Project, Set<ProjectChangeEventListener>>();
	
	public static final Project ANY_PROJECT = new Project();

	public synchronized void addProjectChangeEventListener(Project project,
			ProjectChangeEventListener listener) {
		Set<ProjectChangeEventListener> listeners = listenerMap.get(project);

		if (listeners == null) {
			listeners = new HashSet<ProjectChangeEventListener>();
			listenerMap.put(project, listeners);
		}
		
		listeners.add(listener);
	}
	
	public synchronized void addProjectChangeEventListener(ProjectChangeEventListener listener) {
		addProjectChangeEventListener(ANY_PROJECT, listener);
	}
	
	public synchronized void removeProjectChangeEventListener(ProjectChangeEventListener listener) {
		for (Set<ProjectChangeEventListener> listeners : listenerMap.values()) {
			listeners.remove(listener);
		}
	}
	
	public synchronized void notifyProjectChangeEventListeners(ProjectChangeEvent event) {
		Project project = event.getProject();
		
		if (project == null)
			return;
		
		Set<ProjectChangeEventListener> listeners = listenerMap.get(project);
		
		if (listeners != null && !listeners.isEmpty()) {
			for (ProjectChangeEventListener listener : listeners)
				listener.projectChanged(event);
		}
		
		listeners = listenerMap.get(ANY_PROJECT);
		
		if (listeners != null && !listeners.isEmpty()) {
			for (ProjectChangeEventListener listener : listeners)
				listener.projectChanged(event);
		}		
	}
}
