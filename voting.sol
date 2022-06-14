// SPDX-License-Identifier: GPL-3.0

// Hakim ATTASSI 

pragma solidity >=0.7.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

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

    WorkflowStatus public workflowStatus = WorkflowStatus.RegisteringVoters; //permet de determiner l'etape du process, initialiser à la phase d'enregistrement des voteurs

    mapping(address => Voter) public voters; // Lien entre l'adresse du voteur et l'objet "Voter"

    Proposal[] public proposals; //tableau pour enregistrer les propositions 
    
    uint private num_proposition_gagnante; 

    uint public nombre_voteur_enregistre; // utilisé pour vérifier le taux d'abstention 
    uint public Nombre_total_vote;  // utilisé pour vérifier le taux d'abstention

    // Controles 
    
    modifier Voteur_enregistre() {
        require(voters[msg.sender].isRegistered,"Vous devez etre enrigstre");
       _;
    }
    
    modifier periode_enregistrement_voteur() {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, 
           "Possible pendant la periode d'enregistrement des voteurs");
       _;
    }
    
    modifier periode_enregistrement_propositions() {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, 
           "Possible pendant la periode d'enregistrement des propositions");
       _;
    }
    
    modifier fin_enregistrement_propositions() {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, 
           "Periode enregistrement propositions terminee");
       _;
    }
    
    modifier periode_vote() {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Periode de vote");
       _;
    }
    
    modifier fin_vote() {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "fin de periode de vote");
       _;
    }
    
    modifier apres_depouillement() {
        require(workflowStatus == WorkflowStatus.VotesTallied,  "periode depouillement");
       _;
    }

    modifier majorite_absolue(){                                                               // Regle en plus, vous pouvez l'enlever pour tester le programme sans, en enlevant aussi les verifs sur les fonctions 
        require(nombre_voteur_enregistre <= Nombre_total_vote*2 ,  "Abstention superieur a 50%");
       _;

    }

    // Event
    
    event VoterRegistred (address voterAddress); //

    event ProposalRegistered(uint proposalId); //
     
    event WorkflowStatusChange (WorkflowStatus previousStatus,WorkflowStatus newStatus ); //

    event Voted ( address voter,uint proposalId ); //

    // Fontcions 

    function Enregister_voteur(address _voterAddress) public onlyOwner periode_enregistrement_voteur {
        
        require(!voters[_voterAddress].isRegistered, 
           "le voteur est deja enregistre");
        
        voters[_voterAddress].isRegistered = true;
        voters[_voterAddress].hasVoted = false;
        voters[_voterAddress].votedProposalId = 0;
        nombre_voteur_enregistre += 1; //pour vérifier taux abstention 
        
        emit VoterRegistred(_voterAddress);
    }
    

    function demarrer_enregistrement_propositions() public onlyOwner periode_enregistrement_voteur {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        
     
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, workflowStatus);//
    }
    

    function fin_enrg_propositions() public onlyOwner periode_enregistrement_propositions {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
    
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted, workflowStatus);
    }

    
    function enregistrer_proposition(string memory desc_propo)  public Voteur_enregistre periode_enregistrement_propositions {
        proposals.push(Proposal(
            {
            description: desc_propo,
            voteCount: 0
            }
                               )
        );
        
        emit ProposalRegistered(proposals.length - 1);
    }
    

    function somme_propositions() public view returns (uint) {   //interessant d'avoir le nombre de propositions pour plusieurs
         return proposals.length;
     }
     

    function getdesc_propo (uint index) public view returns (string memory) {
         return proposals[index].description;
     }    


    function debut_session_de_vote() public onlyOwner fin_enregistrement_propositions {
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, workflowStatus);
    }
    

    function fin_session_vote() public onlyOwner periode_vote {
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, workflowStatus);        
    }


    function vote(uint proposalId) Voteur_enregistre periode_vote public {
        require(!voters[msg.sender].hasVoted, "Vous avez deja vote");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = proposalId;

        proposals[proposalId].voteCount += 1;
        Nombre_total_vote +=1;

        emit Voted(msg.sender, proposalId);
    }


    function vote_par_procuration(address procurant, uint proposalId) Voteur_enregistre periode_vote public {
        require(!voters[procurant].hasVoted, "Il a deja vote");

        voters[procurant].hasVoted = true;
        voters[procurant].votedProposalId = proposalId;

        proposals[proposalId].voteCount += 1;
        Nombre_total_vote +=1;

        emit Voted(procurant, proposalId);
    }

    function depouillement() onlyOwner fin_vote public {
        uint nombre_vote_gagnant = 0;
        uint propo_gagnante_index = 0;
        
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > nombre_vote_gagnant) {
                nombre_vote_gagnant = proposals[i].voteCount;
                propo_gagnante_index = i;
            }
        }
        
        num_proposition_gagnante = propo_gagnante_index;
        workflowStatus = WorkflowStatus.VotesTallied;
        
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, workflowStatus);     
    }

    
    function winningProposalId() apres_depouillement majorite_absolue public view returns (uint) {
        return num_proposition_gagnante;
    }
    

    function getWinner() apres_depouillement majorite_absolue public view returns (string memory) {
        return proposals[num_proposition_gagnante].description;
    }  
    
    function getnombre_de_vote_proposition_gagnante() apres_depouillement  majorite_absolue public view returns (uint) {
        return proposals[num_proposition_gagnante].voteCount;
    }   
    
    function voteur_enregistre(address _voterAddress) public view returns (bool) { // Pas de controle sur cette fonction, info publique 
        return voters[_voterAddress].isRegistered;
     }
       
     
}
