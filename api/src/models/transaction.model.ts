import { Document, Schema, model } from 'mongoose'

export enum TransactionStatus {
	Processing = 'processing',
	Completed = 'completed',
	Failed = 'failed',
}

export enum TransactionFailureReason {
	MpesaTransactionCancelledOrFailed = 'mpesa_transaction_cancelled_or_failed',
	BlockchainTransferFailed = 'blockchain_transfer_failed',
}

export interface ITransaction extends Document {
	amount: number
	status: TransactionStatus
	mpesaCode: string
	failureReason?: TransactionFailureReason
	mpesaMetadata: {
		MerchantRequestID: string
		CheckoutRequestID: string
		ResponseCode: string
		ResponseDescription: string
		CustomerMessage: string
		PhoneNumber: string
	}
	createdAt: Date
	updatedAt: Date
}

const TransactionSchema = new Schema<ITransaction>(
	{
		amount: { type: Number, required: true },
		status: {
			type: String,
			enum: Object.values(TransactionStatus),
			default: TransactionStatus.Processing,
		},
		mpesaCode: { type: String, required: false },
		failureReason: {
			type: String,
			enum: Object.values(TransactionFailureReason),
			required: false,
		},
		mpesaMetadata: {
			MerchantRequestID: { type: String, default: '' },
			CheckoutRequestID: { type: String, default: '' },
			ResponseCode: { type: String, default: '' },
			ResponseDescription: { type: String, default: '' },
			CustomerMessage: { type: String, default: '' },
			PhoneNumber: { type: String, default: '' },
		},
	},
	{ timestamps: true }
)

const Transaction = model<ITransaction>('Transaction', TransactionSchema)
export default Transaction
