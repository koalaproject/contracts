pragma solidity =0.6.6;

pragma experimental ABIEncoderV2;

import "../../utils/FixedPoint.sol";

import "../apis/cherry/ICherryFactory.sol";
import "../apis/cherry/ICherryPair.sol";
import "../apis/cherry/CherryOracleLibrary.sol";
import "../apis/cherry/CherryLibrary.sol";

import "../interfaces/IPriceOracle.sol";

import "../../openzeppelin/contracts/access/OwnableUpgradeSafe.sol";
import "../../openzeppelin/contracts/token/ERC20/ERC20.sol";

// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract CherryPriceOracle is OwnableUpgradeSafe, PriceOracle {
    using FixedPoint for *;

    uint public constant PERIOD = 1 hours;

    struct Oracle {
        address token0;
        address token1;
        uint price0CumulativeLast;
        uint price1CumulativeLast;
        uint32 blockTimestampLast;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
    }

    address public factory;
    // pair => price oracle
    mapping(address => Oracle) public oracles;
    address[] public pairs;

    function initialize(address _factory) external initializer {
        OwnableUpgradeSafe.__Ownable_init();
        factory = _factory;
    }

    function addOracle(address tokenA, address tokenB) external onlyOwner {
        ICherryPair _pair = ICherryPair(CherryLibrary.pairFor(factory, tokenA, tokenB));
        Oracle storage oracle = oracles[address(_pair)];
        require(oracle.blockTimestampLast == 0, "duplicate pair for oracel");

        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, 'CherryPriceOracle: NO_RESERVES'); // ensure that there's liquidity in the pair

        oracle.token0 = _pair.token0();
        oracle.token1 = _pair.token1();
        oracle.price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        oracle.price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        oracle.blockTimestampLast = blockTimestampLast;

        pairs.push(address(_pair));
    }

    function pairLength() public view returns(uint256) {
        return pairs.length;
    }

    function update(uint256 offset, uint256 size) external {
        for (uint256 idx = offset; idx < offset + size; ++idx)
        {
            address pair = pairs[idx];
            if (pair == address(0)) break;
            Oracle storage oracle = oracles[pair];

            (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
                CherryOracleLibrary.currentCumulativePrices(address(pair));
            uint32 timeElapsed = blockTimestamp - oracle.blockTimestampLast; // overflow is desired

            // ensure that at least one full period has passed since the last update
            if (oracle.price0Average._x != 0) // ignore first update
            {
                require(timeElapsed >= PERIOD, 'CherryPriceOracle: PERIOD_NOT_ELAPSED');
            }

            // overflow is desired, casting never truncates
            // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
            oracle.price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - oracle.price0CumulativeLast) / timeElapsed));
            oracle.price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - oracle.price1CumulativeLast) / timeElapsed));

            oracle.price0CumulativeLast = price0Cumulative;
            oracle.price1CumulativeLast = price1Cumulative;
            oracle.blockTimestampLast = blockTimestamp;
        }
    }

    /// @dev Return the wad price of token0/token1, multiplied by 1e18
    /// NOTE: (if you have 1 token0 how much you can sell it for token1)
    function getPrice(address token0, address token1) external view override returns (uint256 price, uint256 lastUpdate) {
        ICherryPair _pair = ICherryPair(CherryLibrary.pairFor(factory, token0, token1));
        Oracle memory oracle = oracles[address(_pair)];
        require(oracle.blockTimestampLast != 0, "CherryPriceOracle: oracle not exists");

        uint8 decimals = ERC20(token0).decimals();
        uint256 amountIn = uint256(10) ** decimals;
        
        if (oracle.token0 == token0) {
            price = oracle.price0Average.mul(amountIn).decode144();
        } else {
            require(oracle.token0 == token1, 'CherryPriceOracle: INVALID_TOKEN');
            price = oracle.price1Average.mul(amountIn).decode144();
        }

        require(price != 0, "CherryPriceOracle::getPrice:: bad price data");
        return (price, oracle.blockTimestampLast);
    }
}