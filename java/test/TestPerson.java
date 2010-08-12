package test;

import junit.framework.JUnit4TestAdapter;
import static org.junit.Assert.*;
import org.junit.Test;
import uk.ac.sanger.arcturus.people.Person;

public class TestPerson {
    public static junit.framework.Test suite() {
        return new JUnit4TestAdapter(PersonTest.class);
    }

    @Test
    public void testEqual() {
        Person person1 = new Person("23");
        Person person2 = new Person("24");
        assertEquals(false, person1.equals(person2));
    }
}