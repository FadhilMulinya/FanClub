import { createWalletClient, http, publicActions } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { scrollSepolia } from 'viem/chains';
import dotenv from 'dotenv';

dotenv.config();

export const walletService = () => {
  if (!process.env.PRIVATE_KEY) {
    throw new Error("❌ Missing PRIVATE_KEY in environment variables");
  }
    if (!process.env.RPC_URL) {
    throw new Error("❌ Missing RPC_URL in environment variables");
  }

  // Create account from private key
  const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);

  const rpc_url = process.env.RPC_URL;

  // Create wallet client
  const walletClient = createWalletClient({
    account,
    chain: scrollSepolia,
    transport: http(rpc_url),
  }).extend(publicActions);


  return {
    account,
    walletClient,
    address: account.address,
  };
};

// Example usage
const wallet = walletService();
console.log("✅ Wallet initialized for address:", wallet.address);
