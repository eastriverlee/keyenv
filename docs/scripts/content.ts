import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { docsOrigin, docsRoute } from '../app/lib/shared';

const repository = join(import.meta.dirname, '..', '..');
const content = join(import.meta.dirname, '..', 'content', 'docs');
const assets = join(import.meta.dirname, '..', 'public');
const siteStatic = join(repository, 'site', 'static');

const description =
	'.env you can hand to an LLM, or git add: secrets in your vault, keys in your repo, spent one command at a time, never printed.';

const slugOf = (title: string) =>
	title
		.toLowerCase()
		.replace(/^\./, 'dot-')
		.replace(/\*/g, 'any')
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-|-$/g, '');

const cleanTitle = (heading: string) => heading.replace(/^#+ /, '').replace(/`/g, '');

const asMdx = (markdown: string) =>
	markdown.replace(/^### /gm, '## ').replace(/<(https?:\/\/[^>\s]+)>/g, '[$1]($1)');

const frontmatter = (title: string, description?: string) =>
	['---', `title: ${JSON.stringify(title)}`, ...(description ? [`description: ${JSON.stringify(description)}`] : []), '---', ''].join('\n');

const conceptsRoute = `${docsRoute}/concepts`;

type Concept = { slug: string; word?: RegExp; code?: string; notAfter?: RegExp; notBefore?: RegExp };

const concepts: Concept[] = [
	{ slug: 'key', word: /\bkeys?\b/, notAfter: /API $/ },
	{ slug: 'secret', word: /\bsecrets?\b/, notBefore: /^(-tool| (Service|store|browser|daemon))/ },
	{ slug: 'value', word: /\bplain values?\b/ },
	{ slug: 'vault', word: /\bvaults?\b/ },
	{ slug: 'profile', word: /\bprofiles?\b/ },
	{ slug: 'namespace', word: /\bnamespaces?\b/ },
	{ slug: 'dot-monkeys', code: '`.monkeys`' },
	{ slug: 'any-monsecrets', word: /\bbundles?\b/ }
];

const linkSpan = /\[[^\]]*\]\([^)]*\)/g;
const codeSpan = /`[^`]*`/g;

const spansOf = (line: string, pattern: RegExp) =>
	[...line.matchAll(pattern)].map((match) => [match.index, match.index + match[0].length] as const);

function firstMention(line: string, concept: Concept) {
	const untouchable = concept.code ? spansOf(line, linkSpan) : [...spansOf(line, linkSpan), ...spansOf(line, codeSpan)];
	const pattern = concept.code
		? new RegExp(concept.code.replace(/[.*]/g, '\\$&'), 'g')
		: new RegExp(concept.word!.source, 'gi');
	for (const match of line.matchAll(pattern)) {
		const index = match.index;
		if (untouchable.some(([start, end]) => index >= start && index < end)) continue;
		if (concept.notAfter?.test(line.slice(0, index))) continue;
		if (concept.notBefore?.test(line.slice(index + match[0].length))) continue;
		return { index, length: match[0].length };
	}
}

function linkingConcepts(text: string, ownSlug?: string) {
	const pending = concepts.filter((concept) => concept.slug !== ownSlug);
	let inFence = false;
	const lines = text.split('\n').map((line) => {
		if (line.startsWith('```')) inFence = !inFence;
		if (inFence || line.startsWith('```') || /^(#|>|\|)/.test(line)) return line;
		for (const concept of [...pending]) {
			const found = firstMention(line, concept);
			if (!found) continue;
			const mention = line.slice(found.index, found.index + found.length);
			line = line.slice(0, found.index) + `[${mention}](${conceptsRoute}/${concept.slug})` + line.slice(found.index + found.length);
			pending.splice(pending.indexOf(concept), 1);
		}
		return line;
	});
	return lines.join('\n');
}

const plainText = (markdown: string) =>
	markdown
		.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
		.replace(/<(https?:\/\/[^>\s]+)>/g, '$1')
		.replace(/[`*_]/g, '')
		.replace(/\s+/g, ' ')
		.trim();

/** The first paragraph of prose on a page, cut to a length a search result shows. */
function firstParagraph(markdown: string) {
	const lines = markdown.split('\n');
	let inFence = false;
	let paragraph: string[] = [];
	for (const line of lines) {
		if (line.startsWith('```')) {
			inFence = !inFence;
			continue;
		}
		if (inFence) continue;
		const isProse = line.trim() && !/^(#|>|\||-|\d+\.|<)/.test(line);
		if (isProse) paragraph.push(line);
		else if (paragraph.length) break;
	}
	const text = plainText(paragraph.join(' ')).replace(/:$/, '.');
	if (text.length <= 160) return text;
	return text.slice(0, text.lastIndexOf(' ', 157)) + '…';
}

