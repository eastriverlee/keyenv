import { copyFileSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const repository = join(import.meta.dirname, '..', '..');
const statics = join(import.meta.dirname, '..', 'static');

for (const picture of ['monkeys.svg', 'terminal.svg']) {
	copyFileSync(join(repository, picture), join(statics, picture));
}

const readme = readFileSync(join(repository, 'README.md'), 'utf8');
const reference = readFileSync(join(repository, 'DOCS.md'), 'utf8');
const skill = readFileSync(join(repository, 'plugins', 'monkeys', 'skills', 'monkeys', 'SKILL.md'), 'utf8');
const fullText = [
	'# monkeys',
	'',
	"> .env you can hand to an LLM, or git add: secrets in your vault, keys in your repo, used one command at a time, never printed. `monkeys run` redacts a secret the command prints back. macOS and Linux, MIT. Source: https://github.com/eastriverlee/monkeys",
	'',
	'What follows is the README, the reference (DOCS.md) and the skill for coding agents, joined at build time.',
	'',
	'---',
	'',
	readme.replace(/<p align="center">[\s\S]*?<\/p>\s*/g, '').replace(/<h1 align="center">(.*?)<\/h1>/, '# $1'),
	'',
	'---',
	'',
	reference,
	'',
	'---',
	'',
	skill
].join('\n');
for (const name of ['llms.txt', 'llms-full.txt']) {
	writeFileSync(join(statics, name), fullText);
}
