<script lang="ts">
	import * as Tabs from '$lib/components/ui/tabs';
	import type { SupportedLanguage } from '$lib/components/ui/code/shiki';
	import CodeFile from './code-file.svelte';

	type Tab = { label: string; code: string; lang?: SupportedLanguage; output?: string };

	let { tabs }: { tabs: Tab[] } = $props();
</script>

<Tabs.Root value={tabs[0].label} class="w-full gap-3">
	<Tabs.List>
		{#each tabs as tab (tab.label)}
			<Tabs.Trigger value={tab.label}>{tab.label}</Tabs.Trigger>
		{/each}
	</Tabs.List>
	{#each tabs as tab (tab.label)}
		<Tabs.Content value={tab.label}>
			<CodeFile code={tab.code} lang={tab.lang} output={tab.output} />
		</Tabs.Content>
	{/each}
</Tabs.Root>
