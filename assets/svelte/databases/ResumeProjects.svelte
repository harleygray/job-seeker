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
        id = ""
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
        name: string;
        description: string;
        technologies: string[];
        highlights: string[];
    };

    // Initialize form state
    function initializeFormState(): FormState {
        const state: FormState = {
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
        <Label for="name">Project Name</Label>
        <Input
            type="text"
            id="name"
            bind:value={form.name}
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
        <Label for="description">Description</Label>
        <Textarea
            id="description"
            bind:value={form.description}
            placeholder="Enter project description"
            rows={3}
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
            <Label for="technologies">Technologies</Label>
            <div class="space-y-2">
                {#each form.technologies as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`technologies-${index}`}
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
            <Label for="highlights">Highlights</Label>
            <div class="space-y-2">
                {#each form.highlights as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`highlights-${index}`}
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
