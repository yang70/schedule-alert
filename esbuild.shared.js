const fs = require('node:fs/promises')
const path = require('node:path')
const { parse, rewriteDefault, compileTemplate } = require('@vue/compiler-sfc')

module.exports = {
  entryPoints: ['app/javascript/application.js'], bundle: true, format: 'esm',
  outdir: 'app/assets/builds', publicPath: '/assets',
  alias: { vue: 'vue/dist/vue.runtime.esm-bundler.js' },
  define: {
    __VUE_OPTIONS_API__: 'true', __VUE_PROD_DEVTOOLS__: 'false',
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false'
  },
  plugins: [{
    name: 'vue-sfc',
    setup(build) {
      build.onLoad({ filter: /\.vue$/ }, async ({ path: filename }) => {
        const source = await fs.readFile(filename, 'utf8')
        const { descriptor, errors } = parse(source, { filename })
        if (errors.length) throw errors[0]
        const template = compileTemplate({ source: descriptor.template.content, filename, id: filename })
        if (template.errors.length) throw template.errors[0]
        return {
          contents: `${rewriteDefault(descriptor.script.content, 'component')}\n${template.code}\ncomponent.render = render; export default component;`,
          loader: 'js', resolveDir: path.dirname(filename)
        }
      })
    }
  }]
}
