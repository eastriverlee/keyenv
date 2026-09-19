import { copyFileSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const repository = join(import.meta.dirname, '..', '..');
const statics = join(import.meta.dirname, '..', 'static');

for (const picture of ['monkeys.svg', 'terminal.svg']) {
	copyFileSync(join(repository, picture), join(statics, picture));
}

const readme = readFileSync(join(repository, 'README.md'), 'utf8');
const skill = readFileSync(join(repository, 'plugins', 'monkeys', 'skills', 'monkeys', 'SKILL.md'), 'utf8');
const fullText = [
	'# monkeys',
	'',
	"> Environment variables kept in your operating system's keyring, handed to one command at a time. No command prints a stored value, and `monkeys run` redacts a value the command prints back. macOS and Linux, MIT. Source: https://github.com/eastriverlee/monkeys",
	'',
	'What follows is the README and the skill for coding agents, joined at build time.',
	'',
	'---',
	'',
	readme.replace(/<p align="center">[\s\S]*?<\/p>\s*/g, '').replace(/<h1 align="center">(.*?)<\/h1>/, '# $1'),
	'',
	'---',
	'',
	skill
].join('\n');
for (const name of ['llms.txt', 'llms-full.txt']) {
	writeFileSync(join(statics, name), fullText);
}
