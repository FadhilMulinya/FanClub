import fs from 'fs';
import path from 'path';
import { Logger } from 'borgen';
import swaggerJSDoc from 'swagger-jsdoc';
import { ENV } from '../utils/environments';

const isProduction = process.env.NODE_ENV === 'production';
export const apiDocsServer = isProduction
	? `https://api.website.example`
	: `http://localhost:${ENV.PORT}`;

const swaggerDefinition = {
	openapi: '3.0.0',
	info: {
		title: 'API Documentation',
		version: 'v1.0.0',
		description: `This is the API documentation for the What I Do application. It provides endpoints for managing user activities, tasks, and related resources. The API is designed to be used by both internal services and external clients.`,
		license: {
			name: 'Copyright 2025',
		},
	},
	servers: [
		{
			url: apiDocsServer,
		},
	],
};

const generateOpenAPISpec = () => {
	const swaggerSpec = swaggerJSDoc({
		failOnErrors: true,
		definition: swaggerDefinition,
		apis: [path.join(__dirname, '../controllers/**/*.Controller.ts')],
	});

	fs.writeFileSync(
		path.join(__dirname, 'openapi.json'),
		JSON.stringify(swaggerSpec, null, 2),
		'utf-8'
	);

	Logger.info({ message: 'Swagger spec generated successfully' });
};

export default generateOpenAPISpec;
