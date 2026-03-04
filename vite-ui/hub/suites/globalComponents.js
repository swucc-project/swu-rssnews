// Import components
import LoadingSpinner from '@components/general/LoadingSpinner.vue';
import FailureNotice from '@components/general/FailureNotice.vue';
import EmptyState from '@components/general/EmptyState.vue';
import ProgressIndicator from '@components/general/ProgressIndicator.vue';
import SuccessMessage from '@components/general/SuccessMessage.vue';
import ErrorBoundary from '@components/ErrorBoundary.vue';
import SynchronousNotification from '@components/SynchronousNotification.vue';
import HorizontalMenu from '@components/HorizontalMenu.vue';
import VerticalMenu from '@components/VerticalMenu.vue';
import { Link } from '@inertiajs/vue3';

// สร้างเป็น Vue Plugin
export default {
    install: (app, options) => {
        // ✅ ลงทะเบียนคอมโพเนนต์ทั้งหมดที่นี่
        app.component('LoadingSpinner', LoadingSpinner);
        app.component('FailureNotice', FailureNotice);
        app.component('EmptyState', EmptyState);
        app.component('ProgressIndicator', ProgressIndicator);
        app.component('SuccessMessage', SuccessMessage);
        app.component('ErrorBoundary', ErrorBoundary);
        app.component('SynchronousNotification', SynchronousNotification);
        app.component('HorizontalMenu', HorizontalMenu);
        app.component('VerticalMenu', VerticalMenu);
        app.component('Link', Link);

        // ✅ Log registration in development
        if (import.meta?.env?.DEV) {
            console.log('✅ Global components registered');
        }
    }
};