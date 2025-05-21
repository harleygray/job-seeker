<script lang="ts">
    import { Button } from "$lib/components/ui/button";
    import { Input } from "$lib/components/ui/input";
    import { Label } from "$lib/components/ui/label";
    import { Tooltip } from "bits-ui";
    import Info from "phosphor-svelte/lib/Info";
    import Plus from "phosphor-svelte/lib/Plus";
    import Trash from "phosphor-svelte/lib/Trash";

    // Define props using $props()
    const {
        skill = null,
        errors = {},
        parent,
        live,
        isEditing = false,
        id = ""
    }: {
        skill?: any;
        errors?: Record<string, any>;
        parent: string;
        live: any;
        isEditing?: boolean;
        id?: string;
    } = $props();

    // Define form state type
    type FormState = {
        category: string;
        items: string[];
    };

    // Initialize form state
    function initializeFormState(): FormState {
        const state: FormState = {
            category: skill?.category ?? "",
            items: skill?.items ?? []
        };
        return state;
    }

    let form = $state<FormState>(initializeFormState());
    const fieldErrors = $derived(new Map(Object.entries(errors)));

    // Push event helper
    function pushEvent(event: string, payload = {}) {
        const finalPayload = event === "form_updated" && id ? { ...payload, id: id } : payload;
        live.pushEventTo(`#${parent}`, event, finalPayload);
    }

    // Handle array field updates
    function addArrayItem(fieldName: string) {
        if (!form[fieldName]) {
            form[fieldName] = [];
        }
        form[fieldName] = [...form[fieldName], ""];
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function removeArrayItem(fieldName: string, index: number) {
        form[fieldName] = form[fieldName].filter((_, i) => i !== index);
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function updateArrayItem(fieldName: string, index: number, value: string) {
        form[fieldName][index] = value;
        form[fieldName] = [...form[fieldName]]; // Trigger reactivity
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Expose clearForm for parent components
    export function clearForm() {
        form = {
            category: "",
            items: []
        };
    }
</script>

<div class="space-y-4">
    <!-- Category field -->
    <div class="space-y-2">
        <Label for="category">Category</Label>
        <Input
            type="text"
            id="category"
            bind:value={form.category}
            placeholder="Enter skill category (e.g., Programming Languages, Frameworks)"
        />
        {#if fieldErrors.has("category")}
            <p class="text-destructive text-sm">
                {fieldErrors.get("category")}
            </p>
        {/if}
    </div>

    <!-- Skills items -->
    <div class="space-y-2">
        <Label for="items">Skills</Label>
        <div class="space-y-2">
            {#each form.items as item, index}
                <div class="flex gap-2">
                    <Input
                        type="text"
                        id={`items-${index}`}
                        value={item}
                        on:input={(e) => updateArrayItem("items", index, e.currentTarget.value)}
                        placeholder="Enter skill"
                        class="flex-1"
                    />
                    <Button
                        type="button"
                        variant="destructive"
                        size="icon"
                        onclick={() => removeArrayItem("items", index)}
                    >
                        <Trash class="h-4 w-4" />
                    </Button>
                </div>
            {/each}
            <Button
                type="button"
                variant="outline"
                size="sm"
                onclick={() => addArrayItem("items")}
                class="w-full"
            >
                <Plus class="h-4 w-4 mr-2" />
                Add Skill
            </Button>
        </div>
        {#if fieldErrors.has("items")}
            <p class="text-destructive text-sm">
                {fieldErrors.get("items")}
            </p>
        {/if}
    </div>
</div>
