import uk.ac.sanger.arcturus.*;
import uk.ac.sanger.arcturus.database.*;
import uk.ac.sanger.arcturus.data.*;

import java.io.*;
import java.util.*;
import javax.naming.Context;

public class TestTemplateManager {
    public static void main(String args[]) {
	System.out.println("TestTemplateManager");
	System.out.println("===================");
	System.out.println();

	String ldapURL = "ldap://ldap.internal.sanger.ac.uk/cn=jdbc,ou=arcturus,ou=projects,dc=sanger,dc=ac,dc=uk";

	String separator = "                    --------------------                    ";

	Properties props = new Properties();

	Properties env = System.getProperties();

	props.put(Context.INITIAL_CONTEXT_FACTORY, env.get(Context.INITIAL_CONTEXT_FACTORY));
	props.put(Context.PROVIDER_URL, ldapURL);

	String instance = null;
	String organism = null;
	String objectname = null;

	switch (args.length) {
	case 0:
	case 1:
	    System.out.println("Argument(s) missing: [instance] organism objectname");
	    System.exit(1);
	    break;

	case 2:
	    instance = "dev";
	    organism = args[0];
	    objectname = args[1];
	    break;

	default:
	    instance = args[0];
	    organism = args[1];
	    objectname = args[2];
	    break;
	}

	try {
	    System.out.println("Creating an ArcturusInstance for " + instance);
	    System.out.println();

	    ArcturusInstance ai = new ArcturusInstance(props, instance);

	    System.out.println("Creating an ArcturusDatabase for " + organism);
	    System.out.println();

	    ArcturusDatabase adb = ai.findArcturusDatabase(organism);

	    System.out.println("FInding a CloneManager");
	    System.out.println();

	    CloneManager cmgr = adb.getCloneManager();

	    System.out.println("Pre-loading all clones");
	    System.out.println();

	    cmgr.preloadAllClones();

	    System.out.println("Finding a LigationManager");
	    System.out.println();

	    LigationManager lmgr = adb.getLigationManager();

	    System.out.println("Pre-loading all ligations");
	    System.out.println();

	    lmgr.preloadAllLigations();

	    System.out.println("Finding a TemplateManager");
	    System.out.println();

	    TemplateManager tmgr = adb.getTemplateManager();

	    System.out.println("Pre-loading all templates");
	    System.out.println();

	    tmgr.preloadAllTemplates();

	    System.out.println("Looking up template " + objectname + " by name");
	    System.out.println();

	    Template template = tmgr.getTemplateByName(objectname);

	    if (template == null)
		System.out.println("*** FAILED ***");
	    else {
		System.out.println(template);
		System.out.println("    " + template.getLigation());
		System.out.println("        " + template.getLigation().getClone());
	    }

	    System.out.println();

	    System.out.println("Looking up template 6 by ID");
	    System.out.println();

	    template = tmgr.getTemplateByID(6);

	    if (template == null)
		System.out.println("*** FAILED ***");
	    else {
		System.out.println(template);
		System.out.println("    " + template.getLigation());
		System.out.println("        " + template.getLigation().getClone());
	    }
	}
	catch (Exception e) {
	    e.printStackTrace();
	    System.exit(1);
	}
    }
}
