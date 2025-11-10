const { PlaywrightCrawler, log } = require('crawlee');

// Set Crawlee log level to debug for internal logs
log.setLevel(log.LEVELS.DEBUG);

// Initialize global tracking variables for chunking
global.chunking_in_progress = false;
global.chunks_total = 0;
global.chunks_sent = 0;
global.completion_sent = false; // Flag to track if completion has been sent
// Add pagination tracking variables
global.pagination = {
    enabled: false,
    maxPages: 5,
    currentPage: 1,
    pagesProcessed: 0,
    visitedUrls: new Set(),
    discoveredUrls: new Set(),
    totalPagesDiscovered: 0,
    pendingRequests: 0,     // Track pending requests to avoid early completion
    completionCallback: null // Store callback for final completion
};

// Redirect Crawlee's internal logs to standardize the format
// This helps Elixir parse them correctly as log messages rather than trying to parse them as JSON
const originalConsoleLog = console.log;
const originalConsoleDebug = console.debug;
const originalConsoleInfo = console.info;
const originalConsoleWarn = console.warn;
const originalConsoleError = console.error;

// Custom console methods to standardize output
console.log = function(...args) {
    const message = args.join(' ');
    // Only redirect standard logs, not our special messages
    if (!message.includes('ELIXIR_JSON_MESSAGE') && !message.includes('DIRECT_DEBUG')) {
        process.stderr.write(`LOG: ${message}\n`);
    } else {
        originalConsoleLog.apply(console, args);
    }
};

console.debug = function(...args) {
    const message = args.join(' ');
    process.stderr.write(`DEBUG: ${message}\n`);
};

console.info = function(...args) {
    const message = args.join(' ');
    process.stderr.write(`INFO: ${message}\n`);
};

console.warn = function(...args) {
    const message = args.join(' ');
    process.stderr.write(`WARNING: ${message}\n`);
};

// Keep error intact for our direct debug messages
console.error = function(...args) {
    const message = args.join(' ');
    if (message.includes('DIRECT_DEBUG')) {
        originalConsoleError.apply(console, args);
    } else {
        process.stderr.write(`ERROR: ${message}\n`);
    }
};

// Send all messages as structured JSON to be handled on the Elixir side
function sendMessage(type, data) {
    try {
        // Add a timestamp to every message
        data = data || {};
        data._timestamp = Date.now();
        
        // Make sure we don't have any circular references or non-serializable data
        const safeData = JSON.parse(JSON.stringify(data));
        
        // Format message with special marker to assist parsing on Elixir side
        const jsonString = JSON.stringify({ type, data: safeData });
        
        // Add line breaks before and after to ensure clean separation from other output
        const markedMessage = `\nELIXIR_JSON_MESSAGE: ${jsonString}\n`;
        
        // Send a debug message to stderr to help separate output (won't interfere with stdout JSON)
        console.error(`DIRECT_DEBUG: Sending message of type '${type}' (${jsonString.length} bytes)`);
        
        // Send the message with explicit newlines for better separation
        process.stdout.write(markedMessage);
        
        // Ensure the message is sent immediately by flushing stdout
        if (process.stdout.flush) {
            process.stdout.flush();
        }
        
        return true;
    } catch (error) {
        console.error(`Error sending message: ${error.message}`);
        console.error(`Error stack: ${error.stack}`);
        return false;
    }
}

