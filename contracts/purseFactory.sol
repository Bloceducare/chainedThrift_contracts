// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;
import "./purse.sol";


// @title Deploys new thrift purse contract
// @author Noah Jeremiah

contract PurseFactory {
    // @dev event emitted when a purse is created 
    event PurseCreated(
        address _creator,
        uint256 starting_amount,
        uint256 max_members,
        uint256 _time_created,
        address tokenAddress,
        address purseAddress
    );

    //0xf0169620C98c21341aBaAeaFB16c69629Dafc06b

    uint256 public purse_count;
    address[] _list_of_purses; //this array contains addresss of each purse
    // @dev mapping of thrift purse address to id
    mapping(address => uint256) id_to_purse;
    // @dev mapping of thrift purse address to chatId
    mapping(address => uint256) public purseToChatId;

    // @notice create new thrift purse
    // @params contribution_amount: desired amount user want to contribute
    // @params _max_member: maximum member that can join a purse_count
    // @params time_interval: days interval between contribution
    // @params chatId: user chatId
    // @params _tokenAddress: address of ERC20 token (chainedThrift supports usdc)
    // @params position: order in which user wants to receive thrift contribution
    function createPurse(
        uint256 contribution_amount,
        uint256 _max_member,
        uint256 time_interval,
        uint256 chatId,
        address _tokenAddress,
        uint8 _position
    ) public {
        PurseContract purse = new PurseContract(
            msg.sender,
            contribution_amount,
            _max_member,
            time_interval,
            _tokenAddress,
            _position
        );
        IERC20 tokenInstance = IERC20(_tokenAddress);
        uint256 _collateral = contribution_amount * (_max_member - 1);
        //purse factory contract should be approved
        require(
            tokenInstance.transferFrom(
                msg.sender,
                address(purse),
                (_collateral)
            ),
            "transfer to purse not successful"
        );
        _list_of_purses.push(address(purse));
        purse_count = purse_count++;
        id_to_purse[address(purse)] = purse_count;
        purseToChatId[address(purse)] = chatId;

        emit PurseCreated(
            msg.sender,
            contribution_amount,
            _max_member,
            block.timestamp,
            _tokenAddress,
            address(purse)
        );
    }

    //@notice Returns purse address
    //@ Returns array of address
    function allPurse() public view returns (address[] memory) {
        return _list_of_purses;
    }
}
