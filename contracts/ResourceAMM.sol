// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { GameItems } from "./GameItems.sol";

/// @title ResourceAMM
/// @notice Constant-product (x*y=k) AMM for ERC1155 game resources.
/// @dev Supports a single pair (tokenA <-> tokenB) of ERC1155 resource IDs.
///      LP shares are tracked internally; no external LP ERC20 is minted to keep
///      contract scope focused — governance can extend this later via UUPS upgrade.
contract ResourceAMM is AccessControl, ReentrancyGuard, IERC1155Receiver {
    // ───────────────────────── roles ─────────────────────────────────────────
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    // ───────────────────────── constants ─────────────────────────────────────
    uint256 public constant FEE_DENOMINATOR = 10_000;
    uint256 public constant MIN_LIQUIDITY   = 1_000;

    // ───────────────────────── state ─────────────────────────────────────────
    GameItems public immutable items;
    uint256   public immutable tokenA;   // resource ID A
    uint256   public immutable tokenB;   // resource ID B

    uint256 public reserveA;
    uint256 public reserveB;

    /// @notice Protocol fee in bps (default 30 = 0.30 %)
    uint256 public feeBps;
    /// @notice Accumulated fees sent to feeReceiver
    address public feeReceiver;

    /// @notice LP shares per provider
    mapping(address => uint256) public lpShares;
    uint256 public totalShares;

    // ───────────────────────── events ────────────────────────────────────────
    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    event Swap(
        address indexed trader,
        uint256 tokenIn,
        uint256 amountIn,
        uint256 tokenOut,
        uint256 amountOut,
        uint256 fee
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    // ───────────────────────── errors ────────────────────────────────────────
    error ZeroAmount();
    error InvalidToken();
    error InsufficientLiquidity();
    error SlippageExceeded(uint256 amountOut, uint256 minAmountOut);
    error InsufficientShares();
    error FeeTooHigh();

    // ───────────────────────── constructor ───────────────────────────────────
    constructor(
        address _items,
        uint256 _tokenA,
        uint256 _tokenB,
        uint256 _feeBps,
        address _feeReceiver,
        address _admin
    ) {
        require(_items != address(0), "ResourceAMM: zero items");
        require(_tokenA != _tokenB, "ResourceAMM: identical tokens");
        require(_feeBps <= 1_000, "ResourceAMM: fee > 10%");
        require(_feeReceiver != address(0), "ResourceAMM: zero feeReceiver");
        require(_admin != address(0), "ResourceAMM: zero admin");

        items        = GameItems(_items);
        tokenA       = _tokenA;
        tokenB       = _tokenB;
        feeBps       = _feeBps;
        feeReceiver  = _feeReceiver;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
    }

    // ───────────────────────── liquidity ─────────────────────────────────────

    /// @notice Deposit both resources proportionally and receive LP shares.
    /// @param amountA  Desired amount of tokenA to deposit.
    /// @param amountB  Desired amount of tokenB to deposit.
    /// @param minShares Minimum LP shares to receive (slippage guard).
    function addLiquidity(
        uint256 amountA,
        uint256 amountB,
        uint256 minShares
    ) external nonReentrant returns (uint256 shares) {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        // Pull tokens from caller
        items.safeTransferFrom(msg.sender, address(this), tokenA, amountA, "");
        items.safeTransferFrom(msg.sender, address(this), tokenB, amountB, "");

        if (totalShares == 0) {
            // First deposit — geometric mean as initial shares, minus MIN_LIQUIDITY
            shares = _sqrt(amountA * amountB);
            require(shares > MIN_LIQUIDITY, "ResourceAMM: initial liquidity too low");
            // Lock MIN_LIQUIDITY forever (sent to address(1))
            lpShares[address(1)] += MIN_LIQUIDITY;
            totalShares           += MIN_LIQUIDITY;
            shares                -= MIN_LIQUIDITY;
        } else {
            // Proportional mint
            uint256 sharesA = (amountA * totalShares) / reserveA;
            uint256 sharesB = (amountB * totalShares) / reserveB;
            shares = sharesA < sharesB ? sharesA : sharesB;
        }

        require(shares >= minShares, "ResourceAMM: insufficient shares minted");

        reserveA         += amountA;
        reserveB         += amountB;
        lpShares[msg.sender] += shares;
        totalShares          += shares;

        emit LiquidityAdded(msg.sender, amountA, amountB, shares);
    }

    /// @notice Burn LP shares and withdraw proportional resources.
    /// @param shares       LP shares to burn.
    /// @param minAmountA   Minimum tokenA to receive.
    /// @param minAmountB   Minimum tokenB to receive.
    function removeLiquidity(
        uint256 shares,
        uint256 minAmountA,
        uint256 minAmountB
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (shares == 0) revert ZeroAmount();
        if (lpShares[msg.sender] < shares) revert InsufficientShares();

        amountA = (shares * reserveA) / totalShares;
        amountB = (shares * reserveB) / totalShares;

        if (amountA < minAmountA) revert SlippageExceeded(amountA, minAmountA);
        if (amountB < minAmountB) revert SlippageExceeded(amountB, minAmountB);

        lpShares[msg.sender] -= shares;
        totalShares          -= shares;
        reserveA             -= amountA;
        reserveB             -= amountB;

        items.safeTransferFrom(address(this), msg.sender, tokenA, amountA, "");
        items.safeTransferFrom(address(this), msg.sender, tokenB, amountB, "");

        emit LiquidityRemoved(msg.sender, amountA, amountB, shares);
    }

    // ───────────────────────── swap ──────────────────────────────────────────

    /// @notice Swap an exact amount of one resource for the other.
    /// @param _tokenIn     Resource ID to sell (must be tokenA or tokenB).
    /// @param amountIn     Exact amount of tokenIn to sell.
    /// @param minAmountOut Minimum output enforcing slippage tolerance.
    function swap(
        uint256 _tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (_tokenIn != tokenA && _tokenIn != tokenB) revert InvalidToken();

        bool aToB = (_tokenIn == tokenA);
        (uint256 reserveIn, uint256 reserveOut) = aToB
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        // Calculate fee and net input
        uint256 fee        = (amountIn * feeBps) / FEE_DENOMINATOR;
        uint256 amountInNet = amountIn - fee;

        // x*y = k  →  amountOut = reserveOut - k/(reserveIn + amountInNet)
        uint256 k          = reserveIn * reserveOut;
        uint256 newReserveIn = reserveIn + amountInNet;
        amountOut = reserveOut - (k / newReserveIn);

        if (amountOut < minAmountOut) revert SlippageExceeded(amountOut, minAmountOut);
        if (amountOut == 0) revert InsufficientLiquidity();

        // Pull tokenIn from caller
        items.safeTransferFrom(msg.sender, address(this), _tokenIn, amountIn, "");

        // Send fee to feeReceiver
        if (fee > 0) {
            items.safeTransferFrom(address(this), feeReceiver, _tokenIn, fee, "");
        }

        // Update reserves
        uint256 tokenOut = aToB ? tokenB : tokenA;
        if (aToB) {
            reserveA += amountInNet;
            reserveB -= amountOut;
        } else {
            reserveB += amountInNet;
            reserveA -= amountOut;
        }

        // Push tokenOut to caller
        items.safeTransferFrom(address(this), msg.sender, tokenOut, amountOut, "");

        emit Swap(msg.sender, _tokenIn, amountIn, tokenOut, amountOut, fee);
    }

    // ───────────────────────── view helpers ──────────────────────────────────

    /// @notice Quote: how much tokenOut for a given amountIn (fee-adjusted)?
    function getAmountOut(uint256 _tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (_tokenIn != tokenA && _tokenIn != tokenB) revert InvalidToken();
        bool aToB = (_tokenIn == tokenA);
        (uint256 rIn, uint256 rOut) = aToB ? (reserveA, reserveB) : (reserveB, reserveA);
        if (rIn == 0 || rOut == 0) return 0;
        uint256 fee        = (amountIn * feeBps) / FEE_DENOMINATOR;
        uint256 amountInNet = amountIn - fee;
        amountOut = rOut - ((rIn * rOut) / (rIn + amountInNet));
    }

    /// @notice Current pool reserves.
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    // ───────────────────────── admin ─────────────────────────────────────────

    function setFeeBps(uint256 newFeeBps) external onlyRole(FEE_MANAGER_ROLE) {
        if (newFeeBps > 1_000) revert FeeTooHigh();
        emit FeeUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function setFeeReceiver(address newReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newReceiver != address(0), "ResourceAMM: zero receiver");
        emit FeeReceiverUpdated(feeReceiver, newReceiver);
        feeReceiver = newReceiver;
    }

    // ───────────────────────── ERC1155 receiver ──────────────────────────────

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external pure override returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external pure override returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(AccessControl, IERC1155Receiver) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ───────────────────────── internal ──────────────────────────────────────

    /// @dev Babylonian square root.
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        assembly ("memory-safe") {
            switch gt(y, 3)
            case 1 {
                z := y
                let x := add(div(y, 2), 1)
                for {} lt(x, z) {} {
                    z := x
                    x := div(add(div(y, x), x), 2)
                }
            }
            default {
                if gt(y, 0) { z := 1 }
            }
        }
    }
}
