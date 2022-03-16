// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

// import "./LiquidityProviders.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./metatx/ERC2771ContextUpgradeable.sol";

import "../security/Pausable.sol";
import "./interfaces/ILPToken.sol";
import "./interfaces/ITokenManager.sol";
import "./interfaces/IWhiteListPeriodManager.sol";
import "./interfaces/ILiquidityPool.sol";

contract LiquidityProviders is
    Initializable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable,
    OwnableUpgradeable,
    Pausable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant BASE_DIVISOR = 10**18;

    ILPToken internal lpToken;
    ILiquidityPool internal liquidityPool;
    ITokenManager internal tokenManager;
    IWhiteListPeriodManager internal whiteListPeriodManager;

    event LiquidityAdded(address indexed tokenAddress, uint256 indexed amount, address indexed lp);
    event LiquidityRemoved(address indexed tokenAddress, uint256 indexed amount, address indexed lp);
    event FeeClaimed(address indexed tokenAddress, uint256 indexed fee, address indexed lp, uint256 sharesBurnt);
    event FeeAdded(address indexed tokenAddress, uint256 indexed fee);
    event EthReceived(address indexed sender, uint256 value);
    event CurrentLiquidityChanged(address indexed token, uint256 indexed oldValue, uint256 indexed newValue);

    // LP Fee Distribution
    mapping(address => uint256) public totalReserve; // Include Liquidity + Fee accumulated
    mapping(address => uint256) public totalLiquidity; // Include Liquidity only
    mapping(address => uint256) public currentLiquidity; // Include current liquidity, updated on every in and out transfer
    mapping(address => uint256) public totalLPFees;
    mapping(address => uint256) public totalSharesMinted;

    // ty - currentLiquidity represents the actual liquidity stored in this contract, correct?

    // Modifiers
    // Modifiers
    // Modifiers
    // Modifiers
    // Modifiers
    // Modifiers
    // Modifiers
    // Modifiers
    // ============

    /**
     * @dev Modifier for checking to validate a NFTId and it's ownership
     * @param _tokenId token id to validate
     * @param _transactor typically msgSender(), passed to verify against owner of _tokenId
     */
    // ty - checking the contract the _transactor is always msg sender.
    modifier onlyValidLpToken(uint256 _tokenId, address _transactor) {
        (address token, , ) = lpToken.tokenMetadata(_tokenId);
        require(lpToken.exists(_tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        require(lpToken.ownerOf(_tokenId) == _transactor, "ERR__TRANSACTOR_DOES_NOT_OWN_NFT");
        _;
    }

    /**
     * @dev Modifier for checking if msg.sender in liquiditypool
     */
    modifier onlyLiquidityPool() {
        require(_msgSender() == address(liquidityPool), "ERR__UNAUTHORIZED");
        _;
    }

    // This modifier checks that the token is supported by the provider.
    modifier tokenChecks(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(_isSupportedToken(tokenAddress), "Token not supported");
        _;
    }

    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // ===========

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function initialize(
        address _trustedForwarder,
        address _lpToken,
        address _tokenManager,
        address _pauser
    ) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
        __Pausable_init(_pauser);
        __ReentrancyGuard_init();
        _setLPToken(_lpToken);
        _setTokenManager(_tokenManager);
    }

    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // Mutative function
    // =================

    receive() external payable {
        emit EthReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Function to mint a new NFT for a user, add native liquidity and store the
     *      record in the newly minted NFT
     */
    function addNativeLiquidity() external payable nonReentrant tokenChecks(NATIVE) whenNotPaused {
        (bool success, ) = address(liquidityPool).call{value: msg.value}("");
        require(success, "ERR__NATIVE_TRANSFER_FAILED");
        _addLiquidity(NATIVE, msg.value);
    }

    /**
     * @dev Function to mint a new NFT for a user, add token liquidity and store the
     *      record in the newly minted NFT
     * @param _token Address of token for which liquidity is to be added
     * @param _amount Amount of liquidity added
     */
    function addTokenLiquidity(address _token, uint256 _amount)
        external
        nonReentrant
        tokenChecks(_token)
        whenNotPaused
    {
        // checks to see if the token is NOT native
        require(_token != NATIVE, "ERR__WRONG_FUNCTION");

        // checks to see if this contract can transfer tokens from the msg.sender to this contract.
        uint256 allowedAmountToWithdraw = IERC20Upgradeable(_token).allowance(_msgSender(), address(this));

        require(allowedAmountToWithdraw >= _amount, "ERR__INSUFFICIENT_ALLOWANCE");

        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_token), _msgSender(), address(liquidityPool), _amount);

        // _addLiquidity(_token, _amount);
        //
        // _addLiquidity is defined as:
        //
        require(_amount > 0, "ERR__AMOUNT_IS_0");

        uint256 nftId = lpToken.mint(_msgSender());

        LpTokenMetadata memory data = LpTokenMetadata(_token, 0, 0);

        lpToken.updateTokenMetadata(nftId, data);

        _increaseLiquidity(nftId, _amount);
    }

    /**
     * @dev Function to allow LPs to add native token liquidity to existing NFT
     */
    function increaseNativeLiquidity(uint256 _nftId) external payable nonReentrant whenNotPaused {
        (address token, , ) = lpToken.tokenMetadata(_nftId);
        require(_isSupportedToken(NATIVE), "ERR__TOKEN_NOT_SUPPORTED");
        require(token == NATIVE, "ERR__WRONG_FUNCTION");
        (bool success, ) = address(liquidityPool).call{value: msg.value}("");
        require(success, "ERR__NATIVE_TRANSFER_FAILED");
        _increaseLiquidity(_nftId, msg.value);
    }

    /**
     * @dev Function to allow LPs to add ERC20 token liquidity to existing NFT
     * @param _nftId ID of NFT for updating the balances
     * @param _amount Token amount to be added
     */
    function increaseTokenLiquidity(uint256 _nftId, uint256 _amount) external nonReentrant whenNotPaused {
        (address token, , ) = lpToken.tokenMetadata(_nftId);
        require(_isSupportedToken(token), "ERR__TOKEN_NOT_SUPPORTED");
        require(token != NATIVE, "ERR__WRONG_FUNCTION");
        require(
            IERC20Upgradeable(token).allowance(_msgSender(), address(this)) >= _amount,
            "ERR__INSUFFICIENT_ALLOWANCE"
        );
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(token), _msgSender(), address(liquidityPool), _amount);
        _increaseLiquidity(_nftId, _amount);
    }

    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // Owner functions
    // ================

    /**
     * @dev To be called post initialization, used to set address of WhiteListPeriodManager Contract
     * @param _whiteListPeriodManager address of WhiteListPeriodManager
     */
    function setWhiteListPeriodManager(address _whiteListPeriodManager) external onlyOwner {
        whiteListPeriodManager = IWhiteListPeriodManager(_whiteListPeriodManager);
    }

    /**
     * @dev To be called post initialization, used to set address of LiquidityPool Contract
     * @param _liquidityPool address of LiquidityPool
     */
    function setLiquidityPool(address _liquidityPool) external onlyOwner {
        liquidityPool = ILiquidityPool(_liquidityPool);
    }

    /**
     * @dev To be called post initialization, used to set address of NFT Contract
     * @param _lpToken address of lpToken
     */
    function setLpToken(address _lpToken) external onlyOwner {
        _setLPToken(_lpToken);
    }

    /**
     * Public method to set TokenManager contract.
     */
    function setTokenManager(address _tokenManager) external onlyOwner {
        _setTokenManager(_tokenManager);
    }

    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // liquidity-provider functions
    // =============================

    /**
     * @dev Function to allow LPs to claim the fee earned on their NFT
     * @param _nftId ID of NFT where liquidity is recorded
     */
    function claimFee(uint256 _nftId) external onlyValidLpToken(_nftId, _msgSender()) whenNotPaused nonReentrant {
        (address _tokenAddress, uint256 nftSuppliedLiquidity, uint256 totalNFTShares) = lpToken.tokenMetadata(_nftId);
        require(_isSupportedToken(_tokenAddress), "ERR__TOKEN_NOT_SUPPORTED");

        uint256 lpSharesForSuppliedLiquidity = nftSuppliedLiquidity * getTokenPriceInLPShares(_tokenAddress);

        // Calculate rewards accumulated
        uint256 eligibleLiquidity = sharesToTokenAmount(totalNFTShares, _tokenAddress);
        uint256 lpFeeAccumulated = eligibleLiquidity - nftSuppliedLiquidity;
        require(lpFeeAccumulated > 0, "ERR__NO_REWARDS_TO_CLAIM");
        // Calculate amount of lp shares that represent accumulated Fee
        uint256 lpSharesRepresentingFee = totalNFTShares - lpSharesForSuppliedLiquidity;

        totalReserve[_tokenAddress] -= lpFeeAccumulated;
        totalSharesMinted[_tokenAddress] -= lpSharesRepresentingFee;
        totalLPFees[_tokenAddress] -= lpFeeAccumulated;

        _burnSharesFromNft(_nftId, lpSharesRepresentingFee, 0, _tokenAddress);
        _transferFromLiquidityPool(_tokenAddress, _msgSender(), lpFeeAccumulated);
        emit FeeClaimed(_tokenAddress, lpFeeAccumulated, _msgSender(), lpSharesRepresentingFee);
    }

    /**
     * @dev Function to allow LPs to remove their liquidity from an existing NFT
     *      Also automatically redeems any earned fee
     */
    function removeLiquidity(uint256 _nftId, uint256 _amount)
        external
        nonReentrant
        onlyValidLpToken(_nftId, _msgSender())
        whenNotPaused
    {
        (address _tokenAddress, uint256 nftSuppliedLiquidity, uint256 totalNFTShares) = lpToken.tokenMetadata(_nftId);
        require(_isSupportedToken(_tokenAddress), "ERR__TOKEN_NOT_SUPPORTED");

        require(_amount != 0, "ERR__INVALID_AMOUNT");
        require(nftSuppliedLiquidity >= _amount, "ERR__INSUFFICIENT_LIQUIDITY");
        whiteListPeriodManager.beforeLiquidityRemoval(_msgSender(), _tokenAddress, _amount);
        // Claculate how much shares represent input amount
        uint256 lpSharesForInputAmount = _amount * getTokenPriceInLPShares(_tokenAddress);

        // Calculate rewards accumulated
        uint256 eligibleLiquidity = sharesToTokenAmount(totalNFTShares, _tokenAddress);

        uint256 lpFeeAccumulated;

        // Handle edge cases where eligibleLiquidity is less than what was supplied by very small amount
        if (nftSuppliedLiquidity > eligibleLiquidity) {
            lpFeeAccumulated = 0;
        } else {
            unchecked {
                lpFeeAccumulated = eligibleLiquidity - nftSuppliedLiquidity;
            }
        }
        // Calculate amount of lp shares that represent accumulated Fee
        uint256 lpSharesRepresentingFee = lpFeeAccumulated * getTokenPriceInLPShares(_tokenAddress);

        totalLPFees[_tokenAddress] -= lpFeeAccumulated;
        uint256 amountToWithdraw = _amount + lpFeeAccumulated;
        uint256 lpSharesToBurn = lpSharesForInputAmount + lpSharesRepresentingFee;

        // Handle round off errors to avoid dust lp token in contract
        if (totalNFTShares - lpSharesToBurn < BASE_DIVISOR) {
            lpSharesToBurn = totalNFTShares;
        }
        totalReserve[_tokenAddress] -= amountToWithdraw;
        totalLiquidity[_tokenAddress] -= _amount;
        totalSharesMinted[_tokenAddress] -= lpSharesToBurn;

        _decreaseCurrentLiquidity(_tokenAddress, _amount);

        _burnSharesFromNft(_nftId, lpSharesToBurn, _amount, _tokenAddress);

        _transferFromLiquidityPool(_tokenAddress, _msgSender(), amountToWithdraw);

        emit LiquidityRemoved(_tokenAddress, amountToWithdraw, _msgSender());
    }

    // liquidity pool-only functions
    // ============================

    /**
     * @dev Records fee being added to total reserve
     * @param _token Address of Token for which LP fee is being added
     * @param _amount Amount being added
     */
    function addLPFee(address _token, uint256 _amount) external onlyLiquidityPool tokenChecks(_token) whenNotPaused {
        totalReserve[_token] += _amount;
        totalLPFees[_token] += _amount;
        emit FeeAdded(_token, _amount);
    }

    function increaseCurrentLiquidity(address tokenAddress, uint256 amount) public onlyLiquidityPool {
        _increaseCurrentLiquidity(tokenAddress, amount);
    }

    function decreaseCurrentLiquidity(address tokenAddress, uint256 amount) public onlyLiquidityPool {
        _decreaseCurrentLiquidity(tokenAddress, amount);
    }

    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // ===============

    /**
     * @dev Returns price of Base token in terms of LP Shares
     * @param _baseToken address of baseToken
     * @return Price of Base token in terms of LP Shares
     */
    function getTokenPriceInLPShares(address _baseToken) public view returns (uint256) {
        uint256 supply = totalSharesMinted[_baseToken];
        if (supply > 0) {
            return totalSharesMinted[_baseToken] / totalReserve[_baseToken];
        }
        return BASE_DIVISOR;
    }

    /**
     * @dev Converts shares to token amount
     */

    function sharesToTokenAmount(uint256 _shares, address _tokenAddress) public view returns (uint256) {
        return (_shares * totalReserve[_tokenAddress]) / totalSharesMinted[_tokenAddress];
    }

    /**
     * @dev Returns the fee accumulated on a given NFT
     * @param _nftId Id of NFT
     * @return accumulated fee
     */
    function getFeeAccumulatedOnNft(uint256 _nftId) public view returns (uint256) {
        require(lpToken.exists(_nftId), "ERR__INVALID_NFT");

        (address _tokenAddress, uint256 nftSuppliedLiquidity, uint256 totalNFTShares) = lpToken.tokenMetadata(_nftId);

        if (totalNFTShares == 0) {
            return 0;
        }
        // Calculate rewards accumulated
        uint256 eligibleLiquidity = sharesToTokenAmount(totalNFTShares, _tokenAddress);
        uint256 lpFeeAccumulated;

        // Handle edge cases where eligibleLiquidity is less than what was supplied by very small amount
        if (nftSuppliedLiquidity > eligibleLiquidity) {
            lpFeeAccumulated = 0;
        } else {
            unchecked {
                lpFeeAccumulated = eligibleLiquidity - nftSuppliedLiquidity;
            }
        }
        return lpFeeAccumulated;
    }

    function getSuppliedLiquidity(uint256 _nftId) external view returns (uint256) {
        (, uint256 totalSuppliedLiquidity, ) = lpToken.tokenMetadata(_nftId);
        return totalSuppliedLiquidity;
    }

    function getTotalReserveByToken(address tokenAddress) public view returns (uint256) {
        return totalReserve[tokenAddress];
    }

    function getSuppliedLiquidityByToken(address tokenAddress) public view returns (uint256) {
        return totalLiquidity[tokenAddress];
    }

    function getTotalLPFeeByToken(address tokenAddress) public view returns (uint256) {
        return totalLPFees[tokenAddress];
    }

    function getCurrentLiquidity(address tokenAddress) public view returns (uint256) {
        return currentLiquidity[tokenAddress];
    }

    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // ==================

    /**
     * Internal method to set TokenManager contract.
     */
    function _setTokenManager(address _tokenManager) internal {
        tokenManager = ITokenManager(_tokenManager);
    }

    /**
     * Internal method to set LP token contract.
     */
    function _setLPToken(address _lpToken) internal {
        lpToken = ILPToken(_lpToken);
    }

    function _increaseCurrentLiquidity(address tokenAddress, uint256 amount) private {
        currentLiquidity[tokenAddress] += amount;
        emit CurrentLiquidityChanged(
            tokenAddress,
            currentLiquidity[tokenAddress] - amount,
            currentLiquidity[tokenAddress]
        );
    }

    function _decreaseCurrentLiquidity(address tokenAddress, uint256 amount) private {
        currentLiquidity[tokenAddress] -= amount;
        emit CurrentLiquidityChanged(
            tokenAddress,
            currentLiquidity[tokenAddress] + amount,
            currentLiquidity[tokenAddress]
        );
    }

    /**
     * @dev Internal function to add liquidity to a new NFT
     */
    function _addLiquidity(address _token, uint256 _amount) internal {
        require(_amount > 0, "ERR__AMOUNT_IS_0");
        uint256 nftId = lpToken.mint(_msgSender());
        LpTokenMetadata memory data = LpTokenMetadata(_token, 0, 0);
        lpToken.updateTokenMetadata(nftId, data);
        _increaseLiquidity(nftId, _amount);
    }

    /**
     * @dev Internal helper function to increase liquidity in a given NFT
     */
    function _increaseLiquidity(uint256 _nftId, uint256 _amount) internal onlyValidLpToken(_nftId, _msgSender()) {
        (address token, uint256 totalSuppliedLiquidity, uint256 totalShares) = lpToken.tokenMetadata(_nftId);

        require(_amount > 0, "ERR__AMOUNT_IS_0");
        whiteListPeriodManager.beforeLiquidityAddition(_msgSender(), token, _amount);

        uint256 mintedSharesAmount;
        // Adding liquidity in the pool for the first time
        if (totalReserve[token] == 0) {
            mintedSharesAmount = BASE_DIVISOR * _amount;
        } else {
            mintedSharesAmount = (_amount * totalSharesMinted[token]) / totalReserve[token];
        }

        require(mintedSharesAmount >= BASE_DIVISOR, "ERR__AMOUNT_BELOW_MIN_LIQUIDITY");

        totalLiquidity[token] += _amount;
        totalReserve[token] += _amount;
        totalSharesMinted[token] += mintedSharesAmount;

        LpTokenMetadata memory data = LpTokenMetadata(
            token,
            totalSuppliedLiquidity + _amount,
            totalShares + mintedSharesAmount
        );
        lpToken.updateTokenMetadata(_nftId, data);

        // Increase the current liquidity
        _increaseCurrentLiquidity(token, _amount);
        emit LiquidityAdded(token, _amount, _msgSender());
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /**
     * @dev Internal Function to burn LP shares and remove liquidity from existing NFT
     */
    function _burnSharesFromNft(
        uint256 _nftId,
        uint256 _shares,
        uint256 _tokenAmount,
        address _tokenAddress
    ) internal {
        (, uint256 nftSuppliedLiquidity, uint256 nftShares) = lpToken.tokenMetadata(_nftId);
        nftShares -= _shares;
        nftSuppliedLiquidity -= _tokenAmount;

        lpToken.updateTokenMetadata(_nftId, LpTokenMetadata(_tokenAddress, nftSuppliedLiquidity, nftShares));
    }

    function _transferFromLiquidityPool(
        address _tokenAddress,
        address _receiver,
        uint256 _tokenAmount
    ) internal {
        liquidityPool.transfer(_tokenAddress, _receiver, _tokenAmount);
    }

    function _isSupportedToken(address _token) internal view returns (bool) {
        return tokenManager.getTokensInfo(_token).supportedToken;
    }
}

