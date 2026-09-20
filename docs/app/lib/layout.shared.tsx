import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { appName, gitConfig } from './shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="flex items-center gap-2 font-semibold">
          <img src="/favicon.svg" alt="" className="size-6" />
          {appName}
        </span>
      ),
    },
    links: [{ text: 'monk3ys.dev', url: 'https://monk3ys.dev' }],
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
