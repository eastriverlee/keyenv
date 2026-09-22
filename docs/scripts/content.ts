import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { docsOrigin, docsRoute } from '../app/lib/shared';

const repository = join(import.meta.dirname, '..', '..');
const content = join(import.meta.dirname, '..', 'content', 'docs');
const assets = join(import.meta.dirname, '..', 'public');
const siteStatic = join(repository, 'site', 'static');

const installURL =
	'https://raw.githubusercontent.com/eastriverlee/monkeys/main/plugins/monkeys/skills/monkeys/scripts/install.sh';
const skillURL =
	'https://raw.githubusercontent.com/eastriverlee/monkeys/main/plugins/monkeys/skills/monkeys/SKILL.md';

function redirectsFor(target: string): string[] {
	if (target === 'site') {
		return [
			`/install ${installURL} 302`,
			`/skill ${skillURL} 302`,
			`/poo ${docsOrigin}${docsRoute}/commands/poo/ 302`,
			`${docsRoute}/* ${docsOrigin}${docsRoute}/:splat 301`,
		];
	}
	if (target === 'docs') return [`/ ${docsRoute} 302`, `/install ${installURL} 302`];
	throw new Error(`DEPLOY_TARGET is ${target}, and it has to be site or docs`);
}

const description =
	'.env you can hand to an LLM, or git add: secrets in your vault, keys in your repo, used one command at a time, never printed.';

/** A title whose own slug would read badly as a path. */
const slugFor: Record<string, string> = { 'Q&A': 'questions' };

const slugOf = (title: string) =>
	slugFor[title] ??
	title
		.toLowerCase()
		.replace(/^\./, 'dot-')
		.replace(/\*/g, 'any')
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-|-$/g, '');

const cleanTitle = (heading: string) => heading.replace(/^#+ /, '').replace(/`/g, '');

/** What someone types into a search engine, where a page's own name is shorter than that. */
/** Every page opens on one line saying what it is; these are the ones no body supplies. */
const groupDescriptions: Record<string, string> = {
	'how-it-works':
		'Where monkeys keeps a secret, how a command is handed one, how anything printed back is redacted, and what a .monsecrets bundle is made of.',
	questions: 'What people ask before moving a project onto it.',
	caveats: 'Where the boundary is, and what redaction does not catch.',
	plugin: 'What the plugin adds to the binary, and how to install it in each client.',
	install: 'Getting the binary onto macOS or Linux.',
	'commands/index': 'Every command on one page, and the @profile each one takes.',
	'concepts/index': 'What each concept means.',
};

/** What the two columns of a group's index table are called. */
const indexHeadings: Record<string, [string, string]> = {
	commands: ['command', 'what it does'],
	concepts: ['concept', 'what it means'],
};

const searchTitles: Record<string, string> = {
	'concepts/dot-monkeys': '.monkeys file',
	'concepts/any-monsecrets': '.monsecrets file',
	questions: 'FAQ',
};

/** The anchor GitHub gives a heading, so one link works in the file and on the site. */
const githubAnchor = (title: string) =>
	title
		.toLowerCase()
		.replace(/[^a-z0-9 _-]/g, '')
		.trim()
		.replace(/ +/g, '-');

/** A ```tree fence becomes a fumadocs file tree; on GitHub it stays a code block. */
function asFileTree(block: string) {
	const rows = block
		.split('\n')
		.filter((line) => line.trim())
		.map((line) => {
			const connector = line.search(/[├└]── /);
			const depth = connector < 0 ? 0 : line.slice(0, connector).length / 4 + 1;
			const name = connector < 0 ? line.trim() : line.slice(connector + 4).trim();
			return { depth, name };
		});
	const render = (start: number, depth: number): [string, number] => {
		let index = start;
		let out = '';
		while (index < rows.length && rows[index].depth === depth) {
			const { name } = rows[index];
			const isFolder = name.endsWith('/');
			const pad = '\t'.repeat(depth + 1);
			index += 1;
			if (!isFolder) {
				out += `${pad}<File name="${name}" />\n`;
				continue;
			}
			const [children, next] = render(index, depth + 1);
			index = next;
			out += `${pad}<Folder name="${name.slice(0, -1)}" defaultOpen>\n${children}${pad}</Folder>\n`;
		}
		return [out, index];
	};
	const [body] = render(0, 0);
	return `<Files>\n${body}</Files>`;
}

/** A GitHub alert becomes a fumadocs callout; on GitHub it stays an alert. */
function asCallout(kind: string, block: string) {
	const types: Record<string, string> = {
		NOTE: 'info',
		TIP: 'idea',
		IMPORTANT: 'info',
		WARNING: 'warn',
		CAUTION: 'error',
	};
	const body = block
		.split('\n')
		.map((line) => line.replace(/^> ?/, ''))
		.join('\n')
		.trim();
	return `<Callout type="${types[kind]}" title="${kind}">\n${body}\n</Callout>\n`;
}

function asMdx(markdown: string, shift: number) {
	let inFence = false;
	const lines = markdown.split('\n').map((line) => {
		if (line.startsWith('```')) {
			inFence = !inFence;
			return line;
		}
		if (inFence) return line;
		const heading = /^(#{1,6}) /.exec(line);
		if (!heading) return line;
		return '#'.repeat(Math.max(2, heading[1].length - shift)) + line.slice(heading[1].length);
	});
	return lines
		.join('\n')
		.replace(/```tree\n([\s\S]*?)```/g, (_, block: string) => asFileTree(block))
		.replace(
			/```mermaid\n([\s\S]*?)```/g,
			(_, chart: string) => `<Mermaid chart={\`${chart.trim().replace(/`/g, '\\`')}\`} />`
		)
		.replace(
			/^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\n((?:>.*\n?)*)/gm,
			(_, kind: string, block: string) => asCallout(kind, block)
		)
		.replace(/<(https?:\/\/[^>\s]+)>/g, '[$1]($1)');
}

