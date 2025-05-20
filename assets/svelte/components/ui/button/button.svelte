<script lang="ts">
	import { tv } from "tailwind-variants";
	import { type VariantProps } from "tailwind-variants";
	import type { HTMLAnchorAttributes, HTMLButtonAttributes } from "svelte/elements";
	import { cn } from "$lib/utils.js"; // Assuming utility for class merging
	import type { SvelteComponent } from "svelte";

	// Directly use the buttonVariants definition here or import if preferred
	const buttonVariants = tv({ 
		base: "focus-visible:ring-ring inline-flex items-center justify-center whitespace-nowrap text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 disabled:pointer-events-none disabled:opacity-50",
		variants: {
			variant: {
				default: "bg-primary text-primary-foreground hover:bg-primary/90 shadow", // Adjusted default based on index.ts
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
				action_secondary: "bg-secondary text-secondary-foreground hover:bg-primary/10 rounded-lg border-2 border-secondary-foreground",
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

	type Props = {
			href?: HTMLAnchorAttributes['href'];
			type?: HTMLButtonAttributes['type'];
			variant?: VariantProps<typeof buttonVariants>["variant"];
			size?: VariantProps<typeof buttonVariants>["size"];
			class?: string;
			disabled?: boolean;
			ref?: HTMLButtonElement | HTMLAnchorElement | null;
			children?: any;
			onclick?: ((event: MouseEvent) => void) | undefined;
		};

	// Define props using $props() and $bindable()
	let {
		href,
		type,
		variant = "default",
		size = "default",
		class: className,
		disabled = false,
		ref = $bindable(),
		children,
		onclick,
		...restProps
	}: Props = $props();

	// Calculate classes reactively
	const finalClass = $derived(cn(buttonVariants({ variant, size }), className));

	// Prepare all button props that will be passed to either the default element or child snippet
	const buttonProps = $derived({
		class: finalClass,
		type: href ? undefined : type,
		href: href && !disabled ? href : undefined,
		disabled: href ? undefined : disabled,
		"aria-disabled": disabled ? true : undefined,
		role: href && disabled ? "link" : href ? undefined : "button",
		tabindex: disabled ? -1 : undefined,
		onclick: (event: MouseEvent) => {
			if (!disabled && onclick) {
				onclick(event);
			}
		},
		...restProps
	});

</script>

<svelte:element
	this={href ? "a" : "button"}
	bind:this={ref}
	class={finalClass}
	type={href ? undefined : type}
	href={href && !disabled ? href : undefined}
	disabled={href ? undefined : disabled}
	aria-disabled={disabled ? true : undefined}
	role={href && disabled ? "link" : href ? undefined : "button"}
	tabindex={disabled ? -1 : undefined}
	onclick={(event: MouseEvent) => {
		if (!disabled && onclick) {
			onclick(event);
		}
	}}
	{...restProps}
>
	{#if children}
		{@render children()}
	{/if}
</svelte:element>