const written: string[] = [];

function writePage(path: string, title: string, text: string, description?: string) {
	mkdirSync(join(content, path, '..'), { recursive: true });
	const ownSlug = path.startsWith('concepts/') ? path.slice('concepts/'.length) : undefined;
	const linked = path === 'index';
	const body = asMdx(text).trim();
	const summary = description ?? firstParagraph(body);
	writeFileSync(join(content, `${path}.mdx`), frontmatter(title, summary) + (linked ? linkingConcepts(body, ownSlug) : body) + '\n');
	written.push(path);
}

function writeSitemap() {
	const urls = written.map((path) => `${docsOrigin}${docsRoute}${path === 'index' ? '' : '/' + path.replace(/\/index$/, '')}/`);
	const entries = urls.map((url) => `  <url><loc>${url}</loc></url>`).join('\n');
	writeFileSync(join(assets, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>\n`);
	writeFileSync(join(assets, 'robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${docsOrigin}/sitemap.xml\n`);
}

function splitOn(markdown: string, level: number) {
	const marker = '#'.repeat(level) + ' ';
	const parts: string[][] = [[]];
	let inFence = false;
	for (const line of markdown.split('\n')) {
		if (line.startsWith('```')) inFence = !inFence;
		if (!inFence && line.startsWith(marker)) parts.push([]);
		parts[parts.length - 1].push(line);
	}
	const [intro, ...chunks] = parts.map((lines) => lines.join('\n'));
	return {
		intro,
		chunks: chunks.map((chunk) => {
			const [heading, ...rest] = chunk.split('\n');
			return { title: cleanTitle(heading), text: rest.join('\n') };
		})
	};
}

rmSync(content, { recursive: true, force: true });
mkdirSync(content, { recursive: true });
const order: string[] = [];

const reference = readFileSync(join(repository, 'DOCS.md'), 'utf8');
const [overview, ...groups] = splitOn(reference, 1).chunks;
writePage('index', overview.title, overview.text, description);
order.push('index');

const readme = readFileSync(join(repository, 'README.md'), 'utf8');
const readmeSections = splitOn(readme.slice(readme.indexOf('\n## ') + 1), 2).chunks;
function asSteps(text: string) {
	const { intro, chunks } = splitOn(text, 3);
	const steps = chunks.map((step) => `<Step>\n\n### ${step.title}\n${step.text}\n\n</Step>`).join('\n\n');
	return `${intro}\n<Steps>\n\n${steps}\n\n</Steps>\n`;
}

for (const section of readmeSections.filter(({ title }) => title === 'Quickstart' || title === 'Install')) {
	const slug = slugOf(section.title);
	const isQuickstart = section.title === 'Quickstart';
	writePage(
		slug,
		section.title,
		isQuickstart ? asSteps(section.text) : section.text,
		isQuickstart ? 'Store a secret, run with it and without it, then forget it, in four steps.' : undefined
	);
	order.push(slug);
}

for (const group of groups) {
	const slug = slugOf(group.title);
	const { intro, chunks: pages } = splitOn(group.text, 2);
	if (pages.length === 0) {
		writePage(slug, group.title, intro);
		order.push(slug);
		continue;
	}
	mkdirSync(join(content, slug), { recursive: true });
	if (intro.trim()) writePage(join(slug, 'index'), group.title, intro);
	for (const page of pages) writePage(join(slug, slugOf(page.title)), page.title, page.text);
	writeFileSync(
		join(content, slug, 'meta.json'),
		JSON.stringify({ title: group.title, pages: pages.map((page) => slugOf(page.title)) }, null, 2) + '\n'
	);
	order.push(slug);
}

const skill = readFileSync(join(repository, 'plugins', 'monkeys', 'skills', 'monkeys', 'SKILL.md'), 'utf8');
writePage(
	'skill',
	'The skill',
	'\nThis is `plugins/monkeys/skills/monkeys/SKILL.md`, the file a coding agent reads before it runs anything. Copy it as is: [monk3ys.dev/skill](https://monk3ys.dev/skill).\n\n' +
		skill.replace(/^---[\s\S]*?---\n/, ''),
	'The file a coding agent loads, verbatim.'
);
order.push('skill');

writeFileSync(join(content, 'meta.json'), JSON.stringify({ title: 'monkeys', pages: order }, null, 2) + '\n');
writeSitemap();

for (const name of ['favicon.svg', 'favicon.png']) cpSync(join(siteStatic, name), join(assets, name));
cpSync(join(siteStatic, 'fonts'), join(assets, 'fonts'), { recursive: true });

console.log(`wrote ${order.join(', ')}`);
