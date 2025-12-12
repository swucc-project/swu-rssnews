import { createInertiaApp } from '@inertiajs/vue3';
import { renderToString } from '@vue/server-renderer';
import { resolvePageComponent } from 'laravel-vite-plugin/inertia-helpers';
import { createSSRApp, h, provide } from 'vue';
import { DefaultApolloClient } from '@vue/apollo-composable';
import { createPinia } from 'pinia';
import { createSsrClient } from '~apollo/setup/ssr';
import { createSsrGrpcClient } from '~grpc/install-ssr';
import globalComponents from '@suites/globalComponents.js';

// Import CSS สำหรับ SSR
import '~css/app.css';

const isProduction = import.meta.env.PROD;

export default async function render(page) {
    return await createInertiaApp({
        page,
        render: renderToString,
        resolve: (name) => {
            return resolvePageComponent(
                `./Pages/${name}.vue`,
                import.meta.glob('./Pages/**/*.vue')
            );
        },
        setup({ App, props, plugin }) {
            // สร้าง Apollo Client สำหรับ SSR (แยกต่างหากสำหรับแต่ละ request)
            const apolloClient = createSsrClient();

            // สร้าง gRPC Client สำหรับ SSR
            const grpcClient = createSsrGrpcClient();

            // สร้าง Vue app
            const app = createSSRApp({
                render: () => h(App, props),
                setup() {
                    // Provide Apollo Client และ gRPC Client
                    provide(DefaultApolloClient, apolloClient);
                    provide('grpcClient', grpcClient);
                }
            });

            // สร้าง Pinia store
            const pinia = createPinia();

            // ใช้ plugins
            app.use(pinia);
            app.use(plugin);
            app.use(globalComponents);

            return app;
        }
    });
}

// Log สำหรับ debugging (เฉพาะ development)
if (!isProduction) {
    console.log('Inertia.js SSR app initialized.');
}