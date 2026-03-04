import sys
from eth_utils import keccak

# Parameters strictly matching the VDFRandao.sol contract
T = 50000 
N = 115792089237316195423570985008687907853269984665640564039457584007913129639319

def compute_vdf_and_proof(seed_hex):
    if seed_hex.startswith("0x"):
        seed_hex = seed_hex[2:]
        
    # 1. Map seed to generator 'g'
    g = int(seed_hex, 16) % N
    
    # 2. EVALUATION PHASE: Sequential Squaring
    # This loop is the physical "delay" representing the VDF evaluation time.
    y = g
    for _ in range(T):
        y = (y * y) % N
        
    # 3. PROOF GENERATION: The Fiat-Shamir Heuristic
    # Pack g, y, and T into 32-byte big-endian arrays to match Solidity's abi.encodePacked
    g_bytes = g.to_bytes(32, 'big')
    y_bytes = y.to_bytes(32, 'big')
    t_bytes = T.to_bytes(32, 'big')
    
    # Calculate the prime challenge 'l' exactly as the smart contract does
    l_hash = keccak(g_bytes + y_bytes + t_bytes)
    l = int.from_bytes(l_hash, 'big')
    
    # 4. Long Division of Exponents
    # We divide the massive theoretical exponent (2^T) by l to find the quotient (q)
    # Python natively handles massive numbers, so this calculates instantly.
    q = (2**T) // l
    
    # 5. Compute the proof (pi) = g^q mod N
    # We use Python's highly optimized built-in pow() for the proof exponentiation
    pi = pow(g, q, N)
    
    # 6. ABI ENCODING FOR SOLIDITY
    # Solidity expects a continuous hex string. We encode y and pi as two 32-byte hex strings.
    y_hex = y.to_bytes(32, 'big').hex()
    pi_hex = pi.to_bytes(32, 'big').hex()
    
    return "0x" + y_hex + pi_hex

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error: No seed provided")
        sys.exit(1)
        
    seed = sys.argv[1]
    
    output = compute_vdf_and_proof(seed)
    
    # Print the ABI-encoded hex string so Foundry's vm.ffi can capture it
    print(output)