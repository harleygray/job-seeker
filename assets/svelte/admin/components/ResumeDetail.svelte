<script lang="ts">
    import { onMount } from "svelte";
    import Check from "phosphor-svelte/lib/Check";
    import Plus from "phosphor-svelte/lib/Plus";
    import { Badge } from "$lib/components/ui/badge/index.js";  
    import { Root, Trigger, Content } from "$lib/components/ui/popover/index.js";

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
            console.log("Creating new resume, enabling edit mode.");
            editMode = true;
            formData = {
                experience: [],
                education: [],
                projects: [],
                skills: []
            };
            selectedResume = null;
        } else if (selectedResume) {
            console.log("Selected resume updated:", selectedResume);
            editMode = false;
            formData = {
                experience: selectedResume.experience || [],
                education: selectedResume.education || [],
                projects: selectedResume.projects || [],
                skills: selectedResume.skills || []
            };
        } else {
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
            id: Date.now(), // Temporary ID for new items
            ...getEmptyItemForSection(section)
        };
        formData[section] = [...formData[section], newItem];
    }

    // Remove item from a section
    function removeItem(section: string, index: number) {
        formData[section] = formData[section].filter((_, i) => i !== index);
    }

    // Get empty item structure for each section
    function getEmptyItemForSection(section: string) {
        switch (section) {
            case 'experience':
                return {
                    title: '',
                    company: '',
                    location: '',
                    start_date: '',
                    end_date: '',
                    description: ''
                };
            case 'education':
                return {
                    school: '',
                    degree: '',
                    field: '',
                    start_date: '',
                    end_date: '',
                    description: ''
                };
            case 'projects':
                return {
                    name: '',
                    description: '',
                    technologies: '',
                    url: ''
                };
            case 'skills':
                return {
                    name: '',
                    level: '',
                    category: ''
                };
            default:
                return {};
        }
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
                            on:click={() => activeSection = section}
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
                            on:click={() => addItem(activeSection)}
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
                        {#each formData.experience as experience, index}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <div class="grid grid-cols-2 gap-4">
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
                                            <input
                                                type="text"
                                                bind:value={experience.title}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Job Title"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Company</label>
                                            <input
                                                type="text"
                                                bind:value={experience.company}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Company Name"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Location</label>
                                            <input
                                                type="text"
                                                bind:value={experience.location}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Location"
                                            />
                                        </div>
                                        <div class="grid grid-cols-2 gap-2">
                                            <div>
                                                <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
                                                <input
                                                    type="text"
                                                    bind:value={experience.start_date}
                                                    class="w-full p-2 border border-gray-300 rounded-md"
                                                    placeholder="Start Date"
                                                />
                                            </div>
                                            <div>
                                                <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
                                                <input
                                                    type="text"
                                                    bind:value={experience.end_date}
                                                    class="w-full p-2 border border-gray-300 rounded-md"
                                                    placeholder="End Date"
                                                />
                                            </div>
                                        </div>
                                        <div class="col-span-2">
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                                            <textarea
                                                bind:value={experience.description}
                                                rows="3"
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Job Description"
                                            ></textarea>
                                        </div>
                                    </div>
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            on:click={() => removeItem('experience', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <div class="flex justify-between">
                                            <h3 class="text-lg font-medium">{experience.title}</h3>
                                            <span class="text-gray-500">{experience.start_date} - {experience.end_date}</span>
                                        </div>
                                        <div class="text-gray-600">{experience.company} • {experience.location}</div>
                                        <p class="text-gray-700 whitespace-pre-wrap">{experience.description}</p>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                <!-- Education Section -->
                {:else if activeSection === 'education'}
                    <div class="space-y-4">
                        {#each formData.education as education, index}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <div class="grid grid-cols-2 gap-4">
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">School</label>
                                            <input
                                                type="text"
                                                bind:value={education.school}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="School Name"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Degree</label>
                                            <input
                                                type="text"
                                                bind:value={education.degree}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Degree"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Field</label>
                                            <input
                                                type="text"
                                                bind:value={education.field}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Field of Study"
                                            />
                                        </div>
                                        <div class="grid grid-cols-2 gap-2">
                                            <div>
                                                <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
                                                <input
                                                    type="text"
                                                    bind:value={education.start_date}
                                                    class="w-full p-2 border border-gray-300 rounded-md"
                                                    placeholder="Start Date"
                                                />
                                            </div>
                                            <div>
                                                <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
                                                <input
                                                    type="text"
                                                    bind:value={education.end_date}
                                                    class="w-full p-2 border border-gray-300 rounded-md"
                                                    placeholder="End Date"
                                                />
                                            </div>
                                        </div>
                                        <div class="col-span-2">
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                                            <textarea
                                                bind:value={education.description}
                                                rows="3"
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Additional Information"
                                            ></textarea>
                                        </div>
                                    </div>
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            on:click={() => removeItem('education', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <div class="flex justify-between">
                                            <h3 class="text-lg font-medium">{education.school}</h3>
                                            <span class="text-gray-500">{education.start_date} - {education.end_date}</span>
                                        </div>
                                        <div class="text-gray-600">{education.degree} in {education.field}</div>
                                        <p class="text-gray-700 whitespace-pre-wrap">{education.description}</p>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                <!-- Projects Section -->
                {:else if activeSection === 'projects'}
                    <div class="space-y-4">
                        {#each formData.projects as project, index}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <div class="space-y-4">
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Project Name</label>
                                            <input
                                                type="text"
                                                bind:value={project.name}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Project Name"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                                            <textarea
                                                bind:value={project.description}
                                                rows="3"
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Project Description"
                                            ></textarea>
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Technologies</label>
                                            <input
                                                type="text"
                                                bind:value={project.technologies}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Technologies Used"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Project URL</label>
                                            <input
                                                type="url"
                                                bind:value={project.url}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="https://project-url.com"
                                            />
                                        </div>
                                    </div>
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            on:click={() => removeItem('projects', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="space-y-2">
                                        <div class="flex justify-between items-start">
                                            <h3 class="text-lg font-medium">{project.name}</h3>
                                            {#if project.url}
                                                <a href={project.url} target="_blank" class="text-blue-600 hover:underline">View Project</a>
                                            {/if}
                                        </div>
                                        <p class="text-gray-700 whitespace-pre-wrap">{project.description}</p>
                                        {#if project.technologies}
                                            <div class="flex flex-wrap gap-2 mt-2">
                                                {#each project.technologies.split(',').map(t => t.trim()) as tech}
                                                    <Badge variant="secondary" class="text-xs">{tech}</Badge>
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
                        {#each formData.skills as skill, index}
                            <div class="p-4 border rounded-lg">
                                {#if editMode}
                                    <div class="grid grid-cols-3 gap-4">
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Skill Name</label>
                                            <input
                                                type="text"
                                                bind:value={skill.name}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Skill Name"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Level</label>
                                            <input
                                                type="text"
                                                bind:value={skill.level}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Expertise Level"
                                            />
                                        </div>
                                        <div>
                                            <label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
                                            <input
                                                type="text"
                                                bind:value={skill.category}
                                                class="w-full p-2 border border-gray-300 rounded-md"
                                                placeholder="Skill Category"
                                            />
                                        </div>
                                    </div>
                                    <div class="mt-4 flex justify-end">
                                        <button
                                            type="button"
                                            on:click={() => removeItem('skills', index)}
                                            class="text-red-600 hover:text-red-800"
                                        >
                                            Remove
                                        </button>
                                    </div>
                                {:else}
                                    <div class="flex justify-between items-center">
                                        <div>
                                            <h3 class="text-lg font-medium">{skill.name}</h3>
                                            <div class="text-gray-600">{skill.category}</div>
                                        </div>
                                        <Badge variant="secondary">{skill.level}</Badge>
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
                    on:click={cancelEdit}
                    class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
                >
                    Cancel
                </button>
                <button
                    type="button"
                    on:click={saveResume}
                    class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                    {creatingResume ? 'Create Resume' : 'Save Changes'}
                </button>
            </div>
        {/if}
    {/if}
</div>
