import type { Button as ButtonPrimitive } from "bits-ui";
import { type VariantProps, tv } from "tailwind-variants";
import Root from "./button.svelte";
import type { ButtonRootProps } from "bits-ui";

const buttonVariants = tv({
	base: "focus-visible:ring-ring inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 disabled:pointer-events-none disabled:opacity-50",
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
			_list_item_base: "text-left p-3 border rounded-lg focus:outline-none",
			list_item_active: "_list_item_base bg-primary-50 border-primary-300 hover:bg-primary-100 text-primary-800 outline outline-2 outline-offset-1 outline-[var(--color-ring)] transition-none",
			list_item_inactive: "_list_item_base bg-background border-gray-200 text-gray-700 hover:bg-gray-50 transition-none",
		},
		size: {
			default: "h-9 px-4 py-2",
			sm: "h-8 rounded-md px-3 text-xs",
			lg: "h-10 rounded-md px-8",
			icon: "h-9 w-9",
			item: "h-10 w-full",
		},
	},
	defaultVariants: {
		variant: "default",
		size: "default",
	},
});

type Variant = VariantProps<typeof buttonVariants>["variant"];
type Size = VariantProps<typeof buttonVariants>["size"];

type Props = ButtonRootProps & {
	variant?: Variant;
	size?: Size;
};

type Events = Parameters<ButtonRootProps["onclick"]>[0];

export {
	Root,
	type Props,
	type Events,
	//
	Root as Button,
	type Props as ButtonProps,
	type Events as ButtonEvents,
	buttonVariants,
};