// import "./token/LPToken.sol";
// import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "./token/Base64.sol/contracts/base64.sol";
import "./interfaces/ISvgHelper.sol";
import "./interfaces/ILiquidityProviders.sol";
import "./structures/LpTokenMetadata.sol";

contract LPToken is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC2771ContextUpgradeable,
    Pausable
{
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public liquidityProvidersAddress;
    IWhiteListPeriodManager public whiteListPeriodManager;
    mapping(uint256 => LpTokenMetadata) public tokenMetadata;
    mapping(address => ISvgHelper) public svgHelpers;

    event LiquidityProvidersUpdated(address indexed lpm);
    event WhiteListPeriodManagerUpdated(address indexed manager);
    event SvgHelperUpdated(address indexed tokenAddress, ISvgHelper indexed svgHelper);

    function initialize(
        string memory _name,
        string memory _symbol,
        address _trustedForwarder,
        address _pauser,
        address tokenA,
        ISvgHelper svgC,
        address lp,
        address wlpm
    ) public initializer {
        __Ownable_init();
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Pausable_init(_pauser);
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __ERC2771Context_init(_trustedForwarder);

        svgHelpers[tokenA] = svgC;
        liquidityProvidersAddress = lp;
        whiteListPeriodManager = IWhiteListPeriodManager(wlpm);
    }

    // A Hyphen Pool is a LiquidityProviders contract deployed to mainnet.
    modifier onlyHyphenPools() {
        require(_msgSender() == liquidityProvidersAddress, "ERR_UNAUTHORIZED");
        _;
    }

    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // onlyOwner contracts
    // ===================

    function setSvgHelper(address _tokenAddress, ISvgHelper _svgHelper) public onlyOwner {
        require(_svgHelper != ISvgHelper(address(0)), "ERR_INVALID_SVG_HELPER");
        require(_tokenAddress != address(0), "ERR_INVALID_TOKEN_ADDRESS");
        svgHelpers[_tokenAddress] = _svgHelper;
        emit SvgHelperUpdated(_tokenAddress, _svgHelper);
    }

    function setLiquidityProviders(address _liquidityProviders) external onlyOwner {
        require(_liquidityProviders != address(0), "ERR_INVALID_LIQUIDITY_PROVIDERS");
        liquidityProvidersAddress = _liquidityProviders;
        emit LiquidityProvidersUpdated(_liquidityProviders);
    }

    function setWhiteListPeriodManager(address _whiteListPeriodManager) external onlyOwner {
        require(_whiteListPeriodManager != address(0), "ERR_INVALID_WHITELIST_PERIOD_MANAGER");
        whiteListPeriodManager = IWhiteListPeriodManager(_whiteListPeriodManager);
        emit WhiteListPeriodManagerUpdated(_whiteListPeriodManager);
    }

    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // Hyphen Pool-Only functions
    // ==========================

    function updateTokenMetadata(uint256 _tokenId, LpTokenMetadata memory _lpTokenMetadata)
        external
        onlyHyphenPools
        whenNotPaused
    {
        require(_exists(_tokenId), "ERR__TOKEN_DOES_NOT_EXIST");
        tokenMetadata[_tokenId] = _lpTokenMetadata;
    }

    function mint(address _to) external onlyHyphenPools whenNotPaused nonReentrant returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        _safeMint(_to, tokenId);
        return tokenId;
    }

    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // ================

    function getAllNftIdsByUser(address _owner) public view returns (uint256[] memory) {
        uint256[] memory nftIds = new uint256[](balanceOf(_owner));
        for (uint256 i = 0; i < nftIds.length; ++i) {
            nftIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return nftIds;
    }

    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        address tokenAddress = tokenMetadata[tokenId].token;
        require(svgHelpers[tokenAddress] != ISvgHelper(address(0)), "ERR__SVG_HELPER_NOT_REGISTERED");

        ISvgHelper svgHelper = ISvgHelper(svgHelpers[tokenAddress]);

        string memory svgData = svgHelper.getTokenSvg(
            tokenId,
            tokenMetadata[tokenId].suppliedLiquidity,
            ILiquidityProviders(liquidityProvidersAddress).totalReserve(tokenAddress)
        );

        string memory description = svgHelper.getDescription(
            tokenMetadata[tokenId].suppliedLiquidity,
            ILiquidityProviders(liquidityProvidersAddress).totalReserve(tokenAddress)
        );

        string memory attributes = svgHelper.getAttributes(
            tokenMetadata[tokenId].suppliedLiquidity,
            ILiquidityProviders(liquidityProvidersAddress).totalReserve(tokenAddress)
        );

        string memory json = Base64.encode(
            string(
                abi.encodePacked(
                    '{"name": "',
                    name(),
                    '", "description": "',
                    description,
                    '", "image": "data:image/svg+xml;base64,',
                    Base64.encode((svgData)),
                    '", "attributes": ',
                    attributes,
                    "}"
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // Internal functions
    // ===================

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable, ERC721Upgradeable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);

        // Only call whitelist period manager for NFT Transfers, not mint and burns
        if (from != address(0) && to != address(0)) {
            whiteListPeriodManager.beforeLiquidityTransfer(
                from,
                to,
                tokenMetadata[tokenId].token,
                tokenMetadata[tokenId].suppliedLiquidity
            );
        }
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        ERC721URIStorageUpgradeable._burn(tokenId);
    }
}

// import "./token/TokenManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";
import "./metatx/ERC2771Context.sol";

contract TokenManager is ITokenManager, ERC2771Context, Ownable, Pausable {
    // ty - borrowed from ITokenManager file
    // struct TokenInfo {
    //     uint256 transferOverhead;
    //     bool supportedToken;
    //     uint256 equilibriumFee; // Percentage fee Represented in basis points
    //     uint256 maxFee; // Percentage fee Represented in basis points
    //     TokenConfig tokenConfig;
    // }

    // ty - borrowed from ITokenManager file
    // struct TokenConfig {
    //     uint256 min;
    //     uint256 max;
    // }

    mapping(address => TokenInfo) public tokensInfo;

    /**
     * First key is toChainId and second key is token address being deposited on current chain
     */
    mapping(uint256 => mapping(address => TokenConfig)) public depositConfig;
    // { chainId -> { depositedTokenAddress: TokenConfig } }

    /**
     * Store min/max amount of token to transfer based on token address
     */
    mapping(address => TokenConfig) public transferConfig;
    // { tokenAddress: TokenConfig }

    event FeeChanged(address indexed tokenAddress, uint256 indexed equilibriumFee, uint256 indexed maxFee);

    modifier tokenChecks(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(tokensInfo[tokenAddress].supportedToken, "Token not supported");

        _;
    }

    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {
        // Empty Constructor
    }

    // owner-only functions
    // owner-only functions
    // owner-only functions
    // owner-only functions
    // owner-only functions
    // owner-only functions
    // owner-only functions
    // owner-only functions
    // owner-only functions
    // =====================

    function changeFee(
        address tokenAddress,
        uint256 _equilibriumFee,
        uint256 _maxFee
    ) external override onlyOwner whenNotPaused {
        require(_equilibriumFee != 0, "Equilibrium Fee cannot be 0");
        require(_maxFee != 0, "Max Fee cannot be 0");
        tokensInfo[tokenAddress].equilibriumFee = _equilibriumFee;
        tokensInfo[tokenAddress].maxFee = _maxFee;
        emit FeeChanged(tokenAddress, tokensInfo[tokenAddress].equilibriumFee, tokensInfo[tokenAddress].maxFee);
    }

    function setTokenTransferOverhead(address tokenAddress, uint256 gasOverhead)
        external
        tokenChecks(tokenAddress)
        onlyOwner
    {
        tokensInfo[tokenAddress].transferOverhead = gasOverhead;
    }

    /**
     * Set DepositConfig for the given combination of toChainId, tokenAddress.
     * This is used while depositing token in Liquidity Pool. Based on the destination chainid
     * min and max deposit amount is checked.
     */
    function setDepositConfig(
        uint256[] memory toChainId,
        address[] memory tokenAddresses,
        TokenConfig[] memory tokenConfig
    ) external onlyOwner {
        require(
            (toChainId.length == tokenAddresses.length) && (tokenAddresses.length == tokenConfig.length),
            " ERR_ARRAY_LENGTH_MISMATCH"
        );
        for (uint256 index = 0; index < tokenConfig.length; ++index) {
            depositConfig[toChainId[index]][tokenAddresses[index]].min = tokenConfig[index].min;
            depositConfig[toChainId[index]][tokenAddresses[index]].max = tokenConfig[index].max;
        }
    }

    function addSupportedToken(
        address tokenAddress,
        uint256 minCapLimit,
        uint256 maxCapLimit,
        uint256 equilibriumFee,
        uint256 maxFee
    ) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(maxCapLimit > minCapLimit, "maxCapLimit > minCapLimit");
        tokensInfo[tokenAddress].supportedToken = true;
        transferConfig[tokenAddress].min = minCapLimit;
        transferConfig[tokenAddress].max = maxCapLimit;
        tokensInfo[tokenAddress].tokenConfig = transferConfig[tokenAddress];
        tokensInfo[tokenAddress].equilibriumFee = equilibriumFee;
        tokensInfo[tokenAddress].maxFee = maxFee;
    }

    function removeSupportedToken(address tokenAddress) external tokenChecks(tokenAddress) onlyOwner {
        tokensInfo[tokenAddress].supportedToken = false;
    }

    function updateTokenCap(
        address tokenAddress,
        uint256 minCapLimit,
        uint256 maxCapLimit
    ) external tokenChecks(tokenAddress) onlyOwner {
        require(maxCapLimit > minCapLimit, "maxCapLimit > minCapLimit");
        transferConfig[tokenAddress].min = minCapLimit;
        transferConfig[tokenAddress].max = maxCapLimit;
    }

    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // View functions
    // ==============

    function getTokensInfo(address tokenAddress) public view override returns (TokenInfo memory) {
        TokenInfo memory tokenInfo = TokenInfo(
            tokensInfo[tokenAddress].transferOverhead,
            tokensInfo[tokenAddress].supportedToken,
            tokensInfo[tokenAddress].equilibriumFee,
            tokensInfo[tokenAddress].maxFee,
            transferConfig[tokenAddress]
        );
        return tokenInfo;
    }

    function getEquilibriumFee(address tokenAddress) public view override returns (uint256) {
        return tokensInfo[tokenAddress].equilibriumFee;
    }

    function getMaxFee(address tokenAddress) public view override returns (uint256) {
        return tokensInfo[tokenAddress].maxFee;
    }

    function getDepositConfig(uint256 toChainId, address tokenAddress)
        public
        view
        override
        returns (TokenConfig memory)
    {
        return depositConfig[toChainId][tokenAddress];
    }

    function getTransferConfig(address tokenAddress) public view override returns (TokenConfig memory) {
        return transferConfig[tokenAddress];
    }

    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // ================

    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Context, ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }
}

