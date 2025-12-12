import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import inertia from 'laravel-vite-plugin'
import path from 'path'

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd());
    const ssrRenderUrl = env.SSR_RENDER_URL || 'http://frontend:13714/render';
    const isDev = mode === 'development';

    return {
        base: '/',
        define: {
            __VUE_OPTIONS_API__: true,
            __VUE_PROD_DEVTOOLS__: false,
            __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
            'import.meta.env.VITE_PUBLIC_API_URL': JSON.stringify(
                env.VITE_PUBLIC_API_URL || 'http://localhost:5000'
            ),
            'import.meta.env.VITE_PUBLIC_GRAPHQL_ENDPOINT': JSON.stringify(
                env.VITE_PUBLIC_GRAPHQL_ENDPOINT || 'http://localhost:5000/graphql'
            ),
            'import.meta.env.VITE_PUBLIC_GRAPHQL_WS_URL': JSON.stringify(
                env.VITE_PUBLIC_GRAPHQL_WS_URL || 'ws://localhost:5000/graphql-ws'
            ),
            'import.meta.env.VITE_PUBLIC_GRPC_ENDPOINT': JSON.stringify(
                env.VITE_PUBLIC_GRPC_ENDPOINT || 'http://localhost:5000/grpc'
            ),
        },
        plugins: [
            inertia({
                input: ["hub/main.js"],
                publicDirectory: "wwwroot/volume",
                ssr: {
                    input: "hub/ssr.js",
                    url: ssrRenderUrl,
                    port: 13714
                },
                hotFile: "wwwroot/volume/hot",
            }),
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
                '~images': path.resolve(__dirname, './images'),
                '~grpc': path.resolve(__dirname, './grpc-generated'),
                '~tools': path.resolve(__dirname, './tools'),
                '~joints': path.resolve(__dirname, './hub/joints'),
                // ✅ ให้ @generated ชี้ไปที่เดียวกับ ~apollo/generated
                '@generated': path.resolve(__dirname, './apollo/generated'),
                '@hub': path.resolve(__dirname, './hub'),
                '@components': path.resolve(__dirname, './hub/components'),
                '@pages': path.resolve(__dirname, './hub/Pages'),
                '@suites': path.resolve(__dirname, './hub/suites'),
                'vue': 'vue/dist/vue.esm-bundler.js',
            },
        },
        server: {
            host: '0.0.0.0',
            port: 5173,
            strictPort: true,
            https: false,
            hmr: {
                host: env.VITE_HMR_HOST || 'localhost',
                protocol: env.VITE_HMR_PROTOCOL || 'ws',
                port: 5173,
                clientPort: 5173,
                timeout: 60000,
            },
            watch: {
                usePolling: true,
                interval: 1000,
                ignored: [
                    '!**/node_modules/@vuepic/**',
                    '**/node_modules/**',
                    '**/.git/**',
                    '**/dist/**',
                    '**/wwwroot/ssr/**'
                ],
            },
            warmup: {
                clientFiles: [
                    './hub/main.js',
                    './hub/components/**/*.vue',
                    './hub/Pages/**/*.vue',
                ]
            },
            sourcemapIgnoreList(sourcePath) {
                return sourcePath.includes('node_modules');
            },
            proxy: {
                '/api': {
                    target: env.VITE_API_URL || 'http://aspdotnetweb:5000',
                    changeOrigin: true,
                },
                '/graphql': {
                    target: env.VITE_GRAPHQL_ENDPOINT || 'http://aspdotnetweb:5000',
                    changeOrigin: true,
                    ws: true,
                    secure: false,
                },
                '/graphql-ws': {
                    target: env.VITE_GRAPHQL_WS_URL || 'http://aspdotnetweb:5000',
                    ws: true,
                    changeOrigin: true,
                },
                '/grpc': {
                    target: env.VITE_GRPC_ENDPOINT || 'http://aspdotnetweb:5000',
                    changeOrigin: true,
                    secure: false,
                }
            }
        },
        build: {
            outDir: '/app/wwwroot/volume',
            emptyOutDir: true,
            manifest: true,
            cssCodeSplit: true,
            cssMinify: mode === 'production' ? 'esbuild' : false,
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
                        'vendor': ['vue', '@inertiajs/vue3'],
                        'apollo': ['@apollo/client', '@vue/apollo-composable'],
                        'grpc': ['@protobuf-ts/grpcweb-transport'],
                        'dayjs': ['dayjs'],
                    },
                    assetFileNames: (assetInfo) => {
                        if (assetInfo.name.endsWith('.css')) {
                            return 'css/[name]-[hash][extname]';
                        }
                        if (/\.(woff2?|eot|ttf|otf)(\?.*)?$/i.test(assetInfo.name)) {
                            return 'fonts/[name]-[hash][extname]';
                        }
                        if (/\.(png|jpe?g|gif|svg|webp|avif)(\?.*)?$/i.test(assetInfo.name)) {
                            return 'images/[name]-[hash][extname]';
                        }
                        return 'assets/[name]-[hash][extname]';
                    },
                    sourcemapExcludeSources: true,
                }
            },
            sourcemap: false,
            minify: mode === 'production' ? 'terser' : false,
            terserOptions: {
                compress: {
                    drop_console: mode === 'production',
                },
            },
        },
        ssr: {
            noExternal: [
                '@vue/apollo-composable',
                '@apollo/client',
                '@protobuf-ts/grpcweb-transport',
                'graphql-tag',
            ],
            target: 'node',
        },
        assetInclude: ['**/*.json'],
        optimizeDeps: {
            esbuildOptions: {
                target: 'es2020',
                resolveExtensions: ['.mjs', '.js', '.ts', '.json', '.vue'],
                loader: { '.js': 'jsx', },
                supported: { 'top-level-await': true },
            },
            include: [
                'vue',
                '@inertiajs/vue3',
                '@vue/apollo-composable',
                '@apollo/client',
                'graphql',
                'cross-fetch',
                'dayjs',
                'dayjs/plugin/utc',
                'dayjs/plugin/timezone',
                'dayjs/plugin/buddhistEra',
                'dayjs/plugin/relativeTime',
                'dayjs/locale/th',
                'prismjs',
                'prismjs/components/prism-markup',
            ],
            exclude: [
                '@vuepic/vue-datepicker/dist/main.css'
            ],
            force: isDev,
            entries: [
                'hub/main.js',
                'hub/ssr.js'
            ]
        },
        experimental: {
            renderBuiltUrl(filename, { hostType }) {
                if (hostType === 'js') {
                    return { runtime: `window.__assetsPath(${JSON.stringify(filename)})` }
                }
            }
        },
        cacheDir: 'node_modules/.vite',
        logLevel: isDev ? 'info' : 'warn',
    }
});