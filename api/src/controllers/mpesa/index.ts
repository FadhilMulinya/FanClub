import { Mpesa } from '@zenetralabs/mpesa';
import { ENV } from '../../utils/environments';

export const MpesaSDK = new Mpesa({
	env: ENV.MPESA_ENV,
	type: ENV.MPESA_PAY_TYPE, // 2 or 4
	shortcode: ENV.MPESA_SHORT_CODE,
	store: ENV.MPESA_SHORT_CODE,
	key: ENV.MPESA_CONSUMER_KEY,
	secret: ENV.MPESA_CONSUMER_SECRET,
	username: ENV.MPESA_USER_NAME,
	password: ENV.MPESA_PASSWORD,
	certFolderPath: './certs',
	passkey: ENV.MPESA_PASSKEY,
});

export { createStkPush } from './createStk.Controller';
export { stkCallbackHandler } from './stkCallback.Controller';
