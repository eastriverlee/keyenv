import type { Sample } from './highlight';

export const installTabs = [
  { label: 'curl', code: 'curl -fsSL https://monk3ys.dev/install | sh' },
  { label: 'Homebrew', code: 'brew install eastriverlee/tap/monkeys' },
  { label: 'From source', code: 'git clone https://github.com/eastriverlee/monkeys\ncd monkeys\nmake install' },
];

export const agentTabs = [
  {
    label: 'Claude Code',
    code: 'claude plugin marketplace add eastriverlee/monkeys\nclaude plugin install monkeys@eastriverlee',
  },
  {
    label: 'Codex',
    code: 'codex plugin marketplace add eastriverlee/monkeys\ncodex plugin add monkeys@eastriverlee',
  },
  {
    label: 'Other agents',
    code: 'mkdir -p .agents/skills/monkeys\ncurl -fsSL https://monk3ys.dev/skill -o .agents/skills/monkeys/SKILL.md',
  },
];

const openDoor = `test "$SUPER_SECRET" = sesame && echo opened || echo closed`;

export const samples = {
  remember: {
    code: 'monkeys remember SUPER_SECRET',
    output: `secret:
remembered SUPER_SECRET
give it to a command with:
  monkeys run SUPER_SECRET <command>`,
  },
  use: {
    code: `monkeys run SUPER_SECRET sh -c '
  ${openDoor}
  echo "the word was $SUPER_SECRET"
'`,
    output: `opened
the word was [redacted SUPER_SECRET]`,
  },
  without: { code: `sh -c '${openDoor}'`, output: 'closed' },
  again: {
    code: `monkeys forget SUPER_SECRET
monkeys run SUPER_SECRET sh -c '
  ${openDoor}
'`,
    output: `forgot SUPER_SECRET
monkeys: SUPER_SECRET is not remembered yet
nothing happened. a human types the secret into:
  monkeys remember SUPER_SECRET
then try again.`,
  },
  projectFile: {
    name: '.monkeys',
    lang: 'monkeys',
    code: `+foo
@test
OPENROUTER_API_KEY`,
  },
  helloScript: {
    name: 'hello.sh',
    code: `#!/bin/sh
curl -s -o /dev/null -w "%{http_code}\\n" \\
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \\
  https://openrouter.ai/api/v1/key`,
  },
  runInProject: { code: 'monkeys run ./hello.sh', output: '200' },
  profilesFile: {
    name: '.monkeys',
    lang: 'monkeys',
    code: `+foo
@test,production
OPENROUTER_API_KEY
STRIPE_SECRET_KEY
@production
SENTRY_DSN`,
  },
  runProduction: { code: 'monkeys run @production ./deploy' },
  doctor: {
    code: 'monkeys doctor',
    output: `@test  default
  ✓ OPENROUTER_API_KEY
  ✓ STRIPE_SECRET_KEY
@production
  ✓ OPENROUTER_API_KEY
  ✗ STRIPE_SECRET_KEY
  ✗ SENTRY_DSN`,
  },
  poo: { code: 'monkeys poo --path .' },
  pooResult: {
    name: '.env',
    code: `# monkeys' poo. read https://monk3ys.dev/poo
OPENROUTER_API_KEY
PORT=3000`,
  },
  pack: { code: 'monkeys pack' },
  unpack: { code: 'monkeys unpack ~/Downloads/a.monsecrets' },
} satisfies Record<string, Sample>;

export type SampleName = keyof typeof samples;
