import { createApp, h } from 'vue'
import { DefaultApolloClient } from '@vue/apollo-composable'
import { createInertiaApp } from '@inertiajs/vue3'
import { createPinia } from 'pinia'
import { grpcClient } from '~grpc/feed-client'
import { useAuthStore } from '@hub/stores/auth'
import globalComponents from '@suites/globalComponents.js'
import apolloClient from '~apollo/client'

// ✅ Import CSS
import '~css/app.css'

// ==============================
// Constants
// ==============================
const isDev = import.meta.env.DEV
const appName =
    window.document.getElementsByTagName('title')[0]?.innerText ||
    'RSSNews'

// ==============================
// Error Handlers
// ==============================
const handleError = (error, info) => {
    console.error('Vue Error:', error)

    if (isDev) {
        console.error('Error Info:', info)
    }
}

const handleWarn = (msg, vm, trace) => {
    if (isDev) {
        console.warn('Vue Warning:', msg)
        console.warn('Trace:', trace)
    }
}

// ==============================
// Page Loader (IMPORTANT FIX)
// ==============================
const pages = import.meta.glob('./Pages/**/*.vue')

// ==============================
// Inertia App
// ==============================
createInertiaApp({
    title: (title) => `${title} - ${appName}`,

    resolve: (name) => {
        const path = `./Pages/${name}.vue`
        const page = pages[path]

        if (!page) {
            console.error(`Page not found: ${name}`)
            return pages['./Pages/NotFound.vue']?.()
        }

        return page()
    },

    async setup({ el, App, props, plugin }) {
        const pinia = createPinia()
        const vueApp = createApp({ render: () => h(App, props) })

        vueApp.use(pinia)
        vueApp.use(plugin)
        vueApp.use(globalComponents)
        vueApp.config.errorHandler = handleError
        vueApp.config.warnHandler = handleWarn

        const authStore = useAuthStore()
        try {
            authStore.init()
            await Promise.all([
                authStore.reauthenticate().catch(e => console.error("Auth failed", e)),
                // สามารถโหลดข้อมูลพื้นฐานอื่นๆ ที่นี่ได้
            ])
        } catch (e) {
            console.warn("Initial data fetch failed", e)
        }

        vueApp.provide(DefaultApolloClient, apolloClient)
        vueApp.provide('grpcClient', grpcClient)
        vueApp.provide('appInfo', {
            name: appName,
            version: import.meta.env.VITE_APP_VERSION || '1.0.0',
            env: import.meta.env.MODE,
        })

        vueApp.mount(el)
    },

    progress: {
        delay: 250,
        color: '#29d',
        includeCSS: true,
        showSpinner: true,
    },
})

// ==============================
// Global Error Listeners
// ==============================
window.addEventListener('error', (event) => {
    console.error('Global Error:', event.error)
})

window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled Promise Rejection:', event.reason)
})