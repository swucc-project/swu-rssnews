<!-- /vite-ui/hub/components/layouts/CoreLayout.vue -->
<script setup>
import HorizontalMenu from '@components/HorizontalMenu.vue'
import VerticalMenu from '@components/VerticalMenu.vue'
import NavBanner from '@pages/NavBanner.vue'
import SynchronousNotification from '@components/SynchronousNotification.vue'

</script>

<template>
    <div class="min-h-screen bg-gray-100 flex flex-col font-sarabun">
        <NavBanner />
        <HorizontalMenu />
        
        <div class="flex-grow container mx-auto px-4 py-6">
            <div class="flex flex-col lg:flex-row gap-6">
                <aside class="w-full lg:w-64 flex-shrink-0">
                    <VerticalMenu />
                </aside>
                
                <main class="flex-grow">
                    <slot />
                </main>
            </div>
        </div>
        
        <footer class="copyright py-6 text-center bg-base-200">
            <div class="container mx-auto px-4">
                <div class="font-sarabun text-base leading-relaxed">
                    <p class="font-bold mb-2">มหาวิทยาลัยศรีนครินทรวิโรฒ</p>
                    <p>114 สุขุมวิท 23 แขวงคลองเตยเหนือ เขตวัฒนา กรุงเทพฯ 10110</p>
                    <p>โทร. (02) 649-5000 | แฟกซ์ (02) 258-4007</p>
                    <p class="mt-3">&copy; มีนาคม 2569 ฝ่ายระบบสารสนเทศ สำนักคอมพิวเตอร์</p>
                </div>
            </div>
        </footer>
        
        <SynchronousNotification />
    </div>
</template>