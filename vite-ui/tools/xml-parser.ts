import { parseString, Builder } from 'xml2js';
import Prism from 'prismjs'
import 'prismjs/components/prism-markup'
import 'prismjs/themes/prism-tomorrow.css'

export interface RSSChannel {
    title: string;
    link: string;
    description: string;
    language?: string;
    copyright?: string;
    lastBuildDate?: string;
    items: RSSItem[];
}

export interface RSSItem {
    title: string;
    link: string;
    description: string;
    pubDate: string;
    category?: string;
    author?: string;
    guid?: string;
}

/**
 * แปลง XML string เป็น JavaScript Object
 */
export const parseXMLToJSON = (xml: string): Promise<any> => {
    return new Promise((resolve, reject) => {
        parseString(
            xml,
            { explicitArray: false, trim: true, mergeAttrs: true },
            (err, result) => {
                if (err) reject(err)
                else resolve(result)
            }
        );
    });
};

/**
 * แปลง JavaScript Object เป็น XML string
 */
export const convertJSONToXML = (jsonData: any, rootName: string = 'rss'): string => {
    const builder = new Builder({
        rootName,
        xmldec: { version: '1.0', encoding: 'UTF-8' },
        renderOpts: { pretty: true, indent: '  ', newline: '\n' },
    })
    return builder.buildObject(jsonData)
};

/**
 * แปลง RSS XML เป็น structured data
 */
export const parseRSSFeed = async (xmlString: string): Promise<RSSChannel> => {
    try {
        const parsed = await parseXMLToJSON(xmlString);

        const channel = parsed.rss?.channel || parsed.channel;

        if (!channel) {
            throw new Error('Invalid RSS feed format');
        }

        const items = Array.isArray(channel.item)
            ? channel.item
            : channel.item ? [channel.item] : [];

        return {
            title: channel.title || '',
            link: channel.link || '',
            description: channel.description || '',
            language: channel.language,
            copyright: channel.copyright,
            lastBuildDate: channel.lastBuildDate,
            items: items.map((item: any) => ({
                title: item.title || '',
                link: item.link || '',
                description: item.description || '',
                pubDate: item.pubDate || '',
                category: item.category,
                author: item.author,
                guid: item.guid?._ || item.guid,
            })),
        };
    } catch (error) {
        console.error('Error parsing RSS feed:', error);
        throw error;
    }
};

/**
 * สร้าง RSS XML จาก structured data
 */
export const buildRSSFeed = (channel: RSSChannel): string => {
    const rssObject = {
        $: {
            version: '2.0',
            'xmlns:atom': 'http://www.w3.org/2005/Atom',
        },
        channel: {
            title: channel.title,
            link: channel.link,
            description: channel.description,
            language: channel.language || 'th',
            copyright: channel.copyright,
            lastBuildDate: channel.lastBuildDate || new Date().toUTCString(),
            item: channel.items.map(item => ({
                title: item.title,
                link: item.link,
                description: { _: item.description, $: { 'xmlns': 'http://www.w3.org/1999/xhtml' } },
                pubDate: item.pubDate,
                category: item.category,
                author: item.author,
                guid: { _: item.guid || item.link, $: { isPermaLink: 'true' } },
            })),
        },
    };

    return convertJSONToXML(rssObject, 'rss');
};

export const convertJSONToHighlightedXML = (jsonData: any, rootName: string = 'rss'): string => {
    const xmlString = convertJSONToXML(jsonData, rootName)
    const highlighted = Prism.highlight(xmlString, Prism.languages.xml, 'xml')
    return `<pre class="language-xml"><code>${highlighted}</code></pre>`
}

/**
 * Format XML string ให้อ่านง่าย
 */
export const formatXML = (xmlString: string): string => {
    try {
        const formatted = xmlString
            .replace(/>\s*</g, '>\n<')
            .split('\n')
            .map(line => line.trim())
            .filter(line => line.length > 0)
            .join('\n');

        return formatted;
    } catch (error) {
        console.error('Error formatting XML:', error);
        return xmlString;
    }
};

/**
 * Validate XML string
 */
export const validateXML = async (xmlString: string): Promise<boolean> => {
    try {
        await parseXMLToJSON(xmlString);
        return true;
    } catch (error) {
        console.error('XML validation failed:', error);
        return false;
    }
};

/**
 * Escape XML special characters
 */
export const escapeXML = (text: string): string => {
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
};

/**
 * Unescape XML special characters
 */
export const unescapeXML = (text: string): string => {
    return text
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'");
};