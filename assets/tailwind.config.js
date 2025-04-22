import fs from "fs";
import plugin from "tailwindcss/plugin";
import path from "path";

/** @type {import('tailwindcss').Config} */
const config = {
	content: [
		// Civic Forum content paths
		"./js/**/*.js",
		"../lib/job_hunt_web.ex",
		"../lib/job_hunt_web/**/*.*ex",
		"../lib/job_hunt/ecto/*.ex",
		"./svelte/**/*.svelte",
		
		// shadcn paths
		"$lib/components/**/*.{html,js,svelte,ts}",
	],
	safelist: [],
	theme: {
		container: {
			center: true,
			padding: "2rem",
			screens: {
				"2xl": "1400px"
			}
		},
		screens: {
			'sm': '640px',
			'md': '768px',
			'lg': '1024px',
			'xl': '1280px',
			'2xl': '1536px',
		},
		extend: {
			colors: {
				// shadcn colors replaced with direct HSL values
				border: "hsl(226 2% 92% / <alpha-value>)",
				input: "hsl(226 2% 92% / <alpha-value>)",
				ring: "hsl(226 83% 42% / <alpha-value>)",
				background: "hsl(226 55% 98% / <alpha-value>)",
				foreground: "hsl(226 61% 4% / <alpha-value>)",
				primary: {
					DEFAULT: "hsl(226 83% 42% / <alpha-value>)",
					foreground: "hsl(0 0% 100% / <alpha-value>)",
				},
				secondary: {
					DEFAULT: "hsl(226 43% 92% / <alpha-value>)",
					foreground: "hsl(226 5% 3% / <alpha-value>)"
				},
				destructive: {
					DEFAULT: "hsl(0 86% 40% / <alpha-value>)",
					foreground: "hsl(3 0% 100% / <alpha-value>)"
				},
				muted: {
					DEFAULT: "hsl(224 100% 93% / <alpha-value>)",
					foreground: "hsl(228 5.9% 16.7% / <alpha-value>)"
				},
				accent: {
					DEFAULT: "hsl(220.2 62.6% 61.2% / <alpha-value>)",
					foreground: "hsl(218.4 37.3% 86.9% / <alpha-value>)"
				},
				popover: {
					DEFAULT: "hsl(226 55% 98% / <alpha-value>)",
					foreground: "hsl(226 61% 4% / <alpha-value>)"
				},
				card: {
					DEFAULT: "hsl(226 55% 97% / <alpha-value>)",
					foreground: "hsl(226 61% 3% / <alpha-value>)"
				},
			},
			borderRadius: {
				xl: "5px",
				lg: "3px",
				md: "2px",
				sm: "1px"
			},
			keyframes: {
				"accordion-down": {
					from: { height: "0" },
					to: { height: "var(--bits-accordion-content-height)" },
				},
				"accordion-up": {
					from: { height: "var(--bits-accordion-content-height)" },
					to: { height: "0" },
				},
				"caret-blink": {
					"0%,70%,100%": { opacity: "1" },
					"20%,50%": { opacity: "0" },
				},
			},
			animation: {
				"accordion-down": "accordion-down 0.2s ease-out",
				"accordion-up": "accordion-up 0.2s ease-out",
				"caret-blink": "caret-blink 1.25s ease-out infinite",
			},
		},

		
	},
	plugins: [
		// Phoenix LiveView specific plugins
		plugin(({ addVariant }) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
		plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
		plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
		plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

		// Heroicons integration
		plugin(function ({ matchComponents, theme }) {
			let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
			let values = {}
			let icons = [
				["", "/24/outline"],
				["-solid", "/24/solid"],
				["-mini", "/20/solid"],
				["-micro", "/16/solid"]
			]
			icons.forEach(([suffix, dir]) => {
				fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
					let name = path.basename(file, ".svg") + suffix
					values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
				})
			})
			matchComponents({
				"hero": ({ name, fullPath }) => {
					let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
					let size = theme("spacing.6")
					if (name.endsWith("-mini")) {
						size = theme("spacing.5")
					} else if (name.endsWith("-micro")) {
						size = theme("spacing.4")
					}
					return {
						[`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
						"-webkit-mask": `var(--hero-${name})`,
						"mask": `var(--hero-${name})`,
						"mask-repeat": "no-repeat",
						"background-color": "currentColor",
						"vertical-align": "middle",
						"display": "inline-block",
						"width": size,
						"height": size
					}
				}
			}, { values })
		})
	],
};

export default config;
