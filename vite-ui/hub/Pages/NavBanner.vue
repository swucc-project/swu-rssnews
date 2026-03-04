<script setup>
import { Link } from '@inertiajs/vue3'
import headBanner from '~images/head-banner.jpg'
</script>

<template>
    <div class="navbar bg-cover flex justify-center py-4" :style="{ backgroundImage: `url(${headBanner})` }">
        <Link href="/rss" class="btn btn-ghost text-xl text-white normal-case hover:bg-white/10">
            <span class="hidden md:inline font-swu">มหาวิทยาลัยศรีนครินทรวิโรฒ</span>
        </Link>
    </div>
</template>