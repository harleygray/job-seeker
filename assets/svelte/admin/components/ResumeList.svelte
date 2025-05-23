<script lang="ts">
    import Funnel from "phosphor-svelte/lib/Funnel";
    import MagnifyingGlass from "phosphor-svelte/lib/MagnifyingGlass";
    import Plus from "phosphor-svelte/lib/Plus";
    import CircleNotch from "phosphor-svelte/lib/CircleNotch";
    import ResumeSearch from "../../databases/ResumeSearch.svelte";

    import * as Select from "$lib/components/ui/select/index.js";
    import { Button } from "$lib/components/ui/button/index.js";
    import { Badge } from "$lib/components/ui/badge/index.js";

    const { live, resumes = [], loading = false } = $props();

    let selectedResumeId = $state(null);

    // Local state
    let searchTerm = $state("");
    let filterType = $state("all");
    let showFilters = $state(false);
    let listElement;

    // Filter options for the select
    const typeOptions = [
        { value: "all", label: "All Types" },
        { value: "experience", label: "Experience" },
        { value: "education", label: "Education" },
        { value: "projects", label: "Projects" },
        { value: "skills", label: "Skills" },
    ];

    // Get the display text for the currently selected value
    const typeTriggerContent = $derived(
        typeOptions.find((f) => f.value === filterType)?.label ?? "Select Type",
    );

    // Filtered resumes using $derived
    const filteredResumes = $derived(
        resumes.filter((resume) => {
            if (!resume) return false;

            const matchesSearch =
                !searchTerm ||
                resume.experience?.some(
                    (exp) =>
                        exp.title
                            ?.toLowerCase()
                            .includes(searchTerm.toLowerCase()) ||
                        exp.description
                            ?.toLowerCase()
                            .includes(searchTerm.toLowerCase()),
                ) ||
                resume.education?.some(
                    (edu) =>
                        edu.school
                            ?.toLowerCase()
                            .includes(searchTerm.toLowerCase()) ||
                        edu.degree
                            ?.toLowerCase()
                            .includes(searchTerm.toLowerCase()),
                ) ||
                resume.projects?.some(
                    (proj) =>
                        proj.name
                            ?.toLowerCase()
                            .includes(searchTerm.toLowerCase()) ||
                        proj.description
                            ?.toLowerCase()
                            .includes(searchTerm.toLowerCase()),
                ) ||
                resume.skills?.some((skill) =>
                    skill.name
                        ?.toLowerCase()
                        .includes(searchTerm.toLowerCase()),
                );

            const matchesType =
                filterType === "all" ||
                (filterType === "experience" &&
                    resume.experience?.length > 0) ||
                (filterType === "education" && resume.education?.length > 0) ||
                (filterType === "projects" && resume.projects?.length > 0) ||
                (filterType === "skills" && resume.skills?.length > 0);

            return matchesSearch && matchesType;
        }),
    );

    // Filtered count for the footer
    const filteredCount = $derived(filteredResumes.length);
    const totalCount = $derived(resumes.length);

    // Handle resume selection
    function selectResume(id) {
        if (live) {
            live.pushEvent("select_resume", { id });
            selectedResumeId = id;
        }
    }

    // Handle creating new resume
    function createNewResume() {
        if (live) {
            live.pushEvent("create_new_resume", {}, (reply) => {
                if (reply && reply.success) {
                    console.log("Create new resume initiated:", reply.message);
                }
            });
        }
    }

    // Toggle filters visibility
    function toggleFilters() {
        showFilters = !showFilters;
    }

    // Clear all filters
    function clearFilters() {
        searchTerm = "";
        filterType = "all";
    }

    // Get type badge variant
    function getTypeVariant(
        type: string,
    ):
        | "default"
        | "secondary"
        | "destructive"
        | "failed"
        | "pending"
        | "in_progress"
        | "complete"
        | "official" {
        switch (type?.toLowerCase()) {
            case "experience":
                return "complete";
            case "education":
                return "secondary";
            case "projects":
                return "default";
            case "skills":
                return "pending";
            default:
                return "default";
        }
    }

    // Add this helper function in the <script> block
    function timeSince(dateString: string): string {
        if (!dateString) return "-";
        const now = new Date();
        const date = new Date(dateString);
        const seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

        const intervals = [
            { label: "year", seconds: 31536000 },
            { label: "month", seconds: 2592000 },
            { label: "day", seconds: 86400 },
            { label: "hour", seconds: 3600 },
            { label: "minute", seconds: 60 },
            { label: "second", seconds: 1 }
        ];

        for (const interval of intervals) {
            const count = Math.floor(seconds / interval.seconds);
            if (count >= 1) {
                return `${count} ${interval.label}${count > 1 ? "s" : ""} ago`;
            }
        }
        return "just now";
    }
</script>

