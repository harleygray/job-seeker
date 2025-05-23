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
        id = "" // Prop id primarily for identifying the component instance if needed by parent initially
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
        id: string; // Ensure ID is part of the form state
        institution: string;
        courses: string[];
        highlights: string[];
    };

    // Initialize form state
    function initializeFormState(): FormState {
        // Prioritize education.id (from existing data), then prop id, then new timestamp
        const itemId = education?.id ?? id ?? Date.now().toString();
        const state: FormState = {
            id: itemId,
            institution: education?.institution ?? "",
            courses: education?.courses ?? [],
            highlights: education?.highlights ?? []
        };
        return state;
    }

    let form = $state<FormState>(initializeFormState());
    const fieldErrors = $derived(new Map(Object.entries(errors)));

    // Push event helper
    function pushEvent(event: string, payload: Record<string, any> = {}) {
        let finalPayload;
        if (event === "form_updated") {
            // For form_updated, payload is expected to be { form: formDataSnapshot }
            // We need to structure it as { id: form.id, form: formDataSnapshot.form }
            // Assuming payload = { form: data }, then finalPayload = { id: form.id, form: payload.form }
            finalPayload = { id: form.id, form: payload.form }; 
        } else {
            finalPayload = payload;
        }
        live.pushEventTo(`#${parent}`, event, finalPayload);
    }

    // Handle form field updates for simple text inputs
    function updateField(fieldName: keyof Pick<FormState, 'institution'>, value: any) {
        form[fieldName] = value;
        form = { ...form }; // Trigger reactivity for the whole form object if needed, or just for the field
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Handle array field updates
    function addArrayItem(fieldName: keyof Pick<FormState, 'courses' | 'highlights'>) {
        if (!form[fieldName]) {
            form[fieldName] = [];
        }
        form[fieldName] = [...form[fieldName], ""];
        form = { ...form }; // Trigger reactivity for array changes
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function removeArrayItem(fieldName: keyof Pick<FormState, 'courses' | 'highlights'>, index: number) {
        form[fieldName] = form[fieldName].filter((_, i) => i !== index);
        form = { ...form }; // Trigger reactivity for array changes
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function updateArrayItem(fieldName: keyof Pick<FormState, 'courses' | 'highlights'>, index: number, value: string) {
        form[fieldName][index] = value;
        form[fieldName] = [...form[fieldName]]; // Trigger reactivity for item within array
        form = { ...form }; // Trigger reactivity for the whole form object
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Expose clearForm for parent components
    export function clearForm() {
        form = {
            id: Date.now().toString(), // Give new ID on clear
            institution: "",
            courses: [],
            highlights: []
        };
    }
</script>

<div class="space-y-4">
    <!-- Institution field -->
    <div class="space-y-2">
        <Label for={`institution-${form.id}`}>Institution</Label>
        <Input
            type="text"
            id={`institution-${form.id}`}
            value={form.institution}
            on:input={(e) => updateField("institution", e.currentTarget.value)}
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
            <Label for={`courses-label-${form.id}`}>Courses</Label>
            <div class="space-y-2">
                {#each form.courses as item, index (index)} 
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`courses-${form.id}-${index}`}
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
