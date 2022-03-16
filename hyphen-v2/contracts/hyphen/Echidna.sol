// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./SourceCode.sol";

interface iHevm {
    function warp(uint256 x) external;

    function sign(uint256 sk, bytes32 digest)
        external
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        );

    // function addr(uint256 sk) external returns (address addr);
}

contract SvgHelperBaseSubClass is SvgHelperBase {
    constructor() SvgHelperBase(18) {}

    function getChainName() public view override returns (string memory) {
        return "custom-chain";
    }

    function getTokenSvg(
        uint256 _tokenId,
        uint256 _suppliedLiquidity,
        uint256 _totalSuppliedLiquidity
    ) public view override returns (string memory) {
        return "<svg></svg>";
    }
}

contract SvgHelperInterfaceContract is ISvgHelper {
    function backgroundUrl() external view override returns (string memory) {
        return "http://image.com";
    }

    function getTokenSvg(
        uint256 _tokenId,
        uint256 _suppliedLiquidity,
        uint256 _totalSuppliedLiquidity
    ) external view override returns (string memory) {
        return "<svg></svg>";
    }

    function getAttributes(uint256 _suppliedLiquidity, uint256 _totalSuppliedLiquidity)
        external
        view
        override
        returns (string memory)
    {
        "some attrs";
    }

    function getDescription(uint256 _suppliedLiquidity, uint256 _totalSuppliedLiquidity)
        external
        view
        override
        returns (string memory)
    {
        return "the desc";
    }

    function getChainName() external view override returns (string memory) {
        return "custom-chain";
    }

    function owner() external view override returns (address) {
        return address(0);
    }

    function renounceOwnership() external override {
        // do nothing
    }

    function setBackgroundPngUrl(string memory _backgroundPngUrl) external override {
        // do nothing
    }

    function transferOwnership(address newOwner) external override {
        // do nothing
    }
}

contract Echidna {
    LPToken lpToken;
    LiquidityProviders liquidityProviders;
    LiquidityPool liquidityPool;
    TokenManager tokenManager;
    WhitelistPeriodManager whitelistPeriodManager;
    ExecutorManager executorManager;
    ERC20Token token;
    SvgHelperBaseSubClass svgHelperBase;
    ISvgHelper svgHelperContract;
    iHevm vm;
    address[] callers;

    event String(string);
    event Uint(uint256);
    event Address(address);

    constructor() {
        vm = iHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        lpToken = new LPToken();
        liquidityProviders = new LiquidityProviders();
        liquidityPool = new LiquidityPool();
        tokenManager = new TokenManager(address(this));
        whitelistPeriodManager = new WhitelistPeriodManager();
        executorManager = new ExecutorManager();
        token = new ERC20Token();
        svgHelperBase = new SvgHelperBaseSubClass();
        svgHelperContract = new SvgHelperInterfaceContract();
        callers.push(address(0x1000));
        callers.push(address(0x2000));
        callers.push(address(0x3000));
        whitelistPeriodManager.initialize(
            address(this),
            address(liquidityProviders),
            address(tokenManager),
            address(lpToken),
            address(this)
        );
        liquidityPool.initialize(
            address(executorManager),
            address(this),
            address(this),
            address(tokenManager),
            address(liquidityProviders)
        );
        liquidityProviders.initialize(address(this), address(lpToken), address(tokenManager), address(this));
        lpToken.initialize(
            "Test Token",
            "TST",
            address(this),
            address(this),
            address(token),
            svgHelperContract,
            address(liquidityProviders),
            address(whitelistPeriodManager)
        );
        // lpToken.setLiquidityProviders(address(liquidityProviders));
        // lpToken.setWhiteListPeriodManager(address(whitelistPeriodManager));
        // lpToken.setSvgHelper(address(token), svgHelperContract);
    }

    function warp(uint256 x) public {
        vm.warp(block.timestamp + (x % 10000));
    }

    function testLPDeposit(uint256 amount, address receiver) public {
        token.mint(address(this), amount);
        token.approve(address(liquidityPool), amount);

        tokenManager.addSupportedToken(address(token), 0, type(uint256).max, 0, 1999);
        try liquidityPool.depositErc20(block.chainid, address(token), receiver, amount, "test") {
            assert(token.balanceOf(address(this)) == 0);
            assert(token.balanceOf(address(receiver)) == amount);
            assert(liquidityProviders.getCurrentLiquidity(address(token)) == amount);
        } catch {
            amount == 0 || receiver == address(0) ? assert(true) : assert(false);
        }
    }

    function testAddLiquidity(uint256 amount) public {
        token.mint(address(this), amount);
        token.approve(address(liquidityProviders), amount);
        tokenManager.addSupportedToken(address(token), 0, type(uint256).max, 0, 20000);
        try liquidityProviders.addTokenLiquidity(address(token), amount) {
            assert(lpToken.exists(1));
            assert(liquidityProviders.getSuppliedLiquidityByToken(address(token)) == (amount * 1e18));
            assert(liquidityProviders.getTotalReserveByToken(address(token)) == (amount * 1e18));
            assert(liquidityProviders.getCurrentLiquidity(address(token)) == (amount * 1e18));
        } catch {
            amount == 0 ? assert(true) : assert(false);
        }
    }

    function testIncreaseLiquidity(uint256 amount) public {
        uint256 beforeLiquidity = liquidityProviders.getSuppliedLiquidityByToken(address(token));
        uint256 beforeReserves = liquidityProviders.getTotalReserveByToken(address(token));
        uint256 beforeCurrent = liquidityProviders.getCurrentLiquidity(address(token));
        testAddLiquidity(amount);
        token.mint(address(this), amount);
        try liquidityProviders.increaseTokenLiquidity(1, amount) {
            emit Uint(liquidityProviders.getFeeAccumulatedOnNft(1));
            emit Uint(liquidityProviders.getTokenPriceInLPShares(address(token)));
            assert(liquidityProviders.getCurrentLiquidity(address(token)) == beforeCurrent + (amount * 1e18));

            assert(liquidityProviders.getSuppliedLiquidityByToken(address(token)) == beforeLiquidity + (amount * 1e18));
            assert(liquidityProviders.getTotalReserveByToken(address(token)) == beforeReserves + (amount * 1e18));
        } catch {
            assert(false);
        }
    }

    function testClaimFee(uint256 amount) public {
        testAddLiquidity(amount);
        try liquidityProviders.claimFee(1) {
            assert(token.balanceOf(address(this)) > 0);
        } catch {
            amount == 0 ? assert(true) : assert(false);
        }
    }

    function testRemoveLiquidity(uint256 amount) public {
        testAddLiquidity(amount);
        try liquidityProviders.removeLiquidity(1, amount) {
            assert(!lpToken.exists(1));
            assert(liquidityProviders.getSuppliedLiquidityByToken(address(token)) == 0);
            assert(liquidityProviders.getTotalReserveByToken(address(token)) == 0);
            assert(liquidityProviders.getCurrentLiquidity(address(token)) == 0);
        } catch {
            amount == 0 ? assert(true) : assert(false);
        }
    }
}
