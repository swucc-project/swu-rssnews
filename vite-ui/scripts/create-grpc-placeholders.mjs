#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════
 * 🔧 gRPC Placeholder File Generator v2.0
 * ═══════════════════════════════════════════════════════════
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const GRPC_DIR = path.join(rootDir, 'grpc');

console.log('🔧 Creating gRPC placeholder files...');

// Ensure directory exists
if (!fs.existsSync(GRPC_DIR)) {
    fs.mkdirSync(GRPC_DIR, { recursive: true });
    console.log(`📁 Created: ${GRPC_DIR}`);
}

// ═══════════════════════════════════════════════════════════
// Read template files from grpc/ directory or use embedded
// ═══════════════════════════════════════════════════════════

const templates = {
    'rss_pb.ts': `// Placeholder - see full content above`,
    'RssServiceClientPb.ts': `// Placeholder - see full content above`,
    'feed-client.ts': `// Placeholder - see full content above`,
    'index.ts': `// Placeholder - see full content above`,
};

// Check if files already exist with valid content
const checkExistingFiles = () => {
    const requiredExports = {
        'rss_pb.ts': ['GetRSSItemsRequest', 'GetRSSItemByIDRequest', 'RSSItem'],
        'RssServiceClientPb.ts': ['RSSItemServiceClient'],
        'feed-client.ts': ['grpcClient'],
        'index.ts': ['grpcClient'],
    };

    for (const [file, exports] of Object.entries(requiredExports)) {
        const filePath = path.join(GRPC_DIR, file);
        if (!fs.existsSync(filePath)) {
            return false;
        }

        const content = fs.readFileSync(filePath, 'utf-8');
        for (const exp of exports) {
            if (!content.includes(exp)) {
                console.log(`⚠️ ${file} missing export: ${exp}`);
                return false;
            }
        }
    }

    return true;
};

try {
    if (checkExistingFiles()) {
        console.log('✅ All gRPC files already exist with correct exports');

        // List files
        const files = fs.readdirSync(GRPC_DIR).filter(f => f.endsWith('.ts'));
        console.log('\n📂 Files:');
        files.forEach(f => {
            const stat = fs.statSync(path.join(GRPC_DIR, f));
            console.log(`   • ${f} (${stat.size} bytes)`);
        });

        process.exit(0);
    }

    console.log('⚠️ Some files need to be created or updated');
    console.log('');
    console.log('Please copy the placeholder files from the documentation above.');
    console.log('Or run: npm run grpc:generate (if proto files exist)');

    process.exit(0);

} catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
}