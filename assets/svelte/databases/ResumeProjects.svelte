<script lang="ts">
    import { Button } from "$lib/components/ui/button";
    import { Input } from "$lib/components/ui/input";
    import { Label } from "$lib/components/ui/label";
    import { Textarea } from "$lib/components/ui/textarea";
    import { Tooltip } from "bits-ui";
    import Info from "phosphor-svelte/lib/Info";
    import Plus from "phosphor-svelte/lib/Plus";
    import Trash from "phosphor-svelte/lib/Trash";

    // Define props using $props()
    const {
        project = null,
        errors = {},
        parent,
        live,
        isEditing = false,
        id = "" // Prop id for identifying component instance
    }: {
        project?: any;
        errors?: Record<string, any>;
        parent: string;
        live: any;
        isEditing?: boolean;
        id?: string;
    } = $props();

    // Define form state type
    type FormState = {
        id: string; // Ensure ID is part of the form state
        name: string;
        description: string;
        technologies: string[];
        highlights: string[];
    };

    // Initialize form state
    function initializeFormState(): FormState {
        const itemId = project?.id ?? id ?? Date.now().toString();
        const state: FormState = {
            id: itemId,
            name: project?.name ?? "",
            description: project?.description ?? "",
            technologies: project?.technologies ?? [],
            highlights: project?.highlights ?? []
        };
        return state;
    }

    let form = $state<FormState>(initializeFormState());
    const fieldErrors = $derived(new Map(Object.entries(errors)));

    // Push event helper
    function pushEvent(event: string, payload: Record<string, any> = {}) {
        let finalPayload;
        if (event === "form_updated") {
            finalPayload = { id: form.id, form: payload.form }; 
        } else {
            finalPayload = payload;
        }
        live.pushEventTo(`#${parent}`, event, finalPayload);
    }

    // Handle form field updates for simple text/textarea inputs
    function updateField(fieldName: keyof Pick<FormState, 'name' | 'description'>, value: any) {
        form[fieldName] = value;
        form = { ...form }; 
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Handle array field updates
    function addArrayItem(fieldName: keyof Pick<FormState, 'technologies' | 'highlights'>) {
        if (!form[fieldName]) {
            form[fieldName] = [];
        }
        form[fieldName] = [...form[fieldName], ""];
        form = { ...form };
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function removeArrayItem(fieldName: keyof Pick<FormState, 'technologies' | 'highlights'>, index: number) {
        form[fieldName] = form[fieldName].filter((_, i) => i !== index);
        form = { ...form };
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function updateArrayItem(fieldName: keyof Pick<FormState, 'technologies' | 'highlights'>, index: number, value: string) {
        form[fieldName][index] = value;
        form[fieldName] = [...form[fieldName]]; 
        form = { ...form };
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Expose clearForm for parent components
    export function clearForm() {
        form = {
            id: Date.now().toString(), // Give new ID on clear
            name: "",
            description: "",
            technologies: [],
            highlights: []
        };
    }
</script>

<div class="space-y-4">
    <!-- Name field -->
    <div class="space-y-2">
        <Label for={`name-${form.id}`}>Project Name</Label>
        <Input
            type="text"
            id={`name-${form.id}`}
            value={form.name}
            on:input={(e) => updateField("name", e.currentTarget.value)}
            placeholder="Enter project name"
        />
        {#if fieldErrors.has("name")}
            <p class="text-destructive text-sm">
                {fieldErrors.get("name")}
            </p>
        {/if}
    </div>

    <!-- Description field -->
    <div class="space-y-2">
        <Label for={`description-${form.id}`}>Description</Label>
        <Input
            type="text"
            id={`description-${form.id}`}
            value={form.description}
            on:input={(e) => updateField("description", e.currentTarget.value)}
            placeholder="Enter project description"
        />
        {#if fieldErrors.has("description")}
            <p class="text-destructive text-sm">
                {fieldErrors.get("description")}
            </p>
        {/if}
    </div>

    <!-- Technologies and Highlights on same row -->
    <div class="flex gap-4">
        <div class="flex-1 space-y-2">
            <Label for={`technologies-label-${form.id}`}>Technologies</Label>
            <div class="space-y-2">
                {#each form.technologies as item, index (index)}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`technologies-${form.id}-${index}`}
                            value={item}
                            on:input={(e) => updateArrayItem("technologies", index, e.currentTarget.value)}
                            placeholder="Enter technology"
                            class="flex-1"
                        />
                        <Button
                            type="button"
                            variant="destructive"
                            size="icon"
                            onclick={() => removeArrayItem("technologies", index)}
                        >
                            <Trash class="h-4 w-4" />
                        </Button>
                    </div>
                {/each}
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onclick={() => addArrayItem("technologies")}
                    class="w-full"
                >
                    <Plus class="h-4 w-4 mr-2" />
                    Add Technology
                </Button>
            </div>
            {#if fieldErrors.has("technologies")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("technologies")}
                </p>
            {/if}
        </div>

        <div class="flex-1 space-y-2">
            <Label for={`highlights-label-${form.id}`}>Highlights</Label>
            <div class="space-y-2">
                {#each form.highlights as item, index (index)}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`highlights-${form.id}-${index}`}
                            value={item}
                            on:input={(e) => updateArrayItem("highlights", index, e.currentTarget.value)}
                            placeholder="Enter achievement or highlight"
                            class="flex-1"
                        />
                        <Button
                            type="button"
                            variant="destructive"
                            size="icon"
                            onclick={() => removeArrayItem("highlights", index)}
                        >
                            <Trash class="h-4 w-4" />
                        </Button>
                    </div>
                {/each}
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onclick={() => addArrayItem("highlights")}
                    class="w-full"
                >
                    <Plus class="h-4 w-4 mr-2" />
                    Add Highlight
                </Button>
            </div>
            {#if fieldErrors.has("highlights")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("highlights")}
                </p>
            {/if}
        </div>
    </div>
</div>
