import express from 'express';
import { createServer as createViteServer } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const isProduction = process.env.NODE_ENV === 'production';

async function createServer() {
    const app = express();

    // ✅ เพิ่ม error handler สำหรับ express
    app.use((err, req, res, next) => {
        console.error('Express Error:', err);
        res.status(500).json({
            error: err.message,
            success: false
        });
    });

    // Parse JSON body
    app.use(express.json({ limit: '10mb' }));

    let vite;

    if (!isProduction) {
        try {
            // Development: สร้าง Vite server ใน middleware mode
            vite = await createViteServer({
                server: {
                    middlewareMode: true,
                    hmr: false
                },
                appType: 'custom',
                root: path.resolve(__dirname, '..'),
            });
            app.use(vite.middlewares);
            console.log('✅ Vite middleware initialized');
        } catch (error) {
            console.error('❌ Failed to create Vite server:', error);
            process.exit(1);
        }
    }

    // Health check endpoint
    app.get('/health', (req, res) => {
        res.status(200).json({
            status: 'ok',
            mode: isProduction ? 'production' : 'development',
            timestamp: new Date().toISOString(),
            pid: process.pid
        });
    });

    // SSR render endpoint
    app.post('/render', async (req, res) => {
        const { url, component, props = {}, version = '' } = req.body;

        if (!url) {
            return res.status(400).json({
                error: 'URL is required',
                success: false
            });
        }

        try {
            let render;

            if (isProduction) {
                const ssrPath = path.resolve(__dirname, '../../aspnetcore/wwwroot/ssr/ssr.js');
                render = (await import(ssrPath)).default;
            } else {
                if (!vite) {
                    throw new Error('Vite server not initialized');
                }
                const ssrModule = await vite.ssrLoadModule('./hub/ssr.js');
                render = ssrModule.default || ssrModule.render;
            }

            const appHtml = await render({
                url,
                component: component || 'Index',
                props,
                version,
            });

            res.status(200).json({
                html: appHtml,
                success: true
            });
        } catch (e) {
            if (vite) {
                vite.ssrFixStacktrace(e);
            }
            console.error('SSR Error:', e);
            res.status(500).json({
                error: e.message,
                stack: isProduction ? undefined : e.stack,
                success: false
            });
        }
    });

    const port = process.env.SSR_PORT || 13714;
    const host = '0.0.0.0';

    return new Promise((resolve, reject) => {
        const server = app.listen(port, host, (err) => {
            if (err) {
                console.error('❌ Failed to start SSR server:', err);
                reject(err);
                return;
            }
            console.log(`✅ SSR server running at http://${host}:${port}`);
            console.log(`📦 Mode: ${isProduction ? 'production' : 'development'}`);
            console.log(`🔧 PID: ${process.pid}`);
            resolve(server);
        });

        server.on('error', (err) => {
            if (err.code === 'EADDRINUSE') {
                console.error(`❌ Port ${port} is already in use`);
            } else {
                console.error('❌ Server error:', err);
            }
            reject(err);
        });
    });
}

// ✅ ปรับปรุง error handling
createServer().catch(err => {
    console.error('Fatal: Failed to start SSR server:', err);
    console.error('Stack:', err.stack);
    process.exit(1);
});

// ✅ Handle graceful shutdown
process.on('SIGTERM', () => {
    console.log('📴 Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('📴 Received SIGINT, shutting down gracefully...');
    process.exit(0);
});