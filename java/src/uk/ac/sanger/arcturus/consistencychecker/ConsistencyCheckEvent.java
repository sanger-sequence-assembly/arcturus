package uk.ac.sanger.arcturus.consistencychecker;

public class ConsistencyCheckEvent {
	public enum Type { START_TEST_RUN, START_TEST, TEST_PASSED, TEST_FAILED, INCONSISTENCY, ALL_TESTS_PASSED,
		SOME_TESTS_FAILED, EXCEPTION, UNKNOWN
	}
/* START_TEST_RUN
 The set of tests is about to be run.
START_TEST
 A particular test is about to be run.
TEST_PASSED
 A particular test has passed.
TEST_FAILED
 A particular test has failed.
INCONSISTENCY
 Reports a specific inconsistency i.e. a row from the result set
 of a particular test.
EXCEPTION
 An exception was thrown during a particular test, and all
 subsequent tests have been abandoned.
ALL_TESTS_PASSED
 The set of tests has been run, and all tests passed.
SOME_TESTS_FAILED
 The set of tests has been run, but some tests failed.
The last three events are terminal events i.e. they signal to the listener that no further events will follow. 
*/
	
	private CheckConsistency source;
	private String message;
	private Type type = Type.UNKNOWN;
	private Exception exception;
	
	public ConsistencyCheckEvent(CheckConsistency source) {
		this.source = source;
	}
	
	public void setEvent(String message, Type type) {
		this.message = message;
		this.type = type;
	}
	
	public void setException(Exception exception) {
		this.exception = exception;
	}

	public CheckConsistency getSource() { return source; }
	
	public Type getType() { return type; }
	
	public String getMessage() {
		return message;
	}
	
	public Exception getException() {
		return exception;
	}
}
