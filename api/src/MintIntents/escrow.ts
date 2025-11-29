import { ENV } from '../utils/environments'
import { walletService } from '../walletFolder/walletService'
import { ESCROW_CONTRACT_ABI, ESCROW_CONTRACT_ADDRESS } from './escrowABI'
import { createPublicClient, http, parseEther, stringToHex } from 'viem'
import { scrollSepolia } from 'viem/chains'

// Initialize wallet + clients
const { walletClient, account } = walletService()

// Create public client for read-only calls
const publicClient = createPublicClient({
	chain: scrollSepolia,
	transport: http(ENV.RPC_URL),
})

export const escrow = {
	/**
	 * Submit a mint intent to the escrow contract
	 * @param amount - Amount in USD stablecoin
	 * @param countryCode - e.g. "KES"
	 * @param txRef - Off-chain reference (e.g. M-PESA ID)
	 */
	async submitIntent(amount: number, txRef: string) {
		const countryCode = 'KES'
		const amountWei = parseEther(amount.toString())
		const countryBytes32 = stringToHex(countryCode, { size: 32 })
		const txRefBytes32 = stringToHex(txRef, { size: 32 })

		const hash = await walletClient.writeContract({
			address: ESCROW_CONTRACT_ADDRESS,
			abi: ESCROW_CONTRACT_ABI,
			functionName: 'submitIntent',
			args: [amountWei, countryBytes32, txRefBytes32],
			account,
		})

		console.log('✅ submitIntent tx:', hash)
		return hash
	},

	/**
	 * Read an intent by its ID
	 */
	async getIntent(intentId: string) {
		const intentBytes32 = stringToHex(intentId, { size: 32 })

		const result = await publicClient.readContract({
			address: ESCROW_CONTRACT_ADDRESS,
			abi: ESCROW_CONTRACT_ABI,
			functionName: 'getIntent',
			args: [intentBytes32],
		})

		console.log('ℹ️ getIntent result:', result)
		return result
	},

	/**
	 * Execute a mint for a pending intent (admin-only)
	 */
	async executeMint(intentId: string) {
		const intentBytes32 = stringToHex(intentId, { size: 32 })

		const hash = await walletClient.writeContract({
			address: ESCROW_CONTRACT_ADDRESS,
			abi: ESCROW_CONTRACT_ABI,
			functionName: 'executeMint',
			args: [intentBytes32],
			account,
		})

		console.log('✅ executeMint tx:', hash)
		return hash
	},
}
