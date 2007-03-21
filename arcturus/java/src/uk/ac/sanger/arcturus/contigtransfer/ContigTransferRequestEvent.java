package uk.ac.sanger.arcturus.contigtransfer;

public class ContigTransferRequestEvent {
	private ContigTransferRequest request;
	private int oldStatus = ContigTransferRequest.UNKNOWN;
	
	public ContigTransferRequestEvent(ContigTransferRequest request, int oldStatus) {
		this.request = request;
		this.oldStatus = oldStatus;
	}
	
	public ContigTransferRequest getRequest() {
		return request;
	}
	
	public void setRequest(ContigTransferRequest request) {
		this.request = request;
	}
	
	public int getOldStatus() {
		return oldStatus;
	}
	
	public void setOldStatus(int oldStatus) {
		this.oldStatus = oldStatus;
	}
	
	public void setRequestAndOldStatus(ContigTransferRequest request, int oldStatus) {
		this.request = request;
		this.oldStatus = oldStatus;
	}

	public int getNewStatus() {
		return (request == null) ?  ContigTransferRequest.UNKNOWN : request.getStatus();
	}
}
