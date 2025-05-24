<script lang="ts">
    import Funnel from "phosphor-svelte/lib/Funnel";
    import MagnifyingGlass from "phosphor-svelte/lib/MagnifyingGlass";
    import Plus from "phosphor-svelte/lib/Plus";
    import CircleNotch from "phosphor-svelte/lib/CircleNotch";
    import JobSearch from "../../databases/JobSearch.svelte";

    import * as Select from "$lib/components/ui/select/index.js";
    import { Button } from "$lib/components/ui/button/index.js";
    import { Badge } from "$lib/components/ui/badge/index.js";  

    const { live, jobs = [], loading = false } = $props();

    let selectedJobId = $state(null);
    
    // Local state
    let searchTerm = $state('');
    let filterStatus = $state('all');
    let showFilters = $state(false);
    let listElement;

    // Status options for the select
    const statusOptions = [
        { value: 'all', label: 'All Statuses' },
        { value: 'active', label: 'Active' },
        { value: 'archived', label: 'Archived' }
    ];

    // Get the display text for the currently selected value
    const statusTriggerContent = $derived(
        statusOptions.find((f) => f.value === filterStatus)?.label ?? 'Select Status'
    );

    // Filtered jobs using $derived
    const filteredJobs = $derived(
        jobs.filter(job => {
          if (!job?.title) return false;
          
          const matchesSearch = !searchTerm || 
            job.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
            job.description?.toLowerCase().includes(searchTerm.toLowerCase());

          const matchesStatus = filterStatus === 'all' || job.status?.toLowerCase() === filterStatus.toLowerCase();

          return matchesSearch && matchesStatus;
        })
    );
      
    // Filtered count for the footer
    const filteredCount = $derived(filteredJobs.length);
    const totalCount = $derived(jobs.length);

    // Handle template selection
    function selectJob(id) {
      if (live) {
        live.pushEvent("select_job", { id });
        selectedJobId = id;
      }
    }
    
    // Handle creating new job
    function createNewJob() {
      if (live) {
        live.pushEvent("create_new_job", {}, (reply) => {
          if (reply && reply.success) {
            console.log("Create new job initiated:", reply.message);
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
      searchTerm = '';
      filterStatus = 'all';
    }
    
    // Map job status to badge variant
    function getStatusVariant(status: string): "default" | "secondary" | "destructive" | "failed" | "pending" | "in_progress" | "complete" | "official" {
        const lowerStatus = status?.toLowerCase() || 'active'; 
        switch (lowerStatus) {
            case 'active':
                return 'complete';
            case 'archived':
                return 'secondary';
            default:
                return 'default'; 
        }
    }


</script>
  
    <div class="job-container h-full flex flex-col">
    <!-- Search and filter bar -->
    <div class="job-search flex-shrink-0">
        <div class="flex items-center w-full">
            <div class="flex-1 mr-2">
                <JobSearch
                    bind:searchTerm
                    placeholder="Search jobs..."
                />
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
                    onclick={createNewJob}
                    disabled={loading}
                >
                    <Plus class="w-5 h-5 font-bold" />
                </Button>
            </div>
        </div>

        <!-- Expandable filters -->
        {#if showFilters}
            <div class="mt-3 p-3 bg-gray-50 rounded-lg border border-gray-200 animate-fade-in">
                <div class="space-y-3">
                    <div class="w-full">
                        <Select.Root type="single" bind:value={filterStatus}>
                            <Select.Trigger class="w-full">
                                {statusTriggerContent}
                            </Select.Trigger>
                            <Select.Content>
                                {#each statusOptions as option}
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
    
    <div class="job-list flex-grow overflow-y-auto min-h-0 px-4 pt-2 pb-0" bind:this={listElement}>
        {#if loading}
            <div class="flex justify-center items-center h-full">
                <CircleNotch class="w-8 h-8 animate-spin text-gray-500" />
            </div>
        {:else if filteredJobs.length === 0}
            <div class="flex flex-col items-center justify-center h-full text-gray-500">
                <p>No jobs found</p>
                {#if searchTerm || filterStatus !== "all"}
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
                {#each filteredJobs as job (job.id)}
                    <li>
                        <button 
                            class="w-full text-left p-3 rounded-lg border transition-colors duration-150 hover:bg-gray-50 focus:outline-none focus:ring focus:ring-primary-300"
                            class:bg-primary-50={selectedJobId === job.id}
                            class:border-primary-300={selectedJobId === job.id}
                            class:border-gray-200={selectedJobId !== job.id}
                            onclick={() => selectJob(job.id)}
                        >
                            <div class="flex justify-between items-start">
                                <div class="flex-grow">
                                    <div class="font-medium text-gray-900">
                                        {job.title}
                                    </div>
                                    <div class="text-sm text-gray-600 mt-1">
                                        <span class="inline-block mr-2">
                                            {job.employer || '-'}
                                        </span>
                                    </div>
                                </div>
                                {#if job.status}
                                    <Badge 
                                        variant={getStatusVariant(job.status)}
                                        class="text-xs flex-shrink-0 capitalize"
                                    >
                                        {job.status}
                                    </Badge>
                                {/if}
                            </div>
                        </button>
                    </li>
                {/each}
            </ul>
        {/if}
    </div>
    
    <!-- Status bar - fixed at bottom -->
    <div class="job-footer flex-shrink-0">
        <span>
            {filteredJobs.length} of {jobs.length} jobs
            {#if filterStatus !== 'all'}
                <span class="text-green-600">(showing {filterStatus === 'active' ? 'active' : 'archived'} only)</span>
            {/if}
        </span>
    </div>
</div>

<style>
    /* Main container */
    .job-container {
        display: flex;
        flex-direction: column;
        height: 100%;
        background-color: white;
        border-right: 1px solid #93c5fd;
    }

    /* Search area */
    .job-search {
        padding: 16px 16px 12px 16px;
        background-color: white;
    }

    /* List area */
    .job-list {
        flex: 1;
        overflow-y: auto;
        background-color: white;
    }

    /* Footer */
    .job-footer {
        display: flex;
        justify-content: right;
        align-items: center;
        padding: 12px 16px;
        border-top: 1px solid #e5e7eb;
        background-color: white;
        font-size: 0.875rem;
        color: #4b5563;
    }
</style>
