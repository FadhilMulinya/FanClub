import mongoose from 'mongoose'
import { Logger } from 'borgen'
import { ENV } from '../utils/environments'

mongoose.set('strictQuery', true)

export function connectDb() {
	mongoose
		.connect(ENV.MONGO_URI)
		.then(() => {
			Logger.info({ message: '✅ Connected to MongoDB successfully' })
		})
		.catch((error) => {
			Logger.error({ message: '❌ Error connecting to MongoDB: ' + error })
			process.exit(1)
		})
}
