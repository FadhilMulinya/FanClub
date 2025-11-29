// Get stk push

import { MpesaSDK } from '.';
import { Logger } from 'borgen';
import { HttpStatusCode } from 'axios';
import { Request, Response } from 'express';
import { ENV } from '../../utils/environments';
import { IServerResponse } from '../../types/serverRes';
import Transaction from '../../models/transaction.model';
import { validatePhoneNumber } from '../../utils/validation';

/**
 * @openapi
 * /api/v1/mpesa/stk/init:
 *   post:
 *     summary: Initiate M-Pesa STK Push
 *     tags: [Mpesa]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - mpesaPhoneNumber
 *               - amount
 *             properties:
 *               mpesaPhoneNumber:
 *                 type: string
 *                 description: M-Pesa phone number to receive the STK push
 *               amount:
 *                 type: number
 *                 description: Amount to charge
 *     responses:
 *       200:
 *         description: STK push initiated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: success
 *                 message:
 *                   type: string
 *                 data:
 *                   $ref: '#/components/schemas/TransactionResponse'
 *       400:
 *         description: Invalid phone number or error initiating STK push
 *       500:
 *         description: Internal server error
 */
export const createStkPush = async (req: Request, res: Response<IServerResponse>) => {
	const { mpesaPhoneNumber, amount } = req.body;
	console.log(req.body);
	// try {
		const isValidPhone = validatePhoneNumber(mpesaPhoneNumber);

		if (!isValidPhone) {
			res.status(HttpStatusCode.BadRequest).json({
				status: 'error',
				message: 'Invalid phone number format',
				data: null,
			});
			return;
		}

		console.log("phone is valid")

		const { error, data } = await MpesaSDK.stkPush({
			phone: mpesaPhoneNumber,
			product: `Shown in stk push message`,
			amount,
			CallBackURL: ENV.MPESA_STK_CALLBACK_URL,
			description: `Description of this payment`,
		});

		console.log(`Error ${JSON.stringify(error)}, Data : ${JSON.stringify(data)}`)

		if (error) {
			Logger.error({ message: 'Error initiating STK push: ' + JSON.stringify(error) });

			res.status(HttpStatusCode.BadRequest).json({
				status: 'error',
				message: 'Error initiating STK push',
				data: null,
			});
			return;
		}

		const {
			MerchantRequestID,
			CheckoutRequestID,
			ResponseCode,
			ResponseDescription,
			CustomerMessage,
		} = data;

		let transaction = await Transaction.create({
			amount,
			mpesaMetadata: {
				MerchantRequestID,
				CheckoutRequestID,
				ResponseCode,
				ResponseDescription,
				CustomerMessage,
				PhoneNumber: mpesaPhoneNumber,
			},
		});

		res.status(HttpStatusCode.Ok).json({
			status: 'success',
			message: 'STK push initiated successfully',
			data: transaction,
		});
	// } catch (err) {
	// 	Logger.error({ message: 'Error initiating STK push: ' + err });

	// 	res.status(HttpStatusCode.InternalServerError).json({
	// 		status: 'error',
	// 		message: 'Error initiating STK push',
	// 		data: null,
	// 	});
	// }
};
