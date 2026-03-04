# RANDAO vs. VDF: Empirical Security Analysis and Foundry Simulation

This repository contains the supplementary source code and empirical testing framework for the research project: **Simulating L2 transactions with alternate VDF implemented RANDAO on Proof-of-Stake Blockchain Networks**.

It provides a local, reproducible simulation of Ethereum's RANDAO randomness beacon, demonstrating the **Last-Revealer Attack** on the execution layer, and proves its mitigation through the implementation of a **Verifiable Delay Function (VDF)** using the Wesolowski (2018) construction.

## 📖 Abstract Overview

In standard commit-reveal schemes (Plain RANDAO), the final scheduled participant possesses a 1-bit informational advantage, allowing them to calculate the final randomness before revealing. If the outcome is financially unfavorable (e.g., losing a block proposal or MEV opportunity), they can withhold their reveal to manipulate the result. 

This repository simulates this game-theoretic attack using Foundry. It then introduces an off-chain Python FFI worker to enforce a strict sequential delay and an on-chain Solidity `modexp` verifier. By forcing the adversary to compute an RSA Group of Unknown Order VDF, their predictive advantage is mathematically neutralized.

## 🗂️ Repository Architecture

* `src/Randao.sol`: The baseline, vulnerable Plain RANDAO implementation.
* `src/RandaoVDF.sol`: The secure RANDAO implementation featuring a Wesolowski VDF verification circuit leveraging the Ethereum `0x05` precompile.
* `test/RandaoSimulation.t.sol`: The unified fuzz-testing suite that evaluates both systems side-by-side under identical validator conditions.
* `script/vdf_worker.py`: The off-chain Python worker that computes the sequential RSA squaring delay and generates the Fiat-Shamir proof.

## ⚙️ Prerequisites

To run this simulation locally, you must have the following installed:
1. **Foundry**: Ethereum smart contract development toolkit.
2. **Python 3.10+**: For executing the off-chain cryptographic delay.
3. **Pip**: Python package manager.

**Important:** You must enable Foreign Function Interface (FFI) in Foundry so the smart contracts can trigger the Python VDF worker. Ensure your `foundry.toml` includes:
```toml
[profile.default]
ffi = true
```

📦 Installation & Setup
Clone the repository:

```Bash
git clone [https://github.com/WobbbleFoot/RANDAO-VDF-Implementation.git](https://github.com/WobbbleFoot/RANDAO-VDF-Implementation.git)
cd RANDAO-VDF-Implementation
```
Install the required Python cryptography libraries:
(Note for Ubuntu/WSL users: If you encounter a PEP 668 "externally-managed-environment" error, use the --break-system-packages flag to install these locally for the simulation).

```Bash
pip install eth-utils "eth-hash[pycryptodome]" --break-system-packages
```
Compile the smart contracts:

```Bash
forge build
```
🚀 Reproducing the Results
To execute the unified simulation, trigger the Python off-chain worker, and observe the attacker's decision-making logic in real-time, run the test with level-3 verbosity:

```Bash
forge test --fuzz-runs 1 -vv
```
📊 Empirical Findings
1. Predictability and Bias Resistance
When running the simulation, the console logs will demonstrate the attacker successfully manipulating the Plain RANDAO system to achieve a targeted outcome ~75% of the time. In the VDF-secured system, the sequential compute delay forces the attacker to guess blindly, collapsing their win rate to a fair 50%.

2. Smart Contract Profiling & Gas Economics
Our profiling of the EVM execution revealed the following costs per epoch:

Deployment: VDFRandao requires 1,050,864 gas compared to PlainRandao's 577,951 gas due to the complex precompile routing logic.

Execution Scaling: Both systems scale linearly at approximately ~100,000 gas per participant.

Verification: Outsourcing the evaluation off-chain allows the on-chain submitVDF verification to execute at a highly efficient, constant cost of 81,953 gas, leveraging the 0x05 precompile.

🛡️ Cryptographic Implementation Notes
The Modulus (N): For the purposes of this open-source simulation, the VDF worker utilizes a 256-bit representation of the RSA-1024 Challenge Number to prevent EVM mulmod overflows while simulating the Group of Unknown Order.

On-Chain Verification: Solidity does not natively support large-integer arithmetic. The RandaoVDF.sol contract packages the Fiat-Shamir challenge l and the proof pi into byte arrays and executes the verification equation natively in the Ethereum client via address 0x05.

📜 License
This project is licensed under the MIT License.