const sidebarIcons: Record<string, string> = {
	index: 'Compass',
	install: 'Download',
	quickstart: 'Rocket',
	plugin: 'Puzzle',
	concepts: 'Shapes',
	commands: 'SquareTerminal',
	'how-it-works': 'Workflow',
	questions: 'MessageCircleQuestion',
	caveats: 'TriangleAlert',
	skill: 'Bot'
};

type Frontmatter = { title: string; description?: string; icon?: string; lead?: string; searchTitle?: string };

const frontmatter = ({ title, description, icon, lead, searchTitle }: Frontmatter) =>
	[
		'---',
		`title: ${JSON.stringify(title)}`,
		...(description ? [`description: ${JSON.stringify(description)}`] : []),
		...(lead ? [`lead: ${JSON.stringify(lead)}`] : []),
		...(searchTitle ? [`searchTitle: ${JSON.stringify(searchTitle)}`] : []),
		...(icon ? [`icon: ${icon}`] : []),
		'---',
		''
	].join('\n');

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
const titles = new Map<string, string>();

type PageOptions = { description?: string; shift?: number; lead?: boolean };

/** A reference page opens with one line saying what it is; that line becomes the page's subtitle. */
function takeLead(markdown: string) {
	const end = markdown.indexOf('\n\n');
	return { lead: plainText(markdown.slice(0, end)), rest: markdown.slice(end).trim() };
}

function writePage(path: string, title: string, text: string, { description, shift = 1, lead }: PageOptions = {}) {
	mkdirSync(join(content, path, '..'), { recursive: true });
	const ownSlug = path.startsWith('concepts/') ? path.slice('concepts/'.length) : undefined;
	const linked = path === 'index';
	const page = asMdx(text, shift).trim();
	const { lead: subtitle, rest: body } = lead ? takeLead(page) : { lead: undefined, rest: page };
	const summary = description ?? subtitle ?? firstParagraph(body);
	writeFileSync(
		join(content, `${path}.mdx`),
		frontmatter({
			title,
			description: summary,
			icon: sidebarIcons[path],
			lead: subtitle,
			searchTitle: searchTitles[path],
		}) +
			(linked ? linkingConcepts(body, ownSlug) : body) +
			'\n'
	);
	written.push(path);
	titles.set(path, title);
}

