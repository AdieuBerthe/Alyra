// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    struct Voter {
    bool isRegistered;
    bool hasVoted;
    uint votedProposalId;
    }
    struct Proposal {
    string description;
    uint voteCount;
    }

    enum WorkflowStatus {
    RegisteringVoters,
    ProposalsRegistrationStarted,
    ProposalsRegistrationEnded,
    VotingSessionStarted,
    VotingSessionEnded,
    VotesTallied
    }

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    WorkflowStatus state;
    mapping (address => Voter)  whitelist;
    address[] voters;
    Proposal[] public proposals;
    Proposal[] tmpProposals; //sera utilise en cas d'egalite
    uint[] winners;
    uint public winningProposalId;

    modifier isRegistered{
        require(whitelist[msg.sender].isRegistered, "you're not registered");
        _;
    }

    constructor() {
        proposals.push(Proposal("blank", 0));
        addToWhitelist(msg.sender);
    }

    function addToWhitelist(address _addr) public onlyOwner{
        require(state == WorkflowStatus.RegisteringVoters, "registration is over");
        require(!whitelist[_addr].isRegistered, "this voter is already registered");
        whitelist[_addr] = Voter(true, false, 0);
        voters.push(_addr);
        emit VoterRegistered(_addr);
    }

    function changeState(uint _id) public onlyOwner{
        WorkflowStatus prvState = state;
        require(uint(WorkflowStatus.VotesTallied) >= _id, "this event doesn't exist");
        state = WorkflowStatus(_id);
        emit WorkflowStatusChange(prvState, state);
    }

    function getSomeoneVote(address _addr) public view isRegistered returns(uint){
        require(whitelist[_addr].isRegistered, "this voter isn't registered");
        require(whitelist[_addr].hasVoted, "this voter hasn't voted yet");
        return whitelist[_addr].votedProposalId;
    }

    function addProposal(string calldata _details) public isRegistered {
        require(state == WorkflowStatus.ProposalsRegistrationStarted, "not time for proposals");
        uint propId = proposals.length;
        proposals.push(Proposal(_details, 0));
        emit ProposalRegistered(propId);
    }

    function getProposals() public view isRegistered returns(Proposal[] memory) {
        return proposals;
    }
    
    function vote(uint _propId) public isRegistered {
        require(state == WorkflowStatus.VotingSessionStarted, "it isn't time to vote");
        require(!whitelist[msg.sender].hasVoted, "you've already voted");
        require(_propId < proposals.length, "this proposal doesn't exist");
        proposals[_propId].voteCount++;
        whitelist[msg.sender] = Voter(true, true, _propId);
        emit Voted(msg.sender, _propId);
    }

    function calculateWinner() public onlyOwner returns(string memory){
        require(state == WorkflowStatus.VotingSessionEnded, "Voting session isn't over yet");
        require(proposals.length > 1, "There was no proposition to vote for");
        uint leadId = 1; //initialisation pour ignorer les votes blancs
        if(proposals.length == 2 && proposals[1].voteCount > 0) {
            winningProposalId = leadId;
            changeState(5);
            return "there is a winner";
        } else if (proposals.length > 2){
            for(uint i = 2; i < proposals.length; i++) {
                if(proposals[i].voteCount > proposals[leadId].voteCount) {
                    leadId = i;
                    deletetmpWinners();
                } else if (proposals[i].voteCount == proposals[leadId].voteCount) {
                    winners.push(i);
                }
                i++;
            }
            if(winners.length > 0) {
                winners.push(leadId);
                // on ajoute un tour de vote, jusqu'a avoir un seul gagnant
                nextTurn();
                return "There are multiple winners, started a new turn";
            } else {
                winningProposalId = leadId;
                changeState(5);
                return "there is a winner";
            }
        }
            return "no proposal passed";
    }

    function deletetmpWinners() private {
        for(uint i = winners.length; i > 0; i--) {
            winners.pop();
        }
    }

    //mise en place d'un nouveau tour
    function nextTurn() private {
        //on redonne le vote aux inscrits
        for(uint i = voters.length; i > 0; i--) {
            whitelist[voters[i-1]] = Voter(true, false, 0);
            voters.pop();
        }
        //on recupere les proposals gagnantes
        for(uint i = 0; i < winners.length; i++) {
            tmpProposals.push(proposals[winners[i]]);
            tmpProposals[i].voteCount = 0;
        }
        //on efface les resultats du tour precedent en gardant 'blank'
        deletetmpWinners();
        for(uint i = proposals.length -1; i > 0; i--) {
            proposals.pop();
        }
        proposals[0].voteCount = 0;
        //on ajoute les proposals du nouveau tour
        for(uint i = 0; i < tmpProposals.length; i++) {
            proposals.push(tmpProposals[i]);
        }
        //on vide tmpProposal
        for(uint i = tmpProposals.length; i > 0; i--) {
            tmpProposals.pop();
        }
        //on set le state directement sur VotingSessionStarted
        changeState(3);
    }

    function getBlankVotes() public view returns(uint){
        return proposals[0].voteCount;
    }

    function getWinningPropDetails() public view returns(Proposal memory) {
        require(state == WorkflowStatus.VotesTallied, "votes haven't been tallied yet");
        return proposals[winningProposalId];
    }
}
