<script lang="ts">
    import CaretDown from "phosphor-svelte/lib/CaretDown";
    import {
        Select as SelectPrimitive,
        type WithoutChildrenOrChild,
    } from "bits-ui";
    import { cn } from "$lib/utils.js";

    let {
        ref = $bindable(null),
        class: className,
        ...restProps
    }: WithoutChildrenOrChild<SelectPrimitive.ScrollDownButtonProps> = $props();
</script>

<SelectPrimitive.ScrollDownButton
    bind:ref
    class={cn(
        "flex cursor-default items-center justify-center py-1",
        className,
    )}
    {...restProps}
>
    <CaretDown class="size-4" />
</SelectPrimitive.ScrollDownButton>
