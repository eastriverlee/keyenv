import { llms, loader } from 'fumadocs-core/source';
import * as lucide from 'lucide-react';
import { createElement } from 'react';
import { applyMdxPreset } from 'fumadocs-mdx/config';
import { defineDocs } from 'fumadocs-mdx/macro';
import { monkeysGrammar } from '../../../tools/monkeys-grammar';
import { docsContentRoute, docsRoute } from './shared';

export const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    async: true,
    mdxOptions: applyMdxPreset({
      rehypeCodeOptions: { langs: ['bash', monkeysGrammar] },
    }),
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
});

export const source = loader({
  source: docs.toFumadocsSource(),
  baseUrl: docsRoute,
  icon(name) {
    const icon = name && (lucide as Record<string, unknown>)[name];
    if (icon) return createElement(icon as React.ComponentType);
  },
});

export const docsLlms = llms(source, {
  renderPage: async (page) => `# ${page.data.title} (${page.url})

${await page.data.getText('processed')}`,
});
