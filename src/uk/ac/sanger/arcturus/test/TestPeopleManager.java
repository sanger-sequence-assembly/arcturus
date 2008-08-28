package uk.ac.sanger.arcturus.test;

import uk.ac.sanger.arcturus.people.*;

public class TestPeopleManager {
	public static void main(String[] args) {
		for (int i = 0; i < args.length; i++) {
			String uid = args[i];

			Person person = PeopleManager.createPerson(uid);

			System.out.println(person == null ? uid + " NOT FOUND" : uid
					+ " --> " + person);
		}

		Person me = PeopleManager.createPerson(PeopleManager.getEffectiveUID());

		System.out
				.println(me == null ? "I don't know who I am!" : "I am " + me);
	}
}
