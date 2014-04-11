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

package test.jdbc;


import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestTemplateManager extends Base {
	@Test
	public void lookupTemplateByName() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String templateName = "NO-SUCH-LIGATION";
		
		Template template = adb.getTemplateByName(templateName);
		
		assertNull(template);
	}

	@Test
	public void findOrCreateTemplate() throws ArcturusDatabaseException {
		ArcturusDatabase adb = getArcturusDatabase();
		
		String ligationName = "MyLigation";
		
		Ligation ligation = new Ligation(ligationName);
		
		String templateName = "MyTemplate";
		
		Template template = new Template(templateName, Template.UNKNOWN, ligation, null);
		
		Template newTemplate = adb.findOrCreateTemplate(template);
		
		assertNotNull("findOrCreateTemplate returned null", newTemplate);
		
		assertEquals("findOrCreateTemplate yielded unequal templates", template, newTemplate);
	}

}
