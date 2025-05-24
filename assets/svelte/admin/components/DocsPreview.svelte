<script lang="ts">
    import { Badge } from "$lib/components/ui/badge";
    import { Button } from "$lib/components/ui/button";
    import { onMount, tick } from "svelte";

    const { editMode, selectedJob, live } = $props<{
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
        } | null;
        live: any;
    }>();

    let cv_html_content1 = $state<string | null>(null);
    let cv_html_content2 = $state<string | null>(null);
    let cover_letter_html_content = $state<string | null>(null);
    let edited_cv1_content = $state<string | null>(null);
    let edited_cv2_content = $state<string | null>(null);
    let edited_cover_letter_content = $state<string | null>(null);
    let loading = $state(false);
    let error = $state<string | null>(null);
    let isEditing = $state(false);

    let cv1Div = $state<HTMLDivElement | null>(null);
    let cv2Div = $state<HTMLDivElement | null>(null);
    let coverDiv = $state<HTMLDivElement | null>(null);
    let containerDiv = $state<HTMLDivElement | null>(null);

    // Add parent width tracking
    let parentWidth = $state<number | null>(null);

    interface CVReply {
        success: boolean;
        cv_page1?: string;
        cv_page2?: string;
        cover_letter?: string;
        error?: string;
        cv_path?: string;
        cover_letter_path?: string;
    }

    // Enhanced debug function
    function logDimensions(element: HTMLElement | null, name: string) {
        if (element) {
            const rect = element.getBoundingClientRect();
            const parent = element.parentElement;
            const parentRect = parent?.getBoundingClientRect();
            
            console.log(`${name} dimensions:`, {
                width: rect.width,
                height: rect.height,
                offsetWidth: element.offsetWidth,
                clientWidth: element.clientWidth,
                scrollWidth: element.scrollWidth,
                parentWidth: parentRect?.width,
                parentOffsetWidth: parent?.offsetWidth,
                parentClientWidth: parent?.clientWidth,
                parentScrollWidth: parent?.scrollWidth,
                parentComputedStyle: parent ? window.getComputedStyle(parent).width : null
            });
        }
    }

    // Debug function to log all relevant dimensions
    function logAllDimensions() {
        console.log('=== Dimensions Debug ===');
        logDimensions(containerDiv, 'Container');
        logDimensions(cv1Div, 'CV1');
        logDimensions(cv2Div, 'CV2');
        logDimensions(coverDiv, 'Cover');
        console.log('=====================');
    }

    async function generatePreview() {
        try {
            loading = true;
            error = null;
            console.log('Starting preview generation...');

            const reply = await new Promise<CVReply>((resolve) => {
                live.pushEvent(
                    "generate_cv",
                    {
                        jobId: selectedJob.id,
                    },
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

            // Wait for DOM update
            await tick();
            logAllDimensions();

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

            const reply = await new Promise<CVReply>((resolve) => {
                live.pushEvent(
                    "generate_pdf",
                    {
                        cv_content1: edited_cv1_content || cv_html_content1,
                        cv_content2: edited_cv2_content || cv_html_content2,
                        cover_letter_content:
                            edited_cover_letter_content ||
                            cover_letter_html_content,
                        jobId: selectedJob.id,
                        companyName: selectedJob.employer,
                    },
                    resolve,
                );
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
        }
    }

    // Function to strip CSS from HTML content for safe editing
    function stripCSSFromHTML(html: string): string {
        if (!html) return html;
        
        // Create a temporary DOM element to parse HTML
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = html;
        
        // Remove all style tags
        const styleTags = tempDiv.querySelectorAll('style');
        styleTags.forEach(tag => tag.remove());
        
        // Remove all link tags that reference stylesheets
        const linkTags = tempDiv.querySelectorAll('link[rel="stylesheet"]');
        linkTags.forEach(tag => tag.remove());
        
        // Remove inline styles from all elements
        const allElements = tempDiv.querySelectorAll('*');
        allElements.forEach(element => {
            element.removeAttribute('style');
        });
        
        return tempDiv.innerHTML;
    }

    function handleContentEdit(event: Event, type: "cv1" | "cv2" | "cover") {
        const target = event.target as HTMLElement;
        const content = target.innerHTML;

        switch (type) {
            case "cv1":
                edited_cv1_content = content;
                break;
            case "cv2":
                edited_cv2_content = content;
                break;
            case "cover":
                edited_cover_letter_content = content;
                break;
        }
    }

    $effect(() => {
        if (isEditing && cv1Div && !edited_cv1_content) {
            cv1Div.innerHTML = stripCSSFromHTML(cv_html_content1 || "");
        }
    });
    $effect(() => {
        if (isEditing && cv2Div && !edited_cv2_content) {
            cv2Div.innerHTML = stripCSSFromHTML(cv_html_content2 || "");
        }
    });
    $effect(() => {
        if (isEditing && coverDiv && !edited_cover_letter_content) {
            coverDiv.innerHTML = stripCSSFromHTML(cover_letter_html_content || "");
        }
    });

    // Add resize observer to track width changes
    let resizeObserver: ResizeObserver;
    
    onMount(() => {
        console.log('DocsPreview mounted');
        if (containerDiv) {
            // Log initial parent dimensions
            const parent = containerDiv.parentElement;
            if (parent) {
                parentWidth = parent.offsetWidth;
                console.log('Initial parent width:', parentWidth);
            }

            resizeObserver = new ResizeObserver((entries) => {
                for (const entry of entries) {
                    const parent = entry.target.parentElement;
                    const newParentWidth = parent?.offsetWidth;
                    
                    console.log('Container resized:', {
                        width: entry.contentRect.width,
                        height: entry.contentRect.height,
                        parentWidth: newParentWidth,
                        parentWidthChanged: newParentWidth !== parentWidth
                    });
                    
                    if (newParentWidth !== parentWidth) {
                        console.log('Parent width changed from', parentWidth, 'to', newParentWidth);
                        parentWidth = newParentWidth;
                    }
                }
            });
            resizeObserver.observe(containerDiv);
        }
        
        // Initial dimensions log
        logAllDimensions();
        
        return () => {
            if (resizeObserver) {
                resizeObserver.disconnect();
            }
        };
    });
</script>

<div class="space-y-4 w-full flex flex-col" style="width: 100%; min-width: 100%; max-width: 100%;" bind:this={containerDiv}>
    <!-- Add debug info display -->
    <div class="text-xs text-gray-500 mb-2">
        Container Width: {containerDiv?.offsetWidth || 'N/A'}px | Parent Width: {parentWidth || 'N/A'}px
    </div>
    
    <div class="flex justify-between items-center">
        <h3 class="text-lg font-medium">Document Preview</h3>
        <div class="space-x-2">
            {#if !cv_html_content1 && !cv_html_content2 && !cover_letter_html_content}
                <Button
                    variant="action_primary"
                    onclick={generatePreview}
                    disabled={loading}
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
                    <div class="relative w-full overflow-x-auto">
                        {#if isEditing}
                            <div
                                class="border p-4 overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px;"
                                contenteditable={true}
                                oninput={(e) => (edited_cv1_content = e.currentTarget.innerHTML)}
                                bind:this={cv1Div}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border p-4 overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_cv1_content || cv_html_content1}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="CV Page 1"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            {#if cv_html_content2}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">CV Page 2</h4>
                    <div class="relative w-full overflow-x-auto">
                        {#if isEditing}
                            <div
                                class="border p-4 overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px;"
                                contenteditable={true}
                                oninput={(e) => (edited_cv2_content = e.currentTarget.innerHTML)}
                                bind:this={cv2Div}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border p-4 overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_cv2_content || cv_html_content2}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="CV Page 2"
                                ></iframe>
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            {#if cover_letter_html_content}
                <div class="border rounded-lg p-4 w-full">
                    <h4 class="font-medium mb-2">Cover Letter</h4>
                    <div class="relative w-full overflow-x-auto">
                        {#if isEditing}
                            <div
                                class="border p-4 overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297; min-height: 400px;"
                                contenteditable={true}
                                oninput={(e) => (edited_cover_letter_content = e.currentTarget.innerHTML)}
                                bind:this={coverDiv}
                            >
                                <!-- Content injected via $effect -->
                            </div>
                        {:else}
                            <div
                                class="border p-4 overflow-hidden bg-white shadow-lg mx-auto"
                                style="width: 100%; max-width: 210mm; aspect-ratio: 210/297;"
                            >
                                <iframe 
                                    srcdoc={edited_cover_letter_content || cover_letter_html_content}
                                    style="width: 100%; height: 100%; border: none;"
                                    title="Cover Letter"
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
