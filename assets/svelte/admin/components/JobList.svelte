<script lang="ts">
    import Funnel from "phosphor-svelte/lib/Funnel";
    import MagnifyingGlass from "phosphor-svelte/lib/MagnifyingGlass";
    import Plus from "phosphor-svelte/lib/Plus";
    import { onMount } from "svelte";
    import JobSearch from "../../databases/JobSearch.svelte";


    import { Button } from "$lib/components/ui/button/index.js";
    import { Badge } from "$lib/components/ui/badge/index.js";  

    const { live, jobs = [], loading = false } = $props();

    let selectedJobId = $state(null);
    
    // Local state
    let searchTerm = $state('');
    let activeOnly = $state(false);
    let showFilters = $state(false);
    let listElement;
    let isScrolling = false;
    let scrollTimeout;
    

    // Filtered inquiries using $derived
    const filteredJobs = $derived(
        jobs.filter(job => {
          if (!job?.title) return false;
          
          const matchesSearch = !searchTerm || 
            job.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
            job.description?.toLowerCase().includes(searchTerm.toLowerCase());

          return matchesSearch;
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
      activeOnly = false;
    }
    

    // Map job status to badge variant (similar to JobDetail)
    function getStatusVariant(status: string): "default" | "secondary" | "destructive" | "failed" | "pending" | "in_progress" | "complete" | "official" {
        const lowerStatus = status?.toLowerCase() || 'active'; 
        switch (lowerStatus) {
            case 'active':
                return 'complete'; // Use 'complete' (green) for Active
            case 'archived':
                return 'secondary'; // Use 'secondary' (gray) for Archived
            default:
                return 'default'; 
        }
    }

  </script>
  
  <div class="flex flex-col h-full bg-white border-r border-blue-300 overflow-hidden pt-3">
    <!-- Search and filter bar -->
    <div class="interface-search pb-3">
      <div class="flex items-center w-full">
        <div class="flex-1 mr-2">
          <JobSearch 
            bind:searchTerm 
            placeholder="Search jobs..." 
          />
        </div>
        
        <div class="flex gap-2 flex-shrink-0">
          <Button onclick={() => toggleFilters()} class="relative">
            <Funnel class="w-4 h-4" />
          </Button>
  
          <Button 
            onclick={() => createNewJob()}
            variant="default"
            disabled={loading}
          >

            <Plus class="w-4 h-4"/>

          </Button>
        </div>
      </div>
      
      <!-- Expandable filters -->
      {#if showFilters}
        <div class="mt-3 p-3 bg-gray-50 rounded-lg border border-gray-200 animate-fade-in">
          <div class="space-y-3">
            <div class="flex items-center">
              <input
                type="checkbox"
                id="active-filter"
                bind:checked={activeOnly}
                class="w-4 h-4 text-blue-600 bg-gray-100 rounded border-gray-300 focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-600 dark:bg-gray-700 dark:border-gray-600"
              />
              <label for="active-filter" class="ml-2 text-sm font-medium text-gray-700">
                Active templates only
              </label>
            </div>
          </div>

        </div>
      {/if}
    </div>
    
    <div
      class="flex-1 overflow-y-auto px-3"
      class:scrolling={isScrolling}
      bind:this={listElement}
    >
      {#if searchTerm && filteredJobs.length > 0}
        <div class="px-3 py-2 text-sm text-gray-500">
          Searching for: <span class="font-medium text-gray-700">{searchTerm}</span>
        </div>
      {/if}


      {#if filteredJobs.length === 0}
        <div class="flex flex-col items-center justify-center h-full text-gray-500">
          <p>No jobs found</p>
          {#if searchTerm}
            <Button class="mt-2" onclick={() => clearFilters()}>
              Clear Filters
            </Button>
          {/if}
        </div>
      {:else}
        <ul class="space-y-2 pb-2"> 
          {#each filteredJobs as job (job.id)}
            <li>
              <button 
                class="w-full text-left p-3 rounded-lg border transition-colors duration-150 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary-300" 
                class:bg-primary-50={selectedJobId === job.id}
                class:border-primary-300={selectedJobId === job.id}
                class:border-gray-200={selectedJobId !== job.id}
                onclick={() => selectJob(job.id)}
              >
                <div class="flex justify-between items-center">
                  <div class="flex-grow mr-4">
                    <div class="font-medium text-gray-900">
                      {job.title}
                    </div>
                    <div class="text-sm text-gray-500 mt-1">
                      {job.employer || '-'}
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
    <div class="flex justify-end items-center px-4 py-6 border-t border-gray-200 bg-primary-200 text-sm text-gray-600">
      <span>
        {filteredJobs.length} of {jobs.length} jobs
        {#if activeOnly}
          <span class="text-green-600">(showing active only)</span>
        {/if}
      </span>
    </div>
  </div>
