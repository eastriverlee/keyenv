import type { Root } from 'hast';
import { createHighlighter, type ShikiTransformer, type ThemedToken } from 'shiki';
import { monkeysGrammar } from '../../../tools/monkeys-grammar';

export type Sample = { name?: string; lang?: string; code: string; output?: string };
export type HighlightedSample = { title?: string; commands: Root; output?: Root };

type TokenStyle = Record<string, string>;

const themes = { light: 'github-light-default', dark: 'github-dark-default' };
const highlighter = createHighlighter({ themes: Object.values(themes), langs: ['bash', monkeysGrammar] });

const outputStyle = { '--shiki-light': '#6e7781', '--shiki-dark': '#8b949e' };
const profileStyle = { '--shiki-light': '#116329', '--shiki-dark': '#7ee787', 'font-weight': '600' };
const markStyles: Record<string, TokenStyle> = {
  '✓': { '--shiki-light': '#1a7f37', '--shiki-dark': '#3fb950' },
  '✗': { '--shiki-light': '#cf222e', '--shiki-dark': '#f85149' },
};

const numberedLines: ShikiTransformer = {
  pre(node) {
    node.properties['data-line-numbers'] = 'true';
  },
};

function commandStarts(lines: string[]): boolean[] {
  let isQuoteOpen = false;
  let isContinued = false;
  return lines.map((line) => {
    const starts = !isContinued && !isQuoteOpen;
    isQuoteOpen = isQuoteOpen !== ((line.match(/'/g)?.length ?? 0) % 2 === 1);
    isContinued = line.endsWith('\\');
    return starts;
  });
}

function painted(token: ThemedToken, style: TokenStyle): ThemedToken {
  return { ...token, htmlStyle: style };
}

function asOutput(token: ThemedToken): ThemedToken[] {
  const mark = Object.keys(markStyles).find((candidate) => token.content.includes(candidate));
  if (!mark) return [painted(token, outputStyle)];
  const [before, after] = token.content.split(mark, 2);
  return [
    painted({ ...token, content: before }, outputStyle),
    painted({ ...token, content: mark }, markStyles[mark]),
    painted({ ...token, content: after }, outputStyle),
  ].filter((part) => part.content.length > 0);
}

function asProfileLine(line: ThemedToken[]): ThemedToken[] {
  const content = line.map((token) => token.content).join('');
  const [profile, ...rest] = content.split(/(?=\s{2})/);
  const tail = rest.join('');
  const first = line[0];
  return [
    painted({ ...first, content: profile }, profileStyle),
    ...(tail ? [painted({ ...first, content: tail }, outputStyle)] : []),
  ];
}

function promptedLines(starts: boolean[]): ShikiTransformer {
  return {
    line(node, lineNumber) {
      if (starts[lineNumber - 1]) this.addClassToHast(node, 'command');
    },
  };
}

const outputLines: ShikiTransformer = {
  tokens: (lines) =>
    lines.map((line) => (line[0]?.content.startsWith('@') ? asProfileLine(line) : line.flatMap(asOutput))),
};

export async function highlightSample(sample: Sample): Promise<HighlightedSample> {
  const shiki = await highlighter;
  const options = { lang: sample.lang ?? 'bash', themes, defaultColor: false as const };
  if (sample.name) {
    return { title: sample.name, commands: shiki.codeToHast(sample.code, { ...options, transformers: [numberedLines] }) };
  }
  const starts = commandStarts(sample.code.split('\n'));
  const commands = shiki.codeToHast(sample.code, { ...options, transformers: [promptedLines(starts)] });
  if (sample.output === undefined) return { commands };
  const output = shiki.codeToHast(sample.output, { ...options, lang: 'text', transformers: [outputLines] });
  return { commands, output };
}
