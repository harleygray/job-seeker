<script lang="ts">
    import { onMount } from "svelte";
    import Check from "phosphor-svelte/lib/Check";
    import Plus from "phosphor-svelte/lib/Plus";
    import { Badge } from "$lib/components/ui/badge/index.js";  
    import { Root, Trigger, Content } from "$lib/components/ui/popover/index.js";
    import ResumeExperience from "../../databases/ResumeExperience.svelte";
    import ResumeEducation from "../../databases/ResumeEducation.svelte";
    import ResumeProjects from "../../databases/ResumeProjects.svelte";
    import ResumeSkills from "../../databases/ResumeSkills.svelte";

    // Props from LiveView
    export let live;
    export let selectedResume = null;
    export let creatingResume = false;

    // Local state variables
    let editMode = false;
    let activeSection = 'experience'; // Track which section is being edited

    // Form data structure matching the Ecto schema
    let formData = {
        experience: [],
        education: [],
        projects: [],
        skills: []
    };

    // Sync form data when selectedResume or creatingResume changes
    $: {
        if (creatingResume) {
            editMode = true;
            // If selectedResume is provided by the server (even during creation), its data should populate formData.
            // Otherwise (e.g., initial click on "Create New"), initialize formData for a truly new resume.
            if (selectedResume && typeof selectedResume === 'object' && Object.keys(selectedResume).length > 0) {
                formData.experience = selectedResume.experience || [];
                formData.education = selectedResume.education || [];
                formData.projects = selectedResume.projects || [];
                formData.skills = selectedResume.skills || [];
            } else if (!selectedResume) { // Only reset if selectedResume is explicitly null/undefined
                formData = {
                    experience: [],
                    education: [],
                    projects: [],
                    skills: []
                };
            }
            // DO NOT set selectedResume = null here; let it be driven by the server.
        } else if (selectedResume) {
            editMode = false; // Or based on bind:checked
            formData.experience = selectedResume.experience || [];
            formData.education = selectedResume.education || [];
            formData.projects = selectedResume.projects || [];
            formData.skills = selectedResume.skills || [];
        } else { // No resume selected, not creating
            editMode = false;
            formData = {
                experience: [],
                education: [],
                projects: [],
                skills: []
            };
        }
    }

    // Handle saving the resume
    function saveResume() {
        console.log("Saving resume:", formData);
        if (live) {
            const event = creatingResume ? "create_resume" : "update_resume";
            const payload = creatingResume
                ? formData
                : { id: selectedResume.id, ...formData };

            live.pushEvent(event, payload, (reply) => {
                if (reply && reply.success) {
                    console.log(`Resume ${creatingResume ? 'created' : 'updated'} successfully:`, reply);
                    if (!creatingResume) {
                        editMode = false;
                    }
                } else {
                    console.error(`Error ${creatingResume ? 'creating' : 'updating'} resume:`, reply);
                }
            });
        }
    }

    // Handle canceling edit
    function cancelEdit() {
        if (creatingResume) {
            if (live) {
                live.pushEvent("cancel_create_resume", {});
            }
            editMode = false;
        } else if (selectedResume) {
            formData = {
                experience: selectedResume.experience || [],
                education: selectedResume.education || [],
                projects: selectedResume.projects || [],
                skills: selectedResume.skills || []
            };
            editMode = false;
        }
    }

    // Add new item to a section
    function addItem(section: string) {
        const newItem = {
            id: Date.now().toString(), // Temporary ID for new items
            ...getEmptyItemForSection(section)
        };
        console.log("Adding new item to section:", section, "with ID:", newItem.id);
        formData[section] = [...formData[section], newItem];
        console.log("Updated formData for section:", section, formData[section]);
        // Push the initial form data to ensure it's in the state
        if (live) {
            live.pushEvent("form_updated", { id: newItem.id, form: newItem });
        }
    }

    // Remove item from a section
    function removeItem(section: string, index: number) {
        const itemToRemove = formData[section]?.[index];
        if (itemToRemove && itemToRemove.id && live) {
            let eventName = null;
            switch (section) {
                case 'experience':
                    eventName = "remove_experience_item";
                    break;
                case 'education':
                    eventName = "remove_education_item";
                    break;
                case 'projects':
                    eventName = "remove_project_item";
                    break;
                case 'skills':
                    eventName = "remove_skill_item";
                    break;
            }
            if (eventName) {
                live.pushEvent(eventName, { id: itemToRemove.id });
            }
        }
        // No optimistic update here, let server drive the state
    }

    // Get empty item structure for each section
    function getEmptyItemForSection(section: string) {
        switch (section) {
            case 'experience':
                return {
                    company: '',
                    positions: [],
                    start_date: '',
                    end_date: '',
                    highlights: [],
                    relevant_experience: [],
                    technologies: []
                };
            case 'education':
                return {
                    institution: '',
                    courses: [],
                    highlights: []
                };
            case 'projects':
                return {
                    name: '',
                    description: '',
                    technologies: [],
                    highlights: []
                };
            case 'skills':
                return {
                    category: '',
                    items: []
                };
            default:
                return {};
        }
    }

    // Handle form updates from child components
    $: if (live) {
        live.handleEvent("form_updated", ({ id, form }) => {
            console.log("Received form_updated event for ID:", id, "form:", form);
            // ... rest of the handler
        });
    }

    onMount(() => {
        console.log("ResumeDetail mounted. Creating:", creatingResume, "Selected:", selectedResume);
        if (creatingResume) {
            editMode = true;
        }
    });
