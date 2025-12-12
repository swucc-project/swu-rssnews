import { openApiToZodClient } from 'openapi-zod-client';
import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

async function generateClient() {
    const openApiDoc = JSON.parse(
        readFileSync(join(__dirname, '../../aspnetcore/wwwroot/manual-api.json'), 'utf-8')
    );

    const client = await openApiToZodClient({
        openApiDoc,
        options: {
            withAlias: true,
            baseUrl: 'https://news.swu.ac.th',
            withDocs: true,
            groupStrategy: 'tag'
        }
    });

    const outputPath = join(__dirname, '../api/zod-client.ts');
    writeFileSync(outputPath, client);

    console.log('✅ Generated TypeScript client at:', outputPath);
}

generateClient().catch(console.error);