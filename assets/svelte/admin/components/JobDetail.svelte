<script lang="ts">
    import { onMount } from "svelte";
    import Check from "phosphor-svelte/lib/Check"; // Import Check icon
    import DocsPreview from "./DocsPreview.svelte";

    import { Badge } from "$lib/components/ui/badge/index.js";
    import {
        Root,
        Trigger,
        Content,
    } from "$lib/components/ui/popover/index.js"; // Corrected import path

    // Props from LiveView
    export let live;
    export let selectedJob = null; // Renamed from selectedTemplate
    export let creatingJob = false; // Prop to indicate new job creation mode

    // Local state variables
    let editMode = false;
    let statusPopoverOpen = false; // State for popover visibility
    const statusOptions = ["Active", "Archived"]; // Simplified status options
    let activeTab = "details"; // Add active tab state

    let formData = {
        title: "",
        description: "",
        status: "Pending", // Example status field
        employer: "", // Add employer
        location: "", // Add location
        salary: "",
        apply_link: "",
        seek_job_id: "",
        formatted_description: "",
        data_analyst_score: 0,
        data_engineer_score: 0,
        data_scientist_score: 0,
        software_engineer_score: 0,
        ai_engineer_score: 0,
        product_owner_score: 0,
        applied: false,
        archived: false,
    };

    // Sync form data when selectedJob or creatingJob changes
    $: {
        if (creatingJob) {
            console.log("Creating new job, enabling edit mode.");
            editMode = true;
            formData = {
                title: "",
                description: "",
                status: "Pending",
                employer: "", // Reset employer
                location: "", // Reset location
                salary: "",
                apply_link: "",
                seek_job_id: "",
                formatted_description: "",
                data_analyst_score: 0,
                data_engineer_score: 0,
                data_scientist_score: 0,
                software_engineer_score: 0,
                ai_engineer_score: 0,
                product_owner_score: 0,
                applied: false,
                archived: false,
            };
            selectedJob = null; // Clear selected job when creating a new one
        } else if (selectedJob) {
            console.log("Selected job updated:", selectedJob);
            editMode = false; // Default to view mode when a job is selected
            formData = {
                title: selectedJob.title || "",
                description: selectedJob.description || "",
                status: selectedJob.status || "Pending", // Use job status or default
                employer: selectedJob.employer || "", // Populate employer
                location: selectedJob.location || "", // Populate location
                salary: selectedJob.salary || "",
                apply_link: selectedJob.apply_link || "",
                seek_job_id: selectedJob.seek_job_id || "",
                formatted_description: selectedJob.formatted_description || "",
                data_analyst_score: selectedJob.data_analyst_score || 0,
                data_engineer_score: selectedJob.data_engineer_score || 0,
                data_scientist_score: selectedJob.data_scientist_score || 0,
                software_engineer_score:
                    selectedJob.software_engineer_score || 0,
                ai_engineer_score: selectedJob.ai_engineer_score || 0,
                product_owner_score: selectedJob.product_owner_score || 0,
                applied: selectedJob.applied || false,
                archived: selectedJob.archived || false,
            };
        } else {
            // No job selected and not creating a new one
            editMode = false;
            formData = {
                title: "",
                description: "",
                status: "",
                employer: "",
                location: "",
                salary: "",
                apply_link: "",
                seek_job_id: "",
                formatted_description: "",
                data_analyst_score: 0,
                data_engineer_score: 0,
                data_scientist_score: 0,
                software_engineer_score: 0,
                ai_engineer_score: 0,
                product_owner_score: 0,
                applied: false,
                archived: false,
            };
        }
    }

    // Function to update job status via Popover
    function updateJobStatus(newStatus: string) {
        if (!selectedJob || !live) {
            console.error(
                "Cannot update status: No selected job or live connection.",
            );
            statusPopoverOpen = false;
            return;
        }

        console.log(
            `Updating status for job ${selectedJob.id} to: ${newStatus}`,
        );
        // Update local state optimistically - relies on backend to confirm
        formData.status = newStatus;
        // Update underlying boolean based on new simplified status
        formData.archived = newStatus === "Archived";
        // formData.applied can be handled separately or removed if not needed

        // Push only the changed status to the backend
        live.pushEvent(
            "update_job",
            { id: selectedJob.id, status: newStatus },
            (reply) => {
                if (reply && reply.success) {
                    console.log("Status updated successfully:", reply);
                    // LiveView should send back the updated job, triggering the reactive block
                } else {
                    console.error("Error updating status:", reply);
                    // Revert optimistic update on error
                    // Fetching the current selectedJob might be needed to get the true state back
                    // For now, just log the error.
                }
            },
        );

        statusPopoverOpen = false; // Close popover after selection
    }

    // Map job status to badge variant
    function getStatusVariant(
        status: string,
    ):
        | "default"
        | "secondary"
        | "destructive"
        | "failed"
        | "pending"
        | "in_progress"
        | "complete"
        | "official" {
        const lowerStatus = status?.toLowerCase() || "active";
        switch (lowerStatus) {
            case "active":
                return "complete"; // Use 'complete' (green) for Active
            case "archived":
                return "secondary"; // Use 'secondary' (gray) for Archived
            default:
                return "default";
        }
    }

    // Handle saving the job (placeholder)
    function saveJob() {
        console.log("Saving job:", formData);
        if (live) {
            const event = creatingJob ? "create_job" : "update_job";
            const payload = creatingJob
                ? formData
                : { id: selectedJob.id, ...formData };

            live.pushEvent(event, payload, (reply) => {
                if (reply && reply.success) {
                    console.log(
                        `Job ${creatingJob ? "created" : "updated"} successfully:`,
                        reply,
                    );
                    if (!creatingJob) {
                        editMode = false; // Exit edit mode after successful update
                    }
                    // Optionally reset creatingJob state via LiveView event if needed
                } else {
                    console.error(
                        `Error ${creatingJob ? "creating" : "updating"} job:`,
                        reply,
                    );
                }
            });
        }
    }

    // Handle canceling edit
    function cancelEdit() {
        if (creatingJob) {
            // If creating, maybe push an event to reset the view state in LiveView?
            // Or simply clear the form and exit edit mode locally.
            // For now, let's just revert to the initial state.
            if (live) {
                live.pushEvent("cancel_create_job", {});
            }
            editMode = false; // Exit edit mode
        } else if (selectedJob) {
            // If editing existing, revert changes and exit edit mode
            formData = {
                title: selectedJob.title || "",
                description: selectedJob.description || "",
                status: selectedJob.status || "Pending",
                employer: selectedJob.employer || "",
                location: selectedJob.location || "",
                salary: selectedJob.salary || "",
                apply_link: selectedJob.apply_link || "",
                seek_job_id: selectedJob.seek_job_id || "",
                formatted_description: selectedJob.formatted_description || "",
                data_analyst_score: selectedJob.data_analyst_score || 0,
                data_engineer_score: selectedJob.data_engineer_score || 0,
                data_scientist_score: selectedJob.data_scientist_score || 0,
                software_engineer_score:
                    selectedJob.software_engineer_score || 0,
                ai_engineer_score: selectedJob.ai_engineer_score || 0,
                product_owner_score: selectedJob.product_owner_score || 0,
                applied: selectedJob.applied || false,
                archived: selectedJob.archived || false,
            };
            editMode = false;
        }
    }

    onMount(() => {
        console.log(
            "JobDetail mounted. Creating:",
            creatingJob,
            "Selected:",
            selectedJob,
        );
        // If initially in creating mode, ensure editMode is set
        if (creatingJob) {
            editMode = true;
        }
    });
