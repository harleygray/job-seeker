import { type VariantProps, tv } from "tailwind-variants";
import Root from "./button.svelte";
// Remove bits-ui import as Props/Events are not exported as expected
// import { Button as ButtonPrimitive } from "bits-ui";
import type { HTMLAnchorAttributes, HTMLButtonAttributes } from "svelte/elements";

const buttonVariants = tv({
	base: "focus-visible:ring-ring inline-flex items-center justify-center whitespace-nowrap text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 disabled:pointer-events-none disabled:opacity-50",
	variants: {
		variant: {
			default: "bg-primary text-primary-foreground hover:bg-primary/90 shadow",
			destructive:
				"bg-destructive text-destructive-foreground hover:bg-destructive/90 shadow-sm",
			outline:
				"border-input bg-background hover:bg-accent hover:text-accent-foreground border shadow-sm",
			secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/80 shadow-sm",
			ghost: "hover:bg-accent hover:text-accent-foreground",
			link: "text-primary underline-offset-4 hover:underline",
			next_page: "",
			prev_page: "",
			pagination: "h-8 w-8 border border-input bg-background hover:bg-accent hover:text-accent-foreground p-0",
			action_primary: "bg-primary text-primary-foreground hover:bg-primary/90 rounded-lg",
			action_secondary: "bg-secondary text-secondary-foreground hover:bg-primary/10 rounded-lg border border-secondary-foreground",
		},
		size: {
			default: "h-9 px-4 py-2",
			sm: "h-8 rounded-md px-3 text-xs",
			lg: "h-10 rounded-md px-8",
			icon: "h-9 w-9",
		},
	},
	defaultVariants: {
		variant: "default",
		size: "default",
	},
});

type Variant = VariantProps<typeof buttonVariants>["variant"];
type Size = VariantProps<typeof buttonVariants>["size"];

// Define Props based on button.svelte's $props definition
type Props = {
	href?: HTMLAnchorAttributes['href'];
	type?: HTMLButtonAttributes['type'];
	variant?: Variant;
	size?: Size;
	class?: string;
	disabled?: boolean;
	ref?: HTMLButtonElement | HTMLAnchorElement | null; // Ref type from button.svelte
	children?: any; // Children can be any type
} & Omit<HTMLButtonAttributes & HTMLAnchorAttributes, "type" | "href" | "class" | "disabled">; // Include rest props, omit handled ones


// Remove explicit Events definition. Event handlers will be passed via {...restProps}
// type Events = {
//   click: MouseEvent;
// };

export {
	Root,
	type Props,
	// Remove Events export
	// type Events,
	// Re-export variants if needed by consumers
	buttonVariants,
	// Keep aliases for compatibility if necessary
	Root as Button,
	type Props as ButtonProps,
	// Remove Events alias export
	// type Events as ButtonEvents,
};
