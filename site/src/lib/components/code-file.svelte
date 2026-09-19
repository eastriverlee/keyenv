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
	const shown = $derived(
		!isTranscript ? code : output === undefined ? `$ ${code}` : `$ ${code}\n${output}`
	);
	const commandLineCount = $derived(code.split('\n').length);

	const promptColor = { color: '#e94100', '--shiki-dark': '#e94100' };
	const outputColor = { color: '#6e7781', '--shiki-dark': '#8b949e' };

	function painted(token: ThemedToken, style: Record<string, string>): ThemedToken {
		return { ...token, color: style.color, htmlStyle: style };
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
				if (index === 0) return withPrompt(line);
				if (index >= commandLineCount) return line.map((token) => painted(token, outputColor));
				return line;
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
					<img src="/favicon.png" alt="" class="size-4" />
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