</script>

<div class="h-full flex flex-col bg-white">
    {#if !selectedJob && !creatingJob}
        <div class="flex-grow flex items-center justify-center text-gray-500">
            <p>Select a job from the list or create a new one.</p>
        </div>
    {:else}
        <!-- Header and Edit Toggle -->
        <div
            class="flex justify-between items-center p-4 border-b flex-shrink-0"
        >
            <!-- Title and Status -->
            <div class="flex items-center gap-3">
                <h2 class="text-xl font-semibold">
                    {creatingJob
                        ? "Create New Job"
                        : selectedJob?.title || "Job Details"}
                </h2>
                <!-- Status Popover (Moved Here) -->
                {#if selectedJob || creatingJob}
                    <Root bind:open={statusPopoverOpen}>
                        <Trigger class="text-left">
                            <button type="button" class="p-0">
                                <Badge
                                    variant={getStatusVariant(formData.status)}
                                    class="text-xs cursor-pointer hover:opacity-80 capitalize justify-start py-1 px-2 border {selectedJob
                                        ? 'border-gray-300'
                                        : 'border-dashed border-gray-400'}"
                                >
                                    {formData.status}
                                </Badge>
                            </button>
                        </Trigger>
                        {#if selectedJob}
                            <Content
                                class="z-50 w-[300px] rounded-md border bg-white p-4 shadow-md"
                            >
                                <div class="flex flex-col gap-2">
                                    <p class="text-sm font-medium mb-2">
                                        Update Status
                                    </p>
                                    <div class="grid grid-cols-2 gap-2">
                                        {#each statusOptions as status}
                                            <button
                                                type="button"
                                                class="capitalize {status ===
                                                formData.status
                                                    ? 'bg-blue-600 text-white'
                                                    : 'bg-gray-100 border border-gray-200'} p-2 rounded-md hover:bg-opacity-90 text-sm"
                                                onclick={() =>
                                                    updateJobStatus(status)}
                                            >
                                                <div
                                                    class="flex items-center justify-center gap-2"
                                                >
                                                    {#if status === formData.status}
                                                        <Check
                                                            class="w-4 h-4"
                                                        />
                                                    {/if}
                                                    <span>{status}</span>
                                                </div>
                                            </button>
                                        {/each}
                                    </div>
                                </div>
                            </Content>
                        {:else}
                            <!-- Optionally show a message if trying to change status for a non-existent job -->
                        {/if}
                    </Root>
                {:else}
                    <Badge variant="secondary" class="text-xs italic"
                        >No Job Selected</Badge
                    >
                {/if}
            </div>

            {#if !creatingJob && selectedJob}
                <!-- Controls: Edit -->
                <div class="flex items-center space-x-4">
                    <!-- Edit Mode Toggle -->
                    <div class="flex items-center">
                        <label
                            for="editModeToggle"
                            class="mr-2 text-sm font-medium text-gray-700"
                            >Edit Mode</label
                        >
                        <input
                            type="checkbox"
                            id="editModeToggle"
                            bind:checked={editMode}
                            class="w-4 h-4 text-blue-600 bg-gray-100 rounded border-gray-300 focus:ring-blue-500"
                        />
                    </div>
                </div>
            {/if}
        </div>

        <!-- Tabs -->
        <div class="border-b flex-shrink-0 px-4">
            <nav class="flex space-x-4">
                <button
                    class="px-3 py-2 text-sm font-medium {activeTab ===
                    'details'
                        ? 'border-b-2 border-blue-500 text-blue-600'
                        : 'text-gray-500 hover:text-gray-700'}"
                    onclick={() => (activeTab = "details")}
                >
                    Details
                </button>
                {#if selectedJob}
                    <button
                        class="px-3 py-2 text-sm font-medium {activeTab ===
                        'documents'
                            ? 'border-b-2 border-blue-500 text-blue-600'
                            : 'text-gray-500 hover:text-gray-700'}"
                        onclick={() => (activeTab = "documents")}
                    >
                        Documents
                    </button>
                {/if}
            </nav>
        </div>

        <!-- Tab Content -->
        <div class="flex-grow overflow-y-scroll min-h-0">
            <div class="p-4 bg-white">
                {#if activeTab === "details"}
                    <!-- Form Fields -->
                    <div class="space-y-4">
                        <!-- Title and Employer Row -->
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label
                                    for="jobTitle"
                                    class="block text-sm font-medium text-gray-700 mb-1"
                                    >Title</label
                                >
                                {#if editMode}
                                    <input
                                        type="text"
                                        id="jobTitle"
                                        bind:value={formData.title}
                                        class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                        placeholder="Enter job title"
                                    />
                                {:else}
                                    <div
                                        class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                    >
                                        {formData.title || "-"}
                                    </div>
                                {/if}
                            </div>
                            <div>
                                <label
                                    for="jobEmployer"
                                    class="block text-sm font-medium text-gray-700 mb-1"
                                    >Employer</label
                                >
                                {#if editMode}
                                    <input
                                        type="text"
                                        id="jobEmployer"
                                        bind:value={formData.employer}
                                        class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                        placeholder="Enter employer name"
                                    />
                                {:else}
                                    <div
                                        class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                    >
                                        {formData.employer || "-"}
                                    </div>
                                {/if}
                            </div>
                        </div>

                        <div>
                            <label
                                for="jobDescription"
                                class="block text-sm font-medium text-gray-700 mb-1"
                                >Description</label
                            >
                            {#if editMode}
                                <textarea
                                    id="jobDescription"
                                    bind:value={formData.description}
                                    rows="4"
                                    class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                    placeholder="Enter job description"
                                ></textarea>
                            {:else}
                                <div
                                    class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[90px] whitespace-pre-wrap"
                                >
                                    {formData.description || "-"}
                                </div>
                            {/if}
                        </div>

                        <!-- Location and Salary Fields -->
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <label
                                    for="jobLocation"
                                    class="block text-sm font-medium text-gray-700 mb-1"
                                    >Location</label
                                >
                                {#if editMode}
                                    <input
                                        type="text"
                                        id="jobLocation"
                                        bind:value={formData.location}
                                        class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                        placeholder="Enter job location"
                                    />
                                {:else}
                                    <div
                                        class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                    >
                                        {formData.location || "-"}
                                    </div>
                                {/if}
                            </div>
                            <!-- Salary -->
                            <div>
                                <label
                                    for="jobSalary"
                                    class="block text-sm font-medium text-gray-700 mb-1"
                                    >Salary</label
                                >
                                {#if editMode}
                                    <input
                                        type="text"
                                        id="jobSalary"
                                        bind:value={formData.salary}
                                        class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                        placeholder="e.g., $100k - $120k, Competitive"
                                    />
                                {:else}
                                    <div
                                        class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                    >
                                        {formData.salary || "-"}
                                    </div>
                                {/if}
                            </div>
                        </div>

                        <!-- Apply Link -->
                        <div>
                            <label
                                for="jobApplyLink"
                                class="block text-sm font-medium text-gray-700 mb-1"
                                >Apply Link</label
                            >
                            {#if editMode}
                                <input
                                    type="url"
                                    id="jobApplyLink"
                                    bind:value={formData.apply_link}
                                    class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                    placeholder="https://example.com/apply"
                                />
                            {:else}
                                <div
                                    class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                >
                                    {#if formData.apply_link}
                                        <a
                                            href={formData.apply_link}
                                            target="_blank"
                                            class="text-blue-600 hover:underline font-medium"
                                            >Apply link</a
                                        >
                                    {:else}
                                        -
                                    {/if}
                                </div>
                            {/if}
                        </div>

                        <!-- Seek Job ID -->
                        <div>
                            <label
                                for="jobSeekJobId"
                                class="block text-sm font-medium text-gray-700 mb-1"
                                >Seek Job ID</label
                            >
                            {#if editMode}
                                <input
                                    type="text"
                                    id="jobSeekJobId"
                                    bind:value={formData.seek_job_id}
                                    class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                    placeholder="Seek Job ID (if applicable)"
                                />
                            {:else}
                                <div
                                    class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                >
                                    {formData.seek_job_id || "-"}
                                </div>
                            {/if}
                        </div>

                        <!-- Formatted Description -->
                        <div>
                            <label
                                for="jobFormattedDescription"
                                class="block text-sm font-medium text-gray-700 mb-1"
                                >Formatted Description</label
                            >
                            {#if editMode}
                                <textarea
                                    id="jobFormattedDescription"
                                    bind:value={formData.formatted_description}
                                    rows="6"
                                    class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 font-mono text-sm"
                                    placeholder="Formatted job description (e.g., Markdown)"
                                ></textarea>
                            {:else}
                                <div
                                    class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[120px] whitespace-pre-wrap"
                                >
                                    {formData.formatted_description || "-"}
                                </div>
                            {/if}
                        </div>

                        <!-- Scores Grid -->
                        <div class="grid grid-cols-3 gap-4 pt-2 border-t mt-4">
                            {#each [{ key: "data_analyst_score", label: "Data Analyst" }, { key: "data_engineer_score", label: "Data Engineer" }, { key: "data_scientist_score", label: "Data Scientist" }, { key: "software_engineer_score", label: "Software Engineer" }, { key: "ai_engineer_score", label: "AI Engineer" }, { key: "product_owner_score", label: "Product Owner" }] as score}
                                <div>
                                    <label
                                        for={`job${score.key}`}
                                        class="block text-sm font-medium text-gray-700 mb-1"
                                        >{score.label} Score</label
                                    >
                                    {#if editMode}
                                        <input
                                            type="number"
                                            id={`job${score.key}`}
                                            bind:value={formData[score.key]}
                                            class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
                                            placeholder="0"
                                            min="0"
                                            max="100"
                                        />
                                    {:else}
                                        <div
                                            class="p-2 bg-gray-50 border border-gray-200 rounded-md min-h-[40px]"
                                        >
                                            {formData[score.key] || 0}
                                        </div>
                                    {/if}
                                </div>
                            {/each}
                        </div>
                    </div>
                {:else if activeTab === "documents"}
                    <!-- Documents Tab -->
                    <div class="w-full">
                        <DocsPreview {editMode} {selectedJob} {live} />
                    </div>
                {/if}
            </div>
        </div>

        <!-- Action Buttons -->
        {#if editMode && activeTab === "details"}
            <div class="flex justify-end gap-3 p-4 border-t flex-shrink-0">
                <button
                    type="button"
                    onclick={cancelEdit}
                    class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
                >
                    Cancel
                </button>
                <button
                    type="button"
                    onclick={saveJob}
                    class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                    {creatingJob ? "Create Job" : "Save Changes"}
                </button>
            </div>
        {/if}
    {/if}
</div>
