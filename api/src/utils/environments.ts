import dotenv from 'dotenv'
dotenv.config()

export const ENV = {
	PORT: Number(process.env.PORT) || 3000,
	NODE_ENV: process.env.NODE_ENV || 'dev',
	RPC_URL: process.env.RPC_URL || 'https://scroll-sepolia.drpc.org',
	// Mpesa
	MPESA_ENV: (process.env.MPESA_ENV as 'sandbox' | 'live') || 'sandbox',
	MPESA_PAY_TYPE: Number(process.env.MPESA_PAY_TYPE),
	MPESA_SHORT_CODE: Number(process.env.MPESA_SHORT_CODE) || 0,
	MPESA_CONSUMER_KEY: process.env.MPESA_CONSUMER_KEY || '',
	MPESA_CONSUMER_SECRET: process.env.MPESA_CONSUMER_SECRET || '',
	MPESA_USER_NAME: process.env.MPESA_USERNAME || '',
	MPESA_PASSWORD: process.env.MPESA_PASSWORD || '',
	MPESA_PASSKEY: process.env.MPESA_PASSKEY || '',
	MPESA_STK_CALLBACK_URL: process.env.MPESA_STK_CALLBACK_URL || '',
	// Database
	MONGO_URI: process.env.MONGO_URI || '',
	// API Docs Auth
	API_DOCS_USER: process.env.API_DOCS_USER || 'admin',
	API_DOCS_PASSWORD: process.env.API_DOCS_PASSWORD || 'password',
}
