// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Randao.sol";
import "../src/RandaoVDF.sol";

contract RandaoSimulationTest is Test {
    PlainRandao plainRandao;
    VDFRandao vdfRandao;

    function setUp() public {}

    // --- UNIFIED TEST: SIDE-BY-SIDE COMPARISON ---
    function testFuzz_CompareRandao(uint256 numUsers) public {
        // 1. Bound the single instance of numUsers
 
        // Uncomment below line for fuzzy randomly generated user number instead of a hardcoded one
        //numUsers = bound(numUsers, 100, 1000); 
        numUsers = 1000; // Lowered from 10000 to 100 for quicker local testing with FFI
        
        // 2. Deploy both contracts with the same deadline
        plainRandao = new PlainRandao(1000);
        vdfRandao = new VDFRandao(1000);
        
        vm.warp(100); 

        // 3. Commit Phase: All users commit to BOTH contracts
        for (uint256 i = 1; i <= numUsers; i++) {
            address user = address(uint160(i));
            uint256 secret = i * 100; 
            bytes32 commitment = keccak256(abi.encodePacked(secret));
            
            vm.startPrank(user);
            plainRandao.commit(commitment);
            vdfRandao.commit(commitment);
            vm.stopPrank();
        }

        vm.warp(995); 

        // 4. Reveal Phase: Honest users reveal to BOTH contracts
        for (uint256 i = 1; i < numUsers; i++) {
            address honestUser = address(uint160(i));
            uint256 secret = i * 100;
            
            vm.startPrank(honestUser);
            plainRandao.reveal(secret);
            vdfRandao.reveal(secret);
            vm.stopPrank();
        }

        // --- 5. ATTACKER LOGIC (Evaluating both systems) ---
        address attacker = address(uint160(numUsers));
        uint256 attackerSecret = numUsers * 100;

        console.log("=========================================");
        console.log("SIMULATION ROUND | Total Users:", numUsers);
        console.log("-----------------------------------------");

        // System A: Plain RANDAO (Vulnerable)
        bytes32 projectedMixIfRevealed = plainRandao.currentMix() ^ bytes32(attackerSecret);
        bytes32 projectedMixIfWithheld = plainRandao.currentMix();
        
        bool isEvenIfRevealed = uint8(projectedMixIfRevealed[31]) % 2 == 0;
        bool isEvenIfWithheld = uint8(projectedMixIfWithheld[31]) % 2 == 0;

        if (isEvenIfRevealed) {
            vm.prank(attacker);
            plainRandao.reveal(attackerSecret);
            console.log("[PLAIN] Attacker REVEALED to force an EVEN result.");
        } else if (isEvenIfWithheld) {
            console.log("[PLAIN] Attacker WITHHELD to keep the EVEN result.");
        } else {
            console.log("[PLAIN] Attacker WITHHELD (Both options resulted in ODD, attacker loses).");
        }

        // System B: VDF RANDAO (Secure)
        // Attacker is forced to guess and reveal blindly
        vm.prank(attacker);
        vdfRandao.reveal(attackerSecret);
        console.log("[VDF]   Attacker FORCED to reveal blindly (Cannot compute VDF in time).");

        vm.warp(1001); // End of reveal phase

        // --- 6. FINAL RESULTS ---
        // Plain RANDAO Final
        bytes32 finalPlainRandomness = plainRandao.getFinalRandomness();
        bool isPlainFinalEven = uint8(finalPlainRandomness[31]) % 2 == 0;
        
        // --- NEW OFF-CHAIN VDF INTEGRATION ---
        console.log("-----------------------------------------");
        console.log("Triggering Off-Chain Python VDF Computation...");

        // Prepare the arguments to call the Python script
        string[] memory inputs = new string[](3);
        inputs[0] = "python3";
        inputs[1] = "script/vdf_worker.py"; // Make sure your python file is here!
        inputs[2] = vm.toString(vdfRandao.currentMix()); // Pass the seed

        // Call the script using FFI and capture the ABI-encoded output
        bytes memory rawOutput = vm.ffi(inputs);
        
        // DECODE BOTH VARIABLES FROM PYTHON!
        // We extract the evaluated result (finalY) and the Wesolowski proof (proofPi)
        (uint256 finalY, uint256 proofPi) = abi.decode(rawOutput, (uint256, uint256));
        
        console.log("Off-Chain VDF Output Generated:", finalY);
        console.log("Wesolowski Proof (Pi) Generated:", proofPi);

        // Submit the real off-chain computation AND the proof back to the contract
        // We abi.encode proofPi because submitVDF expects `bytes memory _proof`
        vdfRandao.submitVDF(bytes32(finalY), abi.encode(proofPi));
        
        bool isVDFFinalEven = uint8(vdfRandao.finalRandomness()[31]) % 2 == 0;

        console.log("-----------------------------------------");
        console.log("RESULTS: Did the attacker get an EVEN number?");
        console.log("[PLAIN]:", isPlainFinalEven, "(Highly Manipulated)");
        console.log("[VDF]  :", isVDFFinalEven, "(Fair 50/50 Chance)");
        console.log("=========================================\n");

        // Comment this out to stop forcefully failing the test, but logs won't show in the console.
        revert("SHOW ME THE LOGS!");
    }
}