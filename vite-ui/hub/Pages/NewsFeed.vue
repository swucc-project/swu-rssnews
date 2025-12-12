<script setup lang="ts">
import { ref, computed, onMounted, inject } from 'vue';
import type { RSSItemServiceClient } from '~grpc/rss.client';
import { parseRSSFeed, buildRSSFeed, formatXML, type RSSChannel } from '~tools/xml-parser';
import { convertJSONToHighlightedXML } from '~tools/xml-parser'
import { formatThaiDate } from '~tools/date-packages';

const props = defineProps<{
    categoryId?: string | number;
}>();

const grpcClient = inject<RSSItemServiceClient>('grpcClient');

const loading = ref(false);
const error = ref<string | null>(null);
const rssItems = ref<any[]>([]);
const xmlContent = ref<string>('');
const showXML = ref(false);
const highlightedXML = ref('')
const viewMode = ref<'card' | 'xml'>('card');

// Fetch RSS items using gRPC
const fetchRSSItems = async () => {
    if (!grpcClient) {
        error.value = 'gRPC client not available';
        return;
    }

    loading.value = true;
    error.value = null;

    try {
        const { response } = await grpcClient.getRSSItems({});
        rssItems.value = response.items || [];
        
        // แปลงเป็น XML
        await generateXMLFeed();
    } catch (err: any) {
        error.value = err.message || 'Failed to fetch RSS items';
        console.error('gRPC Error:', err);
    } finally {
        loading.value = false;
    }
};

// Generate XML feed from items
const generateXMLFeed = async () => {
    try {
        const channel: RSSChannel = {
            title: 'ระบบข่าวและกิจกรรม มหาวิทยาลัยศรีนครินทรวิโรฒ',
            link: window.location.origin,
            description: 'ข่าวสารและกิจกรรมล่าสุดจาก มศว',
            language: 'th',
            copyright: '© ฝ่ายระบบสารสนเทศ สำนักคอมพิวเตอร์ มหาวิทยาลัยศรีนครินทรวิโรฒ',
            lastBuildDate: new Date().toUTCString(),
            items: rssItems.value.map(item => ({
                title: item.title,
                link: item.link,
                description: item.description,
                pubDate: new Date(item.publishedDate.seconds * 1000).toUTCString(),
                category: item.category?.name || '',
                author: `${item.author?.firstname || ''} ${item.author?.lastname || ''}`.trim(),
                guid: item.link,
            })),
        };

        const xml = buildRSSFeed(channel);
        xmlContent.value = formatXML(xml);
    } catch (err) {
        console.error('Error generating XML:', err);
        error.value = 'Failed to generate XML feed';
    }
};

// Download XML file
const downloadXML = () => {
    const blob = new Blob([xmlContent.value], { type: 'application/rss+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `rss-feed-${new Date().getTime()}.xml`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
};

// Copy XML to clipboard
const copyXML = async () => {
    try {
        await navigator.clipboard.writeText(xmlContent.value);
        alert('XML copied to clipboard!');
    } catch (err) {
        console.error('Failed to copy:', err);
    }
};

onMounted(async () => {
    await fetchRSSItems();
    highlightedXML.value = convertJSONToHighlightedXML(xmlContent.value, 'rss');
});
</script>

<template>
    <div class="container mx-auto p-6 font-sarabun">
        <!-- Header with controls -->
        <div class="flex justify-between items-center mb-6">
            <h1 class="text-3xl font-bold text-gray-800">RSS Feed</h1>
            
            <div class="flex gap-2">
                <button 
                    @click="viewMode = 'card'" 
                    :class="['btn btn-sm', viewMode === 'card' ? 'btn-primary' : 'btn-outline']"
                >
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                    </svg>
                    การ์ด
                </button>
                
                <button 
                    @click="viewMode = 'xml'" 
                    :class="['btn btn-sm', viewMode === 'xml' ? 'btn-primary' : 'btn-outline']"
                >
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
                    </svg>
                    XML
                </button>
                
                <button 
                    v-if="viewMode === 'xml'"
                    @click="downloadXML" 
                    class="btn btn-sm btn-success"
                >
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    ดาวน์โหลด
                </button>
                
                <button 
                    v-if="viewMode === 'xml'"
                    @click="copyXML" 
                    class="btn btn-sm btn-info"
                >
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                    คัดลอก
                </button>
                
                <button 
                    @click="fetchRSSItems" 
                    class="btn btn-sm btn-secondary"
                    :disabled="loading"
                >
                    <svg class="w-4 h-4 mr-1" :class="{ 'animate-spin': loading }" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    รีเฟรช
                </button>
            </div>
        </div>

        <!-- Loading state -->
        <LoadingSpinner v-if="loading && !rssItems.length" text="กำลังโหลดข่าวสาร..." />

        <!-- Error state -->
        <FailureNotice v-else-if="error" :message="`เกิดข้อผิดพลาด: ${error}`" />

        <!-- Empty state -->
        <EmptyState v-else-if="rssItems.length === 0" message="ไม่พบรายการข่าวสาร" />

        <!-- Card View -->
        <div v-else-if="viewMode === 'card'" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div 
                v-for="item in rssItems" 
                :key="item.itemId" 
                class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow duration-300"
            >
                <div class="card-body">
                    <h2 class="card-title text-xl font-semibold">{{ item.title }}</h2>
                    <div class="text-gray-600 line-clamp-3 mt-2" v-html="item.description"></div>
                    
                    <div class="mt-4 space-y-1 text-xs text-gray-500">
                        <p v-if="item.category" class="badge badge-outline">
                            {{ item.category.name }}
                        </p>
                        <p>เผยแพร่: {{ formatThaiDate(new Date(item.publishedDate.seconds * 1000)) }}</p>
                        <p v-if="item.author">
                            ผู้เขียน: {{ item.author.firstname }} {{ item.author.lastname }}
                        </p>
                    </div>
                    
                    <div class="card-actions justify-end items-center mt-4">
                        <Link 
                            :href="`/rss/update/${item.itemId}`" 
                            class="btn btn-sm btn-warning"
                        >
                            แก้ไข
                        </Link>
                        <a 
                            :href="item.link" 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            class="btn btn-sm btn-primary"
                        >
                            อ่านเพิ่มเติม
                        </a>
                    </div>
                </div>
            </div>
        </div>

        <!-- XML View -->
        <div v-else-if="viewMode === 'xml'" class="rounded-lg p-6 overflow-auto bg-gray-900 text-green-300">
            <pre v-html="highlightedXml"></pre>
        </div>
    </div>
</template>

<style scoped>
.line-clamp-3 {
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

pre code {
    display: block;
    max-width: 100%;
    overflow-x: auto;
}
</style>