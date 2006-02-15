import java.io.*;
import javax.naming.*;

import uk.ac.sanger.arcturus.people.*;

public class TestPeopleManager {
    public static void main(String[] args) {
	try {
	    PeopleManager manager = PeopleManager.getInstance();

	    for (int i = 0; i < args.length; i++) {
		String uid = args[i];

		Person person = manager.findPerson(uid);

		System.out.println(person == null ?
				   uid + " NOT FOUND" :
				   person.toString());
	    }
	}
	catch (NamingException ne) {
	    ne.printStackTrace();
	    System.exit(1);
	}
    }
}
