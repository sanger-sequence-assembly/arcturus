package test.jdbc;


import static org.junit.Assert.*;

import org.junit.Test;

import uk.ac.sanger.arcturus.data.Ligation;
import uk.ac.sanger.arcturus.data.Template;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

public class TestTemplateManager extends TestBase {
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
		
		Template template = adb.findOrCreateTemplate(templateName, ligation);
		
		assertNotNull(template);
	}

}
