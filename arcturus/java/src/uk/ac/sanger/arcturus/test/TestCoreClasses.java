import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class TestCoreClasses {
    public static void main(String args[]) {
	ArcturusDatabase adb = null;

	Clone clone = new Clone("bav1", 1, adb);

	Ligation ligation = new Ligation("bav10101", 1, clone, 1500, 3000, adb);

	Template template = new Template("bav10101a01", 1, ligation, adb);

	Read read = new Read("bav10101a01.p1k", 1, template, new java.sql.Date(System.currentTimeMillis()),
			     Read.FORWARD, Read.UNIVERSAL_PRIMER, Read.DYE_TERMINATOR, adb);

	System.out.println("Read:\n" + read);

	System.out.println("Template:\n" + template);

	System.out.println("Ligation:\n" + ligation);

	System.out.println("Clone:\n" + clone);
    }
}
