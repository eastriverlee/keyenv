<script lang="ts">
	import { browser } from '$app/environment';
	import CodeFile from '$lib/components/code-file.svelte';
	import CommandTabs from '$lib/components/command-tabs.svelte';
	import * as Marker from '$lib/components/ui/marker';
	import SearchIcon from '@lucide/svelte/icons/search';
	import FileTextIcon from '@lucide/svelte/icons/file-text';
	import { Spinner } from '$lib/components/ui/spinner';
	import * as TreeView from '$lib/components/ui/tree-view';
	import { GitHubButton } from '$lib/components/ui/github-button';

	const repository = { owner: 'eastriverlee', repo: 'monkeys' };

	const structuredData = `<script type="application/ld+json">${JSON.stringify({"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "monkeys", "url": "https://monk3ys.dev", "description": "A cross-platform .env alternative for the LLM era: secrets in your vault, keys in your repo, spent one command at a time, never printed.", "applicationCategory": "DeveloperApplication", "operatingSystem": "macOS, Linux", "license": "https://github.com/eastriverlee/monkeys/blob/main/LICENSE", "downloadUrl": "https://github.com/eastriverlee/monkeys/releases", "sameAs": ["https://github.com/eastriverlee/monkeys"], "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "author": {"@type": "Person", "name": "eastriverlee", "url": "https://github.com/eastriverlee"}, "copyrightHolder": {"@type": "Organization", "name": "13e7 corp."}})}<\/script>`;
	const installTabs = [
		{ label: 'curl', code: 'curl -fsSL https://monk3ys.dev/install | sh' },
		{ label: 'Homebrew', code: 'brew install eastriverlee/tap/monkeys' },
		{
			label: 'From source',
			code: 'git clone https://github.com/eastriverlee/monkeys\ncd monkeys\nmake install'
		}
	];
	const storeLine = 'monkeys set OPENROUTER_API_KEY';
	const storeOutput = `Secret:
stored OPENROUTER_API_KEY
give it to a command with:
  monkeys run OPENROUTER_API_KEY <command>`;
	const agentTabs = [
		{
			label: 'Claude Code',
			code: 'claude plugin marketplace add eastriverlee/monkeys\nclaude plugin install monkeys@eastriverlee'
		},
		{
			label: 'Codex',
			code: 'codex plugin marketplace add eastriverlee/monkeys\ncodex plugin add monkeys@eastriverlee'
		},
		{
			label: 'Anywhere else',
			code: 'mkdir -p skills/monkeys\ncurl -fsSL https://monk3ys.dev/skill -o skills/monkeys/SKILL.md'
		}
	];
	const spendLine = `monkeys run OPENROUTER_API_KEY sh -c '
  curl -s -o /dev/null -w "%{http_code}\\n" \\
    -H "Authorization: Bearer ${'$'}OPENROUTER_API_KEY" \\
    https://openrouter.ai/api/v1/key
'`;
	const projectFile = `+foo
@test
OPENROUTER_API_KEY`;
	const helloScript = `#!/bin/sh
curl -s -o /dev/null -w "%{http_code}\\n" \\
  -H "Authorization: Bearer ${'$'}OPENROUTER_API_KEY" \\
  https://openrouter.ai/api/v1/key`;
	const runInProject = 'monkeys run ./hello.sh';
	const profilesFile = `+foo
@test,production
OPENROUTER_API_KEY
STRIPE_SECRET_KEY
@production
SENTRY_DSN`;
	const doctorLine = 'monkeys doctor';
	const doctorOutput = `@test  default
  ✓ OPENROUTER_API_KEY
  ✓ STRIPE_SECRET_KEY
@production
  ✓ OPENROUTER_API_KEY
  ✗ STRIPE_SECRET_KEY
  ✗ SENTRY_DSN`;
	const runStaging = 'monkeys run @production ./deploy';
	const packLine = 'monkeys pack';
	const unpackLine = 'monkeys unpack ~/Downloads/a.monsecrets';

	const stars = browser
		? fetch(`https://api.github.com/repos/${repository.owner}/${repository.repo}`)
				.then((response) => response.json())
				.then((body: { stargazers_count: number }) => body.stargazers_count)
		: undefined;
</script>

