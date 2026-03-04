// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ==========================================
// 1. THE VERIFIER CONTRACT
// ==========================================
contract WesolowskiVerifier {
    
    function verifyWesolowski(
        uint256 g, 
        uint256 y, 
        uint256 pi, 
        uint256 T, 
        uint256 N
    ) public view returns (bool) {
        
        uint256 l = uint256(keccak256(abi.encodePacked(g, y, T)));
        uint256 r = callModExp(2, T, l);

        uint256 pi_l = callModExp(pi, l, N);
        uint256 g_r = callModExp(g, r, N);
        
        uint256 computed_y = mulmod(pi_l, g_r, N);

        return computed_y == y;
    }

    function callModExp(
        uint256 base, 
        uint256 exponent, 
        uint256 modulus
    ) internal view returns (uint256 result) {
        bytes memory input = abi.encodePacked(
            uint256(32), uint256(32), uint256(32),
            base, exponent, modulus
        );

        (bool success, bytes memory output) = address(0x05).staticcall(input);
        require(success, "modExp precompile failed");

        result = abi.decode(output, (uint256));
    }
}

// ==========================================
// 2. THE VDF RANDAO CONTRACT (Inherits Verifier)
// ==========================================
contract VDFRandao is WesolowskiVerifier {
    uint256 public revealDeadline;
    bytes32 public currentMix;
    bytes32 public finalRandomness;
    bool public vdfComputed;
    
    // --- VDF PARAMETERS ---
    // We define T and N here so the smart contract knows what to expect
    uint256 public constant T = 50000; 
    // A mock 256-bit RSA Modulus N for simulation purposes
    uint256 public constant N = 115792089237316195423570985008687907853269984665640564039457584007913129639319;
    
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
        currentMix = currentMix ^ bytes32(_secret);
    }

    // --- THE UPDATED SUBMIT FUNCTION ---
    function submitVDF(bytes32 _vdfOutput, bytes memory _proof) external {
        require(block.timestamp > revealDeadline, "Must wait until reveal phase ends");
        require(!vdfComputed, "VDF already computed");
        
        // 1. Cast the seed (g) and the evaluated output (y) to uint256
        uint256 g = uint256(currentMix);
        uint256 y = uint256(_vdfOutput);
        
        // 2. Decode the incoming byte array proof into a uint256 mathematical proof (pi)
        uint256 pi = abi.decode(_proof, (uint256));
        
        // 3. Trigger the Wesolowski math circuit!
        require(verifyWesolowski(g, y, pi, T, N), "Invalid Wesolowski VDF proof");
        
        finalRandomness = _vdfOutput;
        vdfComputed = true;
    }
}