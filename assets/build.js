const esbuild = require("esbuild")
const sveltePlugin = require("esbuild-svelte")
const importGlobPlugin = require("esbuild-plugin-import-glob").default
//const sveltePreprocess = require("svelte-preprocess")

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")

let clientConditions = ["svelte", "browser"]
let serverConditions = ["svelte"]

if (!deploy) {
    clientConditions.push("development")
    serverConditions.push("development")
}

// Common build options
const commonOptions = {
    bundle: true,
    sourcemap: watch ? "inline" : false,
    logLevel: "info",
    tsconfig: "./tsconfig.json",
    target: ["es2020"],
    define: {
        "process.env.NODE_ENV": deploy ? '"production"' : '"development"'
    },
    loader: {
        '.js': 'jsx'
    },
    alias: {svelte: "svelte"}
}

let optsClient = {
    ...commonOptions,
    entryPoints: ["js/app.js"],
    minify: deploy,
    conditions: [...clientConditions, "style"],
    alias: {svelte: "svelte"},
    outdir: "../priv/static/assets",
    plugins: [
        importGlobPlugin(),
        sveltePlugin({
            //preprocess: sveltePreprocess(),
            compilerOptions: {
                dev: !deploy,
                css: "injected",
                generate: "client",
                hydratable: true
            },
            // Use filterWarnings as per esbuild-svelte source code
            filterWarnings: (warning) => {
                // Return false to filter out/silence the warning
                if (warning.filename.includes('bits-ui/dist/internal/floating-svelte') ||
                    warning.filename.includes('runed/dist/utilities/is-idle')
                    ) {
                    return false;
                }
                // Return true to keep other warnings
                return true;
            }
        }),
    ],
}

let optsServer = {
    ...commonOptions,
    entryPoints: ["js/server.js"],
    platform: "node",
    minify: false,
    conditions: serverConditions,
    alias: {svelte: "svelte"},
    outdir: "../priv/svelte",
    plugins: [
        importGlobPlugin(),
        sveltePlugin({
            //preprocess: sveltePreprocess(),
            compilerOptions: {
                dev: !deploy,
                css: "injected",
                generate: "server",
                hydratable: true
            },
            // Use filterWarnings as per esbuild-svelte source code
            filterWarnings: (warning) => {
                // Return false to filter out/silence the warning
                if (warning.filename?.includes('bits-ui/dist/internal/floating-svelte') ||
                    warning.filename?.includes('runed/dist/utilities/is-idle')
                    ) {
                    return false;
                }
                // Return true to keep other warnings
                return true;
            }
        }),
    ],
}

if (watch) {
    esbuild
        .context(optsClient)
        .then(ctx => ctx.watch())
        .catch(_error => process.exit(1))

    esbuild
        .context(optsServer)
        .then(ctx => ctx.watch())
        .catch(_error => process.exit(1))
} else {
    esbuild.build(optsClient)
    esbuild.build(optsServer)
}
