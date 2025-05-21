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
        education = null,
        errors = {},
        parent,
        live,
        isEditing = false,
        id = ""
    }: {
        education?: any;
        errors?: Record<string, any>;
        parent: string;
        live: any;
        isEditing?: boolean;
        id?: string;
    } = $props();

    // Define form state type
    type FormState = {
        institution: string;
        courses: string[];
        highlights: string[];
    };

    // Initialize form state
    function initializeFormState(): FormState {
        const state: FormState = {
            institution: education?.institution ?? "",
            courses: education?.courses ?? [],
            highlights: education?.highlights ?? []
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
            institution: "",
            courses: [],
            highlights: []
        };
    }
</script>

<div class="space-y-4">
    <!-- Institution field -->
    <div class="space-y-2">
        <Label for="institution">Institution</Label>
        <Input
            type="text"
            id="institution"
            bind:value={form.institution}
            placeholder="Enter institution name"
        />
        {#if fieldErrors.has("institution")}
            <p class="text-destructive text-sm">
                {fieldErrors.get("institution")}
            </p>
        {/if}
    </div>

    <!-- Courses and Highlights on same row -->
    <div class="flex gap-4">
        <div class="flex-1 space-y-2">
            <Label for="courses">Courses</Label>
            <div class="space-y-2">
                {#each form.courses as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`courses-${index}`}
                            value={item}
                            on:input={(e) => updateArrayItem("courses", index, e.currentTarget.value)}
                            placeholder="Enter course name"
                            class="flex-1"
                        />
                        <Button
                            type="button"
                            variant="destructive"
                            size="icon"
                            onclick={() => removeArrayItem("courses", index)}
                        >
                            <Trash class="h-4 w-4" />
                        </Button>
                    </div>
                {/each}
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onclick={() => addArrayItem("courses")}
                    class="w-full"
                >
                    <Plus class="h-4 w-4 mr-2" />
                    Add Course
                </Button>
            </div>
            {#if fieldErrors.has("courses")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("courses")}
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
