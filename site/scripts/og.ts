import { Renderer } from '@takumi-rs/core';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const statics = join(import.meta.dirname, '..', 'static');
const orange = '#e94100';
const ink = '#17181c';

const headline = (parts: { text: string; color?: string; italic?: boolean }[]) => ({
	type: 'container',
	style: { display: 'flex', flexDirection: 'row', alignItems: 'baseline' },
	children: parts.map((part) => ({
		type: 'text',
		text: part.text,
		style: {
			fontFamily: 'Cascadia Code',
			fontSize: 64,
			fontWeight: part.color ? 700 : 600,
			fontStyle: part.italic === false ? 'normal' : 'italic',
			color: part.color ?? ink,
			letterSpacing: -0.5
		}
	}))
});

const card = {
	type: 'container',
	style: {
		width: 1200,
		height: 630,
		display: 'flex',
		flexDirection: 'column',
		alignItems: 'center',
		justifyContent: 'center',
		gap: 36,
		backgroundColor: '#ffffff'
	},
	children: [
		{
			type: 'image',
			src: readFileSync(join(statics, 'monkeys.svg')),
			style: { width: 520, height: 260, objectFit: 'cover' }
		},
		headline([
			{ text: 'LLMs read ' },
			{ text: '.env', color: orange, italic: false },
			{ text: ', not anymore.' }
		]),
		{
			type: 'text',
			text: 'monk3ys.dev',
			style: { fontFamily: 'Cascadia Code', fontSize: 26, color: '#8a8d97' }
		}
	]
};

const renderer = new Renderer();
const png = await renderer.render(card, {
	width: 1200,
	height: 630,
	fonts: [
		readFileSync(join(statics, 'fonts', 'CascadiaCode.woff2')),
		readFileSync(join(statics, 'fonts', 'CascadiaCodeItalic.woff2'))
	]
});
writeFileSync(join(statics, 'og.png'), png);
console.log(`wrote og.png, ${png.length} bytes`);
