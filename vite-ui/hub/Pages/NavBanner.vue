<script setup>
import headerImage from '~images/head-banner.jpg';
</script>

<template>
    <div class="navbar bg-[#228b22] flex justify-center py-4">
        <a href="/rss" class="btn btn-ghost text-xl text-white normal-case">
            <img :src="headerImage" class="h-10 w-auto mr-2" />
            <span class="hidden md:inline">มหาวิทยาลัยศรีนครินทรวิโรฒ</span>
        </a>
    </div>
</template>