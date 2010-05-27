package test.mapping;

import static org.junit.Assert.*;

import org.junit.Test;

import java.util.Arrays;

import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.data.GenericMapping.Direction;

public class TestMappingOperation {
	
	@Test
	public void testInverseForward() {
		Alignment[] af = stub1();
		GenericMapping original = new GenericMapping(af);
		GenericMapping inverse = MappingOperation.inverse(original);
	    assertFalse(original.equals(inverse));
	    GenericMapping restore = MappingOperation.inverse(inverse);
		assertFalse(original==restore);
	    assertTrue(original.equals(restore));
	}
	
	@Test
	public void testInverseReverse() {
		Alignment[] af = stub2();
		GenericMapping original = new GenericMapping(af);
		GenericMapping inverse = MappingOperation.inverse(original);
	    assertFalse(original.equals(inverse));
	    GenericMapping restore = MappingOperation.inverse(inverse);
	    assertTrue(original.equals(restore));
	}

//	@Test
	public void testMultiplyForward() {
		GenericMapping original = new GenericMapping(stub1());
//list(original.getAlignments());
		GenericMapping inverse = MappingOperation.inverse(original);
//list(inverse.getAlignments());
	    assertFalse(original.equals(inverse));
	    GenericMapping unity = MappingOperation.multiply(original,inverse);
//list(unity.getAlignments());
        GenericMapping restore = MappingOperation.multiply(unity,original);
//list(restore.getAlignments());  
	    assertTrue(original.equals(restore));
	}

	@Test
	public void testMultiplyReverse() {
		GenericMapping original = new GenericMapping(stub2());
list(original.getAlignments(),"original");
		GenericMapping inverse = MappingOperation.inverse(original);
list(inverse.getAlignments(),"inverse");
	    assertFalse(original.equals(inverse));
	    GenericMapping unity = MappingOperation.multiply(original,inverse);
list(unity.getAlignments(),"unity");
        GenericMapping restore = MappingOperation.multiply(unity,original);
list(restore.getAlignments(),"restore");  
	    assertTrue(original.equals(restore));
	}
	
	// Stubs
	
	private Alignment[] stub1() {
	    Alignment[] af = new Alignment[6];
	    af[0] = new Alignment( 737,1414, 124, 801);
	    af[1] = new Alignment(1417,1430, 802, 815);
	    af[2] = new Alignment(1432,1440, 816, 824);
	    af[3] = new Alignment(1442,1448, 825, 831);
	    af[4] = new Alignment(1450,1455, 832, 837);
	    af[5] = new Alignment(1457,1464, 838, 845);
		Arrays.sort(af);
	    return af;
	}
	
	private Alignment[] stub2() {
	    Alignment[] af = new Alignment[5];
	    af[0] = new Alignment( 737,1414, 802, 125);
	    af[1] = new Alignment(1417,1430, 124, 111);
	    af[2] = new Alignment(1432,1440, 110, 102);
	    af[3] = new Alignment(1442,1448, 101,  95);
	    af[4] = new Alignment(1450,1455,  94,  89);
		Arrays.sort(af);
	    return af;
	}
	
	private void list (Alignment[] af,String text) {
		System.out.println(text);
		list(af);
	}
    private void list (Alignment[] af) {
	    for (int i=0 ; i < af.length ; i++) {
	    	System.out.println("nr " + i + " " + af[i].toString());
	    }
	}

}