<div class="resume-container">
    <!-- Search and filter bar -->
    <div class="resume-search">
        <div class="flex items-center w-full">
            <div class="flex-1 mr-2">
                <ResumeSearch bind:searchTerm placeholder="Search resumes..." />
            </div>

            <div class="flex gap-2 flex-shrink-0">
                <Button
                    variant="action_secondary"
                    size="sm"
                    onclick={toggleFilters}
                >
                    <Funnel class="w-5 h-5 font-bold" />
                </Button>

                <Button
                    variant="action_primary"
                    size="sm"
                    onclick={createNewResume}
                    disabled={loading}
                >
                    <Plus class="w-5 h-5 font-bold" />
                </Button>
            </div>
        </div>

        <!-- Expandable filters -->
        {#if showFilters}
            <div
                class="mt-3 p-3 bg-gray-50 rounded-lg border border-gray-200 animate-fade-in"
            >
                <div class="space-y-3">
                    <div class="w-full">
                        <Select.Root type="single" bind:value={filterType}>
                            <Select.Trigger class="w-full">
                                {typeTriggerContent}
                            </Select.Trigger>
                            <Select.Content>
                                {#each typeOptions as option}
                                    <Select.Item value={option.value}>
                                        {option.label}
                                    </Select.Item>
                                {/each}
                            </Select.Content>
                        </Select.Root>
                    </div>
                </div>

                <div class="mt-3 flex justify-end">
                    <Button variant="outline" size="sm" onclick={clearFilters}>
                        Clear Filters
                    </Button>
                </div>
            </div>
        {/if}
    </div>

    <div
        class="resume-list flex-1 overflow-y-auto px-4 pt-2 pb-0"
        bind:this={listElement}
    >
        {#if loading}
            <div class="flex justify-center items-center h-full">
                <CircleNotch class="w-8 h-8 animate-spin text-gray-500" />
            </div>
        {:else if filteredResumes.length === 0}
            <div
                class="flex flex-col items-center justify-center h-full text-gray-500"
            >
                <p>No resumes found</p>
                {#if searchTerm || filterType !== "all"}
                    <Button
                        variant="outline"
                        size="sm"
                        class="mt-2"
                        onclick={clearFilters}
                    >
                        Clear Filters
                    </Button>
                {/if}
            </div>
        {:else}
            <ul class="space-y-2 pb-2">
                {#each filteredResumes as resume (resume.id)}
                    <li>
                        <button
                            class="w-full text-left p-3 rounded-lg border transition-colors duration-150 hover:bg-gray-50 focus:outline-none focus:ring focus:ring-primary-300"
                            class:bg-primary-50={selectedResumeId === resume.id}
                            class:border-primary-300={selectedResumeId ===
                                resume.id}
                            class:border-gray-200={selectedResumeId !==
                                resume.id}
                            onclick={() => selectResume(resume.id)}
                        >
                            <div class="flex justify-between items-start">
                                <div class="flex-grow">
                                    <div class="font-medium text-gray-900">
                                        {resume.name ||
                                            resume.experience?.[0]?.title ||
                                            "Untitled Resume"}
                                    </div>
                                    <div class="text-sm text-gray-600 mt-1">
                                        <span class="inline-block mr-2">
                                            Created: {resume.created_at
                                                ? new Date(
                                                      resume.created_at,
                                                  ).toLocaleDateString(
                                                      undefined,
                                                      {
                                                          year: "numeric",
                                                          month: "short",
                                                          day: "numeric",
                                                      },
                                                  )
                                                : "-"}
                                        </span>
                                        <span class="inline-block mr-2">
                                            Edited: {resume.updated_at ? timeSince(resume.updated_at) : "-"}
                                        </span>

                                    </div>
                                </div>
                            </div>
                        </button>
                    </li>
                {/each}
            </ul>
        {/if}
    </div>

    <!-- Status bar - fixed at bottom -->
    <div class="resume-footer">
        <span>
            {filteredResumes.length} of {resumes.length} resumes
            {#if filterType !== "all"}
                <span class="text-green-600">(showing {filterType} only)</span>
            {/if}
        </span>
    </div>
</div>

<style>
    /* Main container */
    .resume-container {
        display: flex;
        flex-direction: column;
        height: 100%;
        background-color: white;
        border-right: 1px solid #93c5fd;
    }

    /* Search area */
    .resume-search {
        padding: 16px 16px 12px 16px;
    }

    /* List area */
    .resume-list {
        flex: 1;
        overflow-y: auto;
    }

    /* Footer */
    .resume-footer {
        display: flex;
        justify-content: right;
        align-items: center;
        padding: 24px 16px;
        border-top: 1px solid #e5e7eb;
        background-color: primary-200;
        font-size: 0.875rem;
        color: #4b5563;
    }
</style>