// import "./LiquidityPool.sol";
import "./interfaces/IExecutorManager.sol";
import "./interfaces/IERC20Permit.sol";

contract LiquidityPool is ReentrancyGuardUpgradeable, Pausable, OwnableUpgradeable, ERC2771ContextUpgradeable {
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant BASE_DIVISOR = 10000000000; // Basis Points * 100 for better accuracy

    uint256 public baseGas;

    IExecutorManager private executorManager;
    ITokenManager public tokenManager;
    ILiquidityProviders public liquidityProviders;

    struct PermitRequest {
        uint256 nonce;
        uint256 expiry;
        bool allowed;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    mapping(bytes32 => bool) public processedHash;
    mapping(address => uint256) public gasFeeAccumulatedByToken;

    // Gas fee accumulated by token address => executor address
    mapping(address => mapping(address => uint256)) public gasFeeAccumulated;

    // Incentive Pool amount per token address
    mapping(address => uint256) public incentivePool;

    event AssetSent(
        address indexed asset,
        uint256 indexed amount,
        uint256 indexed transferredAmount,
        address target,
        bytes depositHash,
        uint256 fromChainId
    );
    event FeeDetails(uint256 indexed lpFee, uint256 indexed transferFee, uint256 indexed gasFee);
    event Received(address indexed from, uint256 indexed amount);
    event Deposit(
        address indexed from,
        address indexed tokenAddress,
        address indexed receiver,
        uint256 toChainId,
        uint256 amount,
        uint256 reward,
        string tag
    );
    event GasFeeWithdraw(address indexed tokenAddress, address indexed owner, uint256 indexed amount);
    event TrustedForwarderChanged(address indexed forwarderAddress);
    event LiquidityProvidersChanged(address indexed liquidityProvidersAddress);
    event EthReceived(address, uint256);

    // MODIFIERS
    modifier onlyExecutor() {
        require(executorManager.getExecutorStatus(_msgSender()), "Only executor is allowed");
        _;
    }

    modifier onlyLiquidityProviders() {
        require(_msgSender() == address(liquidityProviders), "Only liquidityProviders is allowed");
        _;
    }

    modifier tokenChecks(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(tokenManager.getTokensInfo(tokenAddress).supportedToken, "Token not supported");
        _;
    }

    function initialize(
        address _executorManagerAddress,
        address _pauser,
        address _trustedForwarder,
        address _tokenManager,
        address _liquidityProviders
    ) public initializer {
        require(_executorManagerAddress != address(0), "ExecutorManager cannot be 0x0");
        require(_trustedForwarder != address(0), "TrustedForwarder cannot be 0x0");
        require(_liquidityProviders != address(0), "LiquidityProviders cannot be 0x0");
        __ERC2771Context_init(_trustedForwarder);
        __ReentrancyGuard_init();
        __Ownable_init();
        __Pausable_init(_pauser);
        executorManager = IExecutorManager(_executorManagerAddress);
        tokenManager = ITokenManager(_tokenManager);
        liquidityProviders = ILiquidityProviders(_liquidityProviders);
        baseGas = 21000;
    }

    // Only-owner functions
    // ====================

    function setTrustedForwarder(address trustedForwarder) public onlyOwner {
        require(trustedForwarder != address(0), "TrustedForwarder can't be 0");
        _trustedForwarder = trustedForwarder;
        emit TrustedForwarderChanged(trustedForwarder);
    }

    function setLiquidityProviders(address _liquidityProviders) public onlyOwner {
        require(_liquidityProviders != address(0), "LiquidityProviders can't be 0");
        liquidityProviders = ILiquidityProviders(_liquidityProviders);
        emit LiquidityProvidersChanged(_liquidityProviders);
    }

    function setBaseGas(uint128 gas) external onlyOwner {
        baseGas = gas;
    }

    function getExecutorManager() public view returns (address) {
        return address(executorManager);
    }

    function setExecutorManager(address _executorManagerAddress) external onlyOwner {
        require(_executorManagerAddress != address(0), "Executor Manager cannot be 0");
        executorManager = IExecutorManager(_executorManagerAddress);
    }

    function getCurrentLiquidity(address tokenAddress) public view returns (uint256 currentLiquidity) {
        uint256 liquidityPoolBalance = liquidityProviders.getCurrentLiquidity(tokenAddress);

        currentLiquidity =
            liquidityPoolBalance -
            liquidityProviders.totalLPFees(tokenAddress) -
            gasFeeAccumulatedByToken[tokenAddress] -
            incentivePool[tokenAddress];
    }

    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // Mutative functions
    // ===================

    /**
     * @dev Function used to deposit tokens into pool to initiate a cross chain token transfer.
     * @param toChainId Chain id where funds needs to be transfered
     * @param tokenAddress ERC20 Token address that needs to be transfered
     * @param receiver Address on toChainId where tokens needs to be transfered
     * @param amount Amount of token being transfered
     */
    function depositErc20(
        uint256 toChainId,
        address tokenAddress,
        address receiver,
        uint256 amount,
        string memory tag
    ) public tokenChecks(tokenAddress) whenNotPaused nonReentrant {
        // This function is called when a user wants to send this ERC20 token to this pool in exchange for a different cross chain token.

        // The function does the following steps:

        // 1. checks that the amount arg is within a pre-defined range.
        // 2. checks that the receiver arg is not address(0)
        // 3. checks that the amount arg is not 0
        // 4. gets the reward amount
        // 5. reduces the incentive pool amount by how much the rewardAmount is: new `incentive pool amount = (incentive pool address) - (reward amount))`.
        // 6. increases the current liquidity in the token address pool by the amount arg

        // Step 1
        require(
            tokenManager.getDepositConfig(toChainId, tokenAddress).min <= amount &&
                tokenManager.getDepositConfig(toChainId, tokenAddress).max >= amount,
            "Deposit amount not in Cap limit"
        );
        // Step 2
        require(receiver != address(0), "Receiver address cannot be 0");

        // Step 3
        require(amount != 0, "Amount cannot be 0");
        address sender = _msgSender();

        // Step 4
        uint256 rewardAmount = getRewardAmount(amount, tokenAddress);

        // Step 5
        if (rewardAmount != 0) {
            incentivePool[tokenAddress] = incentivePool[tokenAddress] - rewardAmount;
        }

        // Step 6
        liquidityProviders.increaseCurrentLiquidity(tokenAddress, amount);
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(tokenAddress), sender, address(this), amount);

        // Emit (amount + reward amount) in event
        emit Deposit(sender, tokenAddress, receiver, toChainId, amount + rewardAmount, rewardAmount, tag);
    }

    /**
     * @dev Function used to deposit native token into pool to initiate a cross chain token transfer.
     * @param receiver Address on toChainId where tokens needs to be transfered
     * @param toChainId Chain id where funds needs to be transfered
     */

    // ty - Native tokens are the native currency the contract is deployed on. Ethereum would be eth, cardano would be ada, etc.
    function depositNative(
        address receiver,
        uint256 toChainId,
        string memory tag
    ) external payable whenNotPaused nonReentrant {
        // This function deposits the native tokens in the following way:
        //
        // 1. Reduces the native token's incentive pool minus reward amount
        // 2. increases the current liquidity for the native token by calling a
        //    liquidityProviders function called `increaseCurrentLiqudity`.
        //

        // The function does the following steps:

        // 1. checks that the msg.value is within a pre-defined range.
        // 2. checks that the receiver arg is not address(0)
        // 3. checks that the msg.value is not 0
        // 4. gets the reward amount
        // 5. reduces the incentive pool native tokens amount minus the reward amount.
        // 6. increases the current liquidity for the native token's

        // Step 1
        require(
            tokenManager.getDepositConfig(toChainId, NATIVE).min <= msg.value &&
                tokenManager.getDepositConfig(toChainId, NATIVE).max >= msg.value,
            "Deposit amount not in Cap limit"
        );

        // Step 2
        require(receiver != address(0), "Receiver address cannot be 0");

        // Step 3
        require(msg.value != 0, "Amount cannot be 0");

        // Step 4
        uint256 rewardAmount = getRewardAmount(msg.value, NATIVE);

        // Step 5
        if (rewardAmount != 0) {
            // there is no reason to have this if statement because there is no impact here if the rewardAmount was 0.
            incentivePool[NATIVE] = incentivePool[NATIVE] - rewardAmount;
        }

        // Step 6
        liquidityProviders.increaseCurrentLiquidity(NATIVE, msg.value);
        emit Deposit(_msgSender(), NATIVE, receiver, toChainId, msg.value + rewardAmount, rewardAmount, tag);
    }

    /**
     * DAI permit and Deposit.
     */
    function permitAndDepositErc20(
        address tokenAddress,
        address receiver,
        uint256 amount,
        uint256 toChainId,
        PermitRequest calldata permitOptions,
        string memory tag
    ) external {
        IERC20Permit(tokenAddress).permit(
            _msgSender(),
            address(this),
            permitOptions.nonce,
            permitOptions.expiry,
            permitOptions.allowed,
            permitOptions.v,
            permitOptions.r,
            permitOptions.s
        );
        depositErc20(toChainId, tokenAddress, receiver, amount, tag);
    }

    /**
     * EIP2612 and Deposit.
     */
    function permitEIP2612AndDepositErc20(
        address tokenAddress,
        address receiver,
        uint256 amount,
        uint256 toChainId,
        PermitRequest calldata permitOptions,
        string memory tag
    ) external {
        // ty - Is the #permit function safe here?
        IERC20Permit(tokenAddress).permit(
            _msgSender(),
            address(this),
            amount,
            permitOptions.expiry,
            permitOptions.v,
            permitOptions.r,
            permitOptions.s
        );
        depositErc20(toChainId, tokenAddress, receiver, amount, tag);
    }

    receive() external payable {
        emit EthReceived(_msgSender(), msg.value);
    }

    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    // liquidity-provider-only functions
    //  =================================

    function transfer(
        address _tokenAddress,
        address receiver,
        uint256 _tokenAmount
    ) external whenNotPaused onlyLiquidityProviders nonReentrant {
        require(receiver != address(0), "Invalid receiver");
        if (_tokenAddress == NATIVE) {
            require(address(this).balance >= _tokenAmount, "ERR__INSUFFICIENT_BALANCE");
            (bool success, ) = receiver.call{value: _tokenAmount}("");
            require(success, "ERR__NATIVE_TRANSFER_FAILED");
        } else {
            IERC20Upgradeable baseToken = IERC20Upgradeable(_tokenAddress);
            require(baseToken.balanceOf(address(this)) >= _tokenAmount, "ERR__INSUFFICIENT_BALANCE");
            SafeERC20Upgradeable.safeTransfer(baseToken, receiver, _tokenAmount);
        }
    }

    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // executor-only restrictive functions
    // ====================================

    function sendFundsToUser(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes memory depositHash,
        uint256 tokenGasPrice,
        uint256 fromChainId
    ) external nonReentrant onlyExecutor tokenChecks(tokenAddress) whenNotPaused {
        uint256 initialGas = gasleft();
        require(
            tokenManager.getTransferConfig(tokenAddress).min <= amount &&
                tokenManager.getTransferConfig(tokenAddress).max >= amount,
            "Withdraw amnt not in Cap limits"
        );
        require(receiver != address(0), "Bad receiver address");

        (bytes32 hashSendTransaction, bool status) = checkHashStatus(tokenAddress, amount, receiver, depositHash);

        require(!status, "Already Processed");
        processedHash[hashSendTransaction] = true;

        uint256 amountToTransfer = getAmountToTransfer(initialGas, tokenAddress, amount, tokenGasPrice);
        liquidityProviders.decreaseCurrentLiquidity(tokenAddress, amountToTransfer);

        if (tokenAddress == NATIVE) {
            require(address(this).balance >= amountToTransfer, "Not Enough Balance");
            (bool success, ) = receiver.call{value: amountToTransfer}("");
            require(success, "Native Transfer Failed");
        } else {
            require(IERC20Upgradeable(tokenAddress).balanceOf(address(this)) >= amountToTransfer, "Not Enough Balance");
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(tokenAddress), receiver, amountToTransfer);
        }

        emit AssetSent(tokenAddress, amount, amountToTransfer, receiver, depositHash, fromChainId);
    }

    function withdrawErc20GasFee(address tokenAddress) external onlyExecutor whenNotPaused nonReentrant {
        require(tokenAddress != NATIVE, "Can't withdraw native token fee");
        // uint256 gasFeeAccumulated = gasFeeAccumulatedByToken[tokenAddress];
        uint256 _gasFeeAccumulated = gasFeeAccumulated[tokenAddress][_msgSender()];
        require(_gasFeeAccumulated != 0, "Gas Fee earned is 0");
        gasFeeAccumulatedByToken[tokenAddress] = gasFeeAccumulatedByToken[tokenAddress] - _gasFeeAccumulated;
        gasFeeAccumulated[tokenAddress][_msgSender()] = 0;
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(tokenAddress), _msgSender(), _gasFeeAccumulated);
        emit GasFeeWithdraw(tokenAddress, _msgSender(), _gasFeeAccumulated);
    }

    function withdrawNativeGasFee() external onlyExecutor whenNotPaused nonReentrant {
        uint256 _gasFeeAccumulated = gasFeeAccumulated[NATIVE][_msgSender()];
        require(_gasFeeAccumulated != 0, "Gas Fee earned is 0");
        gasFeeAccumulatedByToken[NATIVE] = gasFeeAccumulatedByToken[NATIVE] - _gasFeeAccumulated;
        gasFeeAccumulated[NATIVE][_msgSender()] = 0;
        (bool success, ) = payable(_msgSender()).call{value: _gasFeeAccumulated}("");
        require(success, "Native Transfer Failed");

        emit GasFeeWithdraw(address(this), _msgSender(), _gasFeeAccumulated);
    }

    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // ==============

    function getRewardAmount(uint256 amount, address tokenAddress) public view returns (uint256 rewardAmount) {
        uint256 currentLiquidity = getCurrentLiquidity(tokenAddress);
        uint256 providedLiquidity = liquidityProviders.getSuppliedLiquidityByToken(tokenAddress); // returns LiquidityProviders#totalLiquidity[tokenAddress];
        if (currentLiquidity < providedLiquidity) {
            uint256 liquidityDifference = providedLiquidity - currentLiquidity;
            if (amount >= liquidityDifference) {
                rewardAmount = incentivePool[tokenAddress];
            } else {
                // Multiply by 10000000000 to avoid 0 reward amount for small amount and liquidity difference
                rewardAmount = (amount * incentivePool[tokenAddress] * 10000000000) / liquidityDifference;
                rewardAmount = rewardAmount / 10000000000;
            }
        }
    }

    function getTransferFee(address tokenAddress, uint256 amount) public view returns (uint256 fee) {
        uint256 currentLiquidity = getCurrentLiquidity(tokenAddress);
        uint256 providedLiquidity = liquidityProviders.getSuppliedLiquidityByToken(tokenAddress);

        uint256 resultingLiquidity = currentLiquidity - amount;

        uint256 equilibriumFee = tokenManager.getTokensInfo(tokenAddress).equilibriumFee;
        uint256 maxFee = tokenManager.getTokensInfo(tokenAddress).maxFee;
        // Fee is represented in basis points * 10 for better accuracy
        uint256 numerator = providedLiquidity * equilibriumFee * maxFee; // F(max) * F(e) * L(e)
        uint256 denominator = equilibriumFee * providedLiquidity + (maxFee - equilibriumFee) * resultingLiquidity; // F(e) * L(e) + (F(max) - F(e)) * L(r)

        if (denominator == 0) {
            fee = 0;
        } else {
            fee = numerator / denominator;
        }
    }

    function checkHashStatus(
        address tokenAddress,
        uint256 amount,
        address payable receiver,
        bytes memory depositHash
    ) public view returns (bytes32 hashSendTransaction, bool status) {
        hashSendTransaction = keccak256(abi.encode(tokenAddress, amount, receiver, keccak256(depositHash)));

        status = processedHash[hashSendTransaction];
    }

    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // ===================

    /**
     * @dev Internal function to calculate amount of token that needs to be transfered afetr deducting all required fees.
     * Fee to be deducted includes gas fee, lp fee and incentive pool amount if needed.
     * @param initialGas Gas provided initially before any calculations began
     * @param tokenAddress Token address for which calculation needs to be done
     * @param amount Amount of token to be transfered before deducting the fee
     * @param tokenGasPrice Gas price in the token being transfered to be used to calculate gas fee
     * @return amountToTransfer Total amount to be transfered after deducting all fees.
     */
    function getAmountToTransfer(
        uint256 initialGas,
        address tokenAddress,
        uint256 amount,
        uint256 tokenGasPrice
    ) internal returns (uint256 amountToTransfer) {
        uint256 transferFeePerc = getTransferFee(tokenAddress, amount);
        uint256 lpFee;
        if (transferFeePerc > tokenManager.getTokensInfo(tokenAddress).equilibriumFee) {
            // Here add some fee to incentive pool also
            lpFee = (amount * tokenManager.getTokensInfo(tokenAddress).equilibriumFee) / BASE_DIVISOR;
            incentivePool[tokenAddress] =
                (incentivePool[tokenAddress] +
                    (amount * (transferFeePerc - tokenManager.getTokensInfo(tokenAddress).equilibriumFee))) /
                BASE_DIVISOR;
        } else {
            lpFee = (amount * transferFeePerc) / BASE_DIVISOR;
        }
        uint256 transferFeeAmount = (amount * transferFeePerc) / BASE_DIVISOR;

        liquidityProviders.addLPFee(tokenAddress, lpFee);

        uint256 totalGasUsed = initialGas - gasleft();
        totalGasUsed = totalGasUsed + tokenManager.getTokensInfo(tokenAddress).transferOverhead;
        totalGasUsed = totalGasUsed + baseGas;

        uint256 gasFee = totalGasUsed * tokenGasPrice;
        gasFeeAccumulatedByToken[tokenAddress] = gasFeeAccumulatedByToken[tokenAddress] + gasFee;
        gasFeeAccumulated[tokenAddress][_msgSender()] = gasFeeAccumulated[tokenAddress][_msgSender()] + gasFee;
        amountToTransfer = amount - (transferFeeAmount + gasFee);

        emit FeeDetails(lpFee, transferFeeAmount, gasFee);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}

