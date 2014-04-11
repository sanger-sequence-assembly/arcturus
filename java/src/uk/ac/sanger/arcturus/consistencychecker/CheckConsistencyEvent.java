// Copyright (c) 2001-2014 Genome Research Ltd.
//
// Authors: David Harper
//          Ed Zuiderwijk
//          Kate Taylor
//
// This file is part of Arcturus.
//
// Arcturus is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation; either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

package uk.ac.sanger.arcturus.consistencychecker;

public class CheckConsistencyEvent {
	public enum Type { START_TEST_RUN, START_TEST, TEST_PASSED, TEST_FAILED, INCONSISTENCY, ALL_TESTS_PASSED,
		SOME_TESTS_FAILED, EXCEPTION, UNKNOWN, CANCELLED
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
CANCELLED
  The tests were cancelled by the user
*/
	
	private CheckConsistency source;
	private String message;
	private Type type = Type.UNKNOWN;
	private Exception exception;
	
	public CheckConsistencyEvent(CheckConsistency source) {
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
