<template>
  <div class="api-docs">
    <div class="docs-header">
      <h1>คู่มือการใช้งาน API</h1>
      <div class="language-selector">
        <button @click="setLanguage('th-TH')" :class="{ active: language === 'th-TH' }">
          ไทย
        </button>
        <button @click="setLanguage('en-US')" :class="{ active: language === 'en-US' }">
          English
        </button>
      </div>
    </div>

    <div class="docs-content">
      <!-- Overview -->
      <section class="section">
        <h2>ภาพรวมระบบ</h2>
        <div class="info-grid">
          <div class="info-card">
            <h3>🔌 REST API</h3>
            <p>สำหรับ CRUD operations มาตรฐาน</p>
            <code>https://news.swu.ac.th/api/*</code>
          </div>
          <div class="info-card">
            <h3>📊 GraphQL</h3>
            <p>สำหรับ query ข้อมูลแบบยืดหยุ่น</p>
            <code>https://news.swu.ac.th/graphql</code>
          </div>
          <div class="info-card">
            <h3>⚡ gRPC</h3>
            <p>สำหรับการสื่อสารประสิทธิภาพสูง</p>
            <code>https://news.swu.ac.th/grpc</code>
          </div>
        </div>
      </section>

      <!-- Authentication -->
      <section class="section">
        <h2>🔐 การยืนยันตัวตน (Authentication)</h2>
        <div class="code-block">
          <h4>Login Request</h4>
          <pre><code>{{ authExample }}</code></pre>
          <button @click="copyCode(authExample)" class="copy-btn">Copy</button>
        </div>
      </section>

      <!-- Endpoints -->
      <section class="section" v-for="tag in apiTags" :key="tag.name">
        <h2>{{ tag.description }}</h2>
        
        <div v-for="endpoint in getEndpointsByTag(tag.name)" :key="endpoint.path + endpoint.method" 
             class="endpoint-card">
          <div class="endpoint-header">
            <span :class="['method', endpoint.method]">{{ endpoint.method }}</span>
            <code class="path">{{ endpoint.path }}</code>
          </div>
          
          <p class="description">{{ endpoint.description }}</p>

          <!-- Request Example -->
          <div v-if="endpoint.requestBody" class="example-section">
            <h4>Request Body</h4>
            <div class="code-block">
              <pre><code>{{ getRequestExample(endpoint) }}</code></pre>
              <button @click="copyCode(getRequestExample(endpoint))" class="copy-btn">
                Copy
              </button>
            </div>
          </div>

          <!-- Response Example -->
          <div class="example-section">
            <h4>Response (200)</h4>
            <div class="code-block">
              <pre><code>{{ getResponseExample(endpoint) }}</code></pre>
              <button @click="copyCode(getResponseExample(endpoint))" class="copy-btn">
                Copy
              </button>
            </div>
          </div>

          <!-- Try it out -->
          <div class="try-it-out">
            <button @click="tryEndpoint(endpoint)" class="try-btn">
              ⚡ ทดลองใช้งาน
            </button>
          </div>
        </div>
      </section>

      <!-- Code Examples -->
      <section class="section">
        <h2>💻 ตัวอย่างการใช้งาน</h2>
        
        <div class="tabs">
          <button v-for="lang in codeLangs" :key="lang" 
                  @click="activeCodeLang = lang"
                  :class="{ active: activeCodeLang === lang }">
            {{ lang }}
          </button>
        </div>

        <div class="code-block">
          <pre><code>{{ getCodeExample(activeCodeLang) }}</code></pre>
          <button @click="copyCode(getCodeExample(activeCodeLang))" class="copy-btn">
            Copy
          </button>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import type { OpenAPIV3 } from 'openapi-types';

const language = ref<'th-TH' | 'en-US'>('th-TH');
const apiDoc = ref<OpenAPIV3.Document | null>(null);
const activeCodeLang = ref('TypeScript');
const codeLangs = ['TypeScript', 'JavaScript', 'cURL', 'Python'];

const apiTags = ref([
  { name: 'Items', description: '📰 การจัดการข่าวและกิจกรรม' },
  { name: 'Categories', description: '📁 การจัดการหมวดหมู่' },
  { name: 'Authors', description: '✍️ การจัดการผู้เขียน' }
]);

const authExample = `POST /auth/credentials HTTP/1.1
Host: news.swu.ac.th
Content-Type: application/json

{
  "userName": "your-username",
  "password": "your-password"
}`;

onMounted(async () => {
  try {
    const response = await fetch('/manual-api.json');
    apiDoc.value = await response.json();
  } catch (error) {
    console.error('Failed to load API documentation:', error);
  }
});

function setLanguage(lang: 'th-TH' | 'en-US') {
  language.value = lang;
}

function getEndpointsByTag(tagName: string) {
  if (!apiDoc.value?.paths) return [];
  
  const endpoints = [];
  for (const [path, methods] of Object.entries(apiDoc.value.paths)) {
    for (const [method, operation] of Object.entries(methods)) {
      if (operation.tags?.includes(tagName)) {
        endpoints.push({
          path,
          method: method.toUpperCase(),
          ...operation
        });
      }
    }
  }
  return endpoints;
}

function getRequestExample(endpoint: any) {
  const schema = endpoint.requestBody?.content?.['application/json']?.schema;
  if (!schema) return 'No request body';
  
  return JSON.stringify(generateExampleFromSchema(schema), null, 2);
}

function getResponseExample(endpoint: any) {
  const schema = endpoint.responses?.['200']?.content?.['application/json']?.schema;
  if (!schema) return 'No response body';
  
  return JSON.stringify(generateExampleFromSchema(schema), null, 2);
}