<svelte:head>
	<title>monkeys: a cross-platform .env alternative for the LLM era</title>
	<meta name="description" content="A cross-platform .env alternative for the LLM era. Secrets in your vault, keys in your repo, spent one command at a time, never printed." />
	<meta name="robots" content="index, follow" />
	<link rel="canonical" href="https://monk3ys.dev/" />
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="monkeys" />
	<meta property="og:title" content="monkeys: a cross-platform .env alternative for the LLM era" />
	<meta property="og:description" content="A cross-platform .env alternative for the LLM era. Secrets in your vault, keys in your repo, spent one command at a time, never printed." />
	<meta property="og:url" content="https://monk3ys.dev/" />
	<meta property="og:image" content="https://monk3ys.dev/og.png" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content="monkeys: a cross-platform .env alternative for the LLM era" />
	<meta name="twitter:description" content="A cross-platform .env alternative for the LLM era. Secrets in your vault, keys in your repo, spent one command at a time, never printed." />
	<meta name="twitter:image" content="https://monk3ys.dev/og.png" />
	<link rel="icon" href="/favicon.svg" type="image/svg+xml" />
	<link rel="icon" href="/favicon.png" type="image/png" sizes="any" />
	<link rel="apple-touch-icon" href="/favicon.png" />
	{@html structuredData}
</svelte:head>

<main class="mx-auto flex max-w-2xl flex-col gap-16 px-5 py-10">
	<header class="flex items-center justify-between">
		<a href="/" class="flex items-center gap-2 font-semibold">
			<img src="/favicon.svg" alt="" class="size-9" />
			monkeys
		</a>
		<nav class="flex items-center gap-4 text-sm">
			<a href="https://docs.monk3ys.dev" class="underline underline-offset-4">Docs</a>
			<GitHubButton repo={repository} {stars} size="sm" />
		</nav>
	</header>

	<img src="/monkeys.svg" alt="" class="mx-auto h-36 w-72 object-cover sm:h-48 sm:w-96" />

	<section class="flex flex-col gap-4">
		<h1 class="text-4xl leading-[1.08] font-semibold tracking-tight text-balance italic sm:text-5xl">
			LLMs read <code class="text-primary bg-transparent p-0">.env</code>;
			<span class="block">not anymore.</span>
		</h1>
		<p class="max-w-prose">
			For LLMs, <code>cat .env</code> is just too tempting, and once it's in the
			transcript, it's there for good.
		</p>
		<div class="flex max-w-prose flex-col gap-2">
			<Marker.Root>
				<Marker.Icon>
					<SearchIcon />
				</Marker.Icon>
				<Marker.Content>Explored 4 files</Marker.Content>
			</Marker.Root>
			<Marker.Root variant="separator">
				<Marker.Content>Thought for 42s</Marker.Content>
			</Marker.Root>
			<Marker.Root>
				<Marker.Icon>
					<FileTextIcon />
				</Marker.Icon>
				<Marker.Content>Opened .env</Marker.Content>
			</Marker.Root>
			<Marker.Root role="status">
				<Marker.Icon>
					<Spinner />
				</Marker.Icon>
				<Marker.Content class="shimmer">Reading .env</Marker.Content>
			</Marker.Root>
		</div>
		<p class="max-w-prose">The usual ways to live with that:</p>
		<ol class="max-w-prose list-inside list-decimal">
			<li>Ignore it.</li>
			<li>Trust the provider.</li>
			<li>Rotate the key after it leaks.</li>
		</ol>
		<p class="max-w-prose">
			Someone will call it a skill issue. It isn't. There has never been a safe way for the people
			on a project to share a secret and use it, so it went in a file. C had a memory problem too,
			and being careful didn't fix it. Rust did.
		</p>
		<p class="max-w-prose">
			<code>monkeys</code> keeps each secret in your vault and hands it to one command at a
			time. Nothing prints a stored secret, the command you hand it to included, so there is
			nothing to read.
		</p>
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Install</h2>
		<p class="max-w-prose">
			One binary, no runtime. The script picks the build for your machine, checks the published
			checksum, and puts it in <code>~/.local/bin</code>; Homebrew upgrades it along with
			everything else.
		</p>
		<CommandTabs tabs={installTabs} />
		<p class="max-w-prose">
			For a coding agent, install the skill as well. It is what makes the agent reach for
			<code>monkeys</code> on its own instead of asking you to paste a secret; a key it needs but
			you have not stored comes back as a message that says what to ask you for.
		</p>
		<CommandTabs tabs={agentTabs} />
		<p class="text-muted-foreground max-w-prose text-sm">
			The plugin follows the <a href="https://agent-plugins.org" class="underline underline-offset-4">Agent Plugins</a>
			layout, and the third tab is the one file any other agent needs, in whatever directory it
			reads skills from.
		</p>
	</section>

	<img
		src="/terminal.svg"
		alt="monkeys run refusing a missing secret, then running the command, then preview"
		class="w-full rounded-xl"
	/>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Store a secret once</h2>
		<p class="max-w-prose">
			Paste it at the prompt. It goes into your vault, the keychain on macOS and the Secret Service on Linux, and
			nothing you type lands in your shell history.
		</p>
		<CodeFile code={storeLine} output={storeOutput} />
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Spend it on one command</h2>
		<p class="max-w-prose">
			Name the keys the command reads, then the command, written the way you always write it.
			<code>run</code> puts the secret in that one process and becomes it.
		</p>
		<CodeFile code={spendLine} output="200" />
		<p class="max-w-prose">
			The secret went into the request and the status came back. Nothing else did. The single quotes
			matter: the shell <code>run</code> starts is the one that has the secret, so it has to be the
			one that expands <code>$OPENROUTER_API_KEY</code>.
		</p>
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Let the project list the keys it needs</h2>
		<p class="max-w-prose">
			A <code>.monkeys</code> file next to the code names its namespace on the first line and lists
			the keys under a profile. Commit it. In that directory, <code>run</code> takes only the
			command, and the script reads the variable the way any program does. A value that was
			never secret, <code>PORT=3000</code> and the like, sits in it as <code>KEY=value</code>.
		</p>
		<div class="grid gap-3 sm:grid-cols-[minmax(0,11rem)_minmax(0,1fr)]">
			<TreeView.Root class="rounded-lg border p-2">
				<TreeView.Folder name="foo" open>
					<TreeView.File name=".monkeys" />
					<TreeView.File name="hello.sh" />
				</TreeView.Folder>
			</TreeView.Root>
			<div class="flex min-w-0 flex-col gap-3">
				<CodeFile name=".monkeys" lang="monkeys" code={projectFile} />
				<CodeFile name="hello.sh" lang="bash" code={helloScript} />
			</div>
		</div>
		<CodeFile code={runInProject} output="200" />
		<p class="max-w-prose">
			A profile line can name several profiles, and a file can hold several blocks. A profile's
			keys are those of every block that lists it; the first profile in the file is the one
			<code>run</code> uses when none is given, and one the file does not declare is refused. A
			prefix that fits only one declared profile is enough, the way a short git hash is.
		</p>
		<CodeFile name=".monkeys" lang="monkeys" code={profilesFile} />
		<CodeFile code={runStaging} />
		<p class="max-w-prose">
			A secret missing in one profile stops that profile alone, and only when it is used.
			<code>monkeys fill @production --with @test</code> fills the second profile with what the first
			has and it lacks, and <code>doctor</code> reads the whole file:
		</p>
		<CodeFile code={doctorLine} output={doctorOutput} />
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Hand the profile to a teammate</h2>
		<p class="max-w-prose">
			<code>pack</code> asks for a passphrase and writes <code>/tmp/a.monsecrets</code>, outside the repository: every profile the file declares, or the ones <code>--only @test</code> names, with their
			keys and secrets, sealed. Send the file however you like, and the passphrase another way.
		</p>
		<CodeFile code={packLine} />
		<p class="max-w-prose">
			On the other machine, <code>unpack</code> asks for the passphrase, stores the secrets, writes
			<code>.monsecrets</code> at the root of the checkout, wherever inside it you run it, and deletes the bundle.
			That is the only way a secret leaves the vault.
		</p>
		<CodeFile code={unpackLine} />
	</section>

	<footer class="text-muted-foreground flex flex-wrap items-center gap-x-2 text-sm">
		<a href="https://docs.monk3ys.dev" class="underline underline-offset-4">Docs</a>
		<span>·</span>
		<a href="https://github.com/eastriverlee/monkeys" class="underline underline-offset-4">GitHub</a>
		<span>·</span>
		<span>MIT</span>
		<span>·</span>
		<span>macOS and Linux</span>
		<span>·</span>
		<span>© 2026 13e7 corp.</span>
		<span>·</span>
		<a href="https://github.com/sponsors/onethreeeseven" class="underline underline-offset-4">Sponsor</a>
	</footer>
</main>
