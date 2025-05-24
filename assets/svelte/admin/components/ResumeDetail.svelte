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
        name: '',
        experience: [],
        education: [],
        projects: [],
        skills: []
    };

    let previousSelectedResumeId = null;

    // Helper function to sort experience items by start_date (most recent first)
    function sortExperienceByDate(experienceArray) {
        if (!Array.isArray(experienceArray)) return [];
        return [...experienceArray].sort((a, b) => {
            const dateAValid = a.start_date && !isNaN(new Date(a.start_date).getTime());
            const dateBValid = b.start_date && !isNaN(new Date(b.start_date).getTime());

            if (dateAValid && !dateBValid) return -1; // a comes before b (more recent)
            if (!dateAValid && dateBValid) return 1;  // b comes before a
            if (!dateAValid && !dateBValid) return 0; // Keep original order for two invalid/missing dates

            // Both dates are valid, compare them
            const dateA = new Date(a.start_date);
            const dateB = new Date(b.start_date);
            return dateB.getTime() - dateA.getTime(); // Descending order
        });
    }

    // Sync form data when selectedResume or creatingResume changes
    $: {
        const currentResumeId = selectedResume ? selectedResume.id : null;

        if (creatingResume) {
            editMode = true; // When creating, always start in edit mode.
            if (selectedResume && typeof selectedResume === 'object' && Object.keys(selectedResume).length > 0) {
                formData.name = selectedResume.name || '';
                formData.experience = selectedResume.experience ? sortExperienceByDate(selectedResume.experience) : [];
                formData.education = selectedResume.education || [];
                formData.projects = selectedResume.projects || [];
                formData.skills = selectedResume.skills || [];
            } else if (!selectedResume) { 
                formData = {
                    name: '',
                    experience: [],
                    education: [],
                    projects: [],
                    skills: []
                };
            }
        } else { // Not creatingResume
            if (selectedResume) {
                if (currentResumeId !== previousSelectedResumeId) {
                    editMode = false;
                }
                formData.name = selectedResume.name || '';
                formData.experience = selectedResume.experience ? sortExperienceByDate(selectedResume.experience) : [];
                formData.education = selectedResume.education || [];
                formData.projects = selectedResume.projects || [];
                formData.skills = selectedResume.skills || [];
            } else { // No resume selected, not creating
                editMode = false;
                formData = {
                    name: '',
                    experience: [],
                    education: [],
                    projects: [],
                    skills: []
                };
            }
        }
        previousSelectedResumeId = currentResumeId;
    }

    // Handle saving the resume
    function saveResume() {
        console.log("Saving resume:", formData);
        if (live) {
            const event = creatingResume ? "create_resume" : "update_resume";
            let payload;
            
            if (creatingResume) {
                payload = formData;
            } else {
                // Always include all fields in the update
                payload = {
                    id: selectedResume.id,
                    name: formData.name,
                    experience: formData.experience,
                    education: formData.education,
                    projects: formData.projects,
                    skills: formData.skills
                };
            }

            console.log("Sending payload:", payload);
            live.pushEvent(event, payload, (reply) => {
                if (reply && reply.success) {
                    console.log(`Resume ${creatingResume ? 'created' : 'updated'} successfully:`, reply);
                    if (!creatingResume) {
                        editMode = false;
                        // Refresh the resume data to sync IDs
                        if (selectedResume && selectedResume.id) {
                            live.pushEvent("select_resume", { id: selectedResume.id });
                        }
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
                name: selectedResume.name || '',
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
        if (section === 'experience') {
            formData.experience = sortExperienceByDate(formData.experience);
        }
        console.log("Updated formData for section:", section, formData[section]);
        // Push the initial form data to ensure it's in the state
        if (live) {
            live.pushEvent("form_updated", { id: newItem.id, form: newItem });
        }
    }

    // Remove item from a section
    function removeItem(section: string, index: number) {
        const itemToRemove = formData[section]?.[index];
        if (itemToRemove && live) {
            // Check if this is a temporary item (ID starts with a large timestamp, indicating Date.now())
            const isTemporary = itemToRemove.id && typeof itemToRemove.id === 'string' && 
                                itemToRemove.id.length > 10 && /^\d+$/.test(itemToRemove.id);
            
            // Check if this is an item without a valid database ID
            const hasValidDatabaseId = itemToRemove.id && 
                                     typeof itemToRemove.id === 'string' && 
                                     itemToRemove.id.length <= 10 && 
                                     !isTemporary;
            
            if (isTemporary || !itemToRemove.id) {
                // For temporary items or items without IDs, just remove from local state
                console.log("Removing temporary/local item:", itemToRemove.id || 'no ID');
                formData[section] = formData[section].filter((_, i) => i !== index);
                if (section === 'experience') {
                    formData.experience = sortExperienceByDate(formData.experience);
                }
                // Trigger reactivity
                formData = { ...formData };
            } else if (hasValidDatabaseId) {
                // For database items, send remove event
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
                    console.log("Removing database item:", itemToRemove.id);
                    live.pushEvent(eventName, { id: itemToRemove.id });
                }
            }
        }
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
            // Find which section contains this ID
            const section = Object.keys(formData).find(key => 
                Array.isArray(formData[key]) && 
                formData[key].some(item => item.id === id)
            );

            if (section) {
                // Update the item in the section
                formData[section] = formData[section].map(item => 
                    item.id === id ? { ...item, ...form } : item
                );
                if (section === 'experience') {
                    formData.experience = sortExperienceByDate(formData.experience);
                }
                // Trigger reactivity
                formData = { ...formData };
            }
        });

        live.handleEvent("save_experience_item", ({ success, message }) => {
            console.log("Save experience item result:", success, message);
            if (success) {
                // Reload the resume data
                live.pushEvent("select_resume", { id: selectedResume.id });
            }
        });
    }

    onMount(() => {
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
            <div class="flex-grow">
                {#if editMode}
                    <input
                        type="text"
                        bind:value={formData.name}
                        placeholder="Enter resume name"
                        class="text-xl font-semibold w-full px-2 py-1 border border-gray-400 rounded focus:outline-none focus:ring focus:ring-blue-500"
                    />
                {:else}
                    <h2 class="text-xl font-semibold">
                        {formData.name || (creatingResume ? 'Create New Resume' : 'Resume Details')}
                    </h2>
                {/if}
            </div>

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
            <div>
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
                                            <h3 class="text-lg font-medium">{experienceItem.company}</h3>
                                            <span class="text-gray-500">
                                                {experienceItem.start_date}
                                                {' - '}
                                                {experienceItem.end_date ? experienceItem.end_date : 'Current'}
                                            </span>
                                        </div>
                                        <div class="text-gray-600">
                                            <strong>Positions:</strong> {experienceItem.positions && experienceItem.positions.length > 0 ? experienceItem.positions.join(', ') : '-'}
                                        </div>
                                        <div class="text-gray-600">
                                            <strong>Technologies:</strong> {experienceItem.technologies && experienceItem.technologies.length > 0 ? experienceItem.technologies.join(', ') : '-'}
                                        </div>
                                        <div class="text-gray-600">
                                            <strong>Relevant Experience:</strong>
                                            {#if experienceItem.relevant_experience && experienceItem.relevant_experience.length > 0}
                                                <ul class="list-disc ml-5">
                                                    {#each experienceItem.relevant_experience as relExp}
                                                        <li>{relExp}</li>
                                                    {/each}
                                                </ul>
                                            {:else}
                                                -
                                            {/if}
                                        </div>
                                        <div class="text-gray-600">
                                            <strong>Highlights:</strong>
                                            {#if experienceItem.highlights && experienceItem.highlights.length > 0}
                                                <ul class="list-disc ml-5">
                                                    {#each experienceItem.highlights as highlight}
                                                        <li>{highlight}</li>
                                                    {/each}
                                                </ul>
                                            {:else}
                                                -
                                            {/if}
                                        </div>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                <!-- Education Section -->
                {:else if activeSection === 'education'}
                    <div class="space-y-4">
                        {#each formData.education as educationItem, index (educationItem.id)}
                            <div class="p-4 rounded-lg">
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
                            <div class="p-4 rounded-lg">
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
                            <div class="p-4 rounded-lg">
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
