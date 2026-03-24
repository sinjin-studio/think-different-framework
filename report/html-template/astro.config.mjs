import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  vite: {
    plugins: [tailwindcss()],
    build: {
      // Inline all JS for single-file output
      assetsInlineLimit: 100000,
    },
  },
  build: {
    // Inline all stylesheets for single-file output
    inlineStylesheets: 'always',
  },
});
