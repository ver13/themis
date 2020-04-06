pragma solidity >=0.5.0 <0.6.0;

// Base contract that can be destroyed by owner. 
import "openzeppelin-solidity/contracts/lifecycle/Destructible.sol";

/** 
 * @title DocRegister
 * @author Valentin Encinas
 * @notice This contract represents a registry of document ownership. 
 * Due to storage limitations, documents are stored on IPFS.  
 * The IPFS hash along with metadata are stored onchain.
 */
contract DocRegister is Destructible {
	
	/** 
	* @title Represents a single document which is owned by someone. 
	*/
	struct Document {
		string ipfsHash;        // IPFS hash
		string title;           // Document title
		string description;     // Document description
		string tags;            // Document tags in comma separated format
		uint256 uploadedOn;     // Uploaded timestamp
	}
	
	// Maps owner to their documents
	mapping (address => Document[]) public ownerToDocuments;
	
	// Used by Circuit Breaker pattern to switch contract on/off
	bool private stopped = false;
	
	/**
	* @dev Indicates that a user has uploaded a new document
	* @param _owner The owner of the document
	* @param _ipfsHash The IPFS hash
	* @param _title The document title
	* @param _description The document description
	* @param _tags The document tags
	* @param _uploadedOn The upload timestamp
	*/
	event LogDocumentUploaded(
		address indexed _owner,
		string _ipfsHash,
		string _title,
		string _description,
		string _tags,
		uint256 _uploadedOn
	);
	
	/**
	* @dev Indicates that the owner has performed an emergency stop
	* @param _owner The owner of the document
	* @param _stop Indicates whether to stop or resume
	*/
	event LogEmergencyStop(
		address indexed _owner,
		bool _stop
	);
	
	/**
	* @dev Prevents execution in the case of an emergency
	*/
	modifier stopInEmergency {
		require(!stopped);
		_;
	}
	
	/**  
	* @dev This function is called for all messages sent to this contract (there is no other function).
	* Sending Ether to this contract will cause an exception, because the fallback function does not have the `payable` modifier.
	*/
	function() public {}
	
	/** 
	* @notice associate an document entry with the owner i.e. sender address
	* @dev Controlled by circuit breaker
	* @param _ipfsHash The IPFS hash
	* @param _title The document title
	* @param _description The document description
	* @param _tags The document tag(s)
	*/
	function uploadDocument(
		string _ipfsHash,
		string _title,
		string _description,
		string _tags
	) public stopInEmergency returns (
		bool _success
	) {
		require(bytes(_ipfsHash).length == 46);
		require(bytes(_title).length > 0 && bytes(_title).length <= 256);
		require(bytes(_description).length < 1024);
		require(bytes(_tags).length > 0 && bytes(_tags).length <= 256);
		
		uint256 uploadedOn = now;
		Document memory document = Document(
			_ipfsHash,
			_title,
			_description,
			_tags,
			uploadedOn
		);
		
		ownerToDocuments[msg.sender].push(document);
		
		emit LogDocumentUploaded(
			msg.sender,
			_ipfsHash,
			_title,
			_description,
			_tags,
			uploadedOn
		);
		
		_success = true;
	}
	
	/** 
	* @notice Returns the number of documents associated with the given address
	* @dev Controlled by circuit breaker
	* @param _owner The owner address
	* @return The number of documents associated with a given address
	*/
	function getDocumentCount(address _owner)
	public view stopInEmergency returns (
		uint256
	) {
		require(_owner != 0x0);
		return ownerToDocuments[_owner].length;
	}
	
	/** 
	* @notice Returns the document at index in the ownership array
	* @dev Controlled by circuit breaker
	* @param _owner The owner address
	* @param _index The index of the document to return
	* @return _ipfsHash The IPFS hash
	* @return _title The document title
	* @return _description The document description
	* @return _tags document Then document tags
	* @return _uploadedOn The uploaded timestamp
	*/
	function getDocument(address _owner, uint8 _index)
	public stopInEmergency view returns (
		string _ipfsHash,
		string _title,
		string _description,
		string _tags,
		uint256 _uploadedOn
	) {
		require(_owner != 0x0);
		require(_index >= 0 && _index <= 2**8 - 1);
		require(ownerToDocuments[_owner].length > 0);
		
		Document storage document = ownerToDocuments[_owner][_index];
		
		return (
			document.ipfsHash,
			document.title,
			document.description,
			document.tags,
			document.uploadedOn
		);
	}
	
	/**
	* @notice Pause the contract. 
	* It stops execution if certain conditions are met and can be useful 
	* when new errors are discovered. 
	* @param _stop Switch the circuit breaker on or off
	*/
	function emergencyStop(bool _stop)
	public onlyOwner
	{
		stopped = _stop;
		emit LogEmergencyStop(owner, _stop);
	}
}
