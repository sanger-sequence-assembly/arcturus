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
	
	public synchronized void notifyProjectChangeEventListeners(ProjectChangeEvent event,
			Class listenerClass) {
		Project project = event.getProject();
		
		if (project == null)
			return;
		
		Set<ProjectChangeEventListener> listeners = listenerMap.get(project);
		
		if (listeners != null && !listeners.isEmpty()) {
			for (ProjectChangeEventListener listener : listeners) {
				if (listenerClass == null || listenerClass.isInstance(listener))
					listener.projectChanged(event);			
			}
		}
		
		listeners = listenerMap.get(ANY_PROJECT);
		
		if (listeners != null && !listeners.isEmpty()) {
			for (ProjectChangeEventListener listener : listeners)
				if (listenerClass == null || listenerClass.isInstance(listener))
					listener.projectChanged(event);
		}		
	}
}