/**
 * DOCS.md is one document on GitHub, where [drop](#drop) resolves; here each heading
 * is its own page, so the same anchor has to become that page's path.
 */
function linkAcrossPages() {
	const pageOf = new Map<string, string>();
	for (const path of written) {
		pageOf.set(path.split('/').pop()!, path);
		const anchor = githubAnchor(titles.get(path) ?? '');
		if (anchor && !pageOf.has(anchor)) pageOf.set(anchor, path);
	}
	for (const path of written) {
		const file = join(content, `${path}.mdx`);
		const before = readFileSync(file, 'utf8');
		const after = before.replace(/\]\(#([a-z0-9-]+)\)/g, (whole, anchor: string) => {
			const target = pageOf.get(anchor);
			if (!target || target === path) return whole;
			return `](${docsRoute}/${target === 'index' ? '' : target})`;
		});
		if (after !== before) writeFileSync(file, after);
	}
}

/** Named as well as covered by the wildcard, since a crawler that reads its own name is told plainly. */
const answerEngines = [
	'GPTBot',
	'OAI-SearchBot',
	'ChatGPT-User',
	'ClaudeBot',
	'Claude-User',
	'Claude-SearchBot',
	'PerplexityBot',
	'Perplexity-User',
	'Google-Extended',
	'Applebot-Extended',
	'meta-externalagent',
	'CCBot',
	'Bytespider',
	'cohere-ai',
];

const robots = (origin: string) =>
	['User-agent: *', 'Allow: /', '']
		.concat(answerEngines.flatMap((name) => [`User-agent: ${name}`, 'Allow: /', '']))
		.concat([`Sitemap: ${origin}/sitemap.xml`, ''])
		.join('\n');

