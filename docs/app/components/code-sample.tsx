import type { Root } from 'hast';
import { toJsxRuntime, type Components } from 'hast-util-to-jsx-runtime';
import { Fragment } from 'react';
import { jsx, jsxs } from 'react/jsx-runtime';
import {
  CodeBlock,
  CodeBlockTab,
  CodeBlockTabs,
  CodeBlockTabsList,
  CodeBlockTabsTrigger,
  Pre,
} from 'fumadocs-ui/components/codeblock';
import { cn } from '@/lib/cn';
import type { HighlightedSample } from '@/lib/highlight';

export type HighlightedTab = HighlightedSample & { label: string };

function rendered(tree: Root, components: Partial<Components>) {
  return toJsxRuntime(tree, { Fragment, jsx, jsxs, components });
}

function Output({ tree }: { tree: Root }) {
  return rendered(tree, { pre: (props) => <Pre>{props.children}</Pre> });
}

function titleIcon(title?: string) {
  if (!title?.endsWith('.monkeys')) return undefined;
  return <img src="/favicon.svg" alt="" className="size-3.5" />;
}

export function CodeSample({ sample }: { sample: HighlightedSample }) {
  return rendered(sample.commands, {
    pre: (props) => (
      <CodeBlock
        {...props}
        title={sample.title}
        icon={titleIcon(sample.title)}
        className={cn(props.className, 'my-0')}
      >
        <Pre>{props.children}</Pre>
        {sample.output && <Output tree={sample.output} />}
      </CodeBlock>
    ),
  });
}

export function CodeSampleTabs({ tabs }: { tabs: HighlightedTab[] }) {
  return (
    <CodeBlockTabs defaultValue={tabs[0].label} className="my-0">
      <CodeBlockTabsList>
        {tabs.map((tab) => (
          <CodeBlockTabsTrigger key={tab.label} value={tab.label}>
            {tab.label}
          </CodeBlockTabsTrigger>
        ))}
      </CodeBlockTabsList>
      {tabs.map((tab) => (
        <CodeBlockTab key={tab.label} value={tab.label}>
          <CodeSample sample={tab} />
        </CodeBlockTab>
      ))}
    </CodeBlockTabs>
  );
}
