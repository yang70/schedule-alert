const esbuild = require('esbuild')

esbuild.context({
  entryPoints: ['app/javascript/application.js'],
  bundle: true,
  sourcemap: true,
  format: 'esm',
  outdir: 'app/assets/builds',
  publicPath: '/assets',
  alias: {
    'vue': 'vue/dist/vue.esm-bundler.js'
  },
  define: {
    '__VUE_OPTIONS_API__': 'true',
    '__VUE_PROD_DEVTOOLS__': 'false',
    '__VUE_PROD_HYDRATION_MISMATCH_DETAILS__': 'false'
  }
}).then(context => {
  context.watch()
  console.log('Watching for changes...')
}).catch(() => process.exit(1))
