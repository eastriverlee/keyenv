import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const repository = join(import.meta.dirname, '..', '..');
const content = join(import.meta.dirname, '..', 'content', 'docs');
const assets = join(import.meta.dirname, '..', 'public');
const siteStatic = join(repository, 'site', 'static');

type Section = { title: string; text: string };

const slugOf = (title: string) =>
	title
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-|-$/g, '');

const asMdx = (markdown: string) =>
	markdown.replace(/^### /gm, '## ').replace(/<(https?:\/\/[^>\s]+)>/g, '[$1]($1)');

const frontmatter = (title: string, description?: string) =>
	['---', `title: ${JSON.stringify(title)}`, ...(description ? [`description: ${JSON.stringify(description)}`] : []), '---', ''].join('\n');

function sectionsOf(file: string): Section[] {
	const markdown = readFileSync(join(repository, file), 'utf8');
	const body = markdown.slice(markdown.indexOf('\n## ') + 1);
	return body.split(/^(?=## )/m).map((chunk) => {
		const [heading, ...rest] = chunk.split('\n');
		return { title: heading.replace(/^## /, '').replace(/`/g, ''), text: rest.join('\n') };
	});
}

const readme = sectionsOf('README.md');
const reference = sectionsOf('DOCS.md');
const fromReadme = ['Quickstart', 'Install'];
const pages: { slug: string; title: string; description?: string; text: string }[] = [
	{
		slug: 'index',
		title: readme[0].title,
		description:
			'A cross-platform .env alternative for the LLM era: secrets in your keyring, their names in your repo, spent one command at a time, never printed.',
		text: readme[0].text
	},
	...readme.filter((section) => fromReadme.includes(section.title)).map((section) => ({ slug: slugOf(section.title), ...section })),
	...reference.map((section) => ({ slug: slugOf(section.title), ...section }))
];

const skill = readFileSync(join(repository, 'plugins', 'monkeys', 'skills', 'monkeys', 'SKILL.md'), 'utf8');
pages.push({
	slug: 'skill',
	title: 'The skill',
	description: 'The file a coding agent loads, verbatim.',
	text:
		'\nThis is `plugins/monkeys/skills/monkeys/SKILL.md`, the file a coding agent reads before it runs anything. Copy it as is: [monk3ys.dev/skill](https://monk3ys.dev/skill).\n\n' +
		skill.replace(/^---[\s\S]*?---\n/, '')
});

rmSync(content, { recursive: true, force: true });
mkdirSync(content, { recursive: true });
for (const page of pages) {
	writeFileSync(join(content, `${page.slug}.mdx`), frontmatter(page.title, page.description) + asMdx(page.text).trim() + '\n');
}
writeFileSync(join(content, 'meta.json'), JSON.stringify({ title: 'monkeys', pages: pages.map((page) => page.slug) }, null, 2) + '\n');

for (const name of ['favicon.svg', 'favicon.png']) cpSync(join(siteStatic, name), join(assets, name));
cpSync(join(siteStatic, 'fonts'), join(assets, 'fonts'), { recursive: true });

console.log(`wrote ${pages.length} pages: ${pages.map((page) => page.slug).join(', ')}`);
