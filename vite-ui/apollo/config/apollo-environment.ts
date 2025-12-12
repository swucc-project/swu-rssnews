import * as dotenv from 'dotenv';
dotenv.config({ path: process.env.NODE_ENV === 'production' ? '.env.production' : '.env' });

export const GRAPHQL_ENDPOINT = process.env.VITE_GRAPHQL_ENDPOINT || 'http://localhost:5000/graphql';
export const ALLOW_INTROSPECTION_HEADER = { 'X-Allow-Introspection': 'true' };