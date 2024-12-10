// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {WETH} from "solady/tokens/WETH.sol";
import {IUniswapV3Factory} from "uni-v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3SwapCallback} from "uni-v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool,IUniswapV3PoolState} from "uni-v3-core/interfaces/IUniswapV3Pool.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";


// The libraries from Uniswap V3 codebases are not compatibale with our version of solc
// These libraries are rewritten in uniswap v4 and the compiler version is also updated.
// So, most of the libraries we use are from uniswap v4 codebase which are compatible with our version of solc
import {FullMath} from "uni-v4-core/libraries/FullMath.sol";
import {TickMath} from "uni-v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "uni-v4-core/libraries/SqrtPriceMath.sol";
import {FixedPoint96} from "uni-v4-core/libraries/FixedPoint96.sol";
import {LiquidityAmounts} from "uni-v4-periphery/libraries/LiquidityAmounts.sol";


// our test token 
contract TestToken is ERC20 {
    constructor(){
        // mint all to the msg.sender
        _mint(msg.sender, 1e9 ether);
    }

    function name() public view virtual override returns (string memory) {
        return "token";
    }

    function symbol() public view virtual override returns (string memory) {
        return "symbol";
    }
}




// simulate buy: forge script -vvvv --tc Sim  --rpc-url https://rpc.ankr.com/base  --sig 'run(bool)' script/sim.s.sol  true
// simulate sell: forge script -vvvv --tc Sim  --rpc-url https://rpc.ankr.com/base  --sig 'run(bool)' script/sim.s.sol  false
contract Sim is Script {

    WETH internal constant weth = WETH(payable(0x4200000000000000000000000000000000000006));
    IUniswapV3Factory internal constant v3Factory = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    INonfungiblePositionManager internal constant nfpm = INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    // fee tier 
    uint24 internal constant FEE_TIER = 10000; 
    int24 internal constant TICK_SPACING = 200;

    /// 
    /// @param buy | simulate buying after listed on Uniswap, otherwise simulate selling
    function run(bool buy) public {

        // Deploy the token and mint all tokens to msg.sender
        TestToken token = new TestToken();

        // Create a Uniswap V3 pool
        IUniswapV3Pool pool = IUniswapV3Pool(v3Factory.createPool(address(token), address(weth), FEE_TIER));


        // Let's assume we have raised 3 ETH by selling 30% of the token supply 
        // Then we have 70% supply of the token left. 
        // Let's assume we have taken a 0.2 ETH fee, so we have only 2.8 ETH left 
        // 
        // If the cost of every contributor is the same, when they dump the token, we hope they
        // can get almost the same price of: 
        //     - 2.8 / 30% suppy = 2.8 / (0.3e9) = 0.0000000094 ETH / token 
        //
        // Let's use this as our initial price 
        // 
        // The initial price of the token denominated by ETH in wad 
        // let's use 0.0000000094 ETH/Token here 
        uint256 initialPrice = 0.0000000094 ether; 



        // Step1: let's initialize the pool 
        {
            if(address(token) < address(weth)){
                // decimal(wad) price to sqrtPriceX96
                (uint160 sqrtPriceX96,) = _toPriceX96(initialPrice, TICK_SPACING, false);

                // initialize the pool 
                pool.initialize(sqrtPriceX96);
            }else{
                // the price of WETH enominated by token is 1/initialPrice
                (uint160 sqrtPriceX96,) = _toPriceX96(FixedPointMathLib.divWad(1 ether, initialPrice), TICK_SPACING, true);

                // initialize the pool 
                pool.initialize(sqrtPriceX96);
            }
        }


        // Let's create two positions
        //  - position 1: WITH only ETH, 2.8 ETH added to the concentrated range around the initial price 
        //  - position 2: Token only, the remaining 70% supply of the token to the range of [initial price , +inf]

        // prepare
        weth.deposit{value: 2.8 ether}();
        weth.approve(address(nfpm), 2.8 ether); 
        token.approve(address(nfpm), 0.7e9 ether);


        // Step2: ETH only position 
        {
            // token is token0 
            if(address(token) < address(weth)){
                // decimal(wad) price to sqrtPriceX96
                (,int24 tick) = _toPriceX96(initialPrice, TICK_SPACING, false);  

                // we should add liquidity to  the range of [tick - tickSpacing, tick]
                // This is the most concentrated range around the initial price 
                // The liquidity should be 2.8 ETH
                (uint256 id,,,) = nfpm.mint(
                    INonfungiblePositionManager.MintParams({
                        token0: address(token),
                        token1: address(weth),
                        fee: FEE_TIER,
                        tickLower: tick - TICK_SPACING,  
                        tickUpper: tick, 
                        amount0Desired: 0, 
                        amount1Desired: 2.8 ether,
                        amount0Min: 0,
                        amount1Min: 0,
                        recipient: address(this),
                        deadline: block.timestamp
                    })
                );
            }else{
                // token is token1 
                // the price of WETH enominated by token is 1/initialPrice
                (,int24 tick) = _toPriceX96(FixedPointMathLib.divWad(1 ether, initialPrice), TICK_SPACING, true);  

                // we should add liquidity to  the range of [tick, tick + tickSpacing]
                // This is the most concentrated range around the initial price 
                // The liquidity should be 2.8 ETH
                (uint256 id,,,) = nfpm.mint(
                    INonfungiblePositionManager.MintParams({
                        token0: address(weth),
                        token1: address(token),
                        fee: FEE_TIER,
                        tickLower: tick,  
                        tickUpper: tick + TICK_SPACING, 
                        amount0Desired: 2.8 ether, 
                        amount1Desired: 0,
                        amount0Min: 0,
                        amount1Min: 0,
                        recipient: address(this),
                        deadline: block.timestamp
                    })
                );
            }
        }

        // step3: Token only position
        {
            // token is token0 
            if(address(token) < address(weth)){
                // decimal(wad) price to sqrtPriceX96
                (,int24 tick) = _toPriceX96(initialPrice, TICK_SPACING, true);  

                // we should add liquidity to  the range of [tick, MAX_TICK]
                // The liquidity should be 0.7e9 token
                (uint256 id,,,) = nfpm.mint(
                    INonfungiblePositionManager.MintParams({
                        token0: address(token),
                        token1: address(weth),
                        fee: FEE_TIER,
                        tickLower: tick,  
                        tickUpper: _snapToTickSpacing(TickMath.MAX_TICK, TICK_SPACING, false),
                        amount0Desired: 0.7e9 ether,
                        amount1Desired: 0,
                        amount0Min: 0,
                        amount1Min: 0,
                        recipient: address(this),
                        deadline: block.timestamp
                    })
                );
            }else{
                // token is token1 
                // the price of WETH enominated by token is 1/initialPrice
                (,int24 tick) = _toPriceX96(FixedPointMathLib.divWad(1 ether, initialPrice), TICK_SPACING, false);  

                // we should add liquidity to  the range of [MIN_TICK, tick]
                // The liquidity should be 0.7e9 token
                (uint256 id,,,) = nfpm.mint(
                    INonfungiblePositionManager.MintParams({
                        token0: address(weth),
                        token1: address(token),
                        fee: FEE_TIER,
                        tickLower: _snapToTickSpacing(TickMath.MIN_TICK, TICK_SPACING, true),
                        tickUpper: tick,
                        amount0Desired: 0,
                        amount1Desired: 0.7e9 ether,
                        amount0Min: 0,
                        amount1Min: 0,
                        recipient: address(this),
                        deadline: block.timestamp
                    })
                );
            }
        }



        // let's simulate users' dump/pump after the token being listed on Uniswap 

        if(buy){

            // simulate the pump 
            console2.log("let's simulate the pump...");

            // let buy 5 ETH each time, and buy total 100 ETH 
            
            uint256 totalBought = 0;
            uint256 ethSpent = 0; 
            uint256 ethPerSwap = 5 ether;

            while(ethSpent < 100 ether){
                // buy 
                (int256 amount0, int256 amount1) = pool.swap(
                    address(this),
                    address(weth) < address(token),
                    int256(ethPerSwap),
                    address(weth) < address(token)?TickMath.MIN_SQRT_PRICE + 1:TickMath.MAX_SQRT_PRICE - 1,
                    _getSwapOrMintCalldata(address(weth), address(token))
                );

                totalBought += (address(token) < address(weth)?uint256(-amount0):uint256(-amount1));
                ethSpent += ethPerSwap;

                // print the price after each bought 
                console2.log("after bought %18e eth, we have total bought %18e token, the price of token denominated in eth is %18e", ethSpent, totalBought, getPrice(address(pool)));
            }
        }else{
            // simulate the dump 
            console2.log("let's simulate the dump...");

            // approve all the circulating token to the pool 
            token.approve(address(pool), 0.3e9 ether);
            // let's sell all the token to the pool 
            // each time, we sell 0.5e8 token to the pool

            uint256 totalSold = 0; 
            uint256 soldPerSwap = 0.5e8 ether;

            while(totalSold < 0.3e9 ether){
                // sell 
                pool.swap(
                    address(this),
                    address(weth) > address(token),
                    int256(soldPerSwap),
                    address(weth) > address(token)?TickMath.MIN_SQRT_PRICE + 1:TickMath.MAX_SQRT_PRICE - 1,
                    _getSwapOrMintCalldata(address(weth), address(token))
                );      

                totalSold += soldPerSwap;

                // print the price after each sold 
                console2.log("after sold %18e token, the price of token denominated in eth is %18e", totalSold, getPrice(address(pool)));
            }
            
        }


    }


    /// A helper for computing the price of the "token" from a univ3 like pool
    /// @param pool the pool address
    /// @return price in wad demonimated by WETH
    function getPrice(address pool) internal view returns (uint256) {
        address token0 = IUniswapV3Pool(pool).token0();

        uint160 sqrtPriceX96;
        {
            (bool success, bytes memory data) =
                address(pool).staticcall(abi.encodeWithSelector(IUniswapV3PoolState.slot0.selector));
            if (success) {
                // let's treat all number as uint256, or the compiler generated validation code would
                // revert if feeProtocol is greater than uint16.MAX
                (sqrtPriceX96,,,,,,) = abi.decode(data, (uint160, int256, uint256, uint256, uint256, uint256, bool));
            } else {
                revert("getPoolInfo: failed to get pool info");
            }
        }

        // sqrtPriceX96 to price in wad
        uint256 token0SqrtPrice = (uint256(sqrtPriceX96) * 1e18) >> 96;

        uint256 tokenSqrtPrice =
            token0 != address(weth) ? token0SqrtPrice : FixedPointMathLib.divWad(1 ether, token0SqrtPrice);

        return FixedPointMathLib.mulWad(tokenSqrtPrice, tokenSqrtPrice);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // decode SwapCalldata
        (address token0, address token1) = abi.decode(data, (address, address));

        // amount0Delta
        if (amount0Delta > 0) {
            _sendTokenInCallback(token0, uint256(amount0Delta));
        } else {
            _receiveTokenInCallback(token0, uint256(-amount0Delta));
        }

        // amount1Delta
        if (amount1Delta > 0) {
            _sendTokenInCallback(token1, uint256(amount1Delta));
        } else {
            _receiveTokenInCallback(token1, uint256(-amount1Delta));
        }
    }

    receive() external payable {
        // do nothing
    }


    function _getSwapOrMintCalldata(address token0, address token1) internal pure returns (bytes memory) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        return abi.encode(token0, token1);
    }

    function _receiveTokenInCallback(address token, uint256 amount) internal {
        // if the token is not weth do nothing
        if (token != address(weth)) {
            return;
        }

        // if the token is weth, unwrap it
        weth.withdraw(amount);
    }

    function _sendTokenInCallback(address token, uint256 amount) internal {
        if (token == address(weth)) {
            // wrap before send
            weth.deposit{value: amount}();
        }

        ERC20(token).transfer(msg.sender, amount);
    }


    /// @dev price in wad to price in x96
    ///      The ticker would be rounded to multiple of tickSpacing
    function _toPriceX96(uint256 price, int24 tickSpacing, bool roundup)
        internal
        pure
        returns (uint160 sqrtPriceX96, int24 tick)
    {
        uint256 sqrtWad = FixedPointMathLib.sqrtWad(price);
        if (roundup) {
            sqrtWad += 1 wei;
        } else {
            sqrtWad -= 1 wei;
        }

        sqrtPriceX96 = uint160((sqrtWad << 96) / (1 ether));

        // round to multiple of tickSpacing

        tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        tick = _snapToTickSpacing(tick, tickSpacing, roundup);
        sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick);
    }

    function _snapToTickSpacing(int24 tick, int24 tickSpacing, bool up) internal pure returns (int24) {
        int24 rounded = (tick / tickSpacing) * tickSpacing;
        if (up && rounded < tick) rounded += tickSpacing;
        if (!up && rounded > tick) rounded -= tickSpacing;
        return rounded;
    }
}
