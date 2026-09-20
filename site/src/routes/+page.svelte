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

	const structuredData = `<script type="application/ld+json">${JSON.stringify({"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "monkeys", "url": "https://monk3ys.dev", "description": ".env you can hand to an LLM, or git add: secrets in your vault, keys in your repo, used one command at a time, never printed.", "applicationCategory": "DeveloperApplication", "operatingSystem": "macOS, Linux", "license": "https://github.com/eastriverlee/monkeys/blob/main/LICENSE", "downloadUrl": "https://github.com/eastriverlee/monkeys/releases", "sameAs": ["https://github.com/eastriverlee/monkeys"], "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}, "author": {"@type": "Person", "name": "eastriverlee", "url": "https://github.com/eastriverlee"}, "copyrightHolder": {"@type": "Organization", "name": "13e7 corp."}})}<\/script>`;
	const installTabs = [
		{ label: 'curl', code: 'curl -fsSL https://monk3ys.dev/install | sh' },
		{ label: 'Homebrew', code: 'brew install eastriverlee/tap/monkeys' },
		{
			label: 'From source',
			code: 'git clone https://github.com/eastriverlee/monkeys\ncd monkeys\nmake install'
		}
	];
	const storeLine = 'monkeys set SUPER_SECRET';
	const storeOutput = `Secret:
stored SUPER_SECRET
give it to a command with:
  monkeys run SUPER_SECRET <command>`;
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
			label: 'Other agents',
			code: 'mkdir -p .agents/skills/monkeys\ncurl -fsSL https://monk3ys.dev/skill -o .agents/skills/monkeys/SKILL.md'
		}
	];
	const useLine = `monkeys run SUPER_SECRET sh -c '
  test "${'$'}SUPER_SECRET" = sesame && echo opened || echo closed
  echo "the word was ${'$'}SUPER_SECRET"
'`;
	const useOutput = `opened
the word was [redacted SUPER_SECRET]`;
	const withoutLine = `sh -c 'test "${'$'}SUPER_SECRET" = sesame && echo opened || echo closed'`;
	const againLine = `monkeys forget SUPER_SECRET
monkeys run SUPER_SECRET sh -c '
  test "${'$'}SUPER_SECRET" = sesame && echo opened || echo closed
'`;
	const againOutput = `forgot SUPER_SECRET
monkeys: SUPER_SECRET is not stored yet
nothing ran. a human has to store it, then try again:
  monkeys set SUPER_SECRET`;
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
	<title>monkeys: .env you can hand to an LLM, or git add</title>
	<meta name="description" content=".env you can hand to an LLM, or git add. Secrets in your vault, keys in your repo, used one command at a time, never printed." />
	<meta name="robots" content="index, follow" />
	<link rel="canonical" href="https://monk3ys.dev/" />
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="monkeys" />
	<meta property="og:title" content="monkeys: .env you can hand to an LLM, or git add" />
	<meta property="og:description" content=".env you can hand to an LLM, or git add. Secrets in your vault, keys in your repo, used one command at a time, never printed." />
	<meta property="og:url" content="https://monk3ys.dev/" />
	<meta property="og:image" content="https://monk3ys.dev/og.png" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content="monkeys: .env you can hand to an LLM, or git add" />
	<meta name="twitter:description" content=".env you can hand to an LLM, or git add. Secrets in your vault, keys in your repo, used one command at a time, never printed." />
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

	<div class="flex flex-col items-center gap-3">
		<img src="/monkeys.svg" alt="" class="h-36 w-72 object-cover sm:h-48 sm:w-96" />
		<p class="text-muted-foreground text-center text-balance">
			<code>.env</code> you can hand to an LLM, or <code>git add</code>.
		</p>
	</div>

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
			Skill issue? There was never a safe way to share a secret, so it went in a file. Being
			careful never fixed C's memory bugs. Rust did.
		</p>
		<p class="max-w-prose">
			Keys stay in a file you commit. Secrets stay in your vault and reach one command at a time.
			Even that command cannot print one.
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
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Plugin</h2>
		<p class="max-w-prose">
			The plugin adds the skill. It makes an agent reach for <code>monkeys</code> instead of asking
			you to paste a secret, and a key you have not stored comes back as a message saying what to
			ask for.
		</p>
		<CommandTabs tabs={agentTabs} />
		<p class="text-muted-foreground max-w-prose text-sm">
			The package follows the <a href="https://agent-plugins.org" class="underline underline-offset-4">Agent Plugins</a>
			layout around an <a href="https://agentskills.io" class="underline underline-offset-4">Agent Skills</a>
			skill, and <code>.agents/skills</code> is the directory its clients share.
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
			Type <code>sesame</code> at the prompt. It goes into your vault, the keychain on macOS and the Secret
			Service on Linux, and nothing you type lands in your shell history.
		</p>
		<CodeFile code={storeLine} output={storeOutput} />
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Use it in one command</h2>
		<p class="max-w-prose">
			Name the keys the command reads, then the command, written the way you always write it.
			<code>run</code> puts the secret in that one process and becomes it.
		</p>
		<CodeFile code={useLine} output={useOutput} />
		<p class="max-w-prose">
			The right word reached the command, and what it printed came back with the secret taken out.
			The single quotes matter: the shell <code>run</code> starts is the one with the secret, so it
			has to be the one that expands <code>$SUPER_SECRET</code>.
		</p>
		<p class="max-w-prose">Without monkeys the door stays shut:</p>
		<CodeFile code={withoutLine} output="closed" />
		<p class="max-w-prose">Take the word away and try the door again:</p>
		<CodeFile code={againLine} output={againOutput} />
		<p class="max-w-prose">
			Nothing ran at all. A missing secret stops <code>run</code> before the command starts, and the
			message says what to do, which is what an agent passes on.
		</p>
	</section>

	<section class="flex flex-col gap-4">
		<h2 class="text-2xl font-bold tracking-tight">Let the project list the keys it needs</h2>
		<p class="max-w-prose">
			A <code>.monkeys</code> file names its namespace on the first line and lists the keys under a
			profile. Commit it. In that directory <code>run</code> takes only the command. A value that
			was never secret sits in the same file as <code>KEY=value</code>.
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
			A profile line can name several profiles, and a file can hold several blocks; a profile's
			keys are those of every block that lists it. The first profile is the default, and a prefix
			that fits one of them is enough, the way a short git hash is.
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
			<code>pack</code> asks for a passphrase and writes <code>/tmp/a.monsecrets</code>, outside the
			repository: every profile the file declares, or the ones <code>--only @test</code> names,
			sealed. Send the file however you like, the passphrase another way.
		</p>
		<CodeFile code={packLine} />
		<p class="max-w-prose">
			On the other machine, <code>unpack</code> asks for the passphrase, stores the secrets, writes
			<code>.monkeys</code> at the root of the checkout, and deletes the bundle. That is the only
			way a secret leaves the vault.
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