function generateExampleFromSchema(schema: any): any {
  if (schema.$ref) {
    // Handle references
    return { ref: schema.$ref };
  }
  
  if (schema.type === 'object' && schema.properties) {
    const example: any = {};
    for (const [key, prop] of Object.entries(schema.properties)) {
      example[key] = (prop as any).example || generateExampleFromSchema(prop);
    }
    return example;
  }
  
  if (schema.type === 'array') {
    return [generateExampleFromSchema(schema.items)];
  }
  
  return schema.example || schema.default || `<${schema.type}>`;
}

function getCodeExample(lang: string) {
  const examples: Record<string, string> = {
    'TypeScript': `import { createApiClient } from './api/zod-client';

const client = createApiClient({
  baseURL: 'https://news.swu.ac.th',
  headers: {
    'Accept-Language': 'th-TH'
  }
});

// Get all items with pagination
const items = await client.getItems({
  page: 1,
  pageSize: 10,
  categoryId: 1
});

// Create new item
const newItem = await client.createItem({
  title: 'ข่าวใหม่',
  description: 'รายละเอียด...',
  link: 'https://news.swu.ac.th/article/123',
  pubDate: new Date().toISOString()
});`,
    
    'JavaScript': `const axios = require('axios');

const api = axios.create({
  baseURL: 'https://news.swu.ac.th',
  headers: {
    'Accept-Language': 'th-TH'
  }
});

// Get all items
const items = await api.get('/api/items', {
  params: {
    page: 1,
    pageSize: 10
  }
});

// Create new item
const newItem = await api.post('/api/items', {
  title: 'ข่าวใหม่',
  description: 'รายละเอียด...',
  link: 'https://news.swu.ac.th/article/123',
  pubDate: new Date().toISOString()
});`,
    
    'cURL': `# Get all items
curl -X GET "https://news.swu.ac.th/api/items?page=1&pageSize=10" \\
  -H "Accept-Language: th-TH"

# Create new item (requires authentication)
curl -X POST "https://news.swu.ac.th/api/items" \\
  -H "Accept-Language: th-TH" \\
  -H "Content-Type: application/json" \\
  -d '{
    "title": "ข่าวใหม่",
    "description": "รายละเอียด...",
    "link": "https://news.swu.ac.th/article/123",
    "pubDate": "2024-01-01T00:00:00Z"
  }'`,
    
    'Python': `import requests

# Create session
session = requests.Session()
session.headers.update({
    'Accept-Language': 'th-TH'
})

# Get all items
response = session.get('https://news.swu.ac.th/api/items', params={
    'page': 1,
    'pageSize': 10
})
items = response.json()

# Create new item
new_item = session.post('https://news.swu.ac.th/api/items', json={
    'title': 'ข่าวใหม่',
    'description': 'รายละเอียด...',
    'link': 'https://news.swu.ac.th/article/123',
    'pubDate': '2024-01-01T00:00:00Z'
})
`
  };
  
  return examples[lang] || '';
}

async function copyCode(code: string) {
  try {
    await navigator.clipboard.writeText(code);
    alert('Copied to clipboard!');
  } catch (err) {
    console.error('Failed to copy:', err);
  }
}

function tryEndpoint(endpoint: any) {
  // Open in Swagger UI or create interactive test
  window.open(`/swagger#/${endpoint.tags}/${endpoint.operationId}`, '_blank');
}
</script>

<style scoped>
.api-docs {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  font-family: 'THSarabunNew', sans-serif;
}

.docs-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 2px solid #c82020;
}

.docs-header h1 {
  color: #c82020;
  font-size: 2.5rem;
  margin: 0;
}

.language-selector button {
  padding: 0.5rem 1rem;
  margin-left: 0.5rem;
  border: 1px solid #ddd;
  background: white;
  cursor: pointer;
  border-radius: 4px;
}

.language-selector button.active {
  background: #c82020;
  color: white;
  border-color: #c82020;
}

.section {
  margin-bottom: 3rem;
}

.section h2 {
  color: #333;
  font-size: 2rem;
  margin-bottom: 1rem;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1rem;
  margin-top: 1rem;
}

.info-card {
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 1.5rem;
  background: #f9f9f9;
}

.info-card h3 {
  margin-top: 0;
  color: #c82020;
}

.info-card code {
  display: block;
  margin-top: 0.5rem;
  padding: 0.5rem;
  background: white;
  border-radius: 4px;
  font-size: 0.9rem;
}

.endpoint-card {
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 1rem;
  background: white;
}

.endpoint-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
}

.method {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  font-weight: bold;
  font-size: 0.875rem;
}

.method.GET { background: #61affe; color: white; }
.method.POST { background: #49cc90; color: white; }
.method.PUT { background: #fca130; color: white; }
.method.DELETE { background: #f93e3e; color: white; }

.path {
  font-family: 'Courier New', monospace;
  font-size: 1.1rem;
}

.code-block {
  position: relative;
  margin: 1rem 0;
}

.code-block pre {
  background: #2d2d2d;
  color: #f8f8f2;
  padding: 1rem;
  border-radius: 4px;
  overflow-x: auto;
}

.code-block code {
  font-family: 'Courier New', monospace;
  font-size: 0.9rem;
}

.copy-btn {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  padding: 0.25rem 0.75rem;
  background: #4a4a4a;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.875rem;
}

.copy-btn:hover {
  background: #666;
}

.try-btn {
  padding: 0.75rem 1.5rem;
  background: #c82020;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  font-weight: bold;
}

.try-btn:hover {
  background: #a01818;
}

.tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.tabs button {
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  background: white;
  cursor: pointer;
  border-radius: 4px 4px 0 0;
}

.tabs button.active {
  background: #2d2d2d;
  color: white;
  border-color: #2d2d2d;
}
</style>