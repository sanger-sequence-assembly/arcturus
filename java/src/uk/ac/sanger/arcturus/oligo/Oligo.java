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

package uk.ac.sanger.arcturus.oligo;

import java.util.regex.Pattern;

public class Oligo implements Comparable {
	private static int counter = 0;
	
	private static final String SPACES = "[\\-]*";
	
	private String name;
	private String sequence;
	private String revsequence;
	
	private boolean palindrome = false;
	
	private Pattern fwdPattern;
	private Pattern revPattern;
	
	public Oligo(String name, String sequence) {
		this.name = name;
		this.sequence = sequence.toUpperCase();
		revsequence = reverseComplement(sequence);
		
		palindrome = sequence.equalsIgnoreCase(revsequence);
	}
	
	public Oligo(String sequence) {
		this("ANON." + (++counter), sequence);
	}
	
	public String getName() { return name; }
	
	public String getSequence() { return sequence; }
	
	public String getReverseSequence() { return revsequence; }
	
	public int getLength() { return sequence.length(); }
	
	public boolean isPalindrome() {
		return palindrome;
	}
	
	public Pattern getForwardPattern() {
		if (fwdPattern == null)
			fwdPattern = preparePattern(sequence);
		
		return fwdPattern;
	}
	
	public Pattern getReversePattern() {
		if (revPattern == null && !palindrome)
			revPattern = preparePattern(revsequence);
		
		return revPattern;
	}
	
	private Pattern preparePattern(String seq) {
		StringBuilder sb = new StringBuilder();
		
		sb.append("(");
		sb.append(seq.charAt(0));
		
		for (int i = 1; i < seq.length(); i++) {
			sb.append(SPACES);
			sb.append(seq.charAt(i));
		}
		
		sb.append(")");
		
		return Pattern.compile(sb.toString());
	}
	
	private String reverseComplement(String str) {
		int strlen = str.length();
		
		char[] revchars = new char[strlen];
		
		for (int i = 0; i < strlen; i++) {
			char src = str.charAt(i);
			
			char dst;
			
			switch (src) {
				case 'a': case 'A': dst = 'T'; break;
				case 'c': case 'C': dst = 'G'; break;
				case 'g': case 'G': dst = 'C'; break;
				case 't': case 'T': dst = 'A'; break;
				default: dst = 'N'; break;
			}
			
			revchars[strlen - 1 - i] = dst;
		}
		
		return new String(revchars);
	}

	public int compareTo(Object o) {
		Oligo that = (Oligo)o;
		
		return name.compareTo(that.getName());
	}
}
