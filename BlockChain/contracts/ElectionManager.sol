// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ElectionManager {
    address public admin;

    struct Candidate {
        string name;
        bool approved;
    }

    struct Election {
        string name;
        string position;
        uint256 startTime;
        uint256 endTime;
        uint256 candidateDeadline;
        bool exists;
        bool votingClosed;
        mapping(address => bool) hasVoted;
        mapping(string => uint256) votes;
        address[] candidateAddresses;
        mapping(address => Candidate) candidates;
    }

    mapping(uint256 => Election) private elections;
    mapping(address => mapping(uint256 => bool)) public tokenIssued; // token issued to voter for election
    uint256 public electionCount;

    event ElectionCreated(uint256 electionId, string name, string position);
    event CandidateRequested(uint256 electionId, address candidate, string name);
    event CandidateApproved(uint256 electionId, address candidate);
    event VotingClosed(uint256 electionId);
    event Voted(uint256 electionId, address indexed voter, string candidate);
    event TokenIssued(uint256 electionId, address voter);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function createElection(
        string memory _name,
        string memory _position,
        uint256 _candidateDeadline,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyAdmin {
        require(_candidateDeadline < _startTime, "Candidate deadline must be before voting starts");
        require(_startTime < _endTime, "Invalid time range");

        electionCount++;
        Election storage e = elections[electionCount];
        e.name = _name;
        e.position = _position;
        e.candidateDeadline = _candidateDeadline;
        e.startTime = _startTime;
        e.endTime = _endTime;
        e.exists = true;
        e.votingClosed = false;

        emit ElectionCreated(electionCount, _name, _position);
    }

    function requestCandidacy(uint256 _electionId, string memory _name) external {
        Election storage e = elections[_electionId];
        require(e.exists, "Election does not exist");
        require(block.timestamp <= e.candidateDeadline, "Candidate registration closed");
        require(bytes(e.candidates[msg.sender].name).length == 0, "Already requested");

        e.candidates[msg.sender] = Candidate(_name, false);
        e.candidateAddresses.push(msg.sender);

        emit CandidateRequested(_electionId, msg.sender, _name);
    }


    function approveCandidate(uint256 _electionId, address _candidate) external onlyAdmin {
        Election storage e = elections[_electionId];
        require(e.exists, "Election does not exist");
        require(bytes(e.candidates[_candidate].name).length > 0, "Candidate not found");
        e.candidates[_candidate].approved = true;
        emit CandidateApproved(_electionId, _candidate);
    }

    // function issueVoteToken(uint256 _electionId, address _voter) external onlyAdmin {
    //     require(elections[_electionId].exists, "Election does not exist");
    //     tokenIssued[_voter][_electionId] = true;
    //     emit TokenIssued(_electionId, _voter);
    // }

    function vote(uint256 _electionId, address _candidate) external {
        Election storage e = elections[_electionId];
        require(e.exists, "Election does not exist");
        // _autoCloseIfTimePassed(e, _electionId);
        require(block.timestamp >= e.startTime, "Voting not started");
        require(block.timestamp <= e.endTime, "Voting ended");
        require(!e.votingClosed, "Voting closed manually");
        require(!e.hasVoted[msg.sender], "Already voted");
        require(e.candidates[_candidate].approved, "Candidate not approved");
        e.votes[e.candidates[_candidate].name]++;
        e.hasVoted[msg.sender] = true;
        emit Voted(_electionId, msg.sender, e.candidates[_candidate].name);
    }

    function closeVoting(uint256 _electionId) external onlyAdmin {
        require(elections[_electionId].exists, "Election does not exist");
        elections[_electionId].votingClosed = true;

        emit VotingClosed(_electionId);
    }

    function getCandidates(uint256 _electionId) external view returns (string[] memory) {
        require(elections[_electionId].exists, "Election does not exist");
        Election storage e = elections[_electionId];
        uint256 count = 0;
        for (uint256 i = 0; i < e.candidateAddresses.length; i++) {
            if (e.candidates[e.candidateAddresses[i]].approved) {
                count++;
            }
        }
        string[] memory names = new string[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < e.candidateAddresses.length; i++) {
            if (e.candidates[e.candidateAddresses[i]].approved) {
                names[idx++] = e.candidates[e.candidateAddresses[i]].name;
            }
        }
        return names;
    }

    function getVotes(uint256 _electionId, string memory _candidateName) external view returns (uint256) {
        require(elections[_electionId].exists, "Election does not exist");
        return elections[_electionId].votes[_candidateName];
    }

    function hasVoted(uint256 _electionId, address _voter) external view returns (bool) {
        require(elections[_electionId].exists, "Election does not exist");
        return elections[_electionId].hasVoted[_voter];
    }

    function getElectionDetails(uint256 _electionId) external view returns (
        string memory name,
        string memory position,
        uint256 candidateDeadline,
        uint256 startTime,
        uint256 endTime,
        bool votingClosed
    ) {
        require(elections[_electionId].exists, "Election does not exist");
        Election storage e = elections[_electionId];
        // bool isVotingClosed = e.votingClosed || block.timestamp > e.endTime;
        return (e.name, e.position, e.candidateDeadline, e.startTime, e.endTime, e.votingClosed);
    }

    function getAllElections() external view returns (
        uint256[] memory ids,
        string[] memory names,
        string[] memory positions,
        uint256[] memory candidateDeadlines,
        uint256[] memory startTimes,
        uint256[] memory endTimes,
        bool[] memory votingClosedFlags,
        string[][] memory candidateNames,
        bool[][] memory candidateApprovals,
        address[][] memory candidateAddresses
    ) {
        uint256 total = electionCount;
        uint256 validCount = 0;

        // First count valid elections
        for (uint256 i = 1; i <= total; i++) {
            if (elections[i].exists) {
                validCount++;
            }
        }

        ids = new uint256[](validCount);
        names = new string[](validCount);
        positions = new string[](validCount);
        candidateDeadlines = new uint256[](validCount);
        startTimes = new uint256[](validCount);
        endTimes = new uint256[](validCount);
        votingClosedFlags = new bool[](validCount);
        candidateNames = new string[][](validCount);
        candidateApprovals = new bool[][](validCount);
        candidateAddresses = new address[][](validCount);

        uint256 idx = 0;
        for (uint256 i = 1; i <= total; i++) {
            Election storage e = elections[i];
            if (!e.exists) continue;

            ids[idx] = i;
            names[idx] = e.name;
            positions[idx] = e.position;
            candidateDeadlines[idx] = e.candidateDeadline;
            startTimes[idx] = e.startTime;
            endTimes[idx] = e.endTime;
            votingClosedFlags[idx] = e.votingClosed;

            uint256 cLen = e.candidateAddresses.length;
            string[] memory cNames = new string[](cLen);
            bool[] memory cApprovals = new bool[](cLen);
            address[] memory cAddrs = new address[](cLen);

            for (uint256 j = 0; j < cLen; j++) {
                address candAddr = e.candidateAddresses[j];
                Candidate storage cand = e.candidates[candAddr];
                cNames[j] = cand.name;
                cApprovals[j] = cand.approved;
                cAddrs[j] = candAddr;
            }

            candidateNames[idx] = cNames;
            candidateApprovals[idx] = cApprovals;
            candidateAddresses[idx] = cAddrs;

            idx++;
        }
}

}
