<script lang="ts">
    import { Badge } from "$lib/components/ui/badge";
    import { Button } from "$lib/components/ui/button";
    import { onMount, tick } from "svelte";

    const { editMode, selectedJob, live, resumes = [] } = $props<{
        editMode: boolean;
        selectedJob: {
            id: number;
            title: string;
            employer: string;
            location: string;
            salary: string;
            apply_link: string;
            description: string;
            seek_job_id: string;
            formatted_description: string;
            data_analyst_score: number;
            data_engineer_score: number;
            data_scientist_score: number;
            software_engineer_score: number;
            ai_engineer_score: number;
            product_owner_score: number;
            applied: boolean;
            archived: boolean;
            include_selection_criteria: boolean;
        } | null;
        live: any;
        resumes?: Array<{
            id: number | string;
            name: string;
        }>;
    }>();

    let cv_html_content1 = $state<string | null>(null);
    let cv_html_content2 = $state<string | null>(null);
    let cover_letter_html_content = $state<string | null>(null);
    let selection_criteria_content1 = $state<string | null>(null);
    let selection_criteria_content2 = $state<string | null>(null);
    let edited_cv1_content = $state<string | null>(null);
    let edited_cv2_content = $state<string | null>(null);
    let edited_cover_letter_content = $state<string | null>(null);
    let edited_selection_criteria1_content = $state<string | null>(null);
    let edited_selection_criteria2_content = $state<string | null>(null);
    let loading = $state(false);
    let error = $state<string | null>(null);
    let isEditing = $state(false);
    let selectedResumeId = $state<number | string | "">("");

    let cv1Div = $state<HTMLDivElement | null>(null);
    let cv2Div = $state<HTMLDivElement | null>(null);
    let coverDiv = $state<HTMLDivElement | null>(null);
    let sc1Div = $state<HTMLDivElement | null>(null);
    let sc2Div = $state<HTMLDivElement | null>(null);
    let containerDiv = $state<HTMLDivElement | null>(null);

    interface CVReply {
        success: boolean;
        cv_page1?: string;
        cv_page2?: string;
        cover_letter?: string;
        selection_criteria_page1?: string;
        selection_criteria_page2?: string;
        error?: string;
        cv_path?: string;
        cover_letter_path?: string;
        selection_criteria_path?: string;
    }

    async function generatePreview() {
        try {
            loading = true;
            error = null;
            console.log('Starting preview generation...');

            const payload: any = {
                jobId: selectedJob.id,
            };

            // Include resume_id if a resume is selected and there are multiple resumes
            if (resumes.length > 1 && selectedResumeId && selectedResumeId !== "") {
                payload.resumeId = selectedResumeId;
            }

            const reply = await new Promise<CVReply>((resolve) => {
                live.pushEvent(
                    "generate_cv",
                    payload,
                    resolve,
                );
            });

            console.log("CV Generation Reply:", reply);

            if (!reply.success) {
                throw new Error("Failed to generate preview");
            }

            cv_html_content1 = reply.cv_page1;
            cv_html_content2 = reply.cv_page2;
            cover_letter_html_content = reply.cover_letter;
            selection_criteria_content1 = reply.selection_criteria_page1;
            selection_criteria_content2 = reply.selection_criteria_page2;

            // Wait for DOM update
            await tick();

        } catch (error) {
            console.error("Failed to generate preview:", error);
            error =
                error instanceof Error
                    ? error.message
                    : "Failed to generate preview";
        } finally {
            loading = false;
        }
    }

    async function confirmAndGeneratePDF() {
        try {
            loading = true;
            error = null;

            const payload: any = {
                cv_content1: edited_cv1_content || cv_html_content1,
                cv_content2: edited_cv2_content || cv_html_content2,
                cover_letter_content:
                    edited_cover_letter_content ||
                    cover_letter_html_content,
                jobId: selectedJob.id,
                companyName: selectedJob.employer,
                export_format: "pdf", // Default to PDF format
            };

            // Add selection criteria content if available
            if (selection_criteria_content1 && selection_criteria_content2) {
                payload.selection_criteria_content1 = edited_selection_criteria1_content || selection_criteria_content1;
                payload.selection_criteria_content2 = edited_selection_criteria2_content || selection_criteria_content2;
            }

            const reply = await new Promise<CVReply>((resolve) => {
                live.pushEvent("generate_pdf", payload, resolve);
            });

            if (!reply.success) {
                throw new Error(reply.error || "Failed to generate PDFs");
            }

            // PDFs generated and saved on server - show success message
            if (reply.cv_path && reply.cover_letter_path) {
                console.log(`CV PDF saved successfully: ${reply.cv_path}`);
                console.log(`Cover Letter PDF saved successfully: ${reply.cover_letter_path}`);
                // You could add a toast notification here if desired
            }
        } catch (error) {
            console.error("Failed to generate PDFs:", error);
            error =
                error instanceof Error
                    ? error.message
                    : "Failed to generate PDFs";
        } finally {
            loading = false;
        }
    }

    function toggleEditMode() {
        isEditing = !isEditing;
        if (!isEditing) {
            // Reset edited content when exiting edit mode
            edited_cv1_content = null;
            edited_cv2_content = null;
            edited_cover_letter_content = null;
            edited_selection_criteria1_content = null;
            edited_selection_criteria2_content = null;
        }
    }

    // Function to scope CSS from HTML content for safe editing
    function scopeCSSForEditing(html: string, scopeId: string): string {
        if (!html) return html;
        
        // Create a temporary DOM element to parse HTML
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = html;
        
        // Find all style tags and scope their CSS rules
        const styleTags = tempDiv.querySelectorAll('style');
        styleTags.forEach(styleTag => {
            if (styleTag.textContent) {
                // Scope CSS rules by prefixing selectors with a unique class
                const scopedCSS = styleTag.textContent.replace(
                    /([^{}]+)\s*{/g, 
                    (match, selector) => {
                        // Don't scope @rules (like @media, @keyframes)
                        if (selector.trim().startsWith('@')) {
                            return match;
                        }
                        // Add scope class to each selector
                        const scopedSelector = selector
                            .split(',')
                            .map(s => `.${scopeId} ${s.trim()}`)
                            .join(', ');
                        return `${scopedSelector} {`;
                    }
                );
                styleTag.textContent = scopedCSS;
            }
        });
        
        // Remove external stylesheet links (they could still cause conflicts)
        const linkTags = tempDiv.querySelectorAll('link[rel="stylesheet"]');
        linkTags.forEach(tag => tag.remove());
        
        return tempDiv.innerHTML;
    }

    // Function to unscope CSS from edited content for saving
    function unscopeCSSForSaving(html: string, scopeId: string): string {
        if (!html) return html;
        
        // Create a temporary DOM element to parse HTML
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = html;
        
        // Find all style tags and unscope their CSS rules
        const styleTags = tempDiv.querySelectorAll('style');
        styleTags.forEach(styleTag => {
            if (styleTag.textContent) {
                // Remove scope class from CSS selectors
                const unscopedCSS = styleTag.textContent.replace(
                    new RegExp(`\\.${scopeId}\\s+`, 'g'),
                    ''
                );
                styleTag.textContent = unscopedCSS;
            }
        });
        
        return tempDiv.innerHTML;
    }

    function handleContentEdit(event: Event, type: "cv1" | "cv2" | "cover" | "sc1" | "sc2") {
        const target = event.target as HTMLElement;
        const content = target.innerHTML;
        
        // Unscope the CSS before saving
        let unscopedContent;
        switch (type) {
            case "cv1":
                unscopedContent = unscopeCSSForSaving(content, "cv1-edit-scope");
                edited_cv1_content = unscopedContent;
                break;
            case "cv2":
                unscopedContent = unscopeCSSForSaving(content, "cv2-edit-scope");
                edited_cv2_content = unscopedContent;
                break;
            case "cover":
                unscopedContent = unscopeCSSForSaving(content, "cover-edit-scope");
                edited_cover_letter_content = unscopedContent;
                break;
            case "sc1":
                unscopedContent = unscopeCSSForSaving(content, "sc1-edit-scope");
                edited_selection_criteria1_content = unscopedContent;
                break;
            case "sc2":
                unscopedContent = unscopeCSSForSaving(content, "sc2-edit-scope");
                edited_selection_criteria2_content = unscopedContent;
                break;
        }
    }

    $effect(() => {
        if (isEditing && cv1Div && !edited_cv1_content) {
            cv1Div.innerHTML = scopeCSSForEditing(cv_html_content1 || "", "cv1-edit-scope");
        }
    });
    $effect(() => {
        if (isEditing && cv2Div && !edited_cv2_content) {
            cv2Div.innerHTML = scopeCSSForEditing(cv_html_content2 || "", "cv2-edit-scope");
        }
    });
    $effect(() => {
        if (isEditing && coverDiv && !edited_cover_letter_content) {
            coverDiv.innerHTML = scopeCSSForEditing(cover_letter_html_content || "", "cover-edit-scope");
        }
    });
    $effect(() => {
        if (isEditing && sc1Div && !edited_selection_criteria1_content) {
            sc1Div.innerHTML = scopeCSSForEditing(selection_criteria_content1 || "", "sc1-edit-scope");
        }
    });
    $effect(() => {
        if (isEditing && sc2Div && !edited_selection_criteria2_content) {
            sc2Div.innerHTML = scopeCSSForEditing(selection_criteria_content2 || "", "sc2-edit-scope");
        }
    });

    onMount(() => {
        return () => {
            // Cleanup if needed
        };
    });
</script>

<style>
    /* Hide scrollbars while maintaining scroll functionality */
    .scrollbar-hidden {
        /* For Webkit browsers (Chrome, Safari, Edge) */
        scrollbar-width: none; /* Firefox */
        -ms-overflow-style: none; /* Internet Explorer 10+ */
    }
    
    .scrollbar-hidden::-webkit-scrollbar {
        display: none; /* Webkit browsers */
    }
    
    /* Also hide scrollbars in iframes */
    :global(.scrollbar-hidden iframe) {
        scrollbar-width: none;
        -ms-overflow-style: none;
    }
    
    :global(.scrollbar-hidden iframe::-webkit-scrollbar) {
        display: none;
    }
</style>

    <div class="space-y-4 w-full flex flex-col" style="width: 100%; min-width: 100%; max-width: 100%;" bind:this={containerDiv}>
    
    <div class="flex justify-between items-center">
        <h3 class="text-lg font-medium">Document Preview</h3>
        <div class="flex items-center space-x-2">
            {#if !cv_html_content1 && !cv_html_content2 && !cover_letter_html_content}
                {#if resumes.length > 1}
                    <select
                        bind:value={selectedResumeId}
                        class="px-3 py-2 text-sm border border-gray-300 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                        <option value="">Select a resume...</option>
                        {#each resumes as resume}
                            <option value={resume.id}>{resume.name}</option>
                        {/each}
                    </select>
                {/if}
                <Button
                    variant="action_primary"
                    onclick={generatePreview}
                    disabled={loading || (resumes.length > 1 && (!selectedResumeId || selectedResumeId === ""))}
                >
                    {loading ? "Generating..." : "Generate Preview"}
                </Button>
            {/if}

            {#if cv_html_content1 && cv_html_content2 && cover_letter_html_content}
                <Button
                    variant="action_primary"
                    onclick={confirmAndGeneratePDF}
                    disabled={loading}
                >
                    {loading ? "Generating..." : "Generate PDF"}
                </Button>

                <Button
                    variant="action_secondary"
                    onclick={toggleEditMode}
                    disabled={loading}
                >
                    {isEditing ? "Exit Edit Mode" : "Edit Mode"}
                </Button>
            {/if}
        </div>
    </div>

    {#if error}
        <div
            class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative"
        >
            {error}
        </div>
    {/if}

    {#if cv_html_content1 || cv_html_content2 || cover_letter_html_content}
        <div class="grid grid-cols-1 gap-4 w-full" style="width: 100%; min-width: 100%; max-width: 100%;">
            {#if cv_html_content1}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">CV Page 1</h4>
                    <div class="relative w-full overflow-hidden">
                        {#if isEditing}
                            <div
                                class="border overflow-auto bg-white shadow-lg mx-auto cv1-edit-scope scrollbar-hidden"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px; position: relative; isolation: isolate; contain: layout style;"
                                contenteditable={true}
                                oninput={(e) => handleContentEdit(e, "cv1")}
                                bind:this={cv1Div}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_cv1_content || cv_html_content1}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="CV Page 1"
                                    class="scrollbar-hidden"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            {#if cv_html_content2}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">CV Page 2</h4>
                    <div class="relative w-full overflow-hidden">
                        {#if isEditing}
                            <div
                                class="border overflow-auto bg-white shadow-lg mx-auto cv2-edit-scope scrollbar-hidden"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px; position: relative; isolation: isolate; contain: layout style;"
                                contenteditable={true}
                                oninput={(e) => handleContentEdit(e, "cv2")}
                                bind:this={cv2Div}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_cv2_content || cv_html_content2}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="CV Page 2"
                                    class="scrollbar-hidden"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            {#if cover_letter_html_content}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">Cover Letter</h4>
                    <div class="relative w-full overflow-hidden">
                        {#if isEditing}
                            <div
                                class="border overflow-auto bg-white shadow-lg mx-auto cover-edit-scope scrollbar-hidden"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px; position: relative; isolation: isolate; contain: layout style;"
                                contenteditable={true}
                                oninput={(e) => handleContentEdit(e, "cover")}
                                bind:this={coverDiv}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_cover_letter_content || cover_letter_html_content}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="Cover Letter"
                                    class="scrollbar-hidden"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            {#if selection_criteria_content1}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">Selection Criteria Response - Page 1</h4>
                    <div class="relative w-full overflow-hidden">
                        {#if isEditing}
                            <div
                                class="border overflow-auto bg-white shadow-lg mx-auto sc1-edit-scope scrollbar-hidden"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px; position: relative; isolation: isolate; contain: layout style;"
                                contenteditable={true}
                                oninput={(e) => handleContentEdit(e, "sc1")}
                                bind:this={sc1Div}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_selection_criteria1_content || selection_criteria_content1}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="Selection Criteria Response Page 1"
                                    class="scrollbar-hidden"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            {#if selection_criteria_content2}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">Selection Criteria Response - Page 2</h4>
                    <div class="relative w-full overflow-hidden">
                        {#if isEditing}
                            <div
                                class="border overflow-auto bg-white shadow-lg mx-auto sc2-edit-scope scrollbar-hidden"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px; position: relative; isolation: isolate; contain: layout style;"
                                contenteditable={true}
                                oninput={(e) => handleContentEdit(e, "sc2")}
                                bind:this={sc2Div}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_selection_criteria2_content || selection_criteria_content2}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="Selection Criteria Response Page 2"
                                    class="scrollbar-hidden"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}
        </div>
    {:else}
        <div class="text-center text-gray-500 py-8">
            Click "Generate Preview" to see your documents
        </div>
    {/if}
</div>
