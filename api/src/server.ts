import path from 'path';
import cors from 'cors';
import router from './routes';
import { Borgen } from 'borgen';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { ENV } from './utils/environments';
import { connectDb } from './database/connectDb';
import expressBasicAuth from 'express-basic-auth';
import express, { Request, Response } from 'express';
import { apiReference } from '@scalar/express-api-reference';
import generateOpenAPISpec, { apiDocsServer } from './docs/openapi';

const app = express();
const PORT = process.env.PORT || 3000;

const limiter = rateLimit({
	windowMs: 60 * 1000, // 1 minute
	limit: 150, // limit each IP to 150 requests per windowMs
	standardHeaders: 'draft-8', // draft-6: `RateLimit-*` headers; draft-7 & draft-8: combined `RateLimit` header
	legacyHeaders: false, // Disable the `X-RateLimit-*` headers.
});

app.use(Borgen({}));

// Middleware
app.use(cors());
app.use(express.urlencoded({ extended: true }));
app.use(express.json())
app.use(compression());

// Swagger docs
app.use('/openapi', express.static(path.join(__dirname, './docs/openapi.json')));
app.use(
	'/api/v1/docs',
	expressBasicAuth({
		users: { [ENV.API_DOCS_USER]: ENV.API_DOCS_PASSWORD },
		challenge: true,
		realm: 'web3app_api_docs',
	}),
	apiReference({
		url: `${apiDocsServer}/openapi`,
	})
);

// Routes
app.use('/', router);

app.use(limiter);

// Health check
app.get('/ping', (req: Request, res: Response) => {
	res.status(200).json({ status: 'success', message: 'pong' });
});

// Start
app.listen(PORT, () => {
	// Generate OpenAPI spec
	if (ENV.NODE_ENV == 'dev' || ENV.NODE_ENV == 'development') {
		generateOpenAPISpec();
	}
	connectDb();
	console.log(`🚀 Server running on http://localhost:${PORT}`);
});
