<script setup>
import { computed } from 'vue';
import { Link, usePage } from '@inertiajs/vue3';
import { useAuthStore } from '@hub/stores/auth';
import rssIcon from '~images/rss.png';

const authStore = useAuthStore();
const page = usePage();

const handleLogout = () => {
    if (confirm('คุณต้องการออกจากระบบใช่หรือไม่?')) {
        authStore.logout();
    }
};

const currentUrl = computed(() => page.url);
const currentComponent = computed(() => page.component);

const isActive = (path) => {
    return currentUrl.value === path || currentUrl.value.startsWith(path);
};

</script>

<template>
    <nav class="menu-bar horizontal shadow-lg sticky top-0 z-40">
        <div class="container mx-auto px-4">
            <div class="navbar p-0">
                <!-- Navbar Start -->
                <div class="navbar-start">
                    <Link 
                        href="/rss"
                        class="btn btn-ghost normal-case text-xl font-sarabun text-white hover:bg-white/10"
                    >
                        <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
                        </svg>
                        <span class="font-bold">SWU News Hub</span>
                    </Link>
                </div>

                <!-- Navbar Center -->
                <div class="navbar-center hidden lg:flex">
                    <ul class="menu menu-horizontal p-0 gap-1">
                        <!-- หน้าหลัก -->
                        <li>
                            <Link 
                                href="/rss"
                                class="font-sarabun text-white hover:bg-white/10 rounded-md px-4 py-2"
                                :class="{ 'active bg-white/20 font-bold': isActive('/rss') }"
                            >
                                <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                                </svg>
                                หน้าหลัก
                            </Link>
                        </li>

                        <template v-if="authStore.isAuthenticated">
                            <!-- เพิ่มข่าว -->
                            <li>
                                <Link 
                                    href="/rss/add"
                                    class="font-sarabun text-white hover:bg-white/10 rounded-md px-4 py-2"
                                    :class="{ 'active bg-white/20 font-bold': isActive('/rss/add') }"
                                >
                                    <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                                    </svg>
                                    เพิ่มข่าว
                                </Link>
                            </li>

                            <!-- แก้ไขข่าว -->
                            <li>
                                <Link 
                                    href="/rss/update"
                                    class="font-sarabun text-white hover:bg-white/10 rounded-md px-4 py-2"
                                    :class="{ 'active bg-white/20 font-bold': isActive('/rss/update') }"
                                >
                                    <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                    </svg>
                                    แก้ไขข่าว
                                </Link>
                            </li>

                            <!-- ลบข่าว -->
                            <li>
                                <Link 
                                    href="/rss/delete/select"
                                    class="font-sarabun text-white hover:bg-white/10 rounded-md px-4 py-2"
                                    :class="{ 'active bg-white/20 font-bold': isActive('/rss/delete') }"
                                >
                                    <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                    </svg>
                                    ลบข่าว
                                </Link>
                            </li>
                        </template>

                        <!-- ดู RSS Feed -->
                        <li>
                            <Link 
                                href="/rss/view"
                                class="font-sarabun text-white hover:bg-white/10 rounded-md px-4 py-2"
                                :class="{ 'active bg-white/20 font-bold': isActive('/rss/view') }"
                            >
                                <img :src="rssIcon" alt="RSS" class="w-5 h-5 mr-1" />
                                ดู RSS Feed
                        </Link>
                        </li>
                    </ul>
                </div>

                <!-- Auth Section -->
                <div class="navbar-end gap-2">
                    <Link 
                        v-if="!authStore.isAuthenticated" 
                        href="/rss/signin"
                        class="btn btn-ghost font-sarabun text-white hover:bg-white/10"
                    >
                        <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" />
                        </svg>
                        เข้าสู่ระบบ
                    </Link>

                    <div v-else class="dropdown dropdown-end">
                        <label tabindex="0" class="btn btn-ghost btn-circle avatar hover:bg-white/10">
                            <div class="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center ring-2 ring-white/50">
                                <span class="text-xl font-bold text-white">
                                    {{ authStore.user?.displayName?.charAt(0).toUpperCase() || 'U' }}
                                </span>
                            </div>
                        </label>
                        <ul tabindex="0" class="menu menu-compact dropdown-content mt-3 p-2 shadow-lg bg-white rounded-box w-52">
                            <li class="menu-title">
                                <span class="text-gray-700 font-bold px-4 py-2">
                                    {{ authStore.user?.displayName || 'ผู้ใช้' }}
                                </span>
                            </li>
                            <div class="divider my-0"></div>
                            <li>
                                <a @click.prevent="handleLogout" class="text-gray-700 hover:bg-red-50 hover:text-red-600">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                                    </svg>
                                    ออกจากระบบ
                                </a>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </nav>
</template>