</script>

<div class="p-4 space-y-4 h-full flex flex-col bg-white">
    {#if !selectedResume && !creatingResume}
        <div class="flex-grow flex items-center justify-center text-gray-500">
            <p>Select a resume from the list or create a new one.</p>
        </div>
    {:else}
        <!-- Header and Edit Toggle -->
        <div class="flex justify-between items-center pb-2 border-b">
            <h2 class="text-xl font-semibold">
                {creatingResume ? 'Create New Resume' : 'Resume Details'}
            </h2>

            {#if !creatingResume && selectedResume}
                <div class="flex items-center space-x-4">
                    <div class="flex items-center">
                        <label for="editModeToggle" class="mr-2 text-sm font-medium text-gray-700">Edit Mode</label>
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

        <!-- Content -->
        <div class="flex-grow space-y-4 overflow-y-auto">
            <!-- Navigation Tabs -->
            <div class="border-b">
                <nav class="flex space-x-4">
                    {#each ['experience', 'education', 'projects', 'skills'] as section}
                        <button
                            class="px-3 py-2 text-sm font-medium {activeSection === section ? 'border-b-2 border-blue-500 text-blue-600' : 'text-gray-500 hover:text-gray-700'}"
                            onclick={() => activeSection = section}
                        >
                            {section.charAt(0).toUpperCase() + section.slice(1)}
                            <Badge variant="secondary" class="ml-2">
                                {formData[section]?.length || 0}
                            </Badge>
                        </button>
                    {/each}
                </nav>
            </div>

            <!-- Section Content -->
            <div class="space-y-4">
                {#if editMode}
                    <div class="flex justify-end">
                        <button
                            type="button"
                            onclick={() => addItem(activeSection)}
                            class="flex items-center px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700"
                        >
                            <Plus class="w-4 h-4 mr-1" />
                            Add {activeSection.slice(0, -1)}
                        </button>
                    </div>
                {/if}

                <!-- Experience Section -->
                {#if activeSection === 'experience'}
                    <div class="space-y-4">
                        {#each formData.experience as experienceItem, index (experienceItem.id)}
                            <div class="p-4 rounded-lg">
                                {#if editMode}
                                    <ResumeExperience
                                        experience={experienceItem}
                                        id={experienceItem.id}
                                        errors={{}}
                                        parent="resume-container"
                                        live={live}
                                        isEditing={editMode}
                                    />
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            onclick={() => removeItem('experience', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <div class="flex justify-between">
                                            <h3 class="text-lg font-medium">{experienceItem.title}</h3>
                                            <span class="text-gray-500">{experienceItem.start_date} - {experienceItem.end_date}</span>
                                        </div>
                                        <div class="text-gray-600">{experienceItem.company} • {experienceItem.location}</div>
                                        <p class="text-gray-700 whitespace-pre-wrap">{experienceItem.description}</p>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                <!-- Education Section -->
                {:else if activeSection === 'education'}
                    <div class="space-y-4">
                        {#each formData.education as educationItem, index (educationItem.id)}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <ResumeEducation
                                        education={educationItem}
                                        id={educationItem.id}
                                        errors={{}}
                                        parent="resume-container"
                                        live={live}
                                        isEditing={editMode}
                                    />
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            onclick={() => removeItem('education', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <div class="flex justify-between">
                                            <h3 class="text-lg font-medium">{educationItem.institution}</h3>
                                        </div>
                                        {#if educationItem.courses?.length > 0}
                                            <div class="text-gray-600">
                                                {#each educationItem.courses as course}
                                                    <div>{course}</div>
                                                {/each}
                                            </div>
                                        {/if}
                                        {#if educationItem.highlights?.length > 0}
                                            <div class="text-gray-700">
                                                {#each educationItem.highlights as highlight}
                                                    <div class="flex items-start gap-2">
                                                        <span class="text-gray-500">•</span>
                                                        <span>{highlight}</span>
                                                    </div>
                                                {/each}
                                            </div>
                                        {/if}
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                <!-- Projects Section -->
                {:else if activeSection === 'projects'}
                    <div class="space-y-4">
                        {#each formData.projects as project, index (project.id)}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <ResumeProjects
                                        project={project}
                                        id={project.id}
                                        errors={{}}
                                        parent="resume-container"
                                        live={live}
                                        isEditing={editMode}
                                    />
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            onclick={() => removeItem('projects', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <div class="flex justify-between items-start">
                                            <h3 class="text-lg font-medium">{project.name}</h3>
                                        </div>
                                        <p class="text-gray-700 whitespace-pre-wrap">{project.description}</p>
                                        {#if project.technologies?.length > 0}
                                            <div class="flex flex-wrap gap-2 mt-2">
                                                {#each project.technologies as tech}
                                                    <Badge variant="secondary" class="text-xs">{tech}</Badge>
                                                {/each}
                                            </div>
                                        {/if}
                                        {#if project.highlights?.length > 0}
                                            <div class="text-gray-700">
                                                {#each project.highlights as highlight}
                                                    <div class="flex items-start gap-2">
                                                        <span class="text-gray-500">•</span>
                                                        <span>{highlight}</span>
                                                    </div>
                                                {/each}
                                            </div>
                                        {/if}
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                <!-- Skills Section -->
                {:else if activeSection === 'skills'}
                    <div class="space-y-4">
                        {#each formData.skills as skill, index (skill.id)}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <ResumeSkills
                                        skill={skill}
                                        id={skill.id}
                                        errors={{}}
                                        parent="resume-container"
                                        live={live}
                                        isEditing={editMode}
                                    />
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            onclick={() => removeItem('skills', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <h3 class="text-lg font-medium">{skill.category}</h3>
                                        {#if skill.items?.length > 0}
                                            <div class="flex flex-wrap gap-2">
                                                {#each skill.items as item}
                                                    <Badge variant="secondary" class="text-xs">{item}</Badge>
                                                {/each}
                                            </div>
                                        {/if}
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>
                {/if}
            </div>
        </div>

        <!-- Action Buttons -->
        {#if editMode}
            <div class="flex justify-end gap-3 pt-4">
                <button
                    type="button"
                    onclick={cancelEdit}
                    class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
                >
                    Cancel
                </button>
                <button
                    type="button"
                    onclick={saveResume}
                    class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                    {creatingResume ? 'Create Resume' : 'Save Changes'}
                </button>
            </div>
        {/if}
    {/if}
</div>
