import uk.ac.sanger.arcturus.data.*;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;

public class TestCoreClasses {
    public static void main(String args[]) {
	ArcturusDatabase adb = null;

	Read read = new Read("bav10101a01.p1k", 1, adb);

	Template template = new Template("bav10101a01", 1, adb);

	read.setTemplate(template);

	Ligation ligation = new Ligation("bav10101", 1, adb);

	template.setLigation(ligation);

	ligation.setInsertSizeRange(1500, 3000);

	Clone clone = new Clone("bav1", 1, adb);

	ligation.setClone(clone);

	System.out.println("Read:\n" + read);

	System.out.println("Template:\n" + template);

	System.out.println("Ligation:\n" + ligation);

	System.out.println("Clone:\n" + clone);
    }
}
