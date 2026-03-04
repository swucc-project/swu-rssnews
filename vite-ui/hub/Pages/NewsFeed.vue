<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import { Link, router } from '@inertiajs/vue3';
import { buildRSSFeed, formatXML, highlightXMLString, type RSSChannel } from '~tools/xml-parser';
import { formatThaiDate } from '~tools/date-packages';

interface NewsItem {
    itemID: string;
    title: string;
    link: string;
    description: string;
    publishedDate: string | Date;
    category?: {
    categoryName: string;
  };
  author?: {
    firstName: string;
    lastName: string;
  };
}
const props = defineProps<{
    categoryId?: string | number;
    rssItems: NewsItem[];
    auth?: unknown; // Shared Data
}>();

const xmlContent = ref('');
const highlightedXML = ref('');
const viewMode = ref<'card' | 'xml'>('card');
const loading = ref(false);

// Generate XML feed from items
const generateXMLFeed = () => {
    try {
        if (!props.rssItems || props.rssItems.length === 0) {
            xmlContent.value = '';
            highlightedXML.value = '';
            return;
        }

        const channel: RSSChannel = {
            title: 'ระบบข่าวและกิจกรรม มหาวิทยาลัยศรีนครินทรวิโรฒ',
            link: window.location.origin,
            description: 'ข่าวสารและกิจกรรมล่าสุดจาก มศว',
            language: 'th',
            copyright: '© ฝ่ายระบบสารสนเทศ สำนักคอมพิวเตอร์ มหาวิทยาลัยศรีนครินทรวิโรฒ',
            lastBuildDate: new Date().toUTCString(),
            items: props.rssItems.map(item => ({
                title: item.title,
                link: item.link,
                description: item.description,
                pubDate: item.publishedDate
                    ? new Date(item.publishedDate).toUTCString()
                    : new Date().toUTCString(),
                category: item.category?.categoryName ?? '',
                author: item.author
                ? `${item.author.firstName} ${item.author.lastName}`.trim()
                : undefined,
                guid: item.link,
            })),
        };

        const xml = buildRSSFeed(channel);
        xmlContent.value = formatXML(xml);
        // ✅ ใช้ฟังก์ชันใหม่ที่รับ String
        highlightedXML.value = highlightXMLString(xmlContent.value);
        console.log('✅ XML feed generated');
    } catch (err) {
        console.error('❌ Error generating XML:', err);
    }
};

// Download XML file
const downloadXML = () => {
    const blob = new Blob([xmlContent.value], { type: 'application/rss+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `rss-feed-${Date.now()}.xml`;
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

// Handle Refresh using Inertia Reload
const handleRefresh = () => {
    loading.value = true;
    router.reload({
        only: ['rssItems'],
        onFinish: () => {
            loading.value = false;
            generateXMLFeed();
        }
    });
};

onMounted(generateXMLFeed);

watch(
  () => props.rssItems,
  () => generateXMLFeed()
);
</script>

<template>
    <div class="container mx-auto p-6 font-sarabun">
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
                    :disabled="!xmlContent"
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
                    :disabled="!xmlContent"
                >
                    <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                    </svg>
                    คัดลอก
                </button>
                
                <button 
                    @click="handleRefresh" 
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

        <div v-if="!props.rssItems || props.rssItems.length === 0" class="alert alert-info shadow-lg">
            <div>
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current flex-shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span>ไม่พบรายการข่าวสาร</span>
            </div>
        </div>

        <div v-else-if="viewMode === 'card'" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div 
                v-for="item in props.rssItems" 
                :key="item.itemID" 
                class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow duration-300"
            >
                <div class="card-body">
                    <h2 class="card-title text-xl font-semibold">{{ item.title }}</h2>
                    <div class="text-gray-600 line-clamp-3 mt-2" v-html="item.description"></div>
                    
                    <div class="mt-4 space-y-1 text-xs text-gray-500">
                        <p v-if="item.category" class="badge badge-outline">
                            {{ item.category.categoryName }}
                        </p>
                        <p>เผยแพร่: {{ formatThaiDate(new Date(item.publishedDate)) }}</p>
                        <p v-if="item.author">
                            ผู้เขียน: {{ item.author.firstName }} {{ item.author.lastName }}
                        </p>
                    </div>
                    
                    <div class="card-actions justify-end items-center mt-4">
                        <Link 
                            :href="`/rss/update/${item.itemID}`" 
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

        <div v-else-if="viewMode === 'xml'" class="rounded-lg p-6 overflow-auto bg-gray-900 text-green-300 max-h-[70vh]">
            <pre v-if="highlightedXML" v-html="highlightedXML"></pre>
            <pre v-else class="text-gray-400">{{ xmlContent || 'กำลังสร้าง XML...' }}</pre>
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

pre {
    white-space: pre-wrap;
    word-wrap: break-word;
}
</style>