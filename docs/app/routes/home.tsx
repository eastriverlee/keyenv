import type { Route } from './+types/home';
import { Fragment, type ReactNode } from 'react';
import { HomeLayout } from 'fumadocs-ui/layouts/home';
import { File, Files, Folder } from 'fumadocs-ui/components/files';
import { Heading } from 'fumadocs-ui/components/heading';
import { FileText, Loader2, Search } from 'lucide-react';
import { baseOptions } from '@/lib/layout.shared';
import { docsOrigin, docsRoute } from '@/lib/shared';
import { highlightSample } from '@/lib/highlight';
import { agentTabs, installTabs, samples } from '@/lib/landing-samples';
import { CodeSample, CodeSampleTabs } from '@/components/code-sample';

const title = 'monkeys: .env you can hand to an LLM, or git add';
const description =
  '.env you can hand to an LLM, or git add. Secrets in your vault, keys in your repo, used one command at a time, never printed.';
const siteURL = 'https://monk3ys.dev/';
const imageURL = 'https://monk3ys.dev/og.png';
const docsURL = docsOrigin + docsRoute;

const structuredData = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'monkeys',
  url: siteURL,
  description:
    '.env you can hand to an LLM, or git add: secrets in your vault, keys in your repo, used one command at a time, never printed.',
  applicationCategory: 'DeveloperApplication',
  operatingSystem: 'macOS, Linux',
  license: 'https://github.com/eastriverlee/monkeys/blob/main/LICENSE',
  downloadUrl: 'https://github.com/eastriverlee/monkeys/releases',
  sameAs: ['https://github.com/eastriverlee/monkeys'],
  offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
  author: { '@type': 'Person', name: 'eastriverlee', url: 'https://github.com/eastriverlee' },
  copyrightHolder: { '@type': 'Organization', name: '13e7 corp.' },
};

export function meta({}: Route.MetaArgs) {
  return [
    { title },
    { name: 'description', content: description },
    { name: 'robots', content: 'index, follow' },
    { tagName: 'link', rel: 'canonical', href: siteURL },
    { property: 'og:type', content: 'website' },
    { property: 'og:site_name', content: 'monkeys' },
    { property: 'og:title', content: title },
    { property: 'og:description', content: description },
    { property: 'og:url', content: siteURL },
    { property: 'og:image', content: imageURL },
    { property: 'og:image:width', content: '1200' },
    { property: 'og:image:height', content: '630' },
    { name: 'twitter:card', content: 'summary_large_image' },
    { name: 'twitter:title', content: title },
    { name: 'twitter:description', content: description },
    { name: 'twitter:image', content: imageURL },
    { 'script:ld+json': structuredData },
  ];
}

async function highlightedTabs(tabs: { label: string; code: string }[]) {
  return Promise.all(tabs.map(async (tab) => ({ label: tab.label, ...(await highlightSample(tab)) })));
}

export async function loader() {
  const entries = await Promise.all(
    Object.entries(samples).map(async ([name, sample]) => [name, await highlightSample(sample)] as const),
  );
  return {
    samples: Object.fromEntries(entries),
    installTabs: await highlightedTabs(installTabs),
    agentTabs: await highlightedTabs(agentTabs),
  };
}

function anchor(heading: string): string {
  return heading.toLowerCase().replace(/[^a-z0-9]+/g, '-');
}

function Section({ heading, children }: { heading: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-4">
      <Heading as="h2" id={anchor(heading)} className="text-2xl font-bold tracking-tight">
        {heading}
      </Heading>
      {children}
    </section>
  );
}

function Prose({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <p className={`max-w-prose ${className}`}>{children}</p>;
}

function AgentStep({ icon, children, className }: { icon: ReactNode; children: ReactNode; className?: string }) {
  return (
    <div className="text-fd-muted-foreground flex min-h-4 items-center gap-2 text-sm">
      <span aria-hidden="true" className="size-4 shrink-0 [&_svg]:size-4">
        {icon}
      </span>
      <span className={className}>{children}</span>
    </div>
  );
}

function AgentSeparator({ children }: { children: ReactNode }) {
  return (
    <div className="text-fd-muted-foreground before:bg-fd-border after:bg-fd-border flex items-center gap-2 text-sm before:h-px before:flex-1 after:h-px after:flex-1">
      {children}
    </div>
  );
}

function Hero() {
  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-4xl leading-[1.08] font-semibold tracking-tight text-balance italic sm:text-5xl">
        LLMs read <code className="text-fd-primary bg-transparent p-0">.env</code>;
        <span className="block">not anymore.</span>
      </h1>
      <Prose>
        For LLMs, <code>cat .env</code> is just too tempting, and once it's in the transcript, it's there for good.
      </Prose>
      <div className="flex max-w-prose flex-col gap-2">
        <AgentStep icon={<Search />}>Explored 4 files</AgentStep>
        <AgentSeparator>Thought for 42s</AgentSeparator>
        <AgentStep icon={<FileText />}>Opened .env</AgentStep>
        <AgentStep icon={<Loader2 className="animate-spin" />} className="shimmer">
          Reading .env
        </AgentStep>
      </div>
      <Prose>The usual ways to live with that:</Prose>
      <ol className="max-w-prose list-inside list-decimal">
        <li>Ignore it.</li>
        <li>Trust the provider.</li>
        <li>Rotate the key after it leaks.</li>
      </ol>
      <Prose>
        Skill issue? There was never a safe way to share a secret, so it went in a file. Being careful never fixed
        C's memory bugs. Rust did.
      </Prose>
      <Prose>
        Keys stay in a file you commit. Secrets stay in your vault and reach one command at a time. Even that command
        cannot print one.
      </Prose>
    </section>
  );
}

