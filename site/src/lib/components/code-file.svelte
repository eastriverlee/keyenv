<script lang="ts">
	import * as Code from '$lib/components/ui/code';
	import { CopyButton } from '$lib/components/ui/copy-button';
	import type { SupportedLanguage } from '$lib/components/ui/code/shiki';
	import type { ShikiTransformer, ThemedToken } from 'shiki/core';

	type Props = {
		name?: string;
		lang?: SupportedLanguage;
		code: string;
		output?: string;
	};

	let { name, lang = 'bash', code, output }: Props = $props();

	const isTranscript = $derived(name === undefined);
	const commandLines = $derived(code.split('\n'));
	const commandLineCount = $derived(commandLines.length);
	const startsCommand = $derived.by(() => {
		let openQuote = false;
		let continued = false;
		return commandLines.map((line) => {
			const starts = !continued && !openQuote;
			openQuote = openQuote !== ((line.match(/'/g)?.length ?? 0) % 2 === 1);
			continued = line.endsWith('\\');
			return starts;
		});
	});
	const promptedCommand = $derived(
		commandLines.map((line, index) => (startsCommand[index] ? `$ ${line}` : line)).join('\n')
	);
	const shown = $derived(
		!isTranscript ? code : output === undefined ? promptedCommand : `${promptedCommand}\n${output}`
	);

	const promptColor = { color: '#e94100', '--shiki-dark': '#e94100' };
	const outputColor = { color: '#6e7781', '--shiki-dark': '#8b949e' };
	const profileColor = { color: '#116329', '--shiki-dark': '#7ee787', 'font-weight': '600' };
	const markColors: Record<string, Record<string, string>> = {
		'\u2713': { color: '#1a7f37', '--shiki-dark': '#3fb950' },
		'\u2717': { color: '#cf222e', '--shiki-dark': '#f85149' }
	};

	function painted(token: ThemedToken, style: Record<string, string>): ThemedToken {
		return { ...token, color: style.color, htmlStyle: style };
	}

	function asOutput(token: ThemedToken): ThemedToken[] {
		const mark = Object.keys(markColors).find((candidate) => token.content.includes(candidate));
		if (!mark) return [painted(token, outputColor)];
		const [before, after] = token.content.split(mark, 2);
		return [
			painted({ ...token, content: before }, outputColor),
			painted({ ...token, content: mark }, markColors[mark]),
			painted({ ...token, content: after }, outputColor)
		].filter((part) => part.content.length > 0);
	}

	function asProfileLine(line: ThemedToken[]): ThemedToken[] {
		const content = line.map((token) => token.content).join('');
		const [profile, ...rest] = content.split(/(?=\s{2})/);
		const tail = rest.join('');
		const first = line[0];
		return [
			painted({ ...first, content: profile }, profileColor),
			...(tail ? [painted({ ...first, content: tail }, outputColor)] : [])
		];
	}

	function withPrompt(line: ThemedToken[]): ThemedToken[] {
		const [first, ...rest] = line;
		if (!first?.content.startsWith('$')) return line;
		const prompt = painted({ ...first, content: '$' }, promptColor);
		const remainder = first.content.slice(1);
		return remainder ? [prompt, { ...first, content: remainder }, ...rest] : [prompt, ...rest];
	}

	const transcript: ShikiTransformer = {
		tokens: (lines) =>
			lines.map((line, index) => {
				if (index < commandLineCount) return startsCommand[index] ? withPrompt(line) : line;
				return line[0]?.content.startsWith('@') ? asProfileLine(line) : line.flatMap(asOutput);
			})
	};
	const transformers = $derived(isTranscript ? [transcript] : []);
	const isMonkeysFile = $derived(name?.endsWith('.monkeys') ?? false);
</script>

<div class="border-border overflow-hidden rounded-lg border">
	{#if name}
		<div class="border-border flex h-9 items-center border-b px-6">
			<div class="flex items-center gap-2">
				{#if isMonkeysFile}
					<img src="/favicon.svg" alt="" class="size-4" />
				{/if}
				<span class="text-sm font-medium">{name}</span>
			</div>
		</div>
	{/if}
	<Code.Root
		{lang}
		code={shown}
		hideLines={!name}
		{transformers}
		class="w-full rounded-none border-none [&_pre]:pr-14"
	>
		<CopyButton class="absolute top-2 right-2" text={code} tabindex={-1} variant="ghost" size="icon" />
	</Code.Root>
</div>
