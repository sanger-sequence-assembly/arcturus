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

package uk.ac.sanger.arcturus.gui.createcontigtransfers;

import javax.naming.NamingException;

import uk.ac.sanger.arcturus.ArcturusInstance;
import uk.ac.sanger.arcturus.data.Contig;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.database.ArcturusDatabaseException;

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
		String contig_id_str = "11977";
		String rubbish = "0.07KateIsASecretAgent";
		
		ArcturusInstance ai = null;
		try {
			ai = ArcturusInstance.getInstance("illumina");
		} catch (NamingException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		ArcturusDatabase adb = null;
		try {
			adb = ai.findArcturusDatabase("CELERA_MURIS");
		} catch (ArcturusDatabaseException e1) {
			// TODO Auto-generated catch block
			e1.printStackTrace();
		}
		
		Contig checkedContig = null;
		Contig contig = null;
		int contig_id;
		
		System.out.println("Test 1:");
		if (isName(contigname)) {
			System.out.println(contigname + " is a contig name");	
			try {
				contig = adb.getContigByName(contigname);
				System.out.println("Found contig " + contig.getID());
			}
			catch (ArcturusDatabaseException e1) {
				// TODO Auto-generated catch block
				e1.printStackTrace();
			}
			
			if (contig == null) {
				System.out.println("Cannot find contig " + contigname + " by name");
			}
			
			try {
				if (adb.isCurrentContig(contig.getID())) System.out.println("Contig " + contigname + " is current");
			} 
			catch (ArcturusDatabaseException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}	
			
		} 
		else if (isId(contigname)) {	
			System.out.println(contigname + " is a contig id");	
			
		}
		else {
			System.out.println(contigname + " is neither a contig id nor a contig name");	
		}
		
		System.out.println("Test 2:");
		if (isName(contig_id_str)) {
			System.out.println(contig_id_str + " is a contig name");				
		} 
		else if (isId(contig_id_str)) {	
			System.out.println(contig_id_str + " is a contig id");	
			contig_id = Integer.parseInt(contig_id_str);
			try {
				contig = adb.getContigByID(contig_id);
			} catch (ArcturusDatabaseException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
			if (contig == null) {
				System.out.println("Cannot find contig " + contig_id + " by ID");
			}
			else {
				System.out.println("Found contig " + contig_id + " by ID");
			}
		}
		else {
			System.out.println(contig_id_str + " is neither a contig id nor a contig name");	
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
