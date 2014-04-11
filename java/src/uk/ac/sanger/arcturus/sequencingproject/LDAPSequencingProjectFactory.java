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

package uk.ac.sanger.arcturus.sequencingproject;

import java.util.Iterator;
import java.util.Properties;

import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import javax.sql.DataSource;

public class LDAPSequencingProjectFactory extends SequencingProjectFactory {
	protected final DirContext rootContext;
	protected final SearchControls controls;

	public LDAPSequencingProjectFactory(Properties props)
			throws NamingException {
		rootContext = new InitialDirContext(props);

		controls = new SearchControls();

		controls.setReturningObjFlag(true);
		controls.setSearchScope(SearchControls.SUBTREE_SCOPE);
		controls.setDerefLinkFlag(true);
	}

	public Iterator<SequencingProject> list(String instance, String path)
			throws NamingException {
		DirContext context = walkPath(instance, path);

		if (context == null)
			return null;
		else
			return new LDAPIterator(instance, path, context);
	}

	class LDAPIterator implements Iterator<SequencingProject> {
		private NamingEnumeration<SearchResult> ne;
		private String instance;
		private String path;

		public LDAPIterator(String instance, String path, DirContext context) throws NamingException {
			this.instance = instance;
			this.path = path;
			
			String filter = "(objectClass=javaNamingReference)";

			ne = context.search("", filter, controls);
		}

		public boolean hasNext() {
			try {
				return ne.hasMore();
			} catch (NamingException e) {
				return false;
			}
		}

		public SequencingProject next() {
			try {
				while (ne.hasMore()) {
					SearchResult res = ne.next();

					Object obj = res.getObject();

					if (obj instanceof DataSource)
						return createSequencingProject(instance, path, null, res);
				}
			} catch (NamingException e) {
				return null;
			}

			return null;
		}

		public void remove() {
			throw new UnsupportedOperationException();
		}
	}

	public SequencingProject lookup(String instance, String path, String name)
			throws NamingException {
		DirContext context = walkPath(instance, path);

		String filter = "(&(objectClass=javaNamingReference)(cn=" + name + "))";

		NamingEnumeration<SearchResult> ne = context.search("", filter,
				controls);

		while (ne.hasMore()) {
			SearchResult res = ne.next();

			Object obj = res.getObject();

			if (obj instanceof DataSource)
				return createSequencingProject(instance, path, name, res);
		}

		return null;
	}

	private DirContext walkPath(String instance, String path)
			throws NamingException {
		DirContext context = instance == null ? rootContext
				: (DirContext) rootContext.lookup("cn=" + instance);

		if (context == null)
			return null;

		if (path != null) {
			String[] pathparts = path.split("/");

			for (String part : pathparts) {
				context = (DirContext) context.lookup("cn=" + part);

				if (context == null)
					return null;
			}
		}

		return context;
	}

	private SequencingProject createSequencingProject(String instance,
			String path, String name, SearchResult res) throws NamingException {
		DataSource ds = (DataSource) res.getObject();
		
		String[] nameParts = parseNameParts(res.getName());
		
		int nameOffset = nameParts.length - 1;
		
		int pathOffset = 0;
		
		if (instance == null && pathOffset < nameOffset)
			instance = nameParts[pathOffset++];
		
		while (pathOffset < nameOffset) {
			path = (path == null) ? nameParts[pathOffset] : path + "/" + nameParts[pathOffset];
			pathOffset++;
		}
		
		if (name == null)
			name = nameParts[nameOffset];

		String description = null;

		Attributes attrs = res.getAttributes();

		Attribute attr = attrs.get("description");

		if (attr != null) {
			Object value = null;

			value = attr.get();

			if (value != null && value instanceof String)
				description = (String) value;
		}

		return new SequencingProject(instance, path, name, description, ds);
	}
	
	private String[] parseNameParts(String name) {
		if (name == null)
			return null;
		
		String[] words = name.split(",");
		
		String[] parts = new String[words.length];
		
		int j = words.length - 1;
		
		for (int i = 0; i < words.length; i++) {
			String[] keyvalue = words[i].split("=");
			
			parts[j--] = keyvalue[1];
		}
		
		return parts;
	}
}
