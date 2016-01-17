gulp = require("gulp")
del = require("del")
p = require("gulp-load-plugins")()
runSequence = require("run-sequence")
autoprefixer = require("autoprefixer")
mqpacker = require("css-mqpacker")
csswring = require("csswring")
browserSync = require("browser-sync").create()
argv = require("yargs").argv
templateHelper = require("./lib/templateHelper")
highlightjs = require("highlight.js")

isDev = argv.dev?
assetHost = argv.assetHost or ""

paths =
  src: "src"
  dest: "dist"
  rev: ["dist/**/*.{css,js,map,svg,jpg,png,gif,ttf,woff,woff2}"]
  copy: ["src/{fonts,images,svgs}/**/*", "src/favicon.ico", "src/.htaccess", "src/{styles,}/vendor/highlightjs.css"]
  pages: ["src/pages/**/*.jade"]
  styles: ["src/styles/**/*.styl"]
  scripts: ["src/scripts/**/*.js"]
  sitemap: ["dist/**/*.html"]
  optimizeImages: ["src/{images,svgs}/**/*"]
  articles: if isDev then ["src/articles/*.md", "src/drafts/*.md"] else ["src/articles/*.md"]
  templates: "src/templates/*.jade"
  feedTemplate: "src/templates/atom.jade"
  articleTemplate: "src/templates/article.jade"
  articlesBasepath: "articles"

dest = (folder = "") -> gulp.dest("#{paths.dest}/#{folder}")

mvbConf =
  glob: paths.articles
  template: paths.articleTemplate
  permalink: (article) ->
    "/#{paths.articlesBasepath}/#{article.id}.html"
  highlight: (code) ->
    highlightjs.highlightAuto(code).value
  grouping: (articles) ->
    byYear = {}
    articles.forEach (article) ->
      year = article.date.toISOString().replace(/-.*/, "")
      byYear[year] ||= []
      byYear[year].push(article)
    articlesByYear = []
    Object.keys(byYear).reverse().forEach (year) ->
      articlesByYear.push(year: year, articles: byYear[year])
    byYear: articlesByYear

templateData = (file) ->
  h: templateHelper.createHelper(file, isDev, assetHost)

gulp.task "clean", (cb) ->
  del(paths.dest, cb)

gulp.task "copy", (cb) ->
  gulp.src(paths.copy)
    .pipe(dest())
    .pipe(browserSync.stream())

gulp.task "articles", ->
  gulp.src(paths.articles)
    .pipe(p.plumber())
    .pipe(p.mvb(mvbConf))
    .pipe(p.data(templateData))
    .pipe(p.jade(pretty: true))
    .pipe(p.minifyHtml(empty: true))
    .pipe(dest(paths.articlesBasepath))
    .pipe(browserSync.stream())

gulp.task "pages", ->
  gulp.src(paths.pages)
    .pipe(p.plumber())
    .pipe(p.resolveDependencies(pattern: /^\s*(?:extends|include) ([\w-]+)$/g))
    .pipe(p.mvb(mvbConf))
    .pipe(p.data(templateData))
    .pipe(p.jade(pretty: true))
    .pipe(p.minifyHtml(empty: true))
    .pipe(dest())
    .pipe(browserSync.stream())

gulp.task "feed", ->
  gulp.src(paths.feedTemplate)
    .pipe(p.plumber())
    .pipe(p.mvb(mvbConf))
    .pipe(p.data(templateData))
    .pipe(p.jade(pretty: true))
    .pipe(p.rename("atom.xml"))
    .pipe(dest())

gulp.task "scripts", ->
  gulp.src(paths.scripts)
    .pipe(p.plumber())
    .pipe(p.sourcemaps.init())
    .pipe(p.babel())
    .pipe(p.uglify())
    .pipe(p.sourcemaps.write("./maps"))
    .pipe(dest("scripts"))
    .pipe(browserSync.stream())

gulp.task "styles", ->
  processors = [
    mqpacker
    autoprefixer(browsers: ["last 2 versions"])
    csswring
  ]
  gulp.src(paths.styles)
    .pipe(p.plumber())
    #.pipe(p.sourcemaps.init())
    .pipe(p.stylus(
      paths: ["src/styles/lib"],
      import: ["mediaQueries", "mixins", "variables"]
    ))
    .pipe(p.concat("main.css"))
    .pipe(p.postcss(processors))
    #.pipe(p.sourcemaps.write("./maps"))
    .pipe(dest("styles"))
    .pipe(browserSync.stream())

gulp.task "browserSync", ->
  browserSync.init(
    open: false
    server:
      baseDir: paths.dest
  )

gulp.task "optimizeImages", ->
  gulp.src(paths.optimizeImages)
    .pipe(p.imagemin())
    .pipe(gulp.dest("src"))

gulp.task "revAssets", ->
  revAll = new p.revAll(prefix: assetHost)
  gulp.src(paths.rev)
    .pipe(revAll.revision())
    .pipe(dest())
    .pipe(revAll.manifestFile())
    .pipe(dest())

gulp.task "sitemap", ->
  gulp.src(paths.sitemap)
    .pipe(p.sitemap(
      siteUrl: "https://dennisreimann.de"
      changefreq: "weekly"
    ))
    .pipe(dest())

gulp.task "watch", ->
  gulp.watch paths.copy, ["copy"]
  gulp.watch paths.pages, ["pages"]
  gulp.watch paths.styles, ["styles"]
  gulp.watch paths.scripts, ["scripts"]
  gulp.watch paths.articles, ["articles", "pages", "feed"]
  gulp.watch paths.templates, ["articles", "pages"]
  gulp.watch paths.feedTemplate, ["feed"]
  gulp.watch paths.articleTemplate, ["articles"]

gulp.task "build", (cb) -> runSequence("styles", ["copy", "pages", "articles", "feed", "scripts"], cb)
gulp.task "develop", (cb) -> runSequence("build", ["watch", "browserSync"], cb)
gulp.task "rev", (cb) -> runSequence("revAssets", ["pages", "articles"], cb)
gulp.task "production", (cb) -> runSequence("build", "rev", cb)
