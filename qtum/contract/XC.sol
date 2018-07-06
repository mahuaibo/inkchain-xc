pragma solidity ^0.4.19;

import "./XCInterface.sol";

import "./Token.sol";

import "./XCPlugin.sol";

import "./SafeMath.sol";

contract XC is XCInterface {

    /**
     * Contract Administrator
     * @field status Contract external service status.
     * @field platformName Current contract platform name.
     * @field compareSymbol Current compare symbol.
     * @field account Current contract administrator.
     */
    struct Admin {
        uint8 status;
        bytes32 platformName;
        bytes2 compareSymbol;
        address account;
    }

    Admin private admin;

    uint public lockBalance;

    Token private token;

    XCPlugin private xcPlugin;

    event Lock(bytes32 toPlatform, address toAccount, bytes32 value, bytes32 tokenSymbol);

    event Unlock(string txid, bytes32 fromPlatform, address fromAccount, bytes32 value, bytes32 tokenSymbol);

    constructor() public {
        init();
    }

    /**
     * TODO Parameters that must be set before compilation
     * $Init admin.status
     * $Init admin.platformName
     * $Init admin.account
     * $Init lockBalance
     * $Init token
     * $Init xcPlugin
     */
    function init() internal {
        // Admin {status | platformName | compareSymbol | account}
        admin.status = 3;
        admin.platformName = "QTUM";
        admin.account = msg.sender;
        admin.compareSymbol = "-=";
        lockBalance = 655262036118918764;
        token = Token(0xfe59cbc1704e89a698571413a81f0de9d8f00c69);
        xcPlugin = XCPlugin(0xa86608f3bd6e65e7ecd2f473735191756abab48e);
    }

    function setStatus(uint8 status) onlyAdmin external {
        require(status <= 3);
        if (admin.status != status) {
            admin.status = status;
        }
    }

    function getStatus() external view returns (uint8) {
        return admin.status;
    }

    function getPlatformName() external view returns (bytes32) {
        return admin.platformName;
    }

    function setAdmin(address account) onlyAdmin nonzeroAddress(account) external {
        if (admin.account != account) {
            admin.account = account;
        }
    }

    function getAdmin() external view returns (address) {
        return admin.account;
    }

    function setToken(address account) onlyAdmin nonzeroAddress(account) external {
        if (token != account) {
            token = Token(account);
        }
    }

    function getToken() external view returns (address) {
        return token;
    }

    function setXCPlugin(address account) onlyAdmin nonzeroAddress(account) external {
        if (xcPlugin != account) {
            xcPlugin = XCPlugin(account);
        }
    }

    function getXCPlugin() external view returns (address) {
        return xcPlugin;
    }

    function setCompare(bytes2 symbol) onlyAdmin external {
        require(symbol == "+=" || symbol == "-=");
        if (admin.compareSymbol != symbol) {
            admin.compareSymbol = symbol;
        }
    }

    function getCompare() external view returns (bytes2) {
        return admin.compareSymbol;
    }

    function lock(address toAccount, uint value) nonzeroAddress(toAccount) external {
        require(admin.status == 2 || admin.status == 3);
        require(xcPlugin.getStatus());
        require(value > 0);
        uint allowance = token.allowance(msg.sender, this);
        require(toCompare(allowance, value));
        bool success = token.transferFrom(msg.sender, this, value);
        require(success);
        lockBalance = SafeMath.add(lockBalance, value);
        emit Lock(xcPlugin.getTrustPlatform(), toAccount, bytes32(value), xcPlugin.getTokenSymbol());
    }

    function unlock(string txid, address fromAccount, address toAccount, uint value) nonzeroAddress(toAccount) external {
        require(admin.status == 1 || admin.status == 3);
        require(xcPlugin.getStatus());
        require(value > 0);
        bool complete;
        bool verify;
        (complete, verify) = xcPlugin.verifyProposal(fromAccount, toAccount, value, txid);
        require(verify && !complete);
        uint balance = token.balanceOf(this);
        require(toCompare(balance, value));
        token.transfer(toAccount, value);
        require(xcPlugin.commitProposal(txid));
        lockBalance = SafeMath.sub(lockBalance, value);
        emit Unlock(txid, xcPlugin.getTrustPlatform(), fromAccount, bytes32(value), xcPlugin.getTokenSymbol());
    }

    function withdraw(address account, uint value) onlyAdmin nonzeroAddress(account) external {
        require(value > 0);
        uint balance = token.balanceOf(this);
        require(toCompare(SafeMath.sub(balance, lockBalance), value));
        token.transfer(account, value);
    }

    function transfer(address account, uint value) onlyAdmin external payable {
        require(account != address(0));
        require(value > 0 && value <= address(this).balance);
        account.transfer(value);
    }

    modifier onlyAdmin {
        require(admin.account == msg.sender);
        _;
    }

    modifier nonzeroAddress(address account) {
        require(account != address(0));
        _;
    }

    /**
     *   ######################
     *  #  private function  #
     * ######################
     */

    function toCompare(uint f, uint s) internal view returns (bool) {
        if (admin.compareSymbol == "-=") {
            return f > s;
        } else if (admin.compareSymbol == "+=") {
            return f >= s;
        } else {
            return false;
        }
    }
}