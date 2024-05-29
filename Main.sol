// SPDX-License-Identifier: UNLICENSED
// Title: Newbie-friendly Whitelist Smart Contract 
// Author: Wiggins LYU 
pragma solidity ^0.8.20;

import "./MerkleProof.sol";  // 引入 MerkleProof 合约，用于默克尔证明的验证

// Ownable 是一个抽象合约，用于管理合约的所有权
abstract contract Ownable {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Unauthorized();  // 未授权访问时抛出的错误
    error InvalidOwner();  // 指定无效所有者时抛出的错误

    address public owner;  // 合约的所有者地址

    // 限制只有所有者可以调用的函数
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // 构造函数，设置初始所有者
    constructor(address _owner) {
        if (_owner == address(0)) revert InvalidOwner();
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    // 允许当前所有者转移合约的控制权
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // 允许所有者放弃合约的控制权
    function revokeOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

// Token_WhiteList 是主合约，管理代币铸造的白名单
contract Token_WhiteList is Ownable {
    bytes32 public merkleRoot;  // 默克尔树的根，用于验证白名单
    bool public isOpen;  // 表示铸造操作是否开放
    mapping(address => bool) public mintWhitelistMap;  // 跟踪哪些地址被白名单允许
    address[] public mapKeys;  // 辅助数组，用于跟踪所有键

    // 构造函数，初始化白名单并设置合约所有者
    constructor(address[] memory _addresses) Ownable(msg.sender) {
        for(uint i = 0; i < _addresses.length; i++) {
            mintWhitelistMap[_addresses[i]] = true;
            if (!contains(_addresses[i])) {
                mapKeys.push(_addresses[i]);
            }
        }
    }
    
    // 设置或更新地址的白名单状态
    function setMintWhitelist(address target, bool state) public onlyOwner {
        mintWhitelistMap[target] = state;
        if (!contains(target)) {
            mapKeys.push(target);
        }
    }

    // 开放或关闭铸造操作
    function setIsOpen(bool state) public onlyOwner {
        isOpen = state;
    }

    // 更新用于白名单验证的默克尔树根
    function setMerkleRoot(bytes32 node) public onlyOwner {
        merkleRoot = node;
    }

    // 检查地址是否在白名单上
    function verifyWhitelistNumber(address target) public view returns (bool) {
        return mintWhitelistMap[target];
    }

    // 获取完整白名单及其状态
    function getWhitelist() public view returns (address[] memory, bool[] memory) {
        bool[] memory allData = new bool[](mapKeys.length);
        for (uint i = 0; i < mapKeys.length; i++) {
            allData[i] = mintWhitelistMap[mapKeys[i]];
        }
        return (mapKeys, allData);
    }

    // 允许用户使用有效的默克尔证明将自己添加到白名单
    function mintWhitelist(bytes32 node, bytes32[] calldata _merkleProof) public {
        require(isOpen, "Mint operation is closed");
        require(!mintWhitelistMap[msg.sender], "You are already a whitelist member");
        require(merkleProof(node, _merkleProof, merkleRoot), "Merkle treeverification failed");
        mintWhitelistMap[msg.sender] = true;
        if (!contains(msg.sender)) {
            mapKeys.push(msg.sender);
        }
    }

    // 检查一个地址是否已经在 mapKeys 数组中
    function contains(address key) private view returns (bool) {
        for (uint i = 0; i < mapKeys.length; i++) {
            if (mapKeys[i] == key) {
                return true;
            }
        }
        return false;
    }

    // 验证默克尔证明，用于确保数据的正确性和完整性
    function merkleProof(bytes32 node, bytes32[] calldata _merkleProof, bytes32 _merkleRoot) public pure returns(bool) {
        // 计算 sha256 值
        bytes32 leaf = sha256(abi.encodePacked(node));
        // 验证默克尔证明是否通过
        return MerkleProof.verify(_merkleProof, _merkleRoot, leaf);
    }
}
