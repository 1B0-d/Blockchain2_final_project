// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

/// @title GameItems
/// @notice ERC1155 resources and crafted items for the GameFi economy protocol.
contract GameItems is ERC1155, ERC1155Supply, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_SYSTEM_ROLE = keccak256("GAME_SYSTEM_ROLE");

    uint256 public constant WOOD = 1;
    uint256 public constant IRON = 2;
    uint256 public constant CRYSTAL = 3;
    uint256 public constant SWORD = 100;
    uint256 public constant SHIELD = 101;
    uint256 public constant RELIC = 200;

    event ItemMinted(address indexed operator, address indexed to, uint256 indexed id, uint256 amount);
    event ItemBurned(address indexed operator, address indexed from, uint256 indexed id, uint256 amount);

    constructor(string memory metadataUri, address admin) ERC1155(metadataUri) {
        require(admin != address(0), "GameItems: zero admin");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(GAME_SYSTEM_ROLE, admin);
    }

    function setURI(string calldata newUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newUri);
    }

    function mint(address to, uint256 id, uint256 amount, bytes calldata data)
        external
        onlyRole(MINTER_ROLE)
    {
        require(to != address(0), "GameItems: zero recipient");
        require(amount > 0, "GameItems: zero amount");

        _mint(to, id, amount, data);
        emit ItemMinted(msg.sender, to, id, amount);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "GameItems: zero recipient");

        _mintBatch(to, ids, amounts, data);
    }

    function burnFrom(address from, uint256 id, uint256 amount)
        external
        onlyRole(GAME_SYSTEM_ROLE)
    {
        require(amount > 0, "GameItems: zero amount");

        _burn(from, id, amount);
        emit ItemBurned(msg.sender, from, id, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}

