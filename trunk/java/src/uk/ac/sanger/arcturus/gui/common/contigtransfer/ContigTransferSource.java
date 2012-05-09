package uk.ac.sanger.arcturus.gui.common.contigtransfer;

import java.util.List;

import uk.ac.sanger.arcturus.data.Contig;

public interface ContigTransferSource {
	public List<Contig> getSelectedContigs();
}
