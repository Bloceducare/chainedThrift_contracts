// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// @title purse contract
// @author Noah Jeremiah

// @notice interface bentobox
interface IBentoxBox {
    // @notice Returns balance of user token in bentobox
    function balanceOf(address, address) external view returns (uint256);

    // @notice deposits collateral to bentobox
    // @params token_: token to be deposited
    // @params  from: owner of tokens to be deposited
    // @params to: contract to receive token
    // @params amount: amount of token to be deposited
    // @params share: token  reward  which iz zero initially
    // @return  amountOut, shareOut

    function deposit(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    // @notice withdraw token from bentobox
    // @params token_: token to be deposited
    // @params  from: owner of tokens to be deposited
    // @params to: contract to receive token
    // @params amount: amount of token to be deposited
    // @params share: token  reward  which iz zero initially
    // @return  amountOut shareOut

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

    // @notice Represents states of thrift purse
    // purse state can be open, closed, or terminated
    enum PurseState {
        Open,
        Closed,
        Terminate
    }

    // @notice purse structs
    struct Purse {
        PurseState purseState; //purseState
        uint256 time_interval; //days interval between contribution
        uint256 timeCreated; // time when thrift purse was created
        uint256 timeStarted; //time when thrift starts. Thrift can only start when member of purse are completed
        uint256 contract_total_deposit_balance; // total amount contribution in the thrift purse
        uint256 contract_total_collateral_balance; // total amount of collateral in thrift contract
        uint256 deposit_amount; //the deployer of each purse will set this amount which every other person to join will deposit
        uint256 max_member_num; // maximum member in a purse
        uint256 required_collateral; //collateral to be paid by user upon joining a purse
        uint256 purseId; // purseId
        // uint256 increment_in_membership;
        uint256 num_of_members_who_has_recieved_funds;
        address _address_of_token; //addres of acceptable erc-20 token
        address purseAddress; // purse address
    }
    // @dev Map a user address to bool to check if user is a member of purse (status)
    mapping(address => bool) public isPurseMember;
    //@dev Map  a user to collateral deposited
    mapping(address => uint256) public memberToCollateral;
    // @dev Map a user to amount deposited
    mapping(address => uint256) public memberToDeposit;
    // @dev Map a member address to check wether he has recieved a round of contribution or not
    mapping(address => bool) public member_has_recieved;
    // @dev Map a member address to another member address to check whether user has deposited for member
    mapping(address => mapping(address => bool)) public has_donated_for_member;
    //  @dev Map  a member address to claimable amount
    mapping(address => uint256) public userClaimableDeposit;
    // @dev Maps a member address to check wether he has recieved a round of contribution or not
    mapping(address => bool) public approve_To_Claim_Without_Complete_Votes;
    // @dev Map  member address to vote count to determine if you user can receive fund
    mapping(address => uint256) public votes_for_member_to_recieve_funds;
    // @dev  Map member address to bool; whether to close voting
    mapping(address => bool) public member_close_Purse_Vote;
    // @dev  Map member address to bool; whether to re-open voting
    mapping(address => bool) public member_reOpen_Purse_Vote;
    // @dev  Map member address to bool; whether to terminate voting
    mapping(address => bool) public member_terminate_PurseVote;
    // @dev Map member address to bool; to check whether user has withdrawn collateral and yield
    mapping(address => bool) public hasWithdrawnCollateralAndYield;
    // @dev Map member to uint256; to represnt userPosition
    mapping(address => uint256) public userPosition;
    // @dev Map position to user
    mapping(uint256 => address) public positionToUser;

    address[] public members; //arrays of members in a purse
    uint256 public total_returns_to_members; // total_returns_to_members
    uint256 public yields_to_members; // yields_to_members

    // @notice struct to represent member votes
    struct MemberVoteForPurseState {
        uint256 voteToClose;
        uint256 voteToReOpen;
        uint256 voteToTerminate;
    }



    IERC20 tokenInstance;
    Purse public purse; //instantiate struct purse
    MemberVoteForPurseState public memberVoteForPurseState;

    address admin = 0x9dc821bc9B379a002E5bD4A1Edf200c19Bc5F9CA;

    //@dev instantiate IBentoxBox on mumbai
    address bentoBox_address = 0xF5BCE5077908a1b7370B9ae04AdC565EBd643966;
    IBentoxBox bentoBoxInstance = IBentoxBox(bentoBox_address);

    // @notice event emitted when purse is created
    event PurseCreated(
        address purseAddress,
        address indexed _creator,
        uint256 starting_amount,
        uint256 max_members,
        uint256 indexed _time_created
    );
    // @notice event emitted when purse member vote
    event MemberVotedFor(
        address indexed _member,
        uint256 indexed _currentVotesFor
    );
    // @notice event emitted when members deposit for another purse member during thrift round
    event DonationDeposited(
        address indexed _member,
        uint256 _amount,
        address indexed purseAddress,
        address _recipient
    );
    // @notice event emitted when member claim contribution
    event ClaimedFull(
        address indexed _member,
        address indexed purseAddress,
        uint256 _amount,
        uint256 dateClaimed
    );
    // @notice event emitted when member claims part of contribution
    event ClaimedPart(
        address indexed _member,
        address indexed purseAddress,
        uint256 _amount,
        uint256 dateClaimed
    );
    modifier onlyPurseMember(address _address) {
        require(isPurseMember[msg.sender] == true, "only purse members please");
        _;
    }

    //@notice deposit of collateral for creator happens in token factory- see createPurse function
    // @params _creator: purse creator
    // @params _max_member: maximum member that can join a purse_count
    // @params time_interval: days interval between contribution
    // @params _tokenAddress: address of ERC20 token (chainedThrift supports usdc)
    // @params position: order in which user wants to receive thrift contribution
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
        //@dev  require(tokenInstance.balanceOf(address(this)) == (_amount + required_collateral), 'deposit of funds and collateral not happening, ensure you are deploying fron PurseFactory Contract');
        memberToDeposit[_creator] = _amount; //
        memberToCollateral[_creator] = _required_collateral;
        userPosition[_creator] = _position;
        positionToUser[_position] = _creator;
        members.push(_creator); //push member to array of members

        //@dev convert time_interval to
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

        @params _position: order in which user wants to receive thrift contribution
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

        for (uint8 i = 0; i < members.length; i++) {
            require(_position != userPosition[members[i]], "position taken");
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

        //@dev close purse if max_member_num is reached
        if (members.length == purse.max_member_num) {
            purse.purseState = PurseState.Closed;
            purse.timeStarted = block.timestamp;
        }
    }

    /*
@notice Deposit funds for member when a new thrift round start
@params _member: member to deposit for.
 */

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

    // @notice member who have been voted for as next will be the one to claim
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

    /* @notice this function is meant to give the contract a go-ahead to disburse funds to a member even though he doesnt have complete votes_for_member_to_recieve_funds
      this for instance where a member(s) seem unresponsive in the purse group to vote for another person
    @param _member: member address to vote for
    */
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

    // @notice deposit purse collateral to bentobox
    function deposit_funds_to_bentoBox() public onlyPurseMember(msg.sender) {
        require(
            members.length == purse.max_member_num,
            "members to be in purse are yet to be completed, so collaterals are not complete"
        );
        uint256 MAX_UINT256 = purse.contract_total_collateral_balance;
        tokenInstance.approve(bentoBox_address, MAX_UINT256);
        bentoBoxInstance.deposit(
            tokenInstance,
            address(this),
            address(this),
            purse.contract_total_collateral_balance,
            0
        );

        purse.contract_total_collateral_balance = 0;
    }

    // @notice Balance of purse in bentobox
    // @return Returns balance of thrift purse in bentobox
    function bentoBox_balance() public view returns (uint256) {
        uint256 bento_box_balance = bentoBoxInstance.balanceOf(
            purse._address_of_token,
            address(this)
        );
        return bento_box_balance;
    }

    //@dev any member can call this function
    function withdraw_funds_from_bentoBox() public onlyPurseMember(msg.sender) {
        //@dev   require(block.timestamp >= (purse.time_interval * max_member_num), 'Not yet time for withdrawal');
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
        //@dev bentoBox withdraw functiosn returns 2 values, in this cares, shares will be what has the entire values- our collateral deposits plus yields
        uint256 shares;
        uint256 amount;
        (amount, shares) = bentoBoxInstance.withdraw(
            tokenInstance,
            address(this),
            address(this),
            0,
            bento_box_balance
        );
        //@dev calculate yields
        uint256 yields = shares -
            (purse.required_collateral * purse.max_member_num); //shares will remain total collateral at this point
        //@dev 20% of yields goes to purseFactory admin
        uint256 yields_to_admin = (yields * 8) / 100;
        yields_to_members = yields - yields_to_admin;
        tokenInstance.transfer(admin, yields_to_admin);

        total_returns_to_members = shares - yields_to_admin;
    }

    // @notice calculate missed donation for user
    // params: _memberAddress: member address
    // returns: Return array of address and amount
    function calculateMissedDonationForUser(address _memberAdress)
        public
        view
        onlyPurseMember(_memberAdress)
        returns (address[] memory, uint256)
    {
        address[] memory members_who_didnt_donate_for_user = new address[](
            members.length - 1
        );

        for (uint256 i = 0; i < members.length; i++) {
            if (
                members[i] != _memberAdress &&
                has_donated_for_member[members[i]][_memberAdress] == false
            ) {
                members_who_didnt_donate_for_user[i] = (members[i]);
            }
        }

        return (
            members_who_didnt_donate_for_user,
            members_who_didnt_donate_for_user.length * purse.deposit_amount
        );
    }

    // @notice calculate missed donation by a particular user
    // params: _memberAddress: member address
    // returns: Return array of address and amount
    function calculateMissedDonationByUser(address _memberAdress)
        public
        view
        onlyPurseMember(_memberAdress)
        returns (address[] memory, uint256)
    {
        address[] memory members_who_member_didnt_donate_for = new address[](
            members.length - 1
        );

        for (uint256 i = 0; i < members.length; i++) {
            if (
                members[i] != _memberAdress &&
                has_donated_for_member[_memberAdress][members[i]] == false
            ) {
                members_who_member_didnt_donate_for[i] = (members[i]);
            }
        }

        return (
            members_who_member_didnt_donate_for,
            members_who_member_didnt_donate_for.length * purse.deposit_amount
        );
    }

    // @notice
    function withdrawCollateralAndYields() public onlyPurseMember(msg.sender) {
        require(
            hasWithdrawnCollateralAndYield[msg.sender] == false,
            "You have withdrawn your collateral and yields already"
        );

        //@dev calculate the amount of rounds this user missed
        (, uint256 amountToBeDeducted) = calculateMissedDonationByUser(
            msg.sender
        );

        //@dev calculate amount of donatons to user that was missed
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

    // @notice Thrift round details
    // @returns Returns current round details, the member who is meant for the round, current round and time before next round
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
        //@dev  a round should span for the time of "interval" set upon purse creation

        //@dev calculte how many of the "intervals" is passed to get what _position/round
        uint256 roundPassed = (block.timestamp - purse.timeStarted) /
            purse.time_interval;

        uint256 currentRound = roundPassed + 1;
        uint256 timeForNextRound = purse.timeStarted +
            (currentRound * purse.time_interval);

        //@dev current round is equivalent to position
        address _member = positionToUser[currentRound];

        return (_member, currentRound, timeForNextRound);
    }

    //@notice  Returns address of purse members
    // @returns Returns array of addresses
    function purseMembers() public view returns (address[] memory) {
        return members;
    }
}
