/**
 * ═══════════════════════════════════════════════════════════
 * 🔧 GraphQL Code Generator Configuration
 * ═══════════════════════════════════════════════════════════
 * Version: 2.0.0
 * 
 * This configuration uses the @graphql-codegen/client-preset
 * for optimal type safety and developer experience.
 * ═══════════════════════════════════════════════════════════
 */

import type { CodegenConfig } from '@graphql-codegen/cli';
import { printSchema, parse } from 'graphql';
import fs from 'fs';
import path from 'path';

// ═══════════════════════════════════════════════════════════
// 🎨 Configuration
// ═══════════════════════════════════════════════════════════

const SCHEMA_FILE = './apollo/schema.graphql';
const GENERATED_DIR = './apollo/generated';

// Environment flags
const USE_LOCAL_SCHEMA = process.env.USE_LOCAL_SCHEMA === 'true';
const GRAPHQL_ENDPOINT = process.env.GRAPHQL_ENDPOINT ||
    process.env.VITE_GRAPHQL_ENDPOINT ||
    'http://aspdotnetweb:5000/graphql';
const ENABLE_WATCH = process.env.CODEGEN_WATCH === 'true';
const DEBUG = process.env.DEBUG_CODEGEN === 'true';

// ═══════════════════════════════════════════════════════════
// 🔍 Schema Validation
// ═══════════════════════════════════════════════════════════

function validateSchemaFile(filePath: string): boolean {
    if (!fs.existsSync(filePath)) {
        console.error(`❌ Schema file not found: ${filePath}`);
        return false;
    }

    const stats = fs.statSync(filePath);

    if (stats.size < 500) {
        console.error(`❌ Schema file too small: ${stats.size} bytes`);
        return false;
    }

    const content = fs.readFileSync(filePath, 'utf8');

    // Check for placeholder
    if (content.includes('__PLACEHOLDER_SCHEMA__')) {
        console.error('❌ Schema is a placeholder');
        return false;
    }

    // Check for required types
    const requiredTypes = ['type Query', 'schema {'];
    for (const typeStr of requiredTypes) {
        if (!content.includes(typeStr)) {
            console.error(`❌ Schema missing required type: ${typeStr}`);
            return false;
        }
    }

    // Try to parse schema
    try {
        parse(content);
    } catch (error) {
        console.error('❌ Schema is not valid GraphQL:', error.message);
        return false;
    }

    if (DEBUG) {
        console.log('✓ Schema validation passed');
        console.log(`  Size: ${stats.size} bytes`);
        console.log(`  Types: ${(content.match(/^type /gm) || []).length}`);
    }

    return true;
}

// ═══════════════════════════════════════════════════════════
// 📋 Schema Source Selection
// ═══════════════════════════════════════════════════════════

function getSchemaSource(): string | { [url: string]: any } {
    // Always prefer local schema file if USE_LOCAL_SCHEMA is true
    if (USE_LOCAL_SCHEMA) {
        if (validateSchemaFile(SCHEMA_FILE)) {
            console.log(`ℹ Using local schema: ${SCHEMA_FILE}`);
            return SCHEMA_FILE;
        } else {
            console.error('❌ Local schema validation failed');
            process.exit(1);
        }
    }

    // Use remote endpoint
    console.log(`ℹ Using remote schema: ${GRAPHQL_ENDPOINT}`);

    return {
        [GRAPHQL_ENDPOINT]: {
            headers: {
                'Content-Type': 'application/json',
                'X-Allow-Introspection': 'true',
            },
        },
    };
}

// ═══════════════════════════════════════════════════════════
// 🔧 Codegen Configuration
// ═══════════════════════════════════════════════════════════

