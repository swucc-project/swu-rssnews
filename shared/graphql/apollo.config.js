require('dotenv').config({ path: process.env.NODE_ENV === 'production' ? '.env.production' : '.env' });

module.exports = {
    client: {
        service: {
            name: 'rssnews',
            url: process.env.VITE_GRAPHQL_ENDPOINT || 'http://aspdotnetweb:5000/graphql',
            headers: {
                'X-Allow-Introspection': 'true',
            },
            skipSSLValidation: true,
        },
        includes: [
            './hub/**/*.vue',
            './hub/**/*.ts',
            './apollo/**/*.graphql',
        ],
        excludes: [
            '**/node_modules/**',
            '**/__tests__/**',
            '**/generated/**',
        ],
    },
    // เพิ่ม engine config สำหรับ Apollo Studio
    engine: {
        endpoint: process.env.VITE_GRAPHQL_ENDPOINT || 'http://aspdotnetweb:5000/graphql',
        apiKey: process.env.APOLLO_KEY,
    }
}