function writeSitemap() {
	const urls = written.map((path) => `${docsOrigin}${docsRoute}${path === 'index' ? '' : '/' + path.replace(/\/index$/, '')}/`);
	const entries = urls.map((url) => `  <url><loc>${url}</loc></url>`).join('\n');
	writeFileSync(join(assets, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>\n`);
	writeFileSync(join(assets, 'robots.txt'), robots(docsOrigin));
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

/** The sidebar reads as four sections: where to start, handing it to an agent, what to look up, everything else. */
const gettingStarted: string[] = [];
const agent: string[] = [];
/** Which repository file each top-level page is generated from. */
const sources: Record<string, string> = {};
const lookup: string[] = [];
const rest: string[] = [];

const reference = readFileSync(join(repository, 'DOCS.md'), 'utf8');
const [overview, ...groups] = splitOn(reference, 1).chunks;
writePage('index', overview.title, overview.text, { description });
gettingStarted.push('index');
sources.index = 'DOCS.md';

const readme = readFileSync(join(repository, 'README.md'), 'utf8');
const readmeSections = splitOn(readme.slice(readme.indexOf('\n## ') + 1), 2).chunks;
function asSteps(text: string) {
	const { intro, chunks } = splitOn(text, 3);
	const steps = chunks.map((step) => `<Step>\n\n### ${step.title}\n${step.text}\n\n</Step>`).join('\n\n');
	return `${intro}\n<Steps>\n\n${steps}\n\n</Steps>\n`;
}

/**
 * A group with no words of its own opens on what its pages define, taken from the
 * line each page already opens with, so the summary cannot drift from the page.
 */
/** A group opens with what its own pages say they are, so the list cannot drift. */
function writeIndex(
	slug: string,
	title: string,
	intro: string,
	pages: { title: string; text: string }[],
	shift: number
) {
	const rows = pages.map((page) => {
		const body = asMdx(page.text, shift).trim();
		const lead = body.slice(0, body.indexOf('\n\n')).replace(/\n/g, ' ');
		return `| [${page.title}](/docs/${slug}/${slugOf(page.title)}) | ${lead} |`;
	});
	const [left, right] = indexHeadings[slug] ?? ['', ''];
	const table = [`| ${left} | ${right} |`, '| --- | --- |', ...rows].join('\n');
	const rest = intro.trim() ? `\n\n${asMdx(intro, shift).trim()}` : '';
	writeFileSync(
		join(content, slug, 'index.mdx'),
		frontmatter({
			title,
			description: groupDescriptions[`${slug}/index`],
			icon: sidebarIcons[`${slug}/index`]
		}) +
			table +
			rest +
			'\n'
	);
	written.push(join(slug, 'index'));
	titles.set(join(slug, 'index'), title);
}

function writeGroup(slug: string, title: string, text: string, level: number) {
	const { intro, chunks: pages } = splitOn(text, level);
	const shift = level - 1;
	mkdirSync(join(content, slug), { recursive: true });
	writeIndex(slug, title, intro, pages, shift);
	for (const page of pages)
		writePage(join(slug, slugOf(page.title)), page.title, page.text, { shift, lead: true });
	writeFileSync(
		join(content, slug, 'meta.json'),
		JSON.stringify(
			{
				title,
				...(sidebarIcons[slug] ? { icon: sidebarIcons[slug] } : {}),
				pages: pages.map((page) => slugOf(page.title))
			},
			null,
			2
		) + '\n'
	);
}

for (const section of readmeSections.filter(({ title }) => ['Install', 'Quickstart', 'Plugin'].includes(title))) {
	const slug = slugOf(section.title);
	if (section.title === 'Quickstart')
		writePage(
			slug,
			section.title,
			asSteps(section.text),
			{ description: 'Remember a secret, run with it and without it, then forget it, in four steps.' }
		);
	else writePage(slug, section.title, section.text, { description: groupDescriptions[slug] });
	(slug === 'plugin' ? agent : gettingStarted).push(slug);
	sources[slug] = 'README.md';
}

for (const group of groups) {
	const slug = slugOf(group.title);
	const { intro, chunks: pages } = splitOn(group.text, 2);
	sources[slug] = 'DOCS.md';
	if (pages.length === 0) {
		writePage(slug, group.title, intro, { description: groupDescriptions[slug] });
		(slug === 'how-it-works' ? gettingStarted : rest).push(slug);
		continue;
	}
	writeGroup(slug, group.title, group.text, 2);
	lookup.push(slug);
}

const skillFile = 'plugins/monkeys/skills/monkeys/SKILL.md';
const skill = readFileSync(join(repository, skillFile), 'utf8');
writePage(
	'skill',
	'Skill',
	skill.replace(/^---[\s\S]*?---\n/, ''),
	{
		description:
			'plugins/monkeys/skills/monkeys/SKILL.md, the file a coding agent loads, served verbatim at monk3ys.dev/skill.'
	}
);
agent.push('skill');
sources.skill = skillFile;

const sidebar = [
	'---Getting started---',
	...gettingStarted,
	'---Agent---',
	...agent,
	'---Reference---',
	...lookup,
	'---More---',
	...rest
];
linkAcrossPages();
writeFileSync(join(content, 'meta.json'), JSON.stringify({ title: 'monkeys', pages: sidebar }, null, 2) + '\n');

const listed = new Set(sidebar.filter((entry) => !entry.startsWith('---')));
const missing = [...new Set(written.map((path) => path.split('/')[0]))].filter(
	(slug) => !listed.has(slug)
);
if (missing.length) throw new Error(`not in the sidebar: ${missing.join(', ')}`);
writeFileSync(join(content, 'sources.json'), JSON.stringify(sources, null, 2) + '\n');
writeSitemap();

for (const name of ['favicon.svg', 'favicon.png']) cpSync(join(siteStatic, name), join(assets, name));
for (const name of ['monkeys.svg', 'terminal.svg']) cpSync(join(repository, name), join(assets, name));
writeFileSync(join(assets, '_redirects'), redirectsFor(process.env.DEPLOY_TARGET ?? 'docs').join('\n') + '\n');
cpSync(join(siteStatic, 'fonts'), join(assets, 'fonts'), { recursive: true });

console.log(`wrote ${[...gettingStarted, ...agent, ...lookup, ...rest].join(', ')}`);
