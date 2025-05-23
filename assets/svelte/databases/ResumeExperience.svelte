<script lang="ts">
    import { Button } from "$lib/components/ui/button";
    import { Input } from "$lib/components/ui/input";
    import { Label } from "$lib/components/ui/label";
    import { Textarea } from "$lib/components/ui/textarea";
    import WarningCircle from "phosphor-svelte/lib/WarningCircle";
    import Plus from "phosphor-svelte/lib/Plus";
    import Trash from "phosphor-svelte/lib/Trash";
    import { Tooltip } from "bits-ui";
    import Info from "phosphor-svelte/lib/Info";

    // Define the structure for a field definition
    export type FieldDefinition = {
        name: string;
        label: string;
        type: "text" | "date" | "array" | "textarea";
        defaultValue: any;
        placeholder?: string;
        helpText?: string;
    };

    // Define props using $props()
    const {
        experience = null,
        errors = {},
        parent,
        live,
        isEditing = false,
        id = ""
    }: {
        experience?: any;
        errors?: Record<string, any>;
        parent: string;
        live: any;
        isEditing?: boolean;
        id?: string;
    } = $props();

    // Define form state type
    type FormState = {
        id: string;
        company: string;
        positions: string[];
        start_date: string;
        end_date: string;
        highlights: string[];
        relevant_experience: string[];
        technologies: string[];
    };

    // Field definitions for the experience form
    const fieldDefinitions: FieldDefinition[] = [
        {
            name: "company",
            label: "Company",
            type: "text",
            defaultValue: "",
            placeholder: "Enter company name",
        },
        {
            name: "positions",
            label: "Positions",
            type: "array",
            defaultValue: [],
            placeholder: "Enter position title",
            helpText: "Add multiple positions held at this company",
        },
        {
            name: "start_date",
            label: "Start Date",
            type: "date",
            defaultValue: "",
            placeholder: "YYYY-MM-DD",
        },
        {
            name: "end_date",
            label: "End Date",
            type: "date",
            defaultValue: "",
            placeholder: "YYYY-MM-DD",
            helpText: "Leave empty if current position",
        },
        {
            name: "highlights",
            label: "Key Highlights",
            type: "array",
            defaultValue: [],
            placeholder: "Enter achievement or highlight",
            helpText: "Add key achievements or responsibilities",
        },
        {
            name: "relevant_experience",
            label: "Relevant Experience",
            type: "array",
            defaultValue: [],
            placeholder: "Enter relevant experience",
            helpText: "Add experience points relevant to the position",
        },
        {
            name: "technologies",
            label: "Technologies",
            type: "array",
            defaultValue: [],
            placeholder: "Enter technology",
            helpText: "Add technologies used in this role",
        },
    ];

    // Initialize form state
    function initializeFormState(): FormState {
        const state: FormState = {
            id: experience?.id ?? id ?? Date.now().toString(),
            company: experience?.company ?? "",
            positions: experience?.positions ?? [],
            start_date: experience?.start_date ?? "",
            end_date: experience?.end_date ?? "",
            highlights: experience?.highlights ?? [],
            relevant_experience: experience?.relevant_experience ?? [],
            technologies: experience?.technologies ?? []
        };
        return state;
    }

    let form = $state<FormState>(initializeFormState());
    const fieldErrors = $derived(new Map(Object.entries(errors)));

    // Push event helper
    function pushEvent(event: string, payload = {}) {
        const finalPayload = event === "form_updated" ? { ...payload, id: form.id } : payload;
        live.pushEventTo(`#${parent}`, event, finalPayload);
    }

    // Handle form field updates
    function updateField(fieldName: string, value: any) {
        form[fieldName] = value;
        form = { ...form }; // Trigger reactivity
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Handle array field updates
    function addArrayItem(fieldName: string) {
        if (!form[fieldName]) {
            form[fieldName] = [];
        }
        form[fieldName] = [...form[fieldName], ""];
        form = { ...form }; // Trigger reactivity
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function removeArrayItem(fieldName: string, index: number) {
        form[fieldName] = form[fieldName].filter((_, i) => i !== index);
        form = { ...form }; // Trigger reactivity
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    function updateArrayItem(fieldName: string, index: number, value: string) {
        form[fieldName][index] = value;
        form[fieldName] = [...form[fieldName]]; // Trigger reactivity
        form = { ...form }; // Trigger reactivity
        pushEvent("form_updated", { form: $state.snapshot(form) });
    }

    // Expose clearForm for parent components
    export function clearForm() {
        for (const field of fieldDefinitions) {
            form[field.name] = field.defaultValue;
        }
    }

    // Add a function to handle the entire experience block removal
    function removeExperience() {
        console.log("Attempting to remove experience with ID:", form.id);
        if (live) {
            console.log("Pushing remove_experience_item event with ID:", form.id);
            live.pushEventTo(`#${parent}`, "remove_experience_item", { id: form.id });
        } else {
            console.log("No live connection available");
        }
    }

    // Add save function
    function saveExperience() {
        if (live) {
            live.pushEventTo(`#${parent}`, "save_experience_item", { id: form.id }, (reply) => {
                if (reply && reply.success) {
                    console.log("Experience item saved successfully:", reply);
                    // Update the local form state with the saved data
                    if (reply.resume) {
                        const savedItem = reply.resume.experience.find(item => item.id === form.id);
                        if (savedItem) {
                            form = { ...savedItem };
                        }
                    }
                } else {
                    console.error("Error saving experience item:", reply);
                }
            });
        }
    }

    // Add a helper function to generate unique IDs
    function getUniqueId(fieldName: string) {
        return `${fieldName}-${form.id}`;
    }
</script>

<div class="space-y-4">
    <!-- Company field -->
    <div class="space-y-2">
        <div class="flex justify-between items-center mb-2">
            <Label for={getUniqueId("company")}>Company</Label>
            <div class="flex gap-2">
                <Button
                    type="button"
                    variant="default"
                    size="sm"
                    onclick={saveExperience}
                >
                    Save
                </Button>
                <Button
                    type="button"
                    variant="destructive"
                    size="sm"
                    onclick={removeExperience}
                >
                    <Trash class="h-4 w-4 mr-2" />
                    Remove Experience
                </Button>
            </div>
        </div>
        <Input
            type="text"
            id={getUniqueId("company")}
            value={form.company}
            on:input={(e) => updateField("company", e.currentTarget.value)}
            placeholder="Enter company name"
        />
        {#if fieldErrors.has("company")}
            <p class="text-destructive text-sm">
                {fieldErrors.get("company")}
            </p>
        {/if}
    </div>

    <!-- Positions and Technologies on same row -->
    <div class="flex gap-4">
        <div class="flex-1 space-y-2">
            <Label for={getUniqueId("positions")}>Positions</Label>
            <div class="space-y-2">
                {#each form.positions as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`${getUniqueId("positions")}-${index}`}
                            value={item}
                            on:input={(e) => updateArrayItem("positions", index, e.currentTarget.value)}
                            placeholder="Enter position title"
                            class="flex-1"
                        />
                        <Button
                            type="button"
                            variant="destructive"
                            size="icon"
                            onclick={() => removeArrayItem("positions", index)}
                        >
                            <Trash class="h-4 w-4" />
                        </Button>
                    </div>
                {/each}
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onclick={() => addArrayItem("positions")}
                    class="w-full"
                >
                    <Plus class="h-4 w-4 mr-2" />
                    Add Position
                </Button>
            </div>
            {#if fieldErrors.has("positions")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("positions")}
                </p>
            {/if}
        </div>

        <div class="flex-1 space-y-2">
            <Label for={getUniqueId("technologies")}>Technologies</Label>
            <div class="space-y-2">
                {#each form.technologies as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`${getUniqueId("technologies")}-${index}`}
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
    </div>

    <!-- Start and End Date on same row -->
    <div class="flex gap-4">
        <div class="flex-1">
            <Label for={getUniqueId("start_date")}>Start Date</Label>
            <Input
                type="date"
                id={getUniqueId("start_date")}
                value={form.start_date}
                on:input={(e) => updateField("start_date", e.currentTarget.value)}
                placeholder="YYYY-MM-DD"
            />
        </div>
        <div class="flex-1">
            <div class="flex items-center gap-2 mb-1.5">
                <Label for={getUniqueId("end_date")}>End Date</Label>
                <Tooltip.Provider>
                    <Tooltip.Root delayDuration={50}>
                        <Tooltip.Trigger
                            class="border-none bg-transparent hover:bg-transparent focus:bg-transparent focus:outline-none"
                        >
                            <Info class="h-4 w-4 text-muted-foreground" />
                        </Tooltip.Trigger>
                        <Tooltip.Content sideOffset={8}>
                            <div class="rounded-input border-dark-10 bg-background shadow-popover outline-hidden z-0 flex items-center justify-center border p-3 text-sm font-medium">
                                Leave empty if current position
                            </div>
                        </Tooltip.Content>
                    </Tooltip.Root>
                </Tooltip.Provider>
            </div>
            <Input
                type="date"
                id={getUniqueId("end_date")}
                value={form.end_date}
                on:input={(e) => updateField("end_date", e.currentTarget.value)}
                placeholder="YYYY-MM-DD"
            />
        </div>
    </div>
    {#if fieldErrors.has("start_date") || fieldErrors.has("end_date")}
        <div class="space-y-1">
            {#if fieldErrors.has("start_date")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("start_date")}
                </p>
            {/if}
            {#if fieldErrors.has("end_date")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("end_date")}
                </p>
            {/if}
        </div>
    {/if}

    <!-- Highlights and Relevant Experience on same row -->
    <div class="flex gap-4">
        <div class="flex-1 space-y-2">
            <Label for={getUniqueId("highlights")}>Key Highlights</Label>
            <div class="space-y-2">
                {#each form.highlights as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`${getUniqueId("highlights")}-${index}`}
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

        <div class="flex-1 space-y-2">
            <Label for={getUniqueId("relevant_experience")}>Relevant Experience</Label>
            <div class="space-y-2">
                {#each form.relevant_experience as item, index}
                    <div class="flex gap-2">
                        <Input
                            type="text"
                            id={`${getUniqueId("relevant_experience")}-${index}`}
                            value={item}
                            on:input={(e) => updateArrayItem("relevant_experience", index, e.currentTarget.value)}
                            placeholder="Enter relevant experience"
                            class="flex-1"
                        />
                        <Button
                            type="button"
                            variant="destructive"
                            size="icon"
                            onclick={() => removeArrayItem("relevant_experience", index)}
                        >
                            <Trash class="h-4 w-4" />
                        </Button>
                    </div>
                {/each}
                <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onclick={() => addArrayItem("relevant_experience")}
                    class="w-full"
                >
                    <Plus class="h-4 w-4 mr-2" />
                    Add Experience
                </Button>
            </div>
            {#if fieldErrors.has("relevant_experience")}
                <p class="text-destructive text-sm">
                    {fieldErrors.get("relevant_experience")}
                </p>
            {/if}
        </div>
    </div>
</div>
