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

package uk.ac.sanger.arcturus.logging;

import uk.ac.sanger.arcturus.Arcturus;
import java.util.logging.*;

public class LogTester {
	public static void main(String[] args) {
		// Explicitly set the testing flag to prevent the logging system
		// from instantiating a MailHandler.
		System.setProperty("testing", "true");
		
		// Tell Arcturus to use a console log handler instead of a message dialog handler.
		System.setProperty("useConsoleLogHandler", "true");

		Arcturus.logWarning("Starting");

		try {
			Thread.sleep(3000L);
		} catch (InterruptedException ie) {
			Arcturus.logWarning("Sleep interrupted");
		}

		Arcturus.logWarning("This is a warning");

		try {
			Thread.sleep(3000L);
		} catch (InterruptedException ie) {
			Arcturus.logWarning("Sleep interrupted");
		}

		try {
			doSomething(0);
		} catch (Exception e) {
			Arcturus.log(Level.SEVERE, "exception", e);
		}

		try {
			Thread.sleep(3000L);
		} catch (InterruptedException ie) {
			Arcturus.logWarning("Sleep interrupted");
		}

		try {
			createNestedExceptions();
		} catch (HighLevelException e) {
			Arcturus.logSevere(e);
		}

		System.exit(0);
	}

	static void createNestedExceptions() throws HighLevelException {
		try {
			b();
		} catch (MidLevelException e) {
			throw new HighLevelException(e);
		}
	}

	static void b() throws MidLevelException {
		c();
	}

	static void c() throws MidLevelException {
		try {
			d();
		} catch (LowLevelException e) {
			throw new MidLevelException(e);
		}
	}

	static void d() throws LowLevelException {
		e();
	}

	static void e() throws LowLevelException {
		throw new LowLevelException();
	}

	public static void doSomething(int i) throws Exception {
		if (i < 5)
			doSomething(i + 1);
		else
			throw new Exception("Something bad happened");
	}

}

class HighLevelException extends Exception {
	HighLevelException(Throwable cause) {
		super(cause);
	}
}

class MidLevelException extends Exception {
	MidLevelException(Throwable cause) {
		super(cause);
	}
}

class LowLevelException extends Exception {
}
