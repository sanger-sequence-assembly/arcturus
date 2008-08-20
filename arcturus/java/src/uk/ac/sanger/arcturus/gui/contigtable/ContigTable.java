package uk.ac.sanger.arcturus.gui.contigtable;

import java.awt.*;
import javax.swing.table.*;
import javax.swing.ListSelectionModel;
import java.io.*;
import java.text.*;

import uk.ac.sanger.arcturus.gui.SortableTable;
import uk.ac.sanger.arcturus.gui.SortableTableModel;
import uk.ac.sanger.arcturus.test.CAFWriter;
import uk.ac.sanger.arcturus.Arcturus;
import uk.ac.sanger.arcturus.database.ArcturusDatabase;
import uk.ac.sanger.arcturus.data.Contig;

public class ContigTable extends SortableTable {
	public final static int BY_ROW_NUMBER = 1;
	public final static int BY_PROJECT = 2;
	protected final Color paleYellow = new Color(255, 255, 238);
	protected final Color VIOLET1 = new Color(245, 245, 255);
	protected final Color VIOLET2 = new Color(238, 238, 255);
	protected final Color VIOLET3 = new Color(226, 226, 255);

	protected int howToColour = BY_ROW_NUMBER;

	public ContigTable(SortableTableModel stm) {
		super(stm);
		setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
	}

	public void setHowToColour(int how) {
		howToColour = how;
		repaint();
	}

	public Component prepareRenderer(TableCellRenderer renderer, int rowIndex,
			int vColIndex) {
		Component c = super.prepareRenderer(renderer, rowIndex, vColIndex);

		if (isCellSelected(rowIndex, vColIndex)) {
			c.setBackground(getBackground());
		} else {
			if (rowIndex % 2 == 0) {
				c.setBackground(VIOLET1);
			} else {
				c.setBackground(VIOLET2);
			}
		}

		if (isCellSelected(rowIndex, vColIndex))
			c.setForeground(Color.RED);
		else
			c.setForeground(Color.BLACK);

		return c;
	}

	public ContigList getSelectedValues() {
		int[] indices = getSelectedRows();
		ContigTableModel ctm = (ContigTableModel) getModel();
		ContigList clist = new ContigList();
		for (int i = 0; i < indices.length; i++)
			clist.add(ctm.elementAt(indices[i]));

		return clist;
	}
	
	public void saveSelectedContigsAsCAF(File file) {
		try {
			PrintStream ps = new PrintStream(new FileOutputStream(file));
			
			CAFWriter cw = new CAFWriter(ps);
			
			int[] indices = getSelectedRows();
			ContigTableModel ctm = (ContigTableModel) getModel();
		
			for (int i = 0; i < indices.length; i++) {
				Contig contig = (Contig)ctm.elementAt(indices[i]);
				contig.update(ArcturusDatabase.CONTIG_TO_GENERATE_CAF);
				cw.writeContig(contig);
			}
			
			ps.close();
		}
		catch (Exception e) {
			Arcturus.logWarning(e);
		}
	}
	
	public void saveSelectedContigsAsFasta(File file) {
		try {
			PrintStream ps = new PrintStream(new FileOutputStream(file));
			
			DecimalFormat df = new DecimalFormat("000000");

			int[] indices = getSelectedRows();
			ContigTableModel ctm = (ContigTableModel) getModel();
		
			for (int i = 0; i < indices.length; i++) {
				Contig contig = (Contig)ctm.elementAt(indices[i]);
				contig.update(ArcturusDatabase.CONTIG_CONSENSUS);			
				
				byte[] dna = depad(contig.getDNA());
				
				if (dna != null) {
					if (i > 0)
						ps.print('\n');
					
					ps.println(">contig" + df.format(contig.getID()));
					
					for (int j = 0; j < dna.length; j += 50) {
						int sublen = (j + 50 < dna.length) ? 50 : dna.length - j;
						ps.write(dna, j, sublen);
						ps.print('\n');
					}
				}
			}
			
			ps.close();		
		}
		catch (Exception e) {
			Arcturus.logWarning(e);
		}
	}
	
	private byte[] depad(byte[] input) {
		if (input == null)
			return null;
		
		int pads = 0;
		
		for (int i = 0; i < input.length; i++)
			if (input[i] == '*')
				pads++;
		
		if (pads == 0)
			return input;
		
		byte[] output = new byte[input.length - pads];
		
		int j = 0;
		
		for (int i = 0; i < input.length; i++)
			if (input[i] != '*')
				output[j++] = input[i];
		
		return output;
	}
}
