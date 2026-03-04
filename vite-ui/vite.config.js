import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');
    const isDev = mode === 'development';

    // ✅ ระบุ APP_URL ให้ชัดเจน
    const appUrl = env.VITE_APP_URL || env.APP_URL || env.FRONTEND_URL || 'http://localhost:8080';
    // Vite Dev Server Port
    const vitePort = parseInt(env.VITE_DEV_SERVER_PORT || '5173');
    // HMR Configuration
    const hmrHost = env.VITE_HMR_HOST || 'localhost';
    const hmrProtocol = env.VITE_HMR_PROTOCOL || 'ws';
    // API URLs (Docker internal)
    const apiUrl = env.VITE_API_URL || 'http://aspdotnetweb:5000';

    // Public URLs (Browser)
    const publicApiUrl = env.VITE_PUBLIC_API_URL || 'http://localhost:5000';
    const publicGraphqlUrl = env.VITE_PUBLIC_GRAPHQL_ENDPOINT || 'http://localhost:5000/graphql';

    console.log('═══════════════════════════════════════════════════════════');
    console.log('🔧 Vite Configuration');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('  Mode:', mode);
    console.log('  APP_URL (Nginx):', appUrl);
    console.log('  Vite Dev Server:', `http://0.0.0.0:${vitePort}`);
    console.log('  HMR Host:', hmrHost);
    console.log('  API URL (internal):', apiUrl);
    console.log('  API URL (public):', publicApiUrl);
    console.log('═══════════════════════════════════════════════════════════');

    return {
        plugins: [
            vue({
                template: {
                    transformAssetUrls: {
                        base: null,
                        includeAbsolute: false,
                    },
                },
            }),
        ],
        root: './',
        base: '/',
        publicDir: 'wwwroot',
        // ✅ เพิ่ม define เพื่อให้ APP_URL accessible ใน code
        define: {
            '__APP_URL__': JSON.stringify(appUrl),
            '__API_URL__': JSON.stringify(publicApiUrl),
            '__GRAPHQL_URL__': JSON.stringify(publicGraphqlUrl),
            '__IS_DEV__': JSON.stringify(isDev),
        },

        css: {
            postcss: './postcss.config.cjs',
            preprocessorOptions: {
                css: {
                    charset: false,
                },
            },
            modules: {
                localsConvention: 'camelCase',
                scopeBehaviour: 'local',
            },
            devSourcemap: false,
        },
        resolve: {
            alias: {
                '~api': path.resolve(__dirname, './api'),
                '~apollo': path.resolve(__dirname, './apollo'),
                '~apollo/fragments': path.resolve(__dirname, './apollo/generated/fragments.ts'),
                '~apollo/generated': path.resolve(__dirname, './apollo/generated'),
                '~css': path.resolve(__dirname, './css'),
                '~fonts': path.resolve(__dirname, './fonts'),
                '~grpc': path.resolve(__dirname, './grpc'),
                '~grpc-generated': path.resolve(__dirname, './grpc-generated'),
                '~images': path.resolve(__dirname, './images'),
                '~tools': path.resolve(__dirname, './tools'),
                '~joints': path.resolve(__dirname, './hub/joints'),
                '@generated': path.resolve(__dirname, './apollo/generated'),
                '@hub': path.resolve(__dirname, './hub'),
                '@components': path.resolve(__dirname, './hub/components'),
                '@pages': path.resolve(__dirname, './hub/Pages'),
                '@suites': path.resolve(__dirname, './hub/suites'),
                'vue': 'vue/dist/vue.esm-bundler.js',
            },
            extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue'],
        },
        server: {
            host: '0.0.0.0',
            port: vitePort,
            strictPort: true,
            hmr: {
                host: hmrHost,
                protocol: hmrProtocol,
            },
            watch: {
                usePolling: true,
                interval: 100,
            },
            cors: true,
            proxy: {
                '/api': {
                    target: apiUrl,
                    changeOrigin: true,
                },
                '/graphql': {
                    target: apiUrl,
                    changeOrigin: true,
                    ws: true,
                },
                '/grpc': {
                    target: apiUrl,
                    changeOrigin: true,
                },
                '/health': {
                    target: apiUrl,
                    changeOrigin: true,
                    secure: false,
                },
                '/swagger': {
                    target: apiUrl,
                    changeOrigin: true,
                    secure: false,
                },
                '/auth': {
                    target: apiUrl,
                    changeOrigin: true,
                },
                '/rss': {
                    target: apiUrl,
                    changeOrigin: true,
                },
            },
        },
        build: {
            outDir: 'wwwroot/volume',
            emptyOutDir: true,
            manifest: 'manifest.json',
            cssCodeSplit: true,
            chunkSizeWarningLimit: 1000,
            target: 'es2020',
            rollupOptions: {
                input: {
                    main: path.resolve(__dirname, 'hub/main.js'),
                    app: path.resolve(__dirname, 'css/app.css'),
                    'swagger-guide': path.resolve(__dirname, 'css/swagger-guide.css'),
                },
                output: {
                    manualChunks: {
                        'vendor-vue': ['vue', 'pinia', '@inertiajs/vue3'],
                        'vendor-apollo': ['@apollo/client', '@vue/apollo-composable'],
                        'vendor-grpc': [
                            '@protobuf-ts/grpcweb-transport',
                            '@protobuf-ts/runtime',
                            '@protobuf-ts/runtime-rpc',
                        ],
                    },
                    entryFileNames: 'js/[name]-[hash].js',
                    chunkFileNames: 'js/[name]-[hash].js',
                    assetFileNames: (assetInfo) => {
                        const name = assetInfo.name || '';
                        if (/\.css$/i.test(name)) {
                            return 'css/[name]-[hash][extname]';
                        }
                        if (/\.(png|jpe?g|gif|svg|webp|avif)(\?.*)?$/i.test(name)) {
                            return 'images/[name]-[hash][extname]';
                        }
                        if (/\.(woff2?|eot|ttf|otf)(\?.*)?$/i.test(name)) {
                            return 'fonts/[name]-[hash][extname]';
                        }
                        return 'assets/[name]-[hash][extname]';
                    },
                }
            },
            sourcemap: isDev,
            minify: mode === 'production',
        },
        optimizeDeps: {
            esbuildOptions: {
                target: 'es2020',
            },
            include: [
                'vue',
                'graphql',
                'graphql-tag',
                'pinia',
                '@inertiajs/vue3',
                '@vue/apollo-composable',
                '@apollo/client',
                '@protobuf-ts/grpcweb-transport',
                'cross-fetch',
                'grpc-web',
            ],
            exclude: [],
            force: isDev,
            entries: [
                'hub/main.js',
            ]
        },
        cacheDir: 'node_modules/.vite',
        logLevel: isDev ? 'info' : 'warn',
        clearScreen: false,
    };
});