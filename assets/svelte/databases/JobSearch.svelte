<script lang="ts">
    import { Label } from "$lib/components/ui/label"; // Assuming similar label component exists
    import MagnifyingGlass from "phosphor-svelte/lib/MagnifyingGlass";
    import type { HTMLInputAttributes } from "svelte/elements";
    import { cn } from "$lib/utils.js"; // Assuming shadcn/svelte style utils
  
    // Props
    let {
      searchTerm = $bindable(""), // Bindable search term
      placeholder = "Search...",
      class: className = "",
      id = "search",
      ...restProps
    } = $props<{
        searchTerm?: string,
        placeholder?: string,
        class?: string,
        id?: string
      } & Omit<HTMLInputAttributes, 'value' | 'placeholder' | 'id' | 'class'>>();
  
  </script>
  
  <div class={cn("relative w-full", className)}> 
    <Label for={id} class="sr-only">{placeholder}</Label>
    <input 
      bind:value={searchTerm} 
      {id} 
      {placeholder} 
      class="w-full h-8 rounded-md border border-input bg-transparent px-3 py-1 text-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 pl-8" 
      {...restProps}
    />
    <MagnifyingGlass
      class="pointer-events-none absolute left-2 top-1/2 size-4 -translate-y-1/2 select-none text-muted-foreground"
    />
  </div>
  