// import "./WhitelistPeriodManager.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract WhitelistPeriodManager is Initializable, OwnableUpgradeable, Pausable, ERC2771ContextUpgradeable {
    ILiquidityProviders private liquidityProviders;
    ITokenManager private tokenManager;
    ILPToken private lpToken;
    bool public areWhiteListRestrictionsEnabled;

    /* LP Status */
    // EOA? -> status, stores addresses that we want to ignore, like staking contracts.
    mapping(address => bool) public isExcludedAddress;

    // Token -> TVL
    mapping(address => uint256) private totalLiquidity;

    // ty - i assume this is keeping track how much a lp has deposited.
    // Token -> TVL
    mapping(address => mapping(address => uint256)) public totalLiquidityByLp;

    /* Caps */
    // Token Address -> Limit
    mapping(address => uint256) public perTokenTotalCap;
    // Token Address -> Limit
    mapping(address => uint256) public perTokenWalletCap;

    event ExcludedAddressStatusUpdated(address indexed lp, bool indexed status);
    event TotalCapUpdated(address indexed token, uint256 totalCap);
    event PerTokenWalletCap(address indexed token, uint256 perCommunityWalletCap);
    event WhiteListStatusUpdated(bool status);

    // modifiers
    // modifiers
    // modifiers
    // modifiers
    // modifiers
    // modifiers
    // ==========

    modifier onlyLiquidityPool() {
        require(_msgSender() == address(liquidityProviders), "ERR__UNAUTHORIZED");
        _;
    }

    modifier onlyLpNft() {
        require(_msgSender() == address(lpToken), "ERR__UNAUTHORIZED");
        _;
    }

    modifier tokenChecks(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be 0");
        require(_isSupportedToken(tokenAddress), "Token not supported");

        // _isSupportedToken is defined as:
        //  return tokenManager.getTokensInfo(_token).supportedToken;
        _;
    }

    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // Constructor
    // =========

    /**
     * @dev initalizes the contract, acts as constructor
     * @param _trustedForwarder address of trusted forwarder
     */
    function initialize(
        address _trustedForwarder,
        address _liquidityProviders,
        address _tokenManager,
        address _lpToken,
        address _pauser
    ) public initializer {
        __ERC2771Context_init(_trustedForwarder);
        __Ownable_init();
        __Pausable_init(_pauser);
        areWhiteListRestrictionsEnabled = true;
        _setLiquidityProviders(_liquidityProviders);
        _setTokenManager(_tokenManager);
        _setLpToken(_lpToken);
    }

    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // Liquidity pool-only functions
    // ============================

    /**
     * @dev External Function which checks for various caps before allowing LP to add liqudity. Only callable by LiquidityPoolManager
     */
    function beforeLiquidityAddition(
        address _lp,
        address _token,
        uint256 _amount
    ) external onlyLiquidityPool whenNotPaused {
        // _beforeLiquidityAddition(_lp, _token, _amount);

        // _beforeLiquidityAddition func defined as:
        //
        if (isExcludedAddress[_lp]) {
            return;
        }

        // Per Token Total Cap or PTTC
        require(ifEnabled(totalLiquidity[_token] + _amount <= perTokenTotalCap[_token]), "ERR__LIQUIDITY_EXCEEDS_PTTC");
        require(
            ifEnabled(totalLiquidityByLp[_token][_lp] + _amount <= perTokenWalletCap[_token]),
            "ERR__LIQUIDITY_EXCEEDS_PTWC"
        );

        totalLiquidity[_token] += _amount;
        totalLiquidityByLp[_token][_lp] += _amount;
    }

    /**
     * @dev External Function which checks for various caps before allowing LP to remove liqudity. Only callable by LiquidityPoolManager
     */
    function beforeLiquidityRemoval(
        address _lp,
        address _token,
        uint256 _amount
    ) external onlyLiquidityPool whenNotPaused {
        _beforeLiquidityRemoval(_lp, _token, _amount);

        // _beforeLiquidityRemoval func defined as:
        //
        //     if (isExcludedAddress[_lp]) {
        //         return;
        //     }
        //
        //     totalLiquidityByLp[_token][_lp] -= _amount;
        //     totalLiquidity[_token] -= _amount;
    }

    // LP NFT-only functions
    // LP NFT-only functions
    // LP NFT-only functions
    // LP NFT-only functions
    // LP NFT-only functions
    // LP NFT-only functions
    // LP NFT-only functions
    // LP NFT-only functions
    // =======================
    // Note that the LPToken is the only contract who can call this functions.

    /**
     * @dev External Function which checks for various caps before allowing LP to transfer their LpNFT. Only callable by LpNFT contract
     */
    function beforeLiquidityTransfer(
        address _from,
        address _to,
        address _token,
        uint256 _amount
    ) external onlyLpNft whenNotPaused {
        // Release limit from  _from
        _beforeLiquidityRemoval(_from, _token, _amount);

        // _beforeLiquidityRemoval is defined as:
        //
        // if (isExcludedAddress[_lp]) {
        //     return;
        // }
        // totalLiquidityByLp[_token][_lp] -= _amount;
        // totalLiquidity[_token] -= _amount;

        // Block limit of _to
        _beforeLiquidityAddition(_to, _token, _amount);

        // _beforeLiquidityAddition is defined as:
        //
        // if (isExcludedAddress[_lp]) {
        //     return;
        // }
        // // Per Token Total Cap or PTTC
        // require(
        //     ifEnabled(totalLiquidity[_token] + _amount <= perTokenTotalCap[_token]),
        //     "ERR__LIQUIDITY_EXCEEDS_PTTC"
        // );

        // // checks that the amount the lp is depositing is not more than the wallet limit
        // require(
        //     ifEnabled(totalLiquidityByLp[_token][_lp] + _amount <= perTokenWalletCap[_token]),
        //     "ERR__LIQUIDITY_EXCEEDS_PTWC"
        // );

        // totalLiquidity[_token] += _amount;
        // totalLiquidityByLp[_token][_lp] += _amount;
    }

    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // only owner functions
    // =====================

    function setTokenManager(address _tokenManager) external onlyOwner {
        _setTokenManager(_tokenManager);
    }

    function setLiquidityProviders(address _liquidityProviders) external onlyOwner {
        _setLiquidityProviders(_liquidityProviders);
    }

    function setLpToken(address _lpToken) external onlyOwner {
        _setLpToken(_lpToken);
        // _setLpToken is just lpToken = ILPToken(_lpToken);
    }

    function setIsExcludedAddressStatus(address[] memory _addresses, bool[] memory _status) external onlyOwner {
        require(_addresses.length == _status.length, "ERR__LENGTH_MISMATCH");
        for (uint256 i = 0; i < _addresses.length; ++i) {
            isExcludedAddress[_addresses[i]] = _status[i];
            emit ExcludedAddressStatusUpdated(_addresses[i], _status[i]);
        }
    }

    function setTotalCap(address _token, uint256 _totalCap) public tokenChecks(_token) onlyOwner {
        require(totalLiquidity[_token] <= _totalCap, "ERR__TOTAL_CAP_LESS_THAN_SL");
        require(_totalCap >= perTokenWalletCap[_token], "ERR__TOTAL_CAP_LT_PTWC");
        if (perTokenTotalCap[_token] != _totalCap) {
            perTokenTotalCap[_token] = _totalCap;
            emit TotalCapUpdated(_token, _totalCap);
        }
    }

    // ty - this function is never called anywhere in any of the contracts. looks like a function that runs
    //      manually.

    /**
     * @dev Special care must be taken when calling this function
     *      There are no checks for _perTokenWalletCap (since it's onlyOwner), but it's essential that it
     *      should be >= max lp provided by an lp.
     *      Checking this on chain will probably require implementing a bbst, which needs more bandwidth
     *      Call the view function getMaxCommunityLpPositon() separately before changing this value
     */
    function setPerTokenWalletCap(address _token, uint256 _perTokenWalletCap) public tokenChecks(_token) onlyOwner {
        require(_perTokenWalletCap <= perTokenTotalCap[_token], "ERR__PWC_GT_PTTC");

        if (perTokenWalletCap[_token] != _perTokenWalletCap) {
            perTokenWalletCap[_token] = _perTokenWalletCap;

            emit PerTokenWalletCap(_token, _perTokenWalletCap);
        }
    }

    function setCap(
        address _token,
        uint256 _totalCap,
        uint256 _perTokenWalletCap
    ) public onlyOwner {
        setTotalCap(_token, _totalCap);
        setPerTokenWalletCap(_token, _perTokenWalletCap);
    }

    function setCaps(
        address[] memory _tokens,
        uint256[] memory _totalCaps,
        uint256[] memory _perTokenWalletCaps
    ) external onlyOwner {
        require(
            _tokens.length == _totalCaps.length && _totalCaps.length == _perTokenWalletCaps.length,
            "ERR__LENGTH_MISMACH"
        );
        for (uint256 i = 0; i < _tokens.length; ++i) {
            setCap(_tokens[i], _totalCaps[i], _perTokenWalletCaps[i]);
        }
    }

    /**
     * @dev Enables (or disables) reverts if liquidity exceeds caps.
     *      Even if this is disabled, the contract will continue to track LP's positions
     */
    function setAreWhiteListRestrictionsEnabled(bool _status) external onlyOwner {
        areWhiteListRestrictionsEnabled = _status;
        emit WhiteListStatusUpdated(_status);
    }

    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // ==============

    /**
     * @dev Returns the maximum amount a single community LP has provided
     */
    function getMaxCommunityLpPositon(address _token) external view returns (uint256) {
        uint256 totalSupply = lpToken.totalSupply();
        uint256 maxLp = 0;
        for (uint256 i = 1; i <= totalSupply; ++i) {
            uint256 liquidity = totalLiquidityByLp[_token][lpToken.ownerOf(i)];
            if (liquidity > maxLp) {
                maxLp = liquidity;
            }
        }
        return maxLp;
    }

    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // internal functions
    // ==================

    function _setLpToken(address _lpToken) internal {
        lpToken = ILPToken(_lpToken);
    }

    function _setLiquidityProviders(address _liquidityProviders) internal {
        liquidityProviders = ILiquidityProviders(_liquidityProviders);
    }

    function _setTokenManager(address _tokenManager) internal {
        tokenManager = ITokenManager(_tokenManager);
    }

    function _isSupportedToken(address _token) internal view returns (bool) {
        return tokenManager.getTokensInfo(_token).supportedToken;
    }

    /**
     * @dev Internal Function which checks for various caps before allowing LP to add liqudity
     */
    function _beforeLiquidityAddition(
        address _lp,
        address _token,
        uint256 _amount
    ) internal {
        if (isExcludedAddress[_lp]) {
            return;
        }
        // Per Token Total Cap or PTTC
        require(ifEnabled(totalLiquidity[_token] + _amount <= perTokenTotalCap[_token]), "ERR__LIQUIDITY_EXCEEDS_PTTC");
        require(
            ifEnabled(totalLiquidityByLp[_token][_lp] + _amount <= perTokenWalletCap[_token]),
            "ERR__LIQUIDITY_EXCEEDS_PTWC"
        );
        totalLiquidity[_token] += _amount;
        totalLiquidityByLp[_token][_lp] += _amount;
    }

    /**
     * @dev returns the value of if (areWhiteListEnabled) then (_cond)
     */
    function ifEnabled(bool _cond) private view returns (bool) {
        return !areWhiteListRestrictionsEnabled || (areWhiteListRestrictionsEnabled && _cond);
    }

    /**
     * @dev Meta-Transaction Helper, returns msgSender
     */
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * @dev Meta-Transaction Helper, returns msgData
     */
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    /**
     * @dev Internal Function which checks for various caps before allowing LP to remove liqudity
     */
    function _beforeLiquidityRemoval(
        address _lp,
        address _token,
        uint256 _amount
    ) internal {
        if (isExcludedAddress[_lp]) {
            return;
        }
        totalLiquidityByLp[_token][_lp] -= _amount;
        totalLiquidity[_token] -= _amount;
    }
}

