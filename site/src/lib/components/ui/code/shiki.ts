// Follows the best practices established in https://shiki.matsu.io/guide/best-performance
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript';
import { createHighlighterCore } from 'shiki/core';
import { monkeysGrammar } from './monkeys-grammar';

const bundledLanguages = {
	bash: () => import('@shikijs/langs/bash'),
	diff: () => import('@shikijs/langs/diff'),
	javascript: () => import('@shikijs/langs/javascript'),
	json: () => import('@shikijs/langs/json'),
	monkeys: () => Promise.resolve({ default: [monkeysGrammar] }),
	shellsession: () => import('@shikijs/langs/shellsession'),
	svelte: () => import('@shikijs/langs/svelte'),
	typescript: () => import('@shikijs/langs/typescript')
};

/** The languages configured for the highlighter (`text` is handled by Shiki without a bundled grammar). */
export type SupportedLanguage = keyof typeof bundledLanguages | 'text';

/** A preloaded highlighter instance. */
export const highlighter = createHighlighterCore({
	themes: [
		import('@shikijs/themes/github-light-default'),
		import('@shikijs/themes/github-dark-default')
	],
	langs: Object.entries(bundledLanguages).map(([_, lang]) => lang),
	engine: createJavaScriptRegexEngine()
});
