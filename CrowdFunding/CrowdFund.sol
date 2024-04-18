// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
interface IERC20 {
    //The transfer function is for sending money to the address.
    function transfer(address, uint) external returns (bool);
    //The transfer fron is for sending the money from an address to the owner.
    function transferFrom(address, address, uint) external returns (bool);
}
 
contract CrowdFund {
    // These are the events for Launch, Cancel, Pledge, Unpledge, Claim, Refund functions so 
    // The user can interact with them through front-end
    event Launch(
        // This event for Launch function which start a campaign for the creator
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );
    //This event for Cancel function which cancel a campaign.
    event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint id, address indexed caller, uint amount);
 
    struct Campaign {
        // Creator of campaign
        address creator;
        // Amount of tokens to raise
        uint goal;
        // Total amount pledged
        uint pledged;
        // Timestamp of start of campaign
        uint32 startAt;
        // Timestamp of end of campaign
        uint32 endAt;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }
 
    IERC20 public immutable token;
    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint public count;
    // Mapping from id to Campaign
    mapping(uint => Campaign) public campaigns;
    // Mapping from campaign id => pledger => amount pledged.
    mapping(uint => mapping(address => uint)) public pledgedAmount;
 
    constructor(address _token) {
        // Contructor is set for using an ERC 20 Token.
        token = IERC20(_token);
    }
 
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        // This function for launching a new campaign and the parameters are goal, startat and endat
        //we are requiring that the campaign has to start in the future.
        require(_startAt >= block.timestamp, "start at < now");
        //This campaign should end a later date 
        //The end time has to be greater than the start time.
        require(_endAt >= _startAt, "end at < start at");
        //The end time should be in 90 days time.
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");
 
        //The number of campaigns is increasing by one, each time a new campaign is launched
        count += 1;
        //Creating a new Campaign and save it in the mapping of campaigns.
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });
 
        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
        //tells the front-end that an event has happened
    }
 
    function cancel(uint _id) external {
        //this function is for canceling a compaign
        // Retreive a certain compaign id from compaigns mapping.
        Campaign memory campaign = campaigns[_id];
        //compaign creator must be the one that have the right to cancel his compaign else send error not creator.
        require(campaign.creator == msg.sender, "not creator");
        //we can't cancel a compaign once it has started 
        require(block.timestamp < campaign.startAt, "started");
        // Delete is a function in solidity that ennables the deleting of a particular id in the mapping campaigns.
        delete campaigns[_id];
        // tells the front-end that an event has happened
        emit Cancel(_id);
    }
 
    function pledge(uint _id, uint _amount) external{
        //This function allows a user to pledge for a particular campagin.
        ////Retriving Campaign from the mapping campaigns.
        Campaign storage campaign = campaigns[_id];
        // If the current time is less than the time that the campaign is supposed to start, show not started
        require(block.timestamp >= campaign.startAt, "not started");
        // If the current time is greater than the end time of the campaign, return ended.
        require(block.timestamp <= campaign.endAt, "ended");
        //The amount pledged will be added to the default pledged variable which is 0.
        campaign.pledged += _amount;
        //Storing the informations of a particular amount pledged in a nested mapping called pledgedAmount.
        pledgedAmount[_id][msg.sender] += _amount;
        //Sending the pledged amount from the sender to the owner of this particular campaign.
        token.transferFrom(msg.sender, address(this), _amount);
        // The front-end should show that a pledge has been made.
        emit Pledge(_id, msg.sender, _amount);
    }
 
    function unpledge(uint _id, uint _amount) external {
        //This function allows us to unpledge the previous pledge that has been made.
        //enables us to retreive the particular campaign 
        Campaign storage campaign = campaigns[_id];
        //Requiring that the campaign is still running before the end time else return ended.
        require(block.timestamp <= campaign.endAt, "ended");
        //substruct the unpledged ammount from the previous ammount.
        campaign.pledged -= _amount;
        //Updating the substructed ammount that this particular person has saved.
        pledgedAmount[_id][msg.sender] -= _amount;
        //Transferring the amount back to the sender.
        token.transfer(msg.sender, _amount);
        //Signify the front-end that an Unpleged action has been carried out.
        emit Unpledge(_id, msg.sender, _amount);
    }
 
    function claim(uint _id) external {
        //This function allows the creator to claim a particular campaign.
        //Retrieving campagin from the mapping campaigns and storing it in Campaign.
        Campaign storage campaign = campaigns[_id];
        //The creator should be the one who is allowed to claim this campaign else return not the creator.
        require(campaign.creator == msg.sender, "not creator");
        /* The campaign should be ended for the creator to carry out function claim,
         else return an error not ended*/
        require(block.timestamp > campaign.endAt, "not ended");
        /* The amount pledge should be grater than or equal to the goal of the campaign
        else return the error pledged < goal*/
        require(campaign.pledged >= campaign.goal, "pledged < goal");
        //Require that the campaign is unclaimed else return claimed.
        require(!campaign.claimed, "claimed");
        //Once the campaign is claimed, return true.
        campaign.claimed = true;
        //Transferring the pledged ammount of this compaign to its creator.
        token.transfer(campaign.creator, campaign.pledged);
        //Signify the front-end that the campaign has been claimed.
        emit Claim(_id);
    }
 
    function refund(uint _id) external {
        //This function allows refund of the amount pledged.
        //Retrieving a particular campaign from the mapping campaigns and storing it in the memory Campaign.
        Campaign memory campaign = campaigns[_id];
        /* The campaign should be ended for the creator to carry out the function refund,
         else return an error not ended*/
        require(block.timestamp > campaign.endAt, "not ended");
        //The amount pledged has to be less than the goal, else return pledged >= goal.
        require(campaign.pledged < campaign.goal, "pledged >= goal");
 
        /* Declaring a new variable called balance (how much a particular sender has pledged)
       which is the amount that was stored in mapping before.*/
        uint bal = pledgedAmount[_id][msg.sender];
        //Decreasing the pledgedAmount of a particular sender to 0.
        pledgedAmount[_id][msg.sender] = 0;
        //Refunding bal(the amount the sender pledged) to the sender.
        token.transfer(msg.sender, bal);
        //Signify the front-end that a refund has been made.
        emit Refund(_id, msg.sender, bal);
    }
}