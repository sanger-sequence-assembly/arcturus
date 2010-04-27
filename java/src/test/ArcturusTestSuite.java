package test;

import junit.framework.JUnit4TestAdapter;
import junit.framework.TestSuite;
import junit.framework.Test;

public class ArcturusTestSuite extends TestSuite {
	public static Test suite() {
         return new JUnit4TestAdapter(PersonTest.class);
	}
}
