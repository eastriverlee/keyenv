import { copyFileSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const repository = join(import.meta.dirname, '..', '..');
const statics = join(import.meta.dirname, '..', 'static');

for (const picture of ['monkeys.svg', 'terminal.svg']) {
	copyFileSync(join(repository, picture), join(statics, picture));
}

const readme = readFileSync(join(repository, 'README.md'), 'utf8');
const skill = readFileSync(join(repository, 'skills', 'monkeys', 'SKILL.md'), 'utf8');
const fullText = [
	'# monkeys, the full text',
	'',
	'Generated from README.md and skills/monkeys/SKILL.md at https://github.com/eastriverlee/monkeys. The index is at https://monk3ys.dev/llms.txt.',
	'',
	'---',
	'',
	readme.replace(/<p align="center">[\s\S]*?<\/p>\s*/g, '').replace(/<h1 align="center">(.*?)<\/h1>/, '# $1'),
	'',
	'---',
	'',
	skill
].join('\n');
writeFileSync(join(statics, 'llms-full.txt'), fullText);
