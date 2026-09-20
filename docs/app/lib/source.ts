import { llms, loader } from 'fumadocs-core/source';
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
});

export const docsLlms = llms(source, {
  renderPage: async (page) => `# ${page.data.title} (${page.url})

${await page.data.getText('processed')}`,
});
