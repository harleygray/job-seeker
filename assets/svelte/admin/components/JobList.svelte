<script lang="ts">
    import Funnel from "phosphor-svelte/lib/Funnel";
    import MagnifyingGlass from "phosphor-svelte/lib/MagnifyingGlass";
    import Plus from "phosphor-svelte/lib/Plus";
    import { onMount } from "svelte";

    import { Command } from "bits-ui";

    import { Button } from "$lib/components/ui/button/index.js";
    import { Badge } from "$lib/components/ui/badge/index.js";  

    // Props
    export let live;

    export let jobs = [];
    export let loading = false;
    export let selectedJobId = null;
    
    // Local state
    let searchTerm = '';
    let activeOnly = true; // Default to showing only active jobs
    let showFilters = false;
    let listElement;
    let isScrolling = false;
    let scrollTimeout;
    
    // Log jobs when component mounts
    onMount(() => {
      console.log('JobList mounted with jobs:', jobs);
      
      // Clean up on component destroy
      return () => {
        if (scrollTimeout) {
          clearTimeout(scrollTimeout);
        }
      };
    });
    
    // Filter jobs based on search and filters
    $: filteredJobs = jobs.filter(job => {
      // Ensure job has the expected properties
      if (!job || !job.title) {
        console.warn('Invalid job object:', job);
        return false;
      }
      
      // Search filter
      const matchesSearch = searchTerm === '' || 
        job.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
        job.description?.toLowerCase().includes(searchTerm.toLowerCase());
      
  
      // Active filter (Temporarily removed for debugging)
      // const matchesActive = !activeOnly || job.is_active;
      
      // return matchesSearch && matchesActive;
      return matchesSearch; // Only apply search filter for now
    });
    
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
    
    // Format date for display
    function formatDate(dateString) {
      if (!dateString) return 'N/A';
      
      try {
        const date = new Date(dateString);
        // Check if date is valid
        if (isNaN(date.getTime())) return 'Invalid date';
        
        return new Intl.DateTimeFormat('en-GB', {
          day: '2-digit',
          month: 'short',
          year: 'numeric'
        }).format(date);
      } catch (error) {
        console.error('Error formatting date:', error);
        return 'Invalid date';
      }
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
          <Command.Root class="w-full">
            <Command.Input 
              class="focus-override h-input placeholder:text-foreground-alt/50 focus:outline-hidden bg-background inline-flex truncate w-full rounded-lg border border-gray-300 px-3 py-2 text-sm transition-colors focus:ring-primary-500 focus:border-primary-500"
              placeholder="Search templates..." 
              bind:value={searchTerm}
            />
            <!-- We only need the input for now, Command.List etc. are not required for this use case -->
          </Command.Root>
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
        <ul class="pb-2 w-full">
          {#each filteredJobs as job (job.id)}
            <li>
              <Button 
                variant={selectedJobId === job.id ? 'list_item_active' : 'list_item_inactive'} 
                size="item"
                onclick={() => selectJob(job.id)}
              >
                <div class="flex justify-between items-center"> 
                  <div class="flex-grow mr-4"> 
                    <div class="font-medium text-gray-900">{job.title}</div>
                    <div class="text-sm text-gray-500 mt-1">{job.employer || '-'}</div>
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
              </Button>
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