// import "./ExecutorManager.sol";

contract ExecutorManager is IExecutorManager, Ownable {
    address[] internal executors;
    mapping(address => bool) internal executorStatus;

    event ExecutorAdded(address executor, address owner);
    event ExecutorRemoved(address executor, address owner);

    // MODIFIERS
    modifier onlyExecutor() {
        require(executorStatus[msg.sender], "You are not allowed to perform this operation");
        _;
    }

    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // owner-only contracts
    // ====================

    //Register new Executors
    function addExecutors(address[] calldata executorArray) external override onlyOwner {
        for (uint256 i = 0; i < executorArray.length; ++i) {
            addExecutor(executorArray[i]);
        }
    }

    // Register single executor
    function addExecutor(address executorAddress) public override onlyOwner {
        require(executorAddress != address(0), "executor address can not be 0");
        require(!executorStatus[executorAddress], "Executor already registered");
        executors.push(executorAddress);
        executorStatus[executorAddress] = true;
        emit ExecutorAdded(executorAddress, msg.sender);
    }

    //Remove registered Executors
    function removeExecutors(address[] calldata executorArray) external override onlyOwner {
        for (uint256 i = 0; i < executorArray.length; ++i) {
            removeExecutor(executorArray[i]);
        }
    }

    // Remove Register single executor
    function removeExecutor(address executorAddress) public override onlyOwner {
        require(executorAddress != address(0), "executor address can not be 0");
        executorStatus[executorAddress] = false;
        emit ExecutorRemoved(executorAddress, msg.sender);
    }

    function getExecutorStatus(address executor) public view override returns (bool status) {
        status = executorStatus[executor];
    }

    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // view functions
    // ==============

    function getAllExecutors() public view override returns (address[] memory) {
        return executors;
    }
}

// import "./ERC20Token.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Token is ERC20Upgradeable {
    function initialize(string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

// import "./token/SvgHelperBase.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract SvgHelperBase is Ownable {
    using Strings for uint256;

    uint256 public tokenDecimals;

    event BackgroundUrlUpdated(string newBackgroundUrl);
    event TokenDecimalsUpdated(uint256 newTokenDecimals);

    constructor(uint256 _tokenDecimals) Ownable() {
        tokenDecimals = _tokenDecimals;
    }

    function setTokenDecimals(uint256 _tokenDecimals) public onlyOwner {
        tokenDecimals = _tokenDecimals;
        emit TokenDecimalsUpdated(_tokenDecimals);
    }

    /// @notice Given an integer, returns the number of digits in it's decimal representation.
    /// @param _number The number to get the number of digits in.
    /// @return The number of digits in the decimal representation of the given number.
    function _getDigitsCount(uint256 _number) internal pure returns (uint256) {
        uint256 count = 0;
        while (_number > 0) {
            ++count;
            _number /= 10;
        }
        return count;
    }

    /// @notice Generates a string containing 0s of the given length.
    /// @param _length The length of the string to generate.
    /// @return A string of 0s of the given length.
    function _getZeroString(uint256 _length) internal pure returns (string memory) {
        if (_length == 0) {
            return "";
        }
        string memory result;
        for (uint256 i = 0; i < _length; ++i) {
            result = string(abi.encodePacked(result, "0"));
        }
        return result;
    }

    /// @notice Truncate Digits from the right
    function _truncateDigitsFromRight(uint256 _number, uint256 _digitsCount) internal pure returns (uint256) {
        uint256 result = _number /= (10**_digitsCount);
        // Remove Leading Zeroes
        while (result != 0 && result % 10 == 0) {
            result /= 10;
        }
        return result;
    }

    /// @notice Return str(_value / 10^_power)
    function _divideByPowerOf10(
        uint256 _value,
        uint256 _power,
        uint256 _maxDigitsAfterDecimal
    ) internal pure returns (string memory) {
        uint256 integerPart = _value / 10**_power;
        uint256 leadingZeroesToAddBeforeDecimal = 0;
        uint256 fractionalPartTemp = _value % (10**_power);

        uint256 powerRemaining = _power;
        if (fractionalPartTemp != 0) {
            // Remove Leading Zeroes
            while (fractionalPartTemp != 0 && fractionalPartTemp % 10 == 0) {
                fractionalPartTemp /= 10;
                if (powerRemaining > 0) {
                    powerRemaining--;
                }
            }

            uint256 expectedFractionalDigits = powerRemaining;
            if (_getDigitsCount(fractionalPartTemp) < expectedFractionalDigits) {
                leadingZeroesToAddBeforeDecimal = expectedFractionalDigits - _getDigitsCount(fractionalPartTemp);
            }
        }

        if (fractionalPartTemp == 0) {
            return integerPart.toString();
        }
        uint256 digitsToTruncateCount = _getDigitsCount(fractionalPartTemp) + leadingZeroesToAddBeforeDecimal >
            _maxDigitsAfterDecimal
            ? _getDigitsCount(fractionalPartTemp) + leadingZeroesToAddBeforeDecimal - _maxDigitsAfterDecimal
            : 0;
        return
            string(
                abi.encodePacked(
                    integerPart.toString(),
                    ".",
                    _getZeroString(leadingZeroesToAddBeforeDecimal),
                    _truncateDigitsFromRight(fractionalPartTemp, digitsToTruncateCount).toString()
                )
            );
    }

    function getAttributes(uint256 _suppliedLiquidity, uint256 _totalSuppliedLiquidity)
        public
        view
        virtual
        returns (string memory)
    {
        string memory suppliedLiquidity = _divideByPowerOf10(_suppliedLiquidity, tokenDecimals, 3);
        string memory sharePercent = _calculatePercentage(_suppliedLiquidity, _totalSuppliedLiquidity);
        return
            string(
                abi.encodePacked(
                    "[",
                    '{ "trait_type": "Supplied Liquidity", "display_type": "number", "value": ',
                    suppliedLiquidity,
                    '},{ "trait_type": "Share Percentage", "value": "',
                    sharePercent,
                    '%"}]'
                )
            );
    }

    function getDescription(uint256 _suppliedLiquidity, uint256 _totalSuppliedLiquidity)
        public
        view
        virtual
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "This NFT represents your position as Liquidity Provider on Hyphen Bridge on ",
                    getChainName(),
                    ". To visit the bridge, visit [Hyphen](https://hyphen.biconomy.io)."
                )
            );
    }

    /// @notice Return str(_value / _denom * 100)
    function _calculatePercentage(uint256 _num, uint256 _denom) internal pure returns (string memory) {
        return _divideByPowerOf10((_num * 10**(18 + 2)) / _denom, 18, 2);
    }

    function getTokenSvg(
        uint256 _tokenId,
        uint256 _suppliedLiquidity,
        uint256 _totalSuppliedLiquidity
    ) public view virtual returns (string memory);

    function getChainName() public view virtual returns (string memory);
}
