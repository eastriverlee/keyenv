import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const repository = join(import.meta.dirname, '..', '..');
const content = join(import.meta.dirname, '..', 'content', 'docs');
const assets = join(import.meta.dirname, '..', 'public');
const siteStatic = join(repository, 'site', 'static');

const slugOf = (title: string) =>
	title
		.replace(/`/g, '')
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-|-$/g, '');

const asMdx = (markdown: string) =>
	markdown
		.replace(/^### /gm, '## ')
		.replace(/<(https?:\/\/[^>\s]+)>/g, '[$1]($1)');

const frontmatter = (title: string, description?: string) =>
	['---', `title: ${JSON.stringify(title)}`, description ? `description: ${JSON.stringify(description)}` : '', '---', '']
		.filter((line) => line !== '')
		.join('\n') + '\n';

const readme = readFileSync(join(repository, 'README.md'), 'utf8');
const body = readme.slice(readme.indexOf('\n## ') + 1);

rmSync(content, { recursive: true, force: true });
mkdirSync(content, { recursive: true });

const pages: string[] = [];
for (const [index, chunk] of body.split(/^(?=## )/m).entries()) {
	const [heading, ...rest] = chunk.split('\n');
	const title = heading.replace(/^## /, '').replace(/`/g, '');
	const slug = index === 0 ? 'index' : slugOf(title);
	const description =
		index === 0
			? 'A cross-platform .env alternative for the LLM era: secrets in your keyring, their names in your repo, spent one command at a time, never printed.'
			: undefined;
	writeFileSync(join(content, `${slug}.mdx`), frontmatter(title, description) + asMdx(rest.join('\n')).trim() + '\n');
	pages.push(slug);
}

const skill = readFileSync(join(repository, 'plugins', 'monkeys', 'skills', 'monkeys', 'SKILL.md'), 'utf8');
const skillBody = skill.replace(/^---[\s\S]*?---\n/, '');
writeFileSync(
	join(content, 'skill.mdx'),
	frontmatter('The skill', 'The file a coding agent loads, verbatim.') +
		'This is `plugins/monkeys/skills/monkeys/SKILL.md`, the file a coding agent reads before it runs anything. Copy it as is: [monk3ys.dev/skill](https://monk3ys.dev/skill).\n\n' +
		asMdx(skillBody).trim() +
		'\n'
);
pages.push('skill');

writeFileSync(join(content, 'meta.json'), JSON.stringify({ title: 'monkeys', pages }, null, 2) + '\n');

for (const name of ['favicon.svg', 'favicon.png']) cpSync(join(siteStatic, name), join(assets, name));
cpSync(join(siteStatic, 'fonts'), join(assets, 'fonts'), { recursive: true });

console.log(`wrote ${pages.length} pages: ${pages.join(', ')}`);
