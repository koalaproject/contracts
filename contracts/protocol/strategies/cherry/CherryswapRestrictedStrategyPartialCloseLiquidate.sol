// SPDX-License-Identifier: MIT


pragma solidity 0.6.6;

import "../../../openzeppelin/contracts/utils/ReentrancyGuardUpgradeSafe.sol";
import "../../../openzeppelin/contracts/Initializable.sol";
import "../../../openzeppelin/contracts/access/OwnableUpgradeSafe.sol";

import "../../apis/cherry/ICherryFactory.sol";
import "../../apis/cherry/ICherryPair.sol";
import "../../apis/cherry/ICherryRouter02.sol";

import "../../interfaces/IStrategy.sol";
import "../../../utils/SafeToken.sol";
import "../../interfaces/IWorker.sol";

contract CherryswapRestrictedStrategyPartialCloseLiquidate is
  OwnableUpgradeSafe,
  ReentrancyGuardUpgradeSafe,
  IStrategy
{
  using SafeToken for address;

  ICherryFactory public factory;
  ICherryRouter02 public router;

  mapping(address => bool) public okWorkers;

  event CherryswapRestrictedStrategyPartialCloseLiquidateEvent(
    address indexed baseToken,
    address indexed farmToken,
    uint256 amounToLiquidate
  );

  /// @notice require that only allowed workers are able to do the rest of the method call
  modifier onlyWhitelistedWorkers() {
    require(
      okWorkers[msg.sender],
      "CherryswapRestrictedStrategyPartialCloseLiquidate::onlyWhitelistedWorkers:: bad worker"
    );
    _;
  }

  /// @dev Create a new liquidate strategy instance.
  /// @param _router The PancakeSwap Router smart contract.
  function initialize(ICherryRouter02 _router) public initializer {
    OwnableUpgradeSafe.__Ownable_init();
    ReentrancyGuardUpgradeSafe.__ReentrancyGuard_init();
    factory = ICherryFactory(_router.factory());
    router = _router;
  }

  /// @dev Execute worker strategy. Take LP token. Return  BaseToken.
  /// @param data Extra calldata information passed along to this strategy.
  function execute(
    address, /* user */
    uint256, /* debt */
    bytes calldata data
  ) external override onlyWhitelistedWorkers nonReentrant {
    // 1. Find out what farming token we are dealing with.
    (uint256 lpTokenToLiquidate, uint256 minBaseToken) = abi.decode(data, (uint256, uint256));
    IWorker worker = IWorker(msg.sender);
    address baseToken = worker.baseToken();
    address farmingToken = worker.farmingToken();
    ICherryPair lpToken = ICherryPair(factory.getPair(farmingToken, baseToken));
    // 2. Approve router to do their stuffs
    address(lpToken).safeApprove(address(router), uint256(-1));
    farmingToken.safeApprove(address(router), uint256(-1));
    // 3. Remove some LP back to BaseToken and farming tokens as we want to return some of the position.
    require(
      lpToken.balanceOf(address(this)) >= lpTokenToLiquidate,
      "CherryswapRestrictedStrategyPartialCloseLiquidate::execute:: insufficient LP amount recevied from worker"
    );
    router.removeLiquidity(baseToken, farmingToken, lpTokenToLiquidate, 0, 0, address(this), now);
    // 4. Convert farming tokens to baseToken.
    address[] memory path = new address[](2);
    path[0] = farmingToken;
    path[1] = baseToken;
    router.swapExactTokensForTokens(farmingToken.myBalance(), 0, path, address(this), now);
    // 5. Return all baseToken back to the original caller.
    uint256 balance = baseToken.myBalance();
    require(
      balance >= minBaseToken,
      "CherryswapRestrictedStrategyPartialCloseLiquidate::execute:: insufficient baseToken received"
    );
    SafeToken.safeTransfer(baseToken, msg.sender, balance);
    address(lpToken).safeTransfer(msg.sender, lpToken.balanceOf(address(this)));
    // 6. Reset approve for safety reason
    address(lpToken).safeApprove(address(router), 0);
    farmingToken.safeApprove(address(router), 0);

    emit CherryswapRestrictedStrategyPartialCloseLiquidateEvent(baseToken, farmingToken, lpTokenToLiquidate);
  }

  function setWorkersOk(address[] calldata workers, bool isOk) external onlyOwner {
    for (uint256 idx = 0; idx < workers.length; idx++) {
      okWorkers[workers[idx]] = isOk;
    }
  }
}
