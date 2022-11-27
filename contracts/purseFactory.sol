// SPDX-License-Identifier: MIT
pragma solidity 0.8.1;
import "./purse.sol";

contract PurseFactory {
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
    mapping(address => uint256) id_to_purse;
    mapping(address => uint256) public purseToChatId;

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
        purse_count++;
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

    function allPurse() public view returns (address[] memory) {
        return _list_of_purses;
    }
}