const config: CodegenConfig = {
    // Schema source (local file or remote endpoint)
    schema: getSchemaSource(),

    // Document sources (GraphQL operations in your code)
    documents: [
        // Vue components and composables
        './hub/**/*.{ts,tsx,vue}',

        // Explicit GraphQL files
        './apollo/**/*.graphql',
        './apollo/**/*.gql',

        // Ignore generated files
        '!apollo/generated/**/*',
        '!**/node_modules/**',
        '!**/__tests__/**',
    ],

    // Generation configuration
    generates: {
        // Client Preset - Optimal for frontend development
        [GENERATED_DIR + '/']: {
            preset: 'client',

            // Preset configuration
            presetConfig: {
                // Generate typed document nodes
                gqlTagName: 'gql',

                // Fragment masking for better type safety
                fragmentMasking: {
                    unmaskFunctionName: 'getFragmentData',
                },

                // Optimize for performance
                dedupeFragments: true,

                // Better error messages
                onlyOperationTypes: false,
            },

            // Additional configuration
            config: {
                // Scalar types
                scalars: {
                    DateTime: 'string',
                    Date: 'string',
                    Time: 'string',
                    JSON: 'Record<string, any>',
                    Upload: 'File',
                    UUID: 'string',
                },

                // Type naming
                namingConvention: {
                    typeNames: 'pascal-case#pascalCase',
                    enumValues: 'upper-case#upperCase',
                    transformUnderscore: true,
                },

                // TypeScript options
                skipTypename: false,
                nonOptionalTypename: true,

                // Array types
                immutableTypes: false,

                // Enum handling
                enumsAsTypes: false,
                futureProofEnums: true,

                // Input types
                onlyEnums: false,

                // Import types
                useTypeImports: true,

                // Compatibility
                emitLegacyCommonJSImports: false,
            },
        },

        // Optional: Generate schema types separately
        [GENERATED_DIR + '/schema.ts']: {
            plugins: ['typescript'],
            config: {
                skipTypename: false,
                enumsAsTypes: false,
                futureProofEnums: true,
                scalars: {
                    DateTime: 'string',
                    Date: 'string',
                    Time: 'string',
                    JSON: 'Record<string, any>',
                    Upload: 'File',
                    UUID: 'string',
                },
            },
        },

        // Optional: Generate introspection result for Apollo Client
        [GENERATED_DIR + '/introspection.json']: {
            plugins: ['introspection'],
            config: {
                minify: true,
            },
        },
    },

    // Global configuration
    config: {
        // Avoid ESM issues
        avoidOptionals: {
            field: false,
            inputValue: false,
            object: false,
            defaultValue: false,
        },

        // Array and maybe types
        maybeValue: 'T | null | undefined',
        inputMaybeValue: 'T | null | undefined',

        // Make operations strict
        strictScalars: true,

        // Add descriptions
        addDocBlocks: true,
    },

    // Hooks
    hooks: {
        afterAllFileWrite: [
            // Prettify generated files (if prettier is available)
            'prettier --write',
        ],
    },

    // Watch mode
    watch: ENABLE_WATCH,

    // Silent mode (suppress warnings)
    silent: !DEBUG,

    // Error handling
    errorsOnly: false,

    // Debugging
    debug: DEBUG,

    // Verbose
    verbose: DEBUG,

    // Override default behavior
    overwrite: true,

    // Emit legacy CommonJS imports
    emitLegacyCommonJSImports: false,
};

export default config;

// ═══════════════════════════════════════════════════════════
// 📝 Usage Notes
// ═══════════════════════════════════════════════════════════

/**
 * Environment Variables:
 * 
 * - USE_LOCAL_SCHEMA: Force use of local schema file
 * - GRAPHQL_ENDPOINT: Remote GraphQL endpoint URL
 * - CODEGEN_WATCH: Enable watch mode
 * - DEBUG_CODEGEN: Enable debug output
 * 
 * Commands:
 * 
 * - npm run graphql:codegen - Generate once
 * - npm run codegen:watch - Watch mode
 * - USE_LOCAL_SCHEMA=true npm run graphql:codegen - Force local
 * - DEBUG_CODEGEN=true npm run graphql:codegen - Debug mode
 * 
 * Generated Files:
 * 
 * - apollo/generated/graphql.ts - Main types
 * - apollo/generated/gql.ts - gql tag function
 * - apollo/generated/fragment-masking.ts - Fragment utilities
 * - apollo/generated/index.ts - Main entry point
 * - apollo/generated/schema.ts - Schema types
 * - apollo/generated/introspection.json - Introspection result
 */