function FileTrees() {
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      <div className="flex flex-col gap-2">
        <p className="text-fd-muted-foreground text-sm">
          with <code>.env</code>
        </p>
        <Files className="my-0 flex-1">
          <Folder name="foo" defaultOpen>
            <File name=".env" />
            <File name=".env.example" />
            <File name=".gitignore" />
            <File name="hello.sh" />
          </Folder>
        </Files>
      </div>
      <div className="flex flex-col gap-2">
        <p className="text-fd-muted-foreground text-sm">
          with <code>monkeys</code>
        </p>
        <Files className="my-0 flex-1">
          <Folder name="foo" defaultOpen>
            <File name=".monkeys" />
            <File name="hello.sh" />
          </Folder>
        </Files>
      </div>
    </div>
  );
}

function FooterLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a href={href} className="underline underline-offset-4">
      {children}
    </a>
  );
}

function Footer() {
  const items = [
    <FooterLink href={docsURL}>Docs</FooterLink>,
    <FooterLink href="https://github.com/eastriverlee/monkeys">GitHub</FooterLink>,
    'MIT',
    'macOS and Linux',
    '© 2026 13e7 corp.',
    <FooterLink href="https://github.com/sponsors/onethreeeseven">Sponsor</FooterLink>,
  ];
  return (
    <footer className="text-fd-muted-foreground flex flex-wrap items-center gap-x-2 text-sm">
      {items.map((item, index) => (
        <Fragment key={index}>
          {index > 0 && <span>·</span>}
          {item}
        </Fragment>
      ))}
    </footer>
  );
}

export default function Home({ loaderData }: Route.ComponentProps) {
  const { samples: code } = loaderData;
  const layout = baseOptions();
  return (
    <HomeLayout {...layout} nav={{ ...layout.nav, url: '/' }} links={[{ text: 'Docs', url: docsURL, external: false }]}>
      <main className="landing mx-auto flex w-full max-w-2xl flex-col gap-16 px-5 py-10">
        <div className="flex flex-col items-center gap-3">
          <img src="/monkeys.svg" alt="" className="h-36 w-72 object-cover sm:h-48 sm:w-96" />
          <p className="text-fd-muted-foreground text-center text-balance">
            <code>.env</code> you can hand to an LLM, or <code>git add</code>.
          </p>
        </div>

        <Hero />

        <Section heading="Nothing to read">
          <Prose>
            The secret is not in the repository to begin with. Four files become one, and it is the one you commit:
          </Prose>
          <FileTrees />
          <CodeSample sample={code.projectFile} />
          <Prose>
            That file holds the names of the keys the project needs, never their values, which is what a{' '}
            <code>.env.example</code> was for. The secrets sit in your operating system's vault and reach one command
            at a time. Open the file and there is no line with a secret on it, so an agent that reads everything reads
            nothing.
          </Prose>
        </Section>

        <Section heading="Install">
          <Prose>
            One binary, no runtime. The script picks the build for your machine, checks the published checksum, and
            puts it in <code>~/.local/bin</code>; Homebrew upgrades it along with everything else.
          </Prose>
          <CodeSampleTabs tabs={loaderData.installTabs} />
        </Section>

        <Section heading="Plugin">
          <Prose>
            The plugin adds the skill, which makes an agent reach for <code>monkeys</code> instead of asking you to
            paste a secret. A key you have not remembered comes back as a message saying what to ask for.
          </Prose>
          <Prose>
            The skill is an interface, not a guard. What keeps a secret out of a transcript is that the repository
            never held it; the skill only means an agent knows where to ask for it instead of asking you.
          </Prose>
          <CodeSampleTabs tabs={loaderData.agentTabs} />
          <Prose className="text-fd-muted-foreground text-sm">
            The package follows the{' '}
            <a href="https://agent-plugins.org" className="underline underline-offset-4">
              Agent Plugins
            </a>{' '}
            layout around an{' '}
            <a href="https://agentskills.io" className="underline underline-offset-4">
              Agent Skills
            </a>{' '}
            skill, and <code>.agents/skills</code> is the directory its clients share.
          </Prose>
        </Section>

        <img
          src="/terminal.svg"
          alt="monkeys remembering a secret, running a command with it, forgetting it, and then refusing the same command"
          className="w-full rounded-xl"
        />

        <Section heading="Remember a secret once">
          <Prose>
            Type <code>sesame</code> at the prompt. It goes into your vault, the keychain on macOS and the Secret
            Service on Linux, and nothing you type lands in your shell history.
          </Prose>
          <CodeSample sample={code.remember} />
        </Section>

        <Section heading="Use it in one command">
          <Prose>
            Name the keys the command reads, then the command, written the way you always write it.{' '}
            <code>run</code> puts the secret in that one process and becomes it.
          </Prose>
          <CodeSample sample={code.use} />
          <Prose>
            The right word reached the command, and what it printed came back with the secret taken out. The single
            quotes matter: the shell <code>run</code> starts is the one with the secret, so it has to be the one that
            expands <code>$SUPER_SECRET</code>.
          </Prose>
          <Prose>Without monkeys the door stays shut:</Prose>
          <CodeSample sample={code.without} />
          <Prose>Take the word away and try the door again:</Prose>
          <CodeSample sample={code.again} />
          <Prose>
            Nothing ran at all. A missing secret stops <code>run</code> before the command starts, and the message says
            what to do, which is what an agent passes on.
          </Prose>
        </Section>

        <Section heading="Let the project list the keys it needs">
          <Prose>
            A <code>.monkeys</code> file names its namespace on the first line and lists the keys under a profile.
            Commit it. In that directory <code>run</code> takes only the command. A value that was never secret sits in
            the same file as <code>KEY=value</code>. <code>remember</code> keeps that list: a key it does not name is
            added, a checkout with no file gets one, and <code>drop</code> takes a key back out.
          </Prose>
          <div className="grid gap-3 sm:grid-cols-[minmax(0,11rem)_minmax(0,1fr)]">
            <Files className="my-0">
              <Folder name="foo" defaultOpen>
                <File name=".monkeys" />
                <File name="hello.sh" />
              </Folder>
            </Files>
            <div className="flex min-w-0 flex-col gap-3">
              <CodeSample sample={code.projectFile} />
              <CodeSample sample={code.helloScript} />
            </div>
          </div>
          <CodeSample sample={code.runInProject} />
          <Prose>
            A profile line can name several profiles, and a file can hold several blocks; a profile's keys are those
            of every block that lists it. The first profile is the default, and a prefix that fits one of them is
            enough, the way a short git hash is.
          </Prose>
          <CodeSample sample={code.profilesFile} />
          <CodeSample sample={code.runProduction} />
          <Prose>
            A secret missing in one profile stops that profile alone, and only when it is used.{' '}
            <code>monkeys fill @production --with @test</code> gives the second profile what the first has and it
            lacks. <code>doctor</code> reads the whole file:
          </Prose>
          <CodeSample sample={code.doctor} />
          <Prose>
            Frameworks read the environment, so <code>monkeys run bun run dev</code> is enough for SvelteKit, Vite or
            Next. When a tool wants the file itself, <code>poo</code> writes one carrying the same keys with nothing
            after them, which sets nothing and shadows nothing.
          </Prose>
          <CodeSample sample={code.poo} />
          <CodeSample sample={code.pooResult} />
        </Section>

        <Section heading="Hand the profile to a teammate">
          <Prose>
            <code>pack</code> writes <code>/tmp/a.monsecrets</code>, outside the repository: every profile the file
            declares, or the ones <code>--only @test</code> names, sealed. It draws the passphrase itself and puts it
            on your clipboard, never on your screen. Send the file however you like, and the passphrase another way.
          </Prose>
          <CodeSample sample={code.pack} />
          <Prose>
            On the other machine, <code>unpack</code> asks for the passphrase and puts the secrets in their vault. It
            writes <code>.monkeys</code> at the root of the checkout, then deletes the bundle. That is the only way a
            secret leaves the vault.
          </Prose>
          <CodeSample sample={code.unpack} />
        </Section>

        <Footer />
      </main>
    </HomeLayout>
  );
}