// Send critical messages with retry, backup mechanism, and improved formatting
async function sendCriticalMessage(type, data) {
    console.error(`DIRECT_DEBUG: ========================================`);
    console.error(`DIRECT_DEBUG: Sending critical message of type '${type}'`);
    
    // For complete messages, check if we've already sent a completion
    if (type === 'complete' && global.completion_sent) {
        console.error(`DIRECT_DEBUG: Skipping duplicate complete message - already sent`);
        return true;
    }
    
    // Format the data consistently for critical messages
    data = data || {};
    
    // Add more metadata for debugging
    data._timestamp = Date.now();
    data._critical = true;
    data._source = "crawler.js";
    
    // For page_complete, always ensure consistent structure
    if (type === 'page_complete') {
        data.completed = true;
        data.timestamp = data.timestamp || Date.now();
        if (!data.total_items && data.results) {
            data.total_items = Array.isArray(data.results) ? data.results.length : 0;
        }
    }
    
    // Log the exact message we're about to send
    console.error(`DIRECT_DEBUG: Message data: ${JSON.stringify(data)}`);
    
    for (let attempt = 1; attempt <= 3; attempt++) {
        console.error(`DIRECT_DEBUG: Critical message attempt ${attempt} for type '${type}'`);
        
        try {
            // Format the message for Elixir with extra line breaks for clear separation
            const jsonString = JSON.stringify({ type, data });
            const markedMessage = `\nELIXIR_JSON_MESSAGE: ${jsonString}\n`;
            
            // First log to stderr to help debug
            console.error(`DIRECT_DEBUG: Sending message of type '${type}'`);
            
            // Send the message in a consistent way with explicit line breaks
            process.stdout.write(markedMessage);
            
            // Force flush
            if (process.stdout.flush) {
                process.stdout.flush();
            }
            
            // Wait a moment to ensure transmission and reduce buffer issues
            console.error(`DIRECT_DEBUG: Critical message sent successfully, waiting to ensure transmission`);
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // Send a backup log message as confirmation
            console.error(`CRITICAL_MESSAGE_SENT: ${type} (attempt ${attempt})`);
            
            // Wait another moment
            await new Promise(resolve => setTimeout(resolve, 500));
            
            // Mark completion as sent if this was a complete message
            if (type === 'complete') {
                global.completion_sent = true;
                console.error(`DIRECT_DEBUG: Marked completion as sent, future complete messages will be skipped`);
            }
            
            console.error(`DIRECT_DEBUG: Critical message transmission complete`);
            return true;
        } catch (error) {
            console.error(`DIRECT_DEBUG: Error sending critical message: ${error.message}`);
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
    
    console.error(`DIRECT_DEBUG: Failed to send critical message of type '${type}' after 3 attempts`);
    return false;
}

// Send page results in manageable chunks to avoid overwhelming stdout buffer
function sendPageResultsInChunks(structuredData) {
    const results = structuredData.results || [];
    const metadata = structuredData.metadata || {};
    const page_info = structuredData.page_info || {};
    
    console.error(`DIRECT_DEBUG: ========================================`);
    console.error(`DIRECT_DEBUG: Preparing to send ${results.length} results in chunks`);
    
    // Add pagination information to metadata
    if (global.pagination.enabled) {
        metadata.pagination = {
            enabled: true,
            current_page: global.pagination.pagesProcessed,
            max_pages: global.pagination.maxPages,
            pages_discovered: global.pagination.totalPagesDiscovered,
            visited_urls: Array.from(global.pagination.visitedUrls),
            pending_requests: global.pagination.pendingRequests,
            is_final_page: global.pagination.pendingRequests === 0 && 
                          global.pagination.pagesProcessed >= global.pagination.maxPages
        };
        
        console.error(`DIRECT_DEBUG: Added pagination info to metadata. Current page: ${metadata.pagination.current_page}/${metadata.pagination.max_pages}, discovered ${metadata.pagination.pages_discovered} pages`);
    }
    
    // Create a promise that will track the completion of all chunks
    return new Promise(async (resolveChunksComplete) => {
        // Always chunk data regardless of size
        const CHUNK_SIZE = 20;
        let chunkCount = Math.ceil(results.length / CHUNK_SIZE);
        
        console.error(`DIRECT_DEBUG: Will send ${chunkCount} chunks of size ${CHUNK_SIZE}`);
        
        // Set a global flag to track chunking in progress
        global.chunking_in_progress = true;
        global.chunks_total = chunkCount;
        global.chunks_sent = 0;
        
        // Send metadata first before any chunks
        sendMessage('page_metadata', {
            metadata: metadata,
            page_info: page_info,
            total_count: results.length,
            total_results: metadata.total_results || null,
            timestamp: Date.now(),
            pagination: metadata.pagination // Include pagination information
        });
        
        // Brief pause after metadata to allow separate processing
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // If no results, send empty completion
        if (results.length === 0) {
            console.error(`DIRECT_DEBUG: No results to send, sending completion`);
            await sendCriticalMessage('page_complete', {
                total_items: 0,
                timestamp: Date.now(),
                pagination: metadata.pagination // Include pagination information
            });
            global.chunking_in_progress = false;
            global.chunks_sent = 0;
            resolveChunksComplete();
            return;
        }
        
        // Send each chunk with sequential index
        for (let i = 0; i < results.length; i += CHUNK_SIZE) {
            let chunk = results.slice(i, i + CHUNK_SIZE);
            let chunkIndex = Math.floor(i / CHUNK_SIZE);
            
            console.error(`DIRECT_DEBUG: Sending chunk ${chunkIndex+1}/${chunkCount} with ${chunk.length} items`);
            
            // Brief pause between chunks to ensure messages don't get combined
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            // Add more explicit identification to chunk messages
            sendMessage('page_results', {
                results: chunk,
                metadata: metadata,  // Include metadata with each chunk for safety
                chunk_index: chunkIndex,
                chunk_total: chunkCount,
                chunk_size: chunk.length,
                pagination: metadata.pagination // Include pagination information
            });
            
            console.error(`DIRECT_DEBUG: Sent chunk ${chunkIndex+1}/${chunkCount}`);
            
            // Force flush to make sure messages are separated
            if (process.stdout.flush) {
                process.stdout.flush();
            }
            
            // Update global counter
            global.chunks_sent = chunkIndex + 1;
        }
        
        // Brief pause before completion message to ensure previous chunks are processed
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Send a critical completion message with retry mechanism for reliability
        // If pagination is enabled and we're not on the last page, adjust the completion message
        const isLastPage = !global.pagination.enabled || 
                          (global.pagination.pendingRequests === 0 && 
                           global.pagination.pagesProcessed >= global.pagination.maxPages);
        
        try {
            await sendCriticalMessage('page_complete', {
                total_items: results.length,
                timestamp: Date.now(),
                metadata: metadata,  // Include metadata with completion message
                total_results: metadata.total_results || null,
                status: 'success',
                pagination: metadata.pagination, // Include pagination information
                is_final_page: isLastPage
            });
            
            console.error(`DIRECT_DEBUG: All chunks sent, completion message delivered${isLastPage ? ' (final page)' : ' (more pages coming)'}`);
        } catch (error) {
            console.error(`DIRECT_DEBUG: Error sending page_complete message: ${error.message}`);
            console.error(error.stack);
            sendLog('error', `Failed to send completion message: ${error.message}`);
        }
        
        global.chunking_in_progress = false;
        resolveChunksComplete();
    });
}

// Send logs directly to Elixir
function sendLog(level, message) {
    // First log to local console for immediate feedback
    if (level === 'error') {
        console.error(message);
    } else {
        console.log(`[${level.toUpperCase()}] ${message}`);
    }
    
    // Then send to Elixir
    sendMessage('log', { level, message });
}

// Read config from stdin
const stdin = process.stdin;
let inputData = '';
let inputComplete = false;

stdin.on('data', (chunk) => {
    inputData += chunk;
    sendLog('debug', `Received input chunk: ${chunk.length} bytes`);
    
    // Check if input has complete JSON
    try {
        // See if we can parse what we have
        JSON.parse(inputData.toString().trim());
        if (!inputComplete) {
            inputComplete = true;
            // sendLog('info', 'Received complete JSON input, processing...');
            processInput();
        }
    } catch (e) {
        // Not complete JSON yet, keep waiting
        sendLog('debug', 'Waiting for more input...');
    }
});

stdin.on('end', () => {
    sendLog('info', 'stdin stream ended');
    if (!inputComplete) {
        sendLog('warning', 'stdin ended without complete JSON, trying to process anyway');
        processInput();
    }
});

async function processInput() {
    try {
        if (!inputData) {
            sendLog('error', 'No input data received');
            sendMessage('error', { message: 'No input data received' });
            return;
        }
        
        // sendLog('info', `Received input data, parsing configuration...`);
        
        // Parse the input data as JSON
        let config;
        try {
            config = JSON.parse(inputData.toString().trim());
            // sendLog('info', `Successfully parsed configuration: ${JSON.stringify(config)}`);
        } catch (parseError) {
            sendLog('error', `Failed to parse JSON input: ${parseError.message}`);
            sendLog('error', `Raw input data: ${inputData.toString().trim().substring(0, 200)}...`);
            sendMessage('error', { message: `Failed to parse JSON input: ${parseError.message}` });
            return;
        }
        
        // Ensure URLs is an array
        if (!Array.isArray(config.urls) || config.urls.length === 0) {
            sendLog('error', `No URLs provided in configuration`);
            sendMessage('error', { message: 'No URLs provided in configuration' });
            return;
        }
        
        // Force headless to be false for debugging unless explicitly set
        if (config.headless === undefined) {
            config.headless = false;
            sendLog('info', 'Setting headless mode to false for debugging');
        }
        
        // Set reasonable defaults for other options
        config.maxRequestsPerCrawl = config.maxRequestsPerCrawl || 5;
        config.maxConcurrency = config.maxConcurrency || 1;
        config.navigationTimeoutSecs = config.navigationTimeoutSecs || 120;
        
        // SsendLog('info', `Configuration validated, starting crawler with ${config.urls.length} URLs`);
        
        // Launch the crawler with validated config
        try {
            await runCrawler(config);
            
            // Send success response using the critical message mechanism
            // sendLog('info', 'Crawler run completed successfully, sending complete message');
            await sendCriticalMessage('complete', { status: 'success' });
        } catch (crawlerError) {
            sendLog('error', `Crawler execution failed: ${crawlerError.message}`);
            sendLog('error', crawlerError.stack);
            await sendCriticalMessage('error', { 
                message: `Crawler execution failed: ${crawlerError.message}`,
                stack: crawlerError.stack
            });
        }
    } catch (error) {
        sendLog('error', `Unexpected error in processInput: ${error.message}`);
        sendLog('error', error.stack);
        await sendCriticalMessage('error', { 
            message: `Unexpected error in processInput: ${error.message}`,
            stack: error.stack
        });
    }
}

// Keep the process alive until stdin ends
stdin.resume();

// Function to run the crawler with specific options
async function runCrawler(options) {
    const {
        urls,
        headless = true, // Default to non-headless mode for debugging
        maxRequestsPerCrawl = 10,
        maxConcurrency = 2,
        navigationTimeoutSecs = 60,
        minDelayBetweenRequests = 2000,
        maxDelayBetweenRequests = 5000,
        // Add pagination options
        enablePagination = false,
        maxPages = 5,
    } = options;

    // Set up pagination state
    global.pagination = {
        enabled: enablePagination,
        maxPages: maxPages,
        currentPage: 1,
        pagesProcessed: 0,
        visitedUrls: new Set(urls), // Track initial URLs as already queued
        discoveredUrls: new Set(urls), // Track all discovered URLs
        totalPagesDiscovered: urls.length,
        pendingRequests: 0,     // Track pending requests to avoid early completion
        completionCallback: null // Store callback for final completion
    };

    // Log pagination settings
    if (enablePagination) {
        sendLog('info', `Pagination enabled: Will crawl up to ${maxPages} pages`);
    }

    // Create crawler with enhanced configuration
    const crawler = new PlaywrightCrawler({
        // Request handling configuration
        maxRequestsPerCrawl: enablePagination ? maxRequestsPerCrawl * maxPages : maxRequestsPerCrawl,
        maxConcurrency,
        requestHandlerTimeoutSecs: navigationTimeoutSecs,
        
        // Browser configuration
        headless,
        browserPoolOptions: {
            useFingerprints: false,
        },
        launchContext: {
            launchOptions: {
                headless, // Use the headless setting from options
                devtools: !headless, // Open devtools for debugging in non-headless mode
            },
        },
        
        // Request handler
        async requestHandler({ page, request, enqueueLinks }) {
            // sendLog('info', `Starting to process URL: ${request.url}...`);
            console.error(`DIRECT_DEBUG: Starting to process URL ${request.url}`);

            try {
                // Important: Log exactly when we start loading the page
                console.error(`DIRECT_DEBUG: About to navigate to ${request.url}`);
                
                // Add more direct console logging to bypass potential stdout buffering
                process.stderr.write(`DIRECT_DEBUG_NAVIGATION: Navigating to ${request.url}\n`);
                
                // Immediate log to console
                console.error(`DIRECT_DEBUG: Before navigation ${Date.now()}`);
                
                // Wait for initial page load with an increased timeout
                await page.waitForLoadState('networkidle', { timeout: 120000 });
                
                console.error(`DIRECT_DEBUG: After navigation - network idle ${Date.now()}`);
                sendLog('info', 'Page reached network idle state successfully');
                
                // Add a slight random delay for bot detection instead of waiting for dynamic content
                const randomDelay = Math.floor(Math.random() * 2000) + 1000; // Random delay between 1-3 seconds
                
                // Use human-like behavior to avoid bot detection
                sendLog('info', 'Simulating human-like browsing behavior...');
                await simulateHumanBehavior(page);
                await new Promise(resolve => setTimeout(resolve, randomDelay));

                // Extract and log next page links before proceeding with regular processing
                const paginationLinks = await page.evaluate(() => {
                    console.log("[PAGINATION LINKS] Starting to extract pagination links");
                    
                    // Find the next page link specifically
                    const nextPageLink = document.querySelector('.endmarks a[href*="page="]');
                    const nextPageUrl = nextPageLink ? nextPageLink.href : null;
                    console.log(`[PAGINATION LINKS] Next page link found: ${nextPageUrl || "None"}`);
                    
                    // Find all numbered page links
                    const allPageLinks = document.querySelectorAll('.numbers a[href*="page="]');
                    console.log(`[PAGINATION LINKS] Found ${allPageLinks.length} numbered page links`);
                    
                    // Collect all page links in an array
                    const pageLinks = Array.from(allPageLinks).map(link => ({
                        page: link.textContent.trim(),
                        url: link.href
                    }));
                    
                    // Log each page link
                    pageLinks.forEach(link => {
                        console.log(`[PAGINATION LINKS] Page link: ${link.page} - ${link.url}`);
                    });
                    
                    // Find the last page link
                    const lastPageLink = document.querySelector('.endmarks a:last-child');
                    const lastPageUrl = lastPageLink ? lastPageLink.href : null;
                    if (lastPageLink) {
                        console.log(`[PAGINATION LINKS] Last page link: ${lastPageUrl}`);
                    }
                    
                    // Return structured data for external processing
                    return {
                        next_page: nextPageUrl,
                        last_page: lastPageUrl,
                        page_links: pageLinks
                    };
                });
                
                // Send a dedicated message with pagination links
                sendMessage('pagination_links', {
                    current_url: request.url,
                    next_page: paginationLinks.next_page,
                    last_page: paginationLinks.last_page,
                    page_links: paginationLinks.page_links,
                    timestamp: Date.now()
                });
                
                sendLog('info', `Extracted ${paginationLinks.page_links.length} pagination links`);

                // Process pagination if enabled
                if (global.pagination.enabled) {
                    // Track all discovered page links for bookkeeping
                    if (paginationLinks.page_links && paginationLinks.page_links.length > 0) {
                        paginationLinks.page_links.forEach(link => {
                            if (!global.pagination.discoveredUrls.has(link.url)) {
                                global.pagination.discoveredUrls.add(link.url);
                                global.pagination.totalPagesDiscovered++;
                            }
                        });
                    }
                    
                    // Track page being processed
                    global.pagination.pagesProcessed++;
                    
                    // Decrement pending requests counter as this page is now processed
                    if (global.pagination.pendingRequests > 0) {
                        global.pagination.pendingRequests--;
                        sendLog('info', `Pagination: Completed pending request (${global.pagination.pendingRequests} pending)`);
                        
                        // If this was the last pending request and we have a completion callback, call it
                        if (global.pagination.pendingRequests === 0 && global.pagination.completionCallback) {
                            sendLog('info', 'All pagination requests completed, calling completion callback');
                            console.error('DIRECT_DEBUG: Calling completion callback as all pages are done');
                            
                            // Use setTimeout to ensure this doesn't block the current request completion
                            setTimeout(() => {
                                try {
                                    global.pagination.completionCallback();
                                } catch (err) {
                                    console.error(`DIRECT_DEBUG: Error in completion callback: ${err.message}`);
                                    console.error(err.stack);
                                }
                            }, 1000);
                        }
                    }
                    
                    // Check if we should continue pagination by checking the next link
                    // rather than trying to figure out the total pages
                    const shouldContinuePagination = 
                        global.pagination.pagesProcessed < global.pagination.maxPages && 
                        paginationLinks.next_page;
                        
                    if (shouldContinuePagination) {
                        // Check if we've already seen this URL
                        if (!global.pagination.visitedUrls.has(paginationLinks.next_page)) {
                            sendLog('info', `Pagination: Queueing next page: ${paginationLinks.next_page} (${global.pagination.pagesProcessed}/${global.pagination.maxPages})`);
                            
                            // Add to visited set
                            global.pagination.visitedUrls.add(paginationLinks.next_page);
                            
                            // Increment pending requests counter
                            global.pagination.pendingRequests++;
                            sendLog('info', `Pagination: Added pending request (now ${global.pagination.pendingRequests} pending)`);
                            
                            // Queue next page with a random delay
                            const minDelay = 3000;  // 3 seconds
                            const maxDelay = 8000;  // 8 seconds
                            const paginationDelay = Math.floor(Math.random() * (maxDelay - minDelay)) + minDelay;
                            
                            sendLog('info', `Pagination: Will process next page after ${paginationDelay}ms delay`);
                            
                            // Schedule next page processing with delay
                            setTimeout(() => {
                                crawler.addRequests([paginationLinks.next_page]);
                                sendLog('info', `Pagination: Added next page to queue: ${paginationLinks.next_page}`);
                            }, paginationDelay);
                        } else {
                            sendLog('info', `Pagination: Next page URL already visited, skipping: ${paginationLinks.next_page}`);
                        }
                    } else {
                        // Log why pagination stopped
                        if (global.pagination.pagesProcessed >= global.pagination.maxPages) {
                            sendLog('info', `Pagination: Reached maximum pages limit (${global.pagination.maxPages})`);
                        } else if (!paginationLinks.next_page) {
                            sendLog('info', `Pagination: No next page link found, reached end of pagination`);
                        }
                    }
                }

                // Check if we have results before proceeding
                const hasResults = await page.evaluate(() => {
                    return !!document.querySelector('#results .result');
                });

                if (!hasResults) {
                    sendLog('error', `No results found on the page. The page might not have loaded properly or the selector is incorrect.`);
                    await page.screenshot({ path: 'no-results-error.png' });
                    throw new Error('No results found in page content');
                }

                // Extract and parse page data with detailed logging
                const pageData = await page.evaluate(() => {
                    function debugLog(message) {
                        console.log("[BROWSER CONSOLE] " + message);
                    }
                    
                    debugLog("Starting data extraction in browser context");
                    
                    // Get basic page info
                    const title = document.title;
                    debugLog(`Page title: ${title}`);
                    
                    const resultsSummary = document.querySelector('.resultsSummary')?.textContent || '';
                    debugLog(`Results summary: ${resultsSummary}`);
                    
                    // Extract total results count from summary
                    const totalResultsMatch = resultsSummary.match(/of (\d+).*matches/);
                    const totalResults = totalResultsMatch ? parseInt(totalResultsMatch[1], 10) : null;
                    debugLog(`Total results found: ${totalResults}`);
                    
                    // Extract results with detailed logging
                    const resultElements = document.querySelectorAll('#results .result');
                    debugLog(`Found ${resultElements.length} result elements`);
                    
                    if (resultElements.length === 0) {
                        debugLog("WARNING: No result elements found with selector '#results .result'");
                        // Debug output of page structure
                        debugLog(`Page HTML structure around results section: ${document.querySelector('#results')?.outerHTML?.substring(0, 500) || 'No #results element found'}`);
                    }
                    
                    const results = Array.from(resultElements).map((result, index) => {
                        const link = result.querySelector('.sumLink a');
                        debugLog(`Result ${index+1} link: ${link?.href || 'not found'}`);
                        
                        const pdfLink = result.querySelector('.sumIcon a')?.href || null;
                        
                        // Extract the system_id from the checkbox value attribute
                        const checkbox = result.querySelector('.sumCheck input[type="checkbox"]');
                        const systemId = checkbox?.value || '';
                        debugLog(`Result ${index+1} system_id: ${systemId || 'not found'}`);
                        
                        // Extract the metadata section which contains date and collection
                        const metaDiv = result.querySelector('.sumMeta');
                        const metaText = metaDiv?.textContent || '';
                        debugLog(`Result ${index+1} metadata: ${metaText || 'not found'}`);
                        
                        // Extract the category information
                        const categorySpan = result.querySelector('.sumLink .cat');
                        const category = categorySpan?.textContent?.trim() || '';
                        
                        return {
                            title: link?.textContent?.trim() || '',
                            url: link?.href || '',
                            pdf_url: pdfLink,
                            result_number: result.querySelector('.sumIndex label')?.textContent || '',
                            system_id: systemId,
                            metadata: metaText,
                            category: category
                        };
                    });

                    // Extract pagination info
                    let paginationInfo = {
                        current_page: document.querySelector('.currentPage')?.textContent || '1',
                        total_pages: Array.from(document.querySelectorAll('.pageNumbers a')).pop()?.textContent || '1'
                    };
                    debugLog(`Pagination info: Current page ${paginationInfo.current_page}, Total pages: ${paginationInfo.total_pages}`);

                    debugLog("Data extraction complete");
                    return {
                        title,
                        results_summary: resultsSummary,
                        total_results: totalResults,
                        pagination: paginationInfo,
                        results
                    };
                });
                
                // Add direct console outputs to bypass any message queuing issues
                console.error("DIRECT_DEBUG: Page data extraction complete, proceeding to processing");
                process.stderr.write(`DIRECT_DEBUG: Extracted ${pageData.results.length} results\n`);
                
                sendLog('info', `Page data extraction complete, found ${pageData.results.length} results`);

                // Process the results to add structured data
                const processedResults = pageData.results.map(result => ({
                    ...result,
                    ...parseCommitteeDetails(result.title),
                    raw_title: result.title
                }));

                // More direct debug
                console.error("DIRECT_DEBUG: Results processed, about to send data");
                process.stderr.write(`DIRECT_DEBUG: Sending ${processedResults.length} results\n`);

                // Create structured data object
                const structuredData = {
                    metadata: {
                        url: request.url,
                        crawled_at: Date.now(),
                        total_results: pageData.total_results,
                        results_summary: cleanText(pageData.results_summary)
                    },
                    page_info: {
                        title: pageData.title,
                        current_page: parseInt(pageData.pagination.current_page, 10),
                        total_pages: parseInt(pageData.pagination.total_pages, 10)
                    },
                    results: processedResults
                };
                
                // Send results using our chunking function
                console.log(`Sending ${processedResults.length} results via chunking mechanism`);
                console.error(`DIRECT_DEBUG: Starting chunked data transfer with ${processedResults.length} results`);
                
                // Initialize global tracking variables if not already set
                if (!global.hasOwnProperty('chunking_in_progress')) {
                    global.chunking_in_progress = false;
                    global.chunks_total = 0;
                    global.chunks_sent = 0;
                }
                
                try {
                    // Send results with chunking and await the completion
                    console.error(`DIRECT_DEBUG: Starting chunked data transfer`);
                    await sendPageResultsInChunks(structuredData);
                    console.error(`DIRECT_DEBUG: Chunked data transfer completed`);
                } catch (chunkError) {
                    console.error(`DIRECT_DEBUG: Error during chunked data transfer: ${chunkError.message}`);
                    console.error(`DIRECT_DEBUG: ${chunkError.stack}`);
                    sendLog('error', `Error sending results: ${chunkError.message}`);
                }
                
                // Send a debug log with the data size
                // sendLog('info', `Data transfer initiated, data size: ${JSON.stringify(structuredData).length} bytes`);
                sendLog('info', 'Processing complete for this page');

            } catch (error) {
                sendLog('error', `Error processing ${request.url}: ${error.message}`);
                sendLog('error', error.stack);
                
                // Try to capture screenshot on error
                try {
                    const screenshotBuffer = await page.screenshot({ fullPage: true });
                    const screenshotBase64 = screenshotBuffer.toString('base64');
                    sendLog('error', `Error screenshot captured to help with debugging`);
                    sendMessage('error_screenshot', { timestamp: Date.now(), data: screenshotBase64.substring(0, 1000) + '...' });
                } catch (screenshotError) {
                    sendLog('error', `Failed to take error screenshot: ${screenshotError.message}`);
                }
                
                sendMessage('error', {
                    url: request.url,
                    message: error.message,
                    stack: error.stack
                });
            }
        },

        // Failure handler
        failedRequestHandler: async ({ request, error }) => {
            sendLog('error', `Failed request for ${request.url}: ${error.message}`);
            sendLog('error', error.stack);
            
            sendMessage('error', {
                url: request.url,
                message: error.message,
                stack: error.stack
            });
        }
    });

    try {
        // sendLog('info', `Starting crawler run with URLs: ${urls.join(', ')}`);
        await crawler.run(urls);
        
        // Check if pagination is still in progress by checking the pendingRequests counter
        if (global.pagination.enabled && global.pagination.pendingRequests > 0) {
            sendLog('info', `Crawler run completed initial URLs, but ${global.pagination.pendingRequests} pagination requests still pending`);
            
            // Set up a completion callback to be called when all pagination is done
            return new Promise((resolve) => {
                global.pagination.completionCallback = () => {
                    sendLog('info', 'All pagination completed, finalizing crawler run');
                    finalizeCrawlerRun().then(() => resolve({ success: true }));
                };
                
                // Also set up a safety timeout
                setTimeout(() => {
                    if (global.pagination.pendingRequests > 0) {
                        sendLog('warning', `Pagination timeout: ${global.pagination.pendingRequests} requests never completed, proceeding with completion anyway`);
                        global.pagination.pendingRequests = 0;
                        finalizeCrawlerRun().then(() => resolve({ success: true }));
                    }
                }, 120000); // 2 minute timeout
            });
        }
        
        // If no pagination or no pending requests, complete normally
        return await finalizeCrawlerRun();
    } catch (error) {
        sendLog('error', `Crawler failed: ${error.message}`);
        sendLog('error', error.stack);
        throw error;
    }
}

// Helper function to simulate human-like behavior
async function simulateHumanBehavior(page) {
    // Random mouse movements
    const moveCount = Math.floor(Math.random() * 3) + 1;
    for (let i = 0; i < moveCount; i++) {
        const x = Math.floor(Math.random() * 800);
        const y = Math.floor(Math.random() * 600);
        await page.mouse.move(x, y, { steps: 10 });
        await new Promise(r => setTimeout(r, Math.random() * 500 + 100));
    }
}

// Helper function to get random user agent
function getRandomUserAgent() {
    const userAgents = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36'
    ];
    return userAgents[Math.floor(Math.random() * userAgents.length)];
}

// Helper function to parse committee details from text
function parseCommitteeDetails(text) {
    // Example: "Parliamentary Standing Committee on Public Works : 19/03/2025 : Department of Climate Change..."
    const parts = text.split(' : ').map(p => p.trim());
    return {
        committee_name: parts[0] || '',
        date: parts[1] || '',
        title: parts[2] || '',
        full_title: text
    };
}

// Helper function to clean and normalize text
function cleanText(text) {
    return text.replace(/\s+/g, ' ').trim();
}

// Helper function to finalize the crawler run (shared code path)
async function finalizeCrawlerRun() {
    console.error(`DIRECT_DEBUG: finalizeCrawlerRun called, chunking_in_progress=${global.chunking_in_progress}`);
    sendLog('info', 'Finalizing crawler run - preparing summary and completion message');
    
    // Check if chunking is in progress
    if (global.chunking_in_progress) {
        sendLog('info', `Chunking still in progress (${global.chunks_sent}/${global.chunks_total} chunks sent)`);
        
        // Wait for chunking to finish with a safety timeout
        let waitTime = 0;
        const checkInterval = 1000; // 1 second
        const maxWaitTime = 30000; // 30 seconds
        
        while (global.chunking_in_progress && waitTime < maxWaitTime) {
            sendLog('info', `Waiting for chunking to complete (${global.chunks_sent}/${global.chunks_total} chunks sent)...`);
            await new Promise(resolve => setTimeout(resolve, checkInterval));
            waitTime += checkInterval;
        }
        
        if (global.chunking_in_progress) {
            sendLog('warning', `Timeout waiting for chunking to complete after ${waitTime}ms, proceeding anyway`);
        } else {
            sendLog('info', `Chunking completed after waiting ${waitTime}ms`);
        }
        
        // Additional safety wait
        await new Promise(resolve => setTimeout(resolve, 5000));
    }
    
    // Create pagination summary for final completion message
    console.error(`DIRECT_DEBUG: Creating pagination summary`);
    const paginationSummary = global.pagination.enabled ? {
        enabled: true,
        pages_processed: global.pagination.pagesProcessed,
        pages_discovered: global.pagination.totalPagesDiscovered,
        max_pages: global.pagination.maxPages,
        visited_urls: Array.from(global.pagination.visitedUrls),
        completed: true
    } : null;
    
    // Log pagination summary if available
    if (paginationSummary) {
        sendLog('info', `Pagination summary: Processed ${paginationSummary.pages_processed} pages, discovered ${paginationSummary.pages_discovered} pages (max: ${paginationSummary.max_pages})`);
    }
    
    // Now that we've waited for chunking, send the completion message
    console.error(`DIRECT_DEBUG: Sending final complete message`);
    try {
        await sendCriticalMessage('complete', { 
            status: 'success',
            pagination: paginationSummary
        });
        console.error(`DIRECT_DEBUG: Final complete message sent successfully`);
    } catch (err) {
        console.error(`DIRECT_DEBUG: Error sending final completion message: ${err.message}`);
    }
    
    return { success: true, pagination: paginationSummary };
} 