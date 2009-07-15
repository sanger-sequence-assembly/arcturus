package uk.ac.sanger.arcturus.scaffold;

public class ReadMapping {
	protected int read_id;
	protected int cstart;
	protected int cfinish;
	protected boolean forward;

	public ReadMapping(int read_id, int cstart, int cfinish, boolean forward) {
		this.read_id = read_id;
		this.cstart = cstart;
		this.cfinish = cfinish;
		this.forward = forward;
	}

	public int getReadID() {
		return read_id;
	}

	public int getContigStart() {
		return cstart;
	}

	public int getContigFinish() {
		return cfinish;
	}

	public boolean isForward() {
		return forward;
	}

	public boolean equals(Object obj) {
		if (obj instanceof ReadMapping) {
			ReadMapping that = (ReadMapping) obj;

			return (this.read_id == that.read_id)
					&& (this.cstart == that.cstart)
					&& (this.cfinish == that.cfinish)
					&& (this.forward == that.forward);
		} else
			return false;
	}

	public String toString() {
		return "ReadMapping[read_id=" + read_id + ", cstart=" + cstart
				+ " cfinish=" + cfinish + ", "
				+ (forward ? "forward" : "reverse") + "]";
	}
}
