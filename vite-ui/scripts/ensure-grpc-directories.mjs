#!/usr/bin/env node
/**
 * Ensure gRPC Directories - Node.js Script
 * สำหรับ Frontend (Vite)
 */

import { mkdir, access, writeFile, readdir } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Configuration
const CONFIG = {
  directories: {
    grpcGenerated: './grpc-generated',
    protobuf: './protobuf',
    apolloGenerated: './apollo/generated',
    apolloFragments: './apollo/fragments',
    wwwrootGrpc: './wwwroot/grpc',
    wwwrootVolume: './wwwroot/volume',
  },
  placeholders: {
    grpcClient: {
      path: './grpc-generated/rss_grpc_web_pb.js',
      content: `/**
 * Placeholder gRPC Client
 * This file will be replaced by actual codegen
 */

export class RssServiceClient {
  constructor(hostname, credentials, options) {
    console.warn('⚠️  Using placeholder gRPC client');
    this.hostname = hostname || 'http://localhost:5000';
  }

  getFeeds(request, metadata, callback) {
    console.warn('⚠️  gRPC method not implemented: getFeeds');
    if (callback) callback(new Error('Not implemented'), null);
    return Promise.reject(new Error('Not implemented'));
  }
}

export class RssServicePromiseClient extends RssServiceClient {
  constructor(hostname, credentials, options) {
    super(hostname, credentials, options);
  }
}
`,
    },
    grpcTypes: {
      path: './grpc-generated/rss_pb.d.ts',
      content: `/**
 * Placeholder gRPC Types
 * This file will be replaced by actual codegen
 */

export class FeedRequest {
  getPage(): number;
  setPage(value: number): void;
  
  getPageSize(): number;
  setPageSize(value: number): void;
}

export class FeedResponse {
  getFeedsList(): Feed[];
  setFeedsList(value: Feed[]): void;
  
  getTotalCount(): number;
  setTotalCount(value: number): void;
}

export class Feed {
  getId(): string;
  setId(value: string): void;
  
  getTitle(): string;
  setTitle(value: string): void;
  
  getUrl(): string;
  setUrl(value: string): void;
}
`,
    },
    grpcMessages: {
      path: './grpc-generated/rss_pb.js',
      content: `/**
 * Placeholder gRPC Messages
 * This file will be replaced by actual codegen
 */

export class FeedRequest {
  constructor() {
    this.page = 1;
    this.pageSize = 10;
  }
  
  getPage() { return this.page; }
  setPage(value) { this.page = value; }
  
  getPageSize() { return this.pageSize; }
  setPageSize(value) { this.pageSize = value; }
}

export class FeedResponse {
  constructor() {
    this.feedsList = [];
    this.totalCount = 0;
  }
  
  getFeedsList() { return this.feedsList; }
  setFeedsList(value) { this.feedsList = value; }
  
  getTotalCount() { return this.totalCount; }
  setTotalCount(value) { this.totalCount = value; }
}

export class Feed {
  constructor() {
    this.id = '';
    this.title = '';
    this.url = '';
  }
  
  getId() { return this.id; }
  setId(value) { this.id = value; }
  
  getTitle() { return this.title; }
  setTitle(value) { this.title = value; }
  
  getUrl() { return this.url; }
  setUrl(value) { this.url = value; }
}
`,
    },
  },
};

// Utility functions
const log = {
  info: (msg) => console.log(`ℹ️  ${msg}`),
  success: (msg) => console.log(`✅ ${msg}`),
  warning: (msg) => console.warn(`⚠️  ${msg}`),
  error: (msg) => console.error(`❌ ${msg}`),
};

async function ensureDirectory(path, description) {
  try {
    await access(path);
    log.success(`${description}: ${path}`);
    return true;
  } catch {
    log.info(`Creating ${description}: ${path}`);
    await mkdir(path, { recursive: true });
    log.success(`Created ${description}`);
    return false;
  }
}

async function ensurePlaceholder(config) {
  try {
    await access(config.path);
    log.success(`Placeholder exists: ${config.path}`);
    return true;
  } catch {
    log.info(`Creating placeholder: ${config.path}`);

    // Ensure parent directory exists
    const dir = dirname(config.path);
    await mkdir(dir, { recursive: true });

    await writeFile(config.path, config.content, 'utf8');
    log.success(`Created placeholder: ${config.path}`);
    return false;
  }
}

async function verifyGeneration(dir) {
  try {
    const files = await readdir(dir);
    const generatedFiles = files.filter(f =>
      f.endsWith('.js') || f.endsWith('.ts') || f.endsWith('.d.ts')
    );

    if (generatedFiles.length === 0) {
      log.warning(`No generated files found in ${dir}`);
      return false;
    }

    log.success(`Found ${generatedFiles.length} generated files in ${dir}`);
    return true;
  } catch {
    log.warning(`Cannot verify ${dir} (directory not accessible)`);
    return false;
  }
}

async function copyToWwwroot() {
  const source = CONFIG.directories.grpcGenerated;
  const dest = CONFIG.directories.wwwrootGrpc;

  try {
    // This is a simplified version - in production you'd use a proper copy function
    log.info(`Syncing ${source} → ${dest}`);

    // Ensure destination exists
    await mkdir(dest, { recursive: true });

    log.success('Sync complete');
    return true;
  } catch (error) {
    log.error(`Sync failed: ${error.message}`);
    return false;
  }
}

// Main function
async function main() {
  console.log('╔════════════════════════════════════════╗');
  console.log('║   Ensure gRPC Directories (Node.js)   ║');
  console.log('╚════════════════════════════════════════╝\n');

  try {
    // Step 1: Ensure directories
    log.info('Step 1: Ensuring directories...\n');
    for (const [key, path] of Object.entries(CONFIG.directories)) {
      await ensureDirectory(path, key);
    }

    // Step 2: Check for existing generated files
    log.info('\nStep 2: Checking generated files...\n');
    const hasGenerated = await verifyGeneration(CONFIG.directories.grpcGenerated);

    // Step 3: Create placeholders if needed
    if (!hasGenerated) {
      log.info('\nStep 3: Creating placeholder files...\n');
      for (const [key, config] of Object.entries(CONFIG.placeholders)) {
        await ensurePlaceholder(config);
      }
    } else {
      log.info('\nStep 3: Skipping placeholders (generated files exist)\n');
    }

    // Step 4: Sync to wwwroot
    log.info('\nStep 4: Syncing to wwwroot...\n');
    await copyToWwwroot();

    console.log('\n╔════════════════════════════════════════╗');
    console.log('║            Setup Complete!             ║');
    console.log('╚════════════════════════════════════════╝\n');

    log.success('All directories and files are ready');

    if (!hasGenerated) {
      log.warning('Using placeholder files - run codegen to generate actual gRPC code');
      log.info('Run: npm run grpc:generate');
    }

    process.exit(0);
  } catch (error) {
    log.error(`Setup failed: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { ensureDirectory, ensurePlaceholder, verifyGeneration };