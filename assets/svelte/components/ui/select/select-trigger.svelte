<script lang="ts">
    import { Select as SelectPrimitive, type WithoutChild } from "bits-ui";
    import CaretDown from "phosphor-svelte/lib/CaretDown";
    import { cn } from "$lib/utils.js";

    let {
        ref = $bindable(null),
        class: className,
        children,
        ...restProps
    }: WithoutChild<SelectPrimitive.TriggerProps> = $props();
</script>

<SelectPrimitive.Trigger
    bind:ref
    class={cn(
        "border-input ring-offset-background !text-gray-800 focus:ring-ring flex h-9 w-full items-center justify-between whitespace-nowrap rounded-md border bg-transparent px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-1 disabled:cursor-not-allowed disabled:opacity-50 [&>span]:line-clamp-1",
        className,
    )}
    {...restProps}
>
    {@render children?.()}
    <CaretDown class="size-4 opacity-50" />
</SelectPrimitive.Trigger>
