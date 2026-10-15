const production = process.env.NODE_ENV === 'production' || process.env.RAILS_ENV === 'production'
async function build() {
  if (production) await require('node:fs/promises').rm('app/assets/builds/application.js.map', { force: true })
  await require('esbuild').build({
    ...require('./esbuild.shared'), minify: production, sourcemap: !production,
    define: { ...require('./esbuild.shared').define, 'process.env.NODE_ENV': JSON.stringify(production ? 'production' : 'development') }
  })
}
build().catch(error => { console.error(error); process.exit(1) })
