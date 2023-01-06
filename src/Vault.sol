// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/interfaces/IERC1271.sol";

import "./VaultRegistry.sol";

error NotAuthorized();

/// @title Tokenbound Vault
/// @notice A smart contract wallet owned by a single ERC721 token.
/// @author Jayden Windle
contract Vault {
    // before any transfer
    // check nft ownership
    // extensible as fuck

    /// @dev Address of VaultRegistry
    VaultRegistry public immutable vaultRegistry;

    constructor() {
        vaultRegistry = VaultRegistry(msg.sender);
    }

    /// @dev Returns the owner of the token that controls this Vault
    function owner() public view returns (address) {
        return vaultRegistry.vaultOwner(address(this));
    }

    /**
     * @dev Executes a transaction from the Vault. Must be called by Vault owner
     * @param to      Destination address of the transaction
     * @param value   Ether value of the transaction
     * @param data    Encoded payload of the transaction
     */
    function executeCall(
        address payable to,
        uint256 value,
        bytes calldata data
    ) external payable {
        bool isAuthorized = vaultRegistry.isAuthorizedCaller(
            address(this),
            msg.sender
        );

        if (!isAuthorized) revert NotAuthorized();

        (bool success, bytes memory result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Executes a delegated transaction from the Vault, allowing vault
     * functionality to be expanded without upgradability. Must be called by the Vault owner
     * @param to      Contract address of the delegated call
     * @param data    Encoded payload of the delegated call
     */
    function executeDelegateCall(address payable to, bytes calldata data)
        external
        payable
    {
        bool isAuthorized = vaultRegistry.isAuthorizedCaller(
            address(this),
            msg.sender
        );

        if (!isAuthorized) revert NotAuthorized();

        (bool success, bytes memory result) = to.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @dev Implements EIP-1271 signature validation
     * @param hash      Hash of the signed data
     * @param signature Signature to validate
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        bool isValid = vaultRegistry.isAuthorizedSigner(
            address(this),
            hash,
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }
    }

    // receiver functions

    /// @dev allows contract to receive Ether
    receive() external payable {}

    /// @dev ensures that fallback calls are a noop
    fallback() external payable {}

    /// @dev Allows all ERC721 tokens to be received
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev Allows all ERC1155 tokens to be received
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /// @dev Allows all ERC1155 token batches to be received
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
