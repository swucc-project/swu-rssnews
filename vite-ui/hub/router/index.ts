import { createRouter, createWebHistory } from 'vue-router';
import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
    {
        path: '/',
        name: 'Home',
        component: () => import('@pages/Index.vue'),
        meta: { title: 'หน้าหลัก' }
    },
    {
        path: '/add',
        name: 'AddRSSItem',
        component: () => import('@pages/AddRSSItem.vue'),
        meta: { title: 'เพิ่มข่าว', requiresAuth: true }
    },
    {
        path: '/update/:itemID',
        name: 'UpdateRSSItem',
        component: () => import('@pages/UpdateRSSItem.vue'),
        meta: { title: 'แก้ไขข่าว', requiresAuth: true }
    },
    {
        path: '/delete/:id',
        name: 'DeleteRSSItem',
        component: () => import('@pages/DeleteRSSItem.vue'),
        meta: { title: 'ลบข่าว', requiresAuth: true }
    },
    {
        path: '/view',
        name: 'ViewFeed',
        component: () => import('@pages/Feed.vue'),
        meta: { title: 'ดู RSS Feed' }
    },
    {
        path: '/view/:categoryId',
        name: 'ViewFeedByCategory',
        component: () => import('@pages/Feed.vue'),
        meta: { title: 'ดู RSS Feed ตามหมวดหมู่' }
    },
    {
        path: '/signin',
        name: 'SignIn',
        component: () => import('@pages/Signin.vue'),
        meta: { title: 'เข้าสู่ระบบ' }
    },
    {
        path: '/news-feed',
        name: 'NewsFeed',
        component: () => import('@pages/NewsFeed.vue'),
        meta: { title: 'News Feed' }
    }
];

const router = createRouter({
    history: createWebHistory('/rss'),
    routes,
    scrollBehavior(to, from, savedPosition) {
        if (savedPosition) {
            return savedPosition;
        }
        return { top: 0 };
    }
});

// Navigation guard
router.beforeEach((to, from, next) => {
    // Set document title
    document.title = to.meta.title
        ? `${to.meta.title} - SWU News Hub`
        : 'SWU News Hub';

    // Check authentication
    if (to.meta.requiresAuth) {
        const authStore = useAuthStore();
        if (!authStore.isAuthenticated) {
            next({ name: 'SignIn', query: { redirect: to.fullPath } });
            return;
        }
    }

    next();
});

export default router;