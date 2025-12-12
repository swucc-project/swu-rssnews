import { createApp, h, provide } from 'vue'
import { DefaultApolloClient } from '@vue/apollo-composable'
import { createInertiaApp } from '@inertiajs/vue3'
import { createPinia } from 'pinia'
import { grpcClient } from '~grpc/feed-client'
import router from '@hub/router'
import globalComponents from '@suites/globalComponents.js'
import apolloClient from '~apollo/client'

// ✅ Import CSS
import '~css/app.css'

// ✅ Constants
const appName = window.document.getElementsByTagName('title')[0]?.innerText || 'RSSNews'

// ✅ Error handler
const handleError = (error, info) => {
    console.error('❌ Vue Error:', error)
    console.error('📍 Error Info:', info)

    // ✅ ส่งไปยัง error tracking service (เช่น Sentry)
    // if (import.meta.env.PROD) {
    //     Sentry.captureException(error, { extra: { info } })
    // }
}

// ✅ Warning handler
const handleWarn = (msg, vm, trace) => {
    if (import.meta.env.DEV) {
        console.warn('⚠️ Vue Warning:', msg)
        console.warn('📍 Trace:', trace)
    }
}

console.log('🚀 Initializing Inertia.js application...')
console.log('🔧 Environment:', import.meta.env.MODE)
console.log('🌐 API Endpoints:', {
    graphql: import.meta.env.VITE_PUBLIC_GRAPHQL_ENDPOINT,
    ws: import.meta.env.VITE_PUBLIC_GRAPHQL_WS_URL,
    grpc: import.meta.env.VITE_PUBLIC_GRPC_ENDPOINT,
})

createInertiaApp({
    title: (title) => `${title} - ${appName}`,

    resolve: async (name) => {
        console.log(`📄 Resolving page: ${name}`)

        const pages = import.meta.glob('./Pages/**/*.vue')
        const path = `./Pages/${name}.vue`

        if (!pages[path]) {
            console.error(`❌ Page not found: ${path}`)
            console.log('📁 Available pages:', Object.keys(pages))
            throw new Error(`Page not found: ${path}`)
        }

        try {
            const page = await pages[path]()
            console.log(`✅ Page loaded: ${name}`)
            return page
        } catch (error) {
            console.error(`❌ Failed to load page: ${name}`, error)
            throw error
        }
    },

    setup({ el, App, props, plugin }) {
        console.log('🔧 Setting up Vue app...')

        // ✅ Create Vue app with proper typing
        const vueApp = createApp({
            render: () => h(App, props),
            setup() {
                // ✅ Provide Apollo Client
                provide(DefaultApolloClient, apolloClient)

                // ✅ Provide gRPC Client
                provide('grpcClient', grpcClient)

                // ✅ Provide app info (useful for debugging)
                provide('appInfo', {
                    name: appName,
                    version: import.meta.env.VITE_APP_VERSION || '1.0.0',
                    env: import.meta.env.MODE,
                })
            }
        })

        // ✅ Error handling
        vueApp.config.errorHandler = handleError
        vueApp.config.warnHandler = handleWarn

        // ✅ Performance tracking (development only)
        if (import.meta.env.DEV) {
            vueApp.config.performance = true
        }

        // ✅ Create Pinia store
        const pinia = createPinia()

        // ✅ Register plugins
        vueApp.use(pinia)
        vueApp.use(plugin)
        vueApp.use(router)
        vueApp.use(globalComponents)

        // ✅ Mount app
        try {
            vueApp.mount(el)
            console.log('✅ Vue app mounted successfully')

            // ✅ Log mounted info
            if (import.meta.env.DEV) {
                console.log('🎯 Mounted to element:', el)
                console.log('📦 Initial props:', props)
            }
        } catch (error) {
            console.error('❌ Failed to mount Vue app:', error)
            throw error
        }
    },

    // ✅ Progress bar configuration
    progress: {
        delay: 250,
        color: '#29d',
        includeCSS: true,
        showSpinner: true,
    },
})

// ✅ Global error handlers
window.addEventListener('error', (event) => {
    console.error('❌ Global Error:', event.error)
})

window.addEventListener('unhandledrejection', (event) => {
    console.error('❌ Unhandled Promise Rejection:', event.reason)
})

// ✅ HMR support
if (import.meta.hot) {
    import.meta.hot.accept()
    console.log('🔥 HMR enabled')
}

console.log('✅ Inertia.js client-side initialization complete')