pragma solidity ^0.4.18;


contract FairVoting {    
    event _PollCreated(uint indexed pollID, address indexed creator, uint numOptions, uint voteQuorum, uint commitEndDate, uint revealEndDate);
    event _VoteCommitted(uint indexed pollID, address indexed voter);
    event _VoteRevealed(uint indexed pollID, address indexed voter, uint indexed choice);
    
    uint private pollIndex;
    mapping(uint => Poll) private pollMap; // maps pollID to Poll struct

    struct vote  {
        bytes32 secretHash;
        bool commited;
        bool revealed;
    }

    struct Poll {
        uint[] options;                 // choice of this poll
        uint commitEndDate;             // expiration date of commit period for poll
        uint revealEndDate;             // expiration date of reveal period for poll
        uint revealedQuorum;	        // minimum votes reveal rate
        uint votesNum;                  // how many people voted 
        uint revealedNum;               // how many people revealed
        mapping(address => vote) votes; // indicates whether an address committed/revealed a vote for this poll
    }
    
    constructor() public {
        pollIndex = 0;
    }

    function startPoll(uint _numOptions, uint _revealedQuorum, uint _commitDuration, uint _revealDuration) public {
        require(_numOptions >= 2, "Must be more than 2 options.");
        uint commitEndDate = safeAdd(block.timestamp, _commitDuration);
        uint revealEndDate = safeAdd(commitEndDate, _revealDuration);

        pollMap[pollIndex] = Poll({
            options: new uint[](_numOptions),
            commitEndDate: commitEndDate,
            revealEndDate: revealEndDate,
            revealedQuorum: _revealedQuorum,
            votesNum: 0,
            revealedNum: 0
        });
        pollIndex++;

        emit _PollCreated(pollIndex, msg.sender, _numOptions, _revealedQuorum, commitEndDate, revealEndDate);
    }
    
    function commitVote(uint _pollID, bytes32 _secretHash) public {
        require(pollExists(_pollID), "Poll do not exist.");
        require(pollMap[_pollID].commitEndDate >= block.timestamp, "Commit time limit has been exceeded.");
        require(pollMap[_pollID].votes[msg.sender].commited == false, "Has been voted."); 

        pollMap[_pollID].votes[msg.sender].secretHash = _secretHash;
        pollMap[_pollID].votes[msg.sender].commited = true;
        pollMap[_pollID].votesNum++;
        
        emit _VoteCommitted(_pollID, msg.sender);
    }

    function revealVote(uint _pollID, uint _voteOption, uint _salt) public {
        require(pollExists(_pollID), "Poll do not exist.");
        require(pollMap[_pollID].commitEndDate < block.timestamp, "It's not time to revealte.");
        require(pollMap[_pollID].revealEndDate >= block.timestamp, "Reveal time limit has been exceeded.");
        require(pollMap[_pollID].options.length > _voteOption, "Option unlawful.");
        require(pollMap[_pollID].votes[msg.sender].commited == true, "Has not been voted."); 
        require(pollMap[_pollID].votes[msg.sender].revealed == false, "Has been revealed.");
        require(pollMap[_pollID].votes[msg.sender].secretHash == keccak256(abi.encodePacked(_voteOption, _salt)), "Reveal unlawful.");
    
        pollMap[_pollID].options[_voteOption]++;
        pollMap[_pollID].votes[msg.sender].revealed = true;
        pollMap[_pollID].revealedNum++;
        
        emit _VoteRevealed(_pollID, msg.sender, _voteOption);
    }
    
    function winner(uint _pollID) view public returns (uint) {
        require(pollExists(_pollID), "Poll do not exist.");
        require(pollMap[_pollID].revealEndDate < block.timestamp, "It's not time to finish.");
        require(poolTakesEffect(_pollID), "Revealed Quorum is not enough");
        
        uint topScore = pollMap[_pollID].options[0];
        uint topOption = 0;

        for(uint i = 1; i < pollMap[_pollID].options.length; i++) {
            require(topScore != pollMap[_pollID].options[i], "No optimal selection.");
            if (topScore < pollMap[_pollID].options[i]) {
                topScore = pollMap[_pollID].options[i];
                topOption = i;
            }
        }

        return topOption;
    }
    
    function poolTakesEffect(uint _pollID) view private returns (bool) {
        return 100 * pollMap[_pollID].revealedNum > pollMap[_pollID].revealedQuorum * pollMap[_pollID].votesNum;
    }
    
    function pollExists(uint _pollID) view private returns (bool) {
        return (_pollID >= 0 && _pollID < pollIndex);
    }

    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}