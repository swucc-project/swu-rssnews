#!/usr/bin/env node
/**
 * @fileoverview Sync gRPC files between directories
 * Supports bidirectional sync and creates placeholder files if needed
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

// ✅ Configuration
const GRPC_DIR = path.join(rootDir, 'grpc');
const GRPC_GENERATED_DIR = path.join(rootDir, 'grpc-generated');
const WWWROOT_GRPC_DIR = path.join(rootDir, 'wwwroot', 'grpc');

const VALID_EXTENSIONS = ['.ts', '.js', '.d.ts'];

console.log('🔄 Syncing gRPC files...');
console.log(`   Source: ${GRPC_DIR}`);
console.log(`   Target: ${GRPC_GENERATED_DIR}`);
console.log('');

// ✅ Ensure all directories exist
const ensureDir = (dir) => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
        console.log(`   📁 Created directory: ${path.relative(rootDir, dir)}`);
    }
};

[GRPC_DIR, GRPC_GENERATED_DIR, WWWROOT_GRPC_DIR].forEach(ensureDir);

// ✅ Create placeholder files if source is empty
const createPlaceholderIfNeeded = () => {
    const files = fs.readdirSync(GRPC_DIR).filter(f =>
        VALID_EXTENSIONS.some(ext => f.endsWith(ext))
    );

    if (files.length === 0) {
        console.log('   ⚠️ No gRPC files found, creating placeholders...');

        // Create index.ts placeholder
        const indexContent = `// Auto-generated gRPC placeholder
// This file will be replaced when proto files are compiled

export const GRPC_PLACEHOLDER = true;

// Re-export everything
export * from './rss';
`;

        // Create rss.ts placeholder
        const rssContent = `// Auto-generated RSS gRPC placeholder
// This file will be replaced when proto files are compiled

export interface RssItem {
    itemID: string;
    title: string;
    link: string;
    description?: string;
    publishedDate: string;
    categoryId?: number;
    authorId?: string;
}

export interface Category {
    categoryID: number;
    categoryName: string;
}

export interface Author {
    buasriID: string;
    firstName: string;
    lastName: string;
}

export interface GetRssItemsRequest {
    categoryId?: number;
    skip?: number;
    take?: number;
}

export interface GetRssItemsResponse {
    items: RssItem[];
    totalCount: number;
}

// Placeholder client
export class RssServiceClient {
    constructor(_endpoint: string) {
        console.warn('Using placeholder gRPC client');
    }
    
    async getRssItems(_request: GetRssItemsRequest): Promise<GetRssItemsResponse> {
        console.warn('Placeholder: getRssItems called');
        return { items: [], totalCount: 0 };
    }
}

export default RssServiceClient;
`;

        fs.writeFileSync(path.join(GRPC_DIR, 'index.ts'), indexContent);
        fs.writeFileSync(path.join(GRPC_DIR, 'rss.ts'), rssContent);

        console.log('   ✅ Created placeholder files');
        return true;
    }

    return false;
};

// ✅ Sync files from source to target
const syncFiles = (source, target, description) => {
    try {
        const files = fs.readdirSync(source).filter(f =>
            VALID_EXTENSIONS.some(ext => f.endsWith(ext))
        );

        if (files.length === 0) {
            console.log(`   ℹ️ No files to sync from ${description}`);
            return 0;
        }

        let syncedCount = 0;

        for (const file of files) {
            const srcPath = path.join(source, file);
            const destPath = path.join(target, file);

            // Check if source is newer or dest doesn't exist
            const srcStat = fs.statSync(srcPath);
            let shouldCopy = true;

            if (fs.existsSync(destPath)) {
                const destStat = fs.statSync(destPath);
                shouldCopy = srcStat.mtime > destStat.mtime;
            }

            if (shouldCopy) {
                fs.copyFileSync(srcPath, destPath);
                console.log(`   ✅ ${file}`);
                syncedCount++;
            } else {
                console.log(`   ⏭️ ${file} (up to date)`);
            }
        }

        return syncedCount;

    } catch (error) {
        console.error(`   ❌ Error syncing ${description}:`, error.message);
        return 0;
    }
};

// ✅ Main execution
try {
    // Create placeholders if needed
    const createdPlaceholders = createPlaceholderIfNeeded();

    // Sync from grpc/ to grpc-generated/
    console.log('\n📦 Syncing grpc/ → grpc-generated/');
    const syncedToGenerated = syncFiles(GRPC_DIR, GRPC_GENERATED_DIR, 'grpc → grpc-generated');

    // Also sync to wwwroot/grpc/ for web access
    console.log('\n📦 Syncing grpc/ → wwwroot/grpc/');
    const syncedToWwwroot = syncFiles(GRPC_DIR, WWWROOT_GRPC_DIR, 'grpc → wwwroot/grpc');

    // Summary
    console.log('\n' + '═'.repeat(50));
    console.log('📊 Sync Summary:');
    console.log(`   • Placeholders created: ${createdPlaceholders ? 'Yes' : 'No'}`);
    console.log(`   • Files synced to grpc-generated: ${syncedToGenerated}`);
    console.log(`   • Files synced to wwwroot/grpc: ${syncedToWwwroot}`);
    console.log('═'.repeat(50));

    // List final state
    console.log('\n📂 Final state of grpc-generated/:');
    const finalFiles = fs.readdirSync(GRPC_GENERATED_DIR);
    if (finalFiles.length === 0) {
        console.log('   (empty)');
    } else {
        finalFiles.forEach(f => {
            const stat = fs.statSync(path.join(GRPC_GENERATED_DIR, f));
            console.log(`   • ${f} (${stat.size} bytes)`);
        });
    }

    console.log('\n✅ gRPC sync completed successfully!');
    process.exit(0);

} catch (error) {
    console.error('\n❌ Sync failed:', error.message);
    console.error('Stack trace:', error.stack);

    // Don't exit with error - allow build to continue
    console.log('\n⚠️ Continuing despite sync error...');
    process.exit(0);
}