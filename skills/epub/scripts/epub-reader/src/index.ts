#!/usr/bin/env node

import { program } from "commander";
import * as fs from "fs";
import * as path from "path";
import JSZip from "jszip";
import { parseStringPromise } from "xml2js";
import TurndownService from "turndown";

interface EpubMetadata {
  title?: string;
  creator?: string;
  author?: string;
  language?: string;
  publisher?: string;
  date?: string;
  description?: string;
  subject?: string[];
  identifier?: string;
}

interface ManifestItem {
  id: string;
  href: string;
  mediaType: string;
}

interface SpineItem {
  idref: string;
  linear?: string;
}

interface TocItem {
  label: string;
  href: string;
  children?: TocItem[];
}

interface ParsedEpub {
  metadata: EpubMetadata;
  manifest: Map<string, ManifestItem>;
  spine: SpineItem[];
  toc: TocItem[];
  contentBasePath: string;
  zip: JSZip;
}

const turndown = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
  emDelimiter: "*",
});

// Improve turndown to handle more elements
turndown.addRule("preserveLineBreaks", {
  filter: "br",
  replacement: () => "\n",
});

async function loadEpub(filePath: string): Promise<ParsedEpub> {
  const absolutePath = path.resolve(filePath);

  if (!fs.existsSync(absolutePath)) {
    throw new Error(`File not found: ${absolutePath}`);
  }

  const data = fs.readFileSync(absolutePath);
  const zip = await JSZip.loadAsync(data);

  // Find container.xml
  const containerXml = await zip.file("META-INF/container.xml")?.async("text");
  if (!containerXml) {
    throw new Error("Invalid EPUB: Missing META-INF/container.xml");
  }

  const container = await parseStringPromise(containerXml);
  const rootfilePath =
    container.container.rootfiles[0].rootfile[0].$["full-path"];

  // Get content base path
  const contentBasePath = path.dirname(rootfilePath);

  // Parse OPF file
  const opfContent = await zip.file(rootfilePath)?.async("text");
  if (!opfContent) {
    throw new Error(`Invalid EPUB: Missing OPF file at ${rootfilePath}`);
  }

  const opf = await parseStringPromise(opfContent);
  const pkg = opf.package;

  // Extract metadata
  const metadata = extractMetadata(pkg.metadata[0]);

  // Build manifest map
  const manifest = new Map<string, ManifestItem>();
  for (const item of pkg.manifest[0].item) {
    manifest.set(item.$.id, {
      id: item.$.id,
      href: item.$.href,
      mediaType: item.$["media-type"],
    });
  }

  // Extract spine
  const spine: SpineItem[] = pkg.spine[0].itemref.map(
    (item: { $: { idref: string; linear?: string } }) => ({
      idref: item.$.idref,
      linear: item.$.linear,
    })
  );

  // Try to extract TOC
  const toc = await extractToc(zip, manifest, contentBasePath, pkg);

  return {
    metadata,
    manifest,
    spine,
    toc,
    contentBasePath,
    zip,
  };
}

function extractMetadata(metadataNode: Record<string, unknown>): EpubMetadata {
  const metadata: EpubMetadata = {};

  // Helper to get text content from various formats
  const getText = (node: unknown): string | undefined => {
    if (!node) return undefined;
    if (Array.isArray(node)) {
      const first = node[0];
      if (typeof first === "string") return first;
      if (typeof first === "object" && first !== null && "_" in first)
        return (first as { _: string })._;
      if (typeof first === "object" && first !== null)
        return JSON.stringify(first);
    }
    if (typeof node === "string") return node;
    return undefined;
  };

  // DC metadata (Dublin Core)
  const dc = (key: string) =>
    getText(metadataNode[`dc:${key}`]) || getText(metadataNode[key]);

  metadata.title = dc("title");
  metadata.creator = dc("creator");
  metadata.author = metadata.creator;
  metadata.language = dc("language");
  metadata.publisher = dc("publisher");
  metadata.date = dc("date");
  metadata.description = dc("description");
  metadata.identifier = dc("identifier");

  // Handle multiple subjects
  const subjects = metadataNode["dc:subject"] || metadataNode["subject"];
  if (Array.isArray(subjects)) {
    metadata.subject = subjects.map((s) =>
      typeof s === "string" ? s : (s as { _?: string })._ || String(s)
    );
  }

  return metadata;
}

async function extractToc(
  zip: JSZip,
  manifest: Map<string, ManifestItem>,
  basePath: string,
  pkg: Record<string, unknown>
): Promise<TocItem[]> {
  const toc: TocItem[] = [];

  // Try EPUB 3 nav document first
  for (const [, item] of manifest) {
    if (item.mediaType === "application/xhtml+xml") {
      const fullPath =
        basePath === "." ? item.href : `${basePath}/${item.href}`;
      const content = await zip.file(fullPath)?.async("text");
      if (content && content.includes('epub:type="toc"')) {
        const navToc = await parseNavToc(content);
        if (navToc.length > 0) return navToc;
      }
    }
  }

  // Try NCX file (EPUB 2)
  const spine = pkg.spine as { $?: { toc?: string } }[] | undefined;
  const tocId = spine?.[0]?.$?.toc;
  if (tocId && manifest.has(tocId)) {
    const ncxItem = manifest.get(tocId)!;
    const ncxPath =
      basePath === "." ? ncxItem.href : `${basePath}/${ncxItem.href}`;
    const ncxContent = await zip.file(ncxPath)?.async("text");
    if (ncxContent) {
      return await parseNcxToc(ncxContent);
    }
  }

  // Fallback: look for any .ncx file
  for (const [, item] of manifest) {
    if (item.href.endsWith(".ncx")) {
      const ncxPath =
        basePath === "." ? item.href : `${basePath}/${item.href}`;
      const ncxContent = await zip.file(ncxPath)?.async("text");
      if (ncxContent) {
        return await parseNcxToc(ncxContent);
      }
    }
  }

  return toc;
}

