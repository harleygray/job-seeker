<script lang="ts">
	import { Button as ButtonPrimitive } from "bits-ui";
	import { type Events, type Props, buttonVariants } from "./index.js";

	type $$Props = Props;
	type $$Events = Events;

	let className: $$Props["class"] = undefined;
	export let variant: $$Props["variant"] = "default";
	export let size: $$Props["size"] = "default";
	export { className as class };

	$: classNames = [buttonVariants({ variant, size }), className].filter(Boolean).join(" ");
</script>

<ButtonPrimitive.Root
	class={classNames}
	type="button"
	{...$$restProps}
>
	<slot />
</ButtonPrimitive.Root>
