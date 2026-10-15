require('esbuild').context({
  ...require('./esbuild.shared'), sourcemap: true,
  define: { ...require('./esbuild.shared').define, 'process.env.NODE_ENV': '"development"' }
}).then(context => context.watch()).catch(() => process.exit(1))
