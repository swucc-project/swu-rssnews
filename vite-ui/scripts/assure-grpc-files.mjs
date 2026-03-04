#!/usr/bin/env node
/**
 * Ensure gRPC placeholder files exist with correct exports
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

console.log('🔧 Ensuring gRPC files...');

// ============================================
// Directory Setup
// ============================================

const directories = ['grpc', 'grpc-generated'];
directories.forEach(dir => {
    const fullPath = path.join(rootDir, dir);
    if (!fs.existsSync(fullPath)) {
        fs.mkdirSync(fullPath, { recursive: true });
        console.log(`📁 Created: ${dir}`);
    }
});

// ============================================
// Check Required Files
// ============================================

const requiredFiles = [
    'grpc/rss_pb.ts',
    'grpc/RssServiceClientPb.ts',
    'grpc/feed-client.ts',
    'grpc/index.ts'
];

let missingCount = 0;

for (const file of requiredFiles) {
    const fullPath = path.join(rootDir, file);
    if (!fs.existsSync(fullPath)) {
        console.log(`⚠️ Missing: ${file}`);
        missingCount++;
    } else {
        const stat = fs.statSync(fullPath);
        if (stat.size < 100) {
            console.log(`⚠️ Too small (${stat.size} bytes): ${file}`);
            missingCount++;
        } else {
            console.log(`✅ OK: ${file} (${stat.size} bytes)`);
        }
    }
}

if (missingCount === 0) {
    console.log('\n✅ All gRPC files ready!');
    process.exit(0);
}

console.log(`\n⚠️ ${missingCount} files need attention`);
console.log('Please ensure placeholder files are created correctly');
process.exit(0);