import { type VariantProps, tv } from "tailwind-variants";

export { default as Badge } from "./badge.svelte";
export const badgeVariants = tv({
	base: "focus:ring-ring inline-flex select-none items-center rounded-md border-2 px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2",
	variants: {
		variant: {
			default:
				"bg-primary text-primary-foreground hover:bg-primary/80",
			secondary:
				"bg-secondary text-secondary-foreground hover:bg-secondary/80",
			destructive:
				"bg-destructive text-destructive-foreground hover:bg-destructive/80",
			failed:
				"bg-red-500 text-white hover:bg-red-600 border-red-600",
			pending:
				"bg-yellow-100 text-yellow-800 hover:bg-yellow-200/80",
			in_progress:
				"bg-muted text-primary hover:bg-secondary/80 border-primary",
			complete:
				"bg-green-100 text-green-800 border-green-900 hover:bg-green-200/80",
			official: "bg-accent text-accent-foreground border-accent"
		},
	},
	defaultVariants: {
		variant: "default",
	},
});

export type Variant = VariantProps<typeof badgeVariants>["variant"];
