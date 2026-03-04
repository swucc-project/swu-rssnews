import { parseString, Builder } from 'xml2js';
import Prism from 'prismjs';
import 'prismjs/components/prism-markup';
import 'prismjs/themes/prism-tomorrow.css';

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

export const parseXMLToJSON = (xml: string): Promise<any> =>
    new Promise((resolve, reject) => {
        parseString(
            xml,
            { explicitArray: false, trim: true, mergeAttrs: true },
            (err, result) => (err ? reject(err) : resolve(result))
        );
    });

export const convertJSONToXML = (
    jsonData: any,
    rootName: string = 'rss'
): string => {
    const builder = new Builder({
        rootName,
        xmldec: { version: '1.0', encoding: 'UTF-8' },
        renderOpts: { pretty: true, indent: '  ', newline: '\n' },
    });
    return builder.buildObject(jsonData);
};

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
                description: {
                    _: item.description,
                    $: { xmlns: 'http://www.w3.org/1999/xhtml' },
                },
                pubDate: item.pubDate,
                ...(item.category && { category: item.category }),
                ...(item.author && { author: item.author }),
                guid: {
                    _: item.guid || item.link,
                    $: { isPermaLink: 'true' },
                },
            })),
        },
    };

    return convertJSONToXML(rssObject, 'rss');
};

export const highlightXMLString = (xmlString: string): string => {
    if (typeof window === 'undefined') {
        return `<pre><code>${escapeXML(xmlString)}</code></pre>`;
    }

    const highlighted = Prism.highlight(
        xmlString,
        Prism.languages.xml,
        'xml'
    );
    return `<pre class="language-xml"><code>${highlighted}</code></pre>`;
};

export const formatXML = (xmlString: string): string => {
    try {
        return xmlString
            .replace(/>\s*</g, '>\n<')
            .split('\n')
            .map(line => line.trim())
            .filter(Boolean)
            .join('\n');
    } catch {
        return xmlString;
    }
};

export const validateXML = async (xmlString: string): Promise<boolean> => {
    try {
        await parseXMLToJSON(xmlString);
        return true;
    } catch {
        return false;
    }
};

export const escapeXML = (text: string): string =>
    text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');

export const unescapeXML = (text: string): string =>
    text
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'");