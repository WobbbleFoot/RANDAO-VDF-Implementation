// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract PlainRandao {
    uint256 public revealDeadline;
    bytes32 public currentMix;
    
    mapping(address => bytes32) public commitments;
    mapping(address => bool) public hasRevealed;

    constructor(uint256 _revealDeadline) {
        revealDeadline = _revealDeadline;
    }

    function commit(bytes32 _commitment) external {
        require(block.timestamp < revealDeadline - 10, "Commit phase over");
        commitments[msg.sender] = _commitment;
    }

    function reveal(uint256 _secret) external {
        require(block.timestamp <= revealDeadline, "Reveal phase over");
        require(!hasRevealed[msg.sender], "Already revealed");
        require(keccak256(abi.encodePacked(_secret)) == commitments[msg.sender], "Invalid secret");

        hasRevealed[msg.sender] = true;
        // XOR the secret into the mix
        currentMix = currentMix ^ bytes32(_secret);
    }

    function getFinalRandomness() external view returns (bytes32) {
        require(block.timestamp > revealDeadline, "Reveal phase not over");
        return currentMix;
    }
}