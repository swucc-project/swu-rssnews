import { execSync } from 'child_process';
import * as path from 'path';
import * as dotenv from 'dotenv';
import isUrlHttp from 'is-url-http';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const envPath = process.env.NODE_ENV === 'production' ? '.env.production' : '.env';
dotenv.config({ path: envPath });
const SCHEMA_PATH = path.resolve(__dirname, '../apollo/schema.graphql');
const ENDPOINT = process.env.VITE_GRAPHQL_ENDPOINT || 'http://aspdotnetweb:5000/graphql';

async function downloadSchema() {
    console.log('📥 Downloading schema from', ENDPOINT);

    try {
        if (!isUrlHttp(ENDPOINT)) {
            console.error("❌ Invalid GraphQL URL:", ENDPOINT);
            process.exit(1);
        }
        execSync(
            `rover graph introspect ${ENDPOINT} --header "X-Allow-Introspection: true" > ${SCHEMA_PATH}`,
            {
                stdio: 'pipe',
                encoding: 'utf-8'
            }
        );

        console.log('✅ Schema downloaded successfully');
        return true;
    } catch (error) {
        console.error('❌ Failed to download schema:', error);
        return false;
    }
}

async function generateTypes() {
    console.log('🔨 Generating TypeScript types...');

    try {
        execSync('npm run codegen', { stdio: 'inherit' });
        console.log('✅ Types generated successfully');
        return true;
    } catch (error) {
        console.error('❌ Failed to generate types:', error);
        return false;
    }
}

async function validateSchema() {
    console.log('🧪 Validating GraphQL schema...');
    try {
        execSync(`npx @graphql-validate/cli --schema=${SCHEMA_PATH}`, { stdio: 'inherit' });
        console.log('✅ Schema validation passed!');
        return true;
    } catch (error) {
        console.error('⚠️ Schema seems invalid:', error);
        return false;
    }
}

async function main() {
    console.log('🚀 Starting schema sync...\n');

    // Check if server is running
    console.log('🔍 Checking if GraphQL server is running...');

    const schemaDownloaded = await downloadSchema();

    if (!schemaDownloaded) {
        console.error('\n⚠️  Make sure the GraphQL server is running at', ENDPOINT);
        process.exit(1);
    }

    const isValid = await validateSchema();

    if (!isValid) {
        console.error('\n⚠️ Invalid schema!');
        process.exit(1);
    }

    const typesGenerated = await generateTypes();

    if (!typesGenerated) {
        process.exit(1);
    }

    console.log('\n✨ Schema sync completed!');
}

main().catch(console.error);