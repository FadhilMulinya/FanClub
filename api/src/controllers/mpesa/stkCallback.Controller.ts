import { Request, Response } from 'express';
import Transaction, {
	TransactionFailureReason,
	TransactionStatus,
} from '../../models/transaction.model';
import { escrow } from '../../MintIntents/escrow';

/**
 * @openapi
 * /api/v1/mpesa/stk/callback:
 *   post:
 *     summary: Handle M-Pesa STK Push callback
 *     tags: [Mpesa]
 *     description: Receives callback from M-Pesa after STK push payment attempt. Always responds with 200 to acknowledge receipt.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               Body:
 *                 type: object
 *                 properties:
 *                   stkCallback:
 *                     type: object
 *     responses:
 *       200:
 *         description: Callback received and processed
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Callback received successfully!
 */
export const stkCallbackHandler = async (req: Request, res: Response) => {
	try {
		const {
			Body: { stkCallback },
		} = req.body;

		console.log('STK Callback received', stkCallback);

		// Find transaction using the MerchantRequestID
		let transaction = await Transaction.findOne({
			'mpesaMetadata.MerchantRequestID': stkCallback.MerchantRequestID,
		});

		if (!transaction) {
			console.error(`${stkCallback.MerchantRequestID} Transaction not found`);
			return res.status(200).json({
				message: 'Callback received successfully!',
			});
		}

		// Check if mpesa transaction was successful (ResultCode 0 means success)
		if (stkCallback.ResultCode == 0) {
			// Update transaction status
			transaction.status = TransactionStatus.Completed;
			transaction.mpesaCode = stkCallback.CallbackMetadata.Item[1].Value;

			// Extract phone number from callback metadata
			transaction.mpesaMetadata.PhoneNumber = stkCallback.CallbackMetadata.Item.filter(
				(item: any) => item.Name === 'PhoneNumber'
			)[0].Value;

			await transaction.save();

			// Submit Intent to Escrow contract
			escrow.submitIntent(transaction.amount, transaction.mpesaCode);
		} else {
			// Handle failed transaction
			transaction.status = TransactionStatus.Failed;
			transaction.failureReason = TransactionFailureReason.MpesaTransactionCancelledOrFailed;

			await transaction.save();
		}

		// Always return a 200 status to acknowledge receipt
		return res.status(200).json({
			message: 'Callback received successfully!',
		});
	} catch (err: any) {
		console.error(`STK Callback error: ${err.message}`);

		// Always acknowledge receipt to M-Pesa
		return res.status(200).json({
			message: 'Callback received',
		});
	}
};
