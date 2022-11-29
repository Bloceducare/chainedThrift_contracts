// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IBentoxBox {
    function balanceOf(address, address) external view returns (uint256);

    function deposit(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

contract PurseContract {
    using SafeERC20 for IERC20;

    enum PurseState {
        Open,
        Closed,
        Terminate
    }

    struct Purse {
        PurseState purseState;
        uint256 time_interval;
        uint256 timeCreated;
        uint256 timeStarted;
        uint256 contract_total_deposit_balance;
        uint256 contract_total_collateral_balance;
        uint256 deposit_amount; //the deployer of each purse will set this amount which every other person to join will deposit
        uint256 max_member_num;
        uint256 required_collateral;
        uint256 purseId;
        uint256 num_of_members_who_has_recieved_funds;
        address _address_of_token;
        address purseAddress;
    }

    mapping(address => bool) public isPurseMember;
    mapping(address => uint256) public memberToCollateral; //map a user tp ccollateral deposited
    mapping(address => uint256) public memberToDeposit; // user to deposit
    mapping(address => bool) public member_has_recieved;
    mapping(address => mapping(address => bool)) public has_donated_for_member;
     mapping(address => mapping(address => bool)) public has_been_donated_for_by_member;
    mapping(address => uint256) public userClaimableDeposit;
    mapping(address => bool) public approve_To_Claim_Without_Complete_Votes;
    mapping(address => uint256) public votes_for_member_to_recieve_funds;
    mapping(address => bool) public member_close_Purse_Vote;
    mapping(address => bool) public member_reOpen_Purse_Vote;
    mapping(address => bool) public member_terminate_PurseVote;
    mapping(address => bool) public hasWithdrawnCollateralAndYield;
    mapping(address => uint256) public userPosition;
    mapping(uint256 => address) public positionToUser;

    address[] public members;
    uint256 public total_returns_to_members;
    uint256 public yields_to_members;

    struct MemberVoteForPurseState {
        uint256 voteToClose;
        uint256 voteToReOpen;
        uint256 voteToTerminate;
    }

    //map a user to amount deposited- ofcourse all members will deposit same amount
    //map a user's membership of a purse to true
    //map user to all the purse he is invloved in

    // maps a member address to check wether he has recieved a round of contribution or not
    //maps a user to no of votes to have funds received- this will be required to be equal to no of members in a group

    //these next 2 should be changed to a regular state variable instead

    // maps a user address to true to approve the user to claim even without complete votes

    //address of acceptable erc20 token - basically a stable coin DAI-rinkeby

    IERC20 tokenInstance;
    Purse public purse; //instantiate struct purse
    MemberVoteForPurseState public memberVoteForPurseState;

    address constant ADMIN = 0x9dc821bc9B379a002E5bD4A1Edf200c19Bc5F9CA;

    //instantiate IBentoxBox on mumbai
    address constant BENTOBOX_ADDRESS =
        0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
    IBentoxBox bentoBoxInstance = IBentoxBox(BENTOBOX_ADDRESS);

    //events
    event PurseCreated(
        address purseAddress,
        address indexed _creator,
        uint256 starting_amount,
        uint256 max_members,
        uint256 indexed _time_created
    );
    event MemberVotedFor(
        address indexed _member,
        uint256 indexed _currentVotesFor
    );
    event DonationDeposited(
        address indexed _member,
        uint256 _amount,
        address indexed purseAddress,
        address _recipient
    );

    event ClaimedFull(
        address indexed _member,
        address indexed purseAddress,
        uint256 _amount,
        uint256 dateClaimed
    );

    event ClaimedPart(
        address indexed _member,
        address indexed purseAddress,
        uint256 _amount,
        uint256 dateClaimed
    );

    event MemberLeft(address indexed _member, uint256 _time);

    modifier onlyPurseMember(address _address) {
        require(isPurseMember[_address] == true, "only purse members please");
        _;
    }

    //deposit of collateral for creator happens in token factory- see createPurse function
    // interval is in days
    constructor(
        address _creator,
        uint256 _amount,
        uint256 _max_member,
        uint256 time_interval,
        address _tokenAddress,
        uint256 _position
    ) payable {
        purse.deposit_amount = _amount; //set this amount to deposit_amount
        purse.max_member_num = _max_member; //set max needed member
        uint256 _required_collateral = _amount * (_max_member - 1);
        purse.required_collateral = _required_collateral;

        require(_position <= _max_member, "position out of range");
        //  require(tokenInstance.balanceOf(address(this)) == (_amount + required_collateral), 'deposit of funds and collateral not happening, ensure you are deploying fron PurseFactory Contract');
        memberToDeposit[_creator] = _amount; //
        memberToCollateral[_creator] = _required_collateral;
        userPosition[_creator] = _position;
        positionToUser[_position] = _creator;
        members.push(_creator); //push member to array of members

        //convert time_interval to
        purse.time_interval = time_interval * 24 * 60 * 60;
        isPurseMember[_creator] = true; //set msg.sender to be true as a member of the purse already
        purse.purseState = PurseState.Open; //set purse state to Open
        purse.contract_total_collateral_balance += _required_collateral; //increment mapping for all collaterals
        purse.timeCreated = block.timestamp;
        purse._address_of_token = _tokenAddress;
        purse.purseAddress = address(this);
        tokenInstance = IERC20(_tokenAddress);

        emit PurseCreated(
            address(this),
            _creator,
            _amount,
            _max_member,
            block.timestamp
        );
    }

    /**  @notice upon joining a purse, you need not include deposit amount
        deposit amount will be needed when denoating for a specific user using the
        depositDonation() function
        */

    function joinPurse(uint256 _position) public {
        require(
            purse.purseState == PurseState.Open,
            "This purse is not longer accepting members"
        );
        require(
            isPurseMember[msg.sender] == false,
            "you are already a member in this purse"
        );
        require(_position <= purse.max_member_num, "position out of range");

        address[] memory _members = members;
        for (uint8 i = 0; i < _members.length; i++) {
            require(_position != userPosition[_members[i]], "position taken");
        }

        tokenInstance.transferFrom(
            msg.sender,
            address(this),
            (purse.required_collateral)
        );
        memberToCollateral[msg.sender] = purse.required_collateral;
        members.push(msg.sender); //push member to array of members
        userPosition[msg.sender] = _position;
        positionToUser[_position] = msg.sender;
        isPurseMember[msg.sender] = true; //set msg.sender to be true as a member of the purse already
        purse.contract_total_collateral_balance += purse.required_collateral; //increment mapping for all collaterals

        //close purse if max_member_num is reached
        if (members.length == purse.max_member_num) {
            purse.purseState = PurseState.Closed;
            purse.timeStarted = block.timestamp;
        }
    }

    /// @notice this function is available in the instance a purse doesn't get full on time
    /// and a member wants to leave
    function leavePurse() public onlyPurseMember(msg.sender) {
        require(purse.purseState == PurseState.Open, "purse started already");
        isPurseMember[msg.sender] = false;
        userPosition[msg.sender] = 0;
        memberToCollateral[msg.sender] = 0;
        purse.contract_total_collateral_balance -= purse.required_collateral;

        // gets the index of the member trying to leave from the array of members
        // switches the position pf the member to be removed as last item and vice vers
        // then pop it
        for (uint8 i = 0; i < members.length; i++) {
            if (members[i] == msg.sender) {
                members[i] = members[members.length - 1];
                members[members.length - 1] = msg.sender;
                members.pop();
            }
        }
        tokenInstance.transfer(msg.sender, (purse.required_collateral));
        emit MemberLeft(msg.sender, block.timestamp);
    }

    function depositDonation(address _member)
        public
        onlyPurseMember(msg.sender)
    {
        (address _currentMemberToRecieve, , ) = currentRoundDetails();
        require(_member == _currentMemberToRecieve, "not this members round");
        require(
            has_donated_for_member[msg.sender][_member] == false,
            "you have donated for this member already"
        );
        require(
            member_has_recieved[_member] == false,
            "this user has recieved donation already"
        );

        userClaimableDeposit[_member] += purse.deposit_amount;
        purse.contract_total_deposit_balance += purse.deposit_amount;

        has_donated_for_member[msg.sender][_member] = true;
        has_been_donated_for_by_member[_member][msg.sender] = true;
        tokenInstance.transferFrom(
            msg.sender,
            address(this),
            purse.deposit_amount
        );
        emit DonationDeposited(
            msg.sender,
            purse.deposit_amount,
            address(this),
            _member
        );
    }

    // member who have been voted for as next will be the one to claim
    function claimDonations() public onlyPurseMember(msg.sender) {
        require(
            member_has_recieved[msg.sender] == false,
            "You have recieved a round of contribution already"
        );
        require(
            userClaimableDeposit[msg.sender] > 0,
            "You currently have no deposit for you to claim"
        );

        if (
            userClaimableDeposit[msg.sender] <
            (purse.deposit_amount * (purse.max_member_num - 1))
        ) {
            require(
                approve_To_Claim_Without_Complete_Votes[msg.sender] == true,
                "you could either approve yourself or let another team member approve that you can claim without complete donation using the approveToClaimWithoutCompleteVotes function "
            );
            purse.num_of_members_who_has_recieved_funds += 1;
            member_has_recieved[msg.sender] = true;
            tokenInstance.transfer(
                msg.sender,
                userClaimableDeposit[msg.sender]
            );
            emit ClaimedPart(
                msg.sender,
                address(this),
                userClaimableDeposit[msg.sender],
                block.timestamp
            );
        } else {
            purse.num_of_members_who_has_recieved_funds += 1;
            member_has_recieved[msg.sender] = true;
            tokenInstance.transfer(
                msg.sender,
                userClaimableDeposit[msg.sender]
            );
            emit ClaimedFull(
                msg.sender,
                address(this),
                userClaimableDeposit[msg.sender],
                block.timestamp
            );
        }
    }

    // this function is meant to give the contract a go-ahead to disburse funds to a member even though he doesnt have complete votes_for_member_to_recieve_funds
    // this for instance where a member(s) seem unresponsive in the purse group to vote for another person
    function approveToClaimWithoutCompleteVotes(address _member)
        public
        onlyPurseMember(msg.sender)
    {
        require(
            isPurseMember[_member] == true,
            "This provided address is not a member"
        );
        approve_To_Claim_Without_Complete_Votes[_member] = true;
    }

    function deposit_funds_to_bentoBox() public onlyPurseMember(msg.sender) {
        require(
            members.length == purse.max_member_num,
            "members to be in purse are yet to be completed, so collaterals are not complete"
        );
        uint256 MAX_UINT256 = purse.contract_total_collateral_balance;
        tokenInstance.approve(BENTOBOX_ADDRESS, MAX_UINT256);
        bentoBoxInstance.deposit(
            tokenInstance,
            address(this),
            address(this),
            purse.contract_total_collateral_balance,
            0
        );

        purse.contract_total_collateral_balance = 0;
    }

    function bentoBox_balance() public view returns (uint256) {
        uint256 bento_box_balance = bentoBoxInstance.balanceOf(
            purse._address_of_token,
            address(this)
        );
        return bento_box_balance;
    }

    //any member can call this function
    function withdraw_funds_from_bentoBox() public onlyPurseMember(msg.sender) {
        //    require(block.timestamp >= (purse.time_interval * max_member_num), 'Not yet time for withdrawal');
        require(
            purse.num_of_members_who_has_recieved_funds == members.length,
            "Not yet time, not all members have recieved a round of contribution"
        );
        //      require(
        //        for(uint256 i=0; i<purse.members.length; i++){
        //          member_has_recieved[purse.members[i]] == true;
        //        }, 'Not all members have recieved thier round of contribution'
        //          );
        uint256 bento_box_balance = bentoBoxInstance.balanceOf(
            purse._address_of_token,
            address(this)
        );
        //bentoBox withdraw functiosn returns 2 values, in this cares, shares will be what has the entire values- our collateral deposits plus yields
        uint256 shares;
        uint256 amount;
        (amount, shares) = bentoBoxInstance.withdraw(
            tokenInstance,
            address(this),
            address(this),
            0,
            bento_box_balance
        );
        //calculate yields
        uint256 yields = shares -
            (purse.required_collateral * purse.max_member_num); //shares will remain total collateral at this point
        //20% of yields goes to purseFactory admin
        uint256 yields_to_admin = (yields * 8) / 100;
        yields_to_members = yields - yields_to_admin;
        tokenInstance.transfer(ADMIN, yields_to_admin);

        total_returns_to_members = shares - yields_to_admin;
    }

    function calculateMissedDonationForUser(address _memberAdress)
        public
        view
        onlyPurseMember(_memberAdress)
        returns (
            address[] memory trimmed_members_who_didnt_donate_for_user,
            uint256
        )
    {
        address[] memory members_who_didnt_donate_for_user = new address[](
            members.length - 1
        );
        //    address[] memory members_list = members;
        uint256 count = 0;

        for (uint256 i = 0; i < members.length; i++) {
            if (
                members[i] != _memberAdress &&
               has_been_donated_for_by_member[_memberAdress][members[i]] == false
            ) {
                if(count == 0){
                     members_who_didnt_donate_for_user[0] = members[i];
                     count += 1;
                }
                else{
                    members_who_didnt_donate_for_user[count+1] = members[i];
                    count += 1;
                }
               
            }
        }

        // instantiate the return array with the length of number of members who didn't donate for this user
        trimmed_members_who_didnt_donate_for_user = new address[](count);
        for (uint256 j = 0; j < count; j++) {
            if (members_who_didnt_donate_for_user[j] != address(0)) {
                trimmed_members_who_didnt_donate_for_user[
                    j
                ] = members_who_didnt_donate_for_user[j];
            }
        }

        return (
            trimmed_members_who_didnt_donate_for_user,
            trimmed_members_who_didnt_donate_for_user.length *
                purse.deposit_amount
        );
    }

    function calculateMissedDonationByUser(address _memberAdress)
        public
        view
        onlyPurseMember(_memberAdress)
        returns (
            address[] memory trimmed_members_who_member_didnt_donate_for,
            uint256
        )
    {
        address[] memory members_who_member_didnt_donate_for = new address[](
            members.length - 1
        );
        //keep count of valid entry of members in the above array,
        uint256 count = 0;

        for (uint256 i = 0; i < members.length; i++) {
            if (
                members[i] != _memberAdress &&
                has_donated_for_member[members[i]][_memberAdress] == false
            ) {

                if(count == 0){
                    members_who_member_didnt_donate_for[0] = (members[i]);
                    count += 1;
                }else{
                    members_who_member_didnt_donate_for[count + 1] = (members[i]);
                    count += 1;
                }
               
            }
        }

        //instantiate the return array with the lenght of number of members who this member didn't donate for
        trimmed_members_who_member_didnt_donate_for = new address[](count);
        for (uint256 j = 0; j < count; j++) {
            if (members_who_member_didnt_donate_for[j] != address(0)) {
                trimmed_members_who_member_didnt_donate_for[
                    j
                ] = members_who_member_didnt_donate_for[j];
            }
        }

        return (
            trimmed_members_who_member_didnt_donate_for,
            trimmed_members_who_member_didnt_donate_for.length *
                purse.deposit_amount
        );
    }

    function withdrawCollateralAndYields() public onlyPurseMember(msg.sender) {
        require(
            hasWithdrawnCollateralAndYield[msg.sender] == false,
            "You have withdrawn your collateral and yields already"
        );

        // calculate the amount of rounds this user missed
        (, uint256 amountToBeDeducted) = calculateMissedDonationByUser(
            msg.sender
        );

        //calculate amount of donatons to user that was missed
        (, uint256 amountToBeAdded) = calculateMissedDonationForUser(
            msg.sender
        );

        uint256 intendedTotalReturnsForUser = (purse.required_collateral) +
            (yields_to_members / purse.max_member_num);

        uint256 finalTotalReturnsToUser = intendedTotalReturnsForUser +
            amountToBeAdded -
            amountToBeDeducted;

        hasWithdrawnCollateralAndYield[msg.sender] = true;
        tokenInstance.transfer(msg.sender, finalTotalReturnsToUser);
    }

    // returns current round details, the member who is meant for the round, current round and time before next round-
    function currentRoundDetails()
        public
        view
        returns (
            address,
            uint256,
            uint256
        )
    {
        require(purse.purseState == PurseState.Closed, "rounds yet to start");
        // a round should span for the time of "interval" set upon purse creation

        //calculte how many of the "intervals" is passed to get what _position/round
        uint256 roundPassed = (block.timestamp - purse.timeStarted) /
            purse.time_interval;

        uint256 currentRound = roundPassed + 1;
        uint256 timeForNextRound = purse.timeStarted +
            (currentRound * purse.time_interval);

        //current round is equivalent to position
        address _member = positionToUser[currentRound];

        return (_member, currentRound, timeForNextRound);
    }

    function purseMembers() public view returns (address[] memory) {
        return members;
    }
}
