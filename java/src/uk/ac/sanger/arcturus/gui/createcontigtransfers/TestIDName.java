package uk.ac.sanger.arcturus.gui.createcontigtransfers;

public class TestIDName {

	
	static boolean isName(String contigString) {

		if (contigString.matches("^\\d{5}\\.\\d+$")) {
			return true;			
		} 
		else {	
			return false;
		}
	}


	static boolean isId(String contigString) {

		if (contigString.matches("^\\d+$")){
			return true;			
		} 
		else {	
			return false;
		}
	}
	
	/**
	 * @param args
	 */
	public static void main(String[] args) {

		String contigname = "00001.7180000827104";
		String contig_id = "11977";
		String rubbish = "0.07KateIsASecretAgent";
		
		System.out.println("Test 1:");
		if (isName(contigname)) {
			System.out.println(contigname + " is a contig name");				
		} 
		else if (isId(contigname)) {	
			System.out.println(contigname + " is a contig id");	
		}
		else {
			System.out.println(contigname + " is neither a contig id nor a contig name");	
		}
		
		System.out.println("Test 2:");
		if (isName(contig_id)) {
			System.out.println(contig_id + " is a contig name");				
		} 
		else if (isId(contig_id)) {	
			System.out.println(contig_id + " is a contig id");	
		}
		else {
			System.out.println(contig_id + " is neither a contig id nor a contig name");	
		}
		
		System.out.println("Test 3:");
		if (isName(rubbish)) {
			System.out.println(rubbish + " is a contig name");				
		} 
		else if (isId(rubbish)) {	
			System.out.println(rubbish + " is a contig id");	
		}
		else {
			System.out.println(rubbish + " is neither a contig id nor a contig name");	
		}
	}
}
