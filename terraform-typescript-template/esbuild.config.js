const esbuild = require('esbuild')

esbuild
  .build({
    entryPoints: ['src/handlers/helloWorld.ts'],
    bundle: true,
    platform: 'node',
    target: 'es2020',
    minify: true,
    outdir: 'dist',
    sourcemap: true,
  })
  .catch(() => process.exit(1))