async function parseNavToc(navContent: string): Promise<TocItem[]> {
  const toc: TocItem[] = [];

  // Simple regex-based parsing for nav document
  const tocMatch = navContent.match(
    /<nav[^>]*epub:type="toc"[^>]*>([\s\S]*?)<\/nav>/i
  );
  if (!tocMatch) return toc;

  const linkRegex = /<a[^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>/gi;
  let match;

  while ((match = linkRegex.exec(tocMatch[1])) !== null) {
    toc.push({
      label: match[2].trim(),
      href: match[1],
    });
  }

  return toc;
}

async function parseNcxToc(ncxContent: string): Promise<TocItem[]> {
  const ncx = await parseStringPromise(ncxContent);
  const navMap = ncx.ncx?.navMap?.[0]?.navPoint;

  if (!navMap) return [];

  return parseNavPoints(navMap);
}

function parseNavPoints(
  navPoints: Array<{
    navLabel?: Array<{ text?: string[] }>;
    content?: Array<{ $?: { src?: string } }>;
    navPoint?: unknown[];
  }>
): TocItem[] {
  return navPoints.map((point) => {
    const item: TocItem = {
      label: point.navLabel?.[0]?.text?.[0] || "Untitled",
      href: point.content?.[0]?.$?.src || "",
    };

    if (point.navPoint && Array.isArray(point.navPoint)) {
      item.children = parseNavPoints(
        point.navPoint as Array<{
          navLabel?: Array<{ text?: string[] }>;
          content?: Array<{ $?: { src?: string } }>;
          navPoint?: unknown[];
        }>
      );
    }

    return item;
  });
}

async function getChapterContent(
  epub: ParsedEpub,
  index: number
): Promise<{ title: string; content: string }> {
  if (index < 0 || index >= epub.spine.length) {
    throw new Error(
      `Chapter index ${index + 1} out of range. Book has ${epub.spine.length} chapters.`
    );
  }

  const spineItem = epub.spine[index];
  const manifestItem = epub.manifest.get(spineItem.idref);

  if (!manifestItem) {
    throw new Error(`Could not find manifest item for spine entry: ${spineItem.idref}`);
  }

  const fullPath =
    epub.contentBasePath === "."
      ? manifestItem.href
      : `${epub.contentBasePath}/${manifestItem.href}`;

  const content = await epub.zip.file(fullPath)?.async("text");
  if (!content) {
    throw new Error(`Could not read content file: ${fullPath}`);
  }

  // Extract title: search TOC tree for matching href, fallback to content extraction
  const titleMatch = content.match(/<title>([^<]*)<\/title>/i);
  const h1Match = content.match(/<h1[^>]*>([^<]*)<\/h1>/i);
  const tocItem = findTocItemByHref(epub.toc, manifestItem.href);
  const title =
    tocItem?.label ||
    h1Match?.[1] ||
    titleMatch?.[1] ||
    `Chapter ${index + 1}`;

  // Convert HTML to Markdown
  const markdown = htmlToMarkdown(content);

  return { title, content: markdown };
}

function htmlToMarkdown(html: string): string {
  // Extract body content if present
  const bodyMatch = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
  const content = bodyMatch ? bodyMatch[1] : html;

  // Convert to markdown
  let markdown = turndown.turndown(content);

  // Clean up excessive whitespace
  markdown = markdown.replace(/\n{3,}/g, "\n\n");
  markdown = markdown.trim();

  return markdown;
}

async function searchContent(
  epub: ParsedEpub,
  query: string
): Promise<Array<{ chapter: number; title: string; matches: string[] }>> {
  const results: Array<{ chapter: number; title: string; matches: string[] }> =
    [];
  const searchRegex = new RegExp(`.{0,50}${escapeRegex(query)}.{0,50}`, "gi");

  for (let i = 0; i < epub.spine.length; i++) {
    const { title, content } = await getChapterContent(epub, i);
    const matches = content.match(searchRegex);

    if (matches && matches.length > 0) {
      results.push({
        chapter: i + 1,
        title,
        matches: matches.slice(0, 5).map((m) => `...${m.trim()}...`),
      });
    }
  }

  return results;
}

function escapeRegex(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Build a map from href (normalized, without fragment) to spine index (1-based).
 */
function buildHrefToSpineMap(epub: ParsedEpub): Map<string, number> {
  const hrefToSpine = new Map<string, number>();

  epub.spine.forEach((spineItem, index) => {
    const manifestItem = epub.manifest.get(spineItem.idref);
    if (manifestItem) {
      // Normalize href: remove fragment and leading path components that might differ
      const href = manifestItem.href.split("#")[0];
      hrefToSpine.set(href, index + 1); // 1-based for user display
    }
  });

  return hrefToSpine;
}

/**
 * Recursively search TOC tree for an item matching the given href.
 */
function findTocItemByHref(toc: TocItem[], href: string): TocItem | undefined {
  const normalizedHref = href.split("#")[0];

  for (const item of toc) {
    const itemHref = item.href.split("#")[0];
    if (itemHref === normalizedHref) {
      return item;
    }
    if (item.children) {
      const found = findTocItemByHref(item.children, href);
      if (found) return found;
    }
  }
  return undefined;
}

function formatToc(toc: TocItem[], hrefToSpine: Map<string, number>, indent = 0): string {
  let output = "";
  toc.forEach((item, index) => {
    const prefix = "  ".repeat(indent);
    const itemHref = item.href.split("#")[0];
    const spineIndex = hrefToSpine.get(itemHref);
    const chapterRef = spineIndex ? ` [ch: ${spineIndex}]` : "";
    output += `${prefix}${indent === 0 ? index + 1 + "." : "-"} ${item.label}${chapterRef}\n`;
    if (item.children) {
      output += formatToc(item.children, hrefToSpine, indent + 1);
    }
  });
  return output;
}

// CLI Commands
program
  .name("epub-reader")
  .description("CLI tool for reading EPUB files and extracting content as Markdown")
  .version("1.0.0");

program
  .command("metadata")
  .description("Display EPUB metadata (title, author, etc.)")
  .argument("<file>", "Path to EPUB file")
  .action(async (file: string) => {
    try {
      const epub = await loadEpub(file);
      const m = epub.metadata;

      console.log("# EPUB Metadata\n");
      if (m.title) console.log(`**Title:** ${m.title}`);
      if (m.author) console.log(`**Author:** ${m.author}`);
      if (m.publisher) console.log(`**Publisher:** ${m.publisher}`);
      if (m.date) console.log(`**Date:** ${m.date}`);
      if (m.language) console.log(`**Language:** ${m.language}`);
      if (m.identifier) console.log(`**Identifier:** ${m.identifier}`);
      if (m.subject && m.subject.length > 0) {
        console.log(`**Subjects:** ${m.subject.join(", ")}`);
      }
      if (m.description) {
        console.log(`\n## Description\n\n${m.description}`);
      }
      console.log(`\n**Total Chapters:** ${epub.spine.length}`);
    } catch (error) {
      console.error(
        `Error: ${error instanceof Error ? error.message : String(error)}`
      );
      process.exit(1);
    }
  });

program
  .command("toc")
  .description("Display table of contents")
  .argument("<file>", "Path to EPUB file")
  .action(async (file: string) => {
    try {
      const epub = await loadEpub(file);
      const hrefToSpine = buildHrefToSpineMap(epub);

      console.log("# Table of Contents\n");

      if (epub.toc.length > 0) {
        console.log(formatToc(epub.toc, hrefToSpine));
      } else {
        // Fallback to spine-based listing
        console.log("(No structured TOC found, listing spine items)\n");
        for (let i = 0; i < epub.spine.length; i++) {
          const item = epub.manifest.get(epub.spine[i].idref);
          console.log(`${i + 1}. ${item?.href || `Chapter ${i + 1}`}`);
        }
      }
    } catch (error) {
      console.error(
        `Error: ${error instanceof Error ? error.message : String(error)}`
      );
      process.exit(1);
    }
  });

program
  .command("chapter")
  .description("Read a specific chapter (1-indexed)")
  .argument("<file>", "Path to EPUB file")
  .argument("<number>", "Chapter number (starting from 1)")
  .action(async (file: string, number: string) => {
    try {
      const chapterNum = parseInt(number, 10);
      if (isNaN(chapterNum) || chapterNum < 1) {
        throw new Error("Chapter number must be a positive integer");
      }

      const epub = await loadEpub(file);
      const { title, content } = await getChapterContent(epub, chapterNum - 1);

      console.log(`# ${title}\n`);
      console.log(content);
    } catch (error) {
      console.error(
        `Error: ${error instanceof Error ? error.message : String(error)}`
      );
      process.exit(1);
    }
  });

program
  .command("full")
  .description("Extract entire book as Markdown")
  .argument("<file>", "Path to EPUB file")
  .action(async (file: string) => {
    try {
      const epub = await loadEpub(file);
      const m = epub.metadata;

      // Print metadata header
      console.log(`# ${m.title || "Untitled"}\n`);
      if (m.author) console.log(`*By ${m.author}*\n`);
      console.log("---\n");

      // Print each chapter
      for (let i = 0; i < epub.spine.length; i++) {
        const { title, content } = await getChapterContent(epub, i);
        console.log(`## ${title}\n`);
        console.log(content);
        console.log("\n---\n");
      }
    } catch (error) {
      console.error(
        `Error: ${error instanceof Error ? error.message : String(error)}`
      );
      process.exit(1);
    }
  });

program
  .command("search")
  .description("Search for text in the book")
  .argument("<file>", "Path to EPUB file")
  .argument("<query>", "Text to search for")
  .action(async (file: string, query: string) => {
    try {
      const epub = await loadEpub(file);
      const results = await searchContent(epub, query);

      if (results.length === 0) {
        console.log(`No matches found for "${query}"`);
        return;
      }

      console.log(`# Search Results for "${query}"\n`);
      console.log(`Found matches in ${results.length} chapter(s):\n`);

      for (const result of results) {
        console.log(`## Chapter ${result.chapter}: ${result.title}\n`);
        for (const match of result.matches) {
          console.log(`- ${match}`);
        }
        console.log();
      }
    } catch (error) {
      console.error(
        `Error: ${error instanceof Error ? error.message : String(error)}`
      );
      process.exit(1);
    }
  });

program.parse();
