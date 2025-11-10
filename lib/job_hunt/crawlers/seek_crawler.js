import { PlaywrightCrawler, log } from 'crawlee';

// Set Crawlee log level to debug for internal logs
log.setLevel(log.LEVELS.DEBUG);

// Initialize global tracking variables for chunking
global.chunking_in_progress = false;
global.chunks_total = 0;
global.chunks_sent = 0;
global.completion_sent = false;

// Add pagination tracking variables
global.pagination = {
    enabled: false,
    maxPages: 5,
    currentPage: 1,
    pagesProcessed: 0,
    visitedUrls: new Set(),
    discoveredUrls: new Set(),
    totalPagesDiscovered: 0,
    pendingRequests: 0,
    completionCallback: null
};

// Redirect Crawlee's internal logs to standardize the format
const originalConsoleLog = console.log;
const originalConsoleDebug = console.debug;
const originalConsoleInfo = console.info;
const originalConsoleWarn = console.warn;
const originalConsoleError = console.error;

// Custom console methods to standardize output
console.log = function(...args) {
    const message = args.join(' ');
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
        data = data || {};
        data._timestamp = Date.now();
        
        const safeData = JSON.parse(JSON.stringify(data));
        const jsonString = JSON.stringify({ type, data: safeData });
        const markedMessage = `\nELIXIR_JSON_MESSAGE: ${jsonString}\n`;
        
        console.error(`DIRECT_DEBUG: Sending message of type '${type}' (${jsonString.length} bytes)`);
        process.stdout.write(markedMessage);
        
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
    
    if (type === 'complete' && global.completion_sent) {
        console.error(`DIRECT_DEBUG: Skipping duplicate complete message - already sent`);
        return true;
    }
    
    data = data || {};
    data._timestamp = Date.now();
    data._critical = true;
    data._source = "seek_crawler.js";
    
    if (type === 'page_complete') {
        data.completed = true;
        data.timestamp = data.timestamp || Date.now();
        if (!data.total_items && data.results) {
            data.total_items = Array.isArray(data.results) ? data.results.length : 0;
        }
    }
    
    console.error(`DIRECT_DEBUG: Message data: ${JSON.stringify(data)}`);
    
    for (let attempt = 1; attempt <= 3; attempt++) {
        console.error(`DIRECT_DEBUG: Critical message attempt ${attempt} for type '${type}'`);
        
        try {
            const jsonString = JSON.stringify({ type, data });
            const markedMessage = `\nELIXIR_JSON_MESSAGE: ${jsonString}\n`;
            
            console.error(`DIRECT_DEBUG: Sending message of type '${type}'`);
            process.stdout.write(markedMessage);
            
            if (process.stdout.flush) {
                process.stdout.flush();
            }
            
            console.error(`DIRECT_DEBUG: Critical message sent successfully, waiting to ensure transmission`);
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            console.error(`CRITICAL_MESSAGE_SENT: ${type} (attempt ${attempt})`);
            await new Promise(resolve => setTimeout(resolve, 500));
            
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

// Send page results in manageable chunks
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
    
    return new Promise(async (resolveChunksComplete) => {
        const CHUNK_SIZE = 20;
        let chunkCount = Math.ceil(results.length / CHUNK_SIZE);
        
        console.error(`DIRECT_DEBUG: Will send ${chunkCount} chunks of size ${CHUNK_SIZE}`);
        
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
            pagination: metadata.pagination
        });
        
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        if (results.length === 0) {
            console.error(`DIRECT_DEBUG: No results to send, sending completion`);
            await sendCriticalMessage('page_complete', {
                total_items: 0,
                timestamp: Date.now(),
                pagination: metadata.pagination
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
            
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            sendMessage('page_results', {
                results: chunk,
                metadata: metadata,
                chunk_index: chunkIndex,
                chunk_total: chunkCount,
                chunk_size: chunk.length,
                pagination: metadata.pagination
            });
            
            console.error(`DIRECT_DEBUG: Sent chunk ${chunkIndex+1}/${chunkCount}`);
            
            if (process.stdout.flush) {
                process.stdout.flush();
            }
            
            global.chunks_sent = chunkIndex + 1;
        }
        
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        const isLastPage = !global.pagination.enabled || 
                          (global.pagination.pendingRequests === 0 && 
                           global.pagination.pagesProcessed >= global.pagination.maxPages);
        
        try {
            await sendCriticalMessage('page_complete', {
                total_items: results.length,
                timestamp: Date.now(),
                metadata: metadata,
                total_results: metadata.total_results || null,
                status: 'success',
                pagination: metadata.pagination,
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
    if (level === 'error') {
        console.error(message);
    } else {
        console.log(`[${level.toUpperCase()}] ${message}`);
    }
    
    sendMessage('log', { level, message });
}

// Read config from stdin
const stdin = process.stdin;
let inputData = '';
let inputComplete = false;

stdin.on('data', (chunk) => {
    inputData += chunk;
    sendLog('debug', `Received input chunk: ${chunk.length} bytes`);
    
    try {
        JSON.parse(inputData.toString().trim());
        if (!inputComplete) {
            inputComplete = true;
            processInput();
        }
    } catch (e) {
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
        
        let config;
        try {
            config = JSON.parse(inputData.toString().trim());
        } catch (parseError) {
            sendLog('error', `Failed to parse JSON input: ${parseError.message}`);
            sendLog('error', `Raw input data: ${inputData.toString().trim().substring(0, 200)}...`);
            sendMessage('error', { message: `Failed to parse JSON input: ${parseError.message}` });
            return;
        }
        
        if (!Array.isArray(config.urls) || config.urls.length === 0) {
            sendLog('error', `No URLs provided in configuration`);
            sendMessage('error', { message: 'No URLs provided in configuration' });
            return;
        }
        
        // Force headless mode for Seek to avoid detection
        config.headless = config.headless !== false; // Default to true unless explicitly false
        
        config.maxRequestsPerCrawl = config.maxRequestsPerCrawl || 10;
        config.maxConcurrency = config.maxConcurrency || 1;
        config.navigationTimeoutSecs = config.navigationTimeoutSecs || 120;
        
        try {
            await runSeekCrawler(config);
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

stdin.resume();

// Function to run the Seek-specific crawler
async function runSeekCrawler(options) {
    const {
        urls,
        headless = true,
        maxRequestsPerCrawl = 10,
        maxConcurrency = 1,
        navigationTimeoutSecs = 120,
        minDelayBetweenRequests = 3000,
        maxDelayBetweenRequests = 8000,
        enablePagination = true,
        maxPages = 5,
    } = options;

    // Set up pagination state
    global.pagination = {
        enabled: enablePagination,
        maxPages: maxPages,
        currentPage: 1,
        pagesProcessed: 0,
        visitedUrls: new Set(urls),
        discoveredUrls: new Set(urls),
        totalPagesDiscovered: urls.length,
        pendingRequests: 0,
        completionCallback: null
    };

    if (enablePagination) {
        sendLog('info', `Pagination enabled: Will crawl up to ${maxPages} pages`);
    }

    const crawler = new PlaywrightCrawler({
        maxRequestsPerCrawl: enablePagination ? maxRequestsPerCrawl * maxPages : maxRequestsPerCrawl,
        maxConcurrency,
        requestHandlerTimeoutSecs: navigationTimeoutSecs,
        
        headless,
        browserPoolOptions: {
            useFingerprints: true, // Use fingerprints for Seek
        },
        launchContext: {
            launchOptions: {
                headless,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--disable-gpu',
                    '--disable-blink-features=AutomationControlled',
                    '--disable-features=VizDisplayCompositor',
                    '--window-size=1920,1080',
                    '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
                ],
            },
        },
        
        async requestHandler({ page, request, enqueueLinks }) {
            console.error(`DIRECT_DEBUG: Starting to process Seek URL ${request.url}`);

            try {
                // Set viewport to look like a real browser
                await page.setViewportSize({ width: 1920, height: 1080 });
                
                // Remove automation indicators
                await page.addInitScript(() => {
                    Object.defineProperty(navigator, 'webdriver', {
                        get: () => undefined,
                    });
                    
                    // Remove chrome automation indicators
                    delete window.chrome.runtime.onConnect;
                    delete window.chrome.runtime.onMessage;
                    
                    // Override the plugins property to mimic a real browser
                    Object.defineProperty(navigator, 'plugins', {
                        get: () => [1, 2, 3, 4, 5],
                    });
                    
                    // Override the languages property
                    Object.defineProperty(navigator, 'languages', {
                        get: () => ['en-US', 'en'],
                    });
                });
                
                // Set additional headers to avoid detection
                await page.setExtraHTTPHeaders({
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
                    'Accept-Language': 'en-US,en;q=0.9',
                    'Accept-Encoding': 'gzip, deflate, br',
                    'Cache-Control': 'max-age=0',
                    'Sec-Ch-Ua': '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
                    'Sec-Ch-Ua-Mobile': '?0',
                    'Sec-Ch-Ua-Platform': '"Windows"',
                    'Sec-Fetch-Dest': 'document',
                    'Sec-Fetch-Mode': 'navigate',
                    'Sec-Fetch-Site': 'none',
                    'Sec-Fetch-User': '?1',
                    'Upgrade-Insecure-Requests': '1',
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
                });

                console.error(`DIRECT_DEBUG: About to navigate to ${request.url}`);
                
                // Navigate with longer timeout
                await page.goto(request.url, { 
                    waitUntil: 'domcontentloaded', 
                    timeout: 180000  // 3 minutes
                });
                
                // Wait for network to be idle with longer timeout
                await page.waitForLoadState('networkidle', { timeout: 180000 });
                
                console.error(`DIRECT_DEBUG: After navigation - network idle ${Date.now()}`);
                sendLog('info', 'Seek page reached network idle state successfully');
                
                // Add human-like behavior
                await simulateHumanBehavior(page);
                
                // Random delay to avoid detection
                const randomDelay = Math.floor(Math.random() * 3000) + 2000;
                await new Promise(resolve => setTimeout(resolve, randomDelay));

                // Check if we're on a job search results page
                const isJobSearchPage = await page.evaluate(() => {
                    return !!document.querySelector('[data-automation="normalJob"]') || 
                           !!document.querySelector('article[data-automation="normalJob"]');
                });

                if (!isJobSearchPage) {
                    sendLog('error', `Page does not appear to be a Seek job search results page`);
                    throw new Error('Not a valid Seek job search results page');
                }

                // Extract pagination info first
                const paginationInfo = await page.evaluate(() => {
                    console.log("[SEEK PAGINATION] Starting to extract pagination links");
                    
                    // Look for next page button
                    const nextButton = document.querySelector('a[aria-label="Go to next page"]') ||
                                     document.querySelector('a[data-automation="page-next"]') ||
                                     document.querySelector('nav a[aria-label*="next"]');
                    
                    const nextPageUrl = nextButton && !nextButton.hasAttribute('disabled') ? 
                                       nextButton.href : null;
                    
                    console.log(`[SEEK PAGINATION] Next page link found: ${nextPageUrl || "None"}`);
                    
                    // Get current page info
                    const currentPageElement = document.querySelector('[aria-current="page"]') ||
                                             document.querySelector('.current-page') ||
                                             document.querySelector('[data-automation="page-current"]');
                    
                    const currentPage = currentPageElement ? 
                                       parseInt(currentPageElement.textContent.trim()) : 1;
                    
                    // Get total pages if available
                    const pageNumbers = Array.from(document.querySelectorAll('nav a[data-automation^="page-"]'))
                                            .map(link => parseInt(link.textContent.trim()))
                                            .filter(num => !isNaN(num));
                    
                    const totalPages = pageNumbers.length > 0 ? Math.max(...pageNumbers) : null;
                    
                    console.log(`[SEEK PAGINATION] Current page: ${currentPage}, Total pages: ${totalPages || "Unknown"}`);
                    
                    return {
                        next_page: nextPageUrl,
                        current_page: currentPage,
                        total_pages: totalPages,
                        has_next: !!nextPageUrl
                    };
                });

                // Send pagination info
                sendMessage('pagination_links', {
                    current_url: request.url,
                    next_page: paginationInfo.next_page,
                    current_page: paginationInfo.current_page,
                    total_pages: paginationInfo.total_pages,
                    has_next: paginationInfo.has_next,
                    timestamp: Date.now()
                });

                // Process pagination if enabled
                if (global.pagination.enabled) {
                    global.pagination.pagesProcessed++;
                    
                    if (global.pagination.pendingRequests > 0) {
                        global.pagination.pendingRequests--;
                        sendLog('info', `Pagination: Completed pending request (${global.pagination.pendingRequests} pending)`);
                        
                        if (global.pagination.pendingRequests === 0 && global.pagination.completionCallback) {
                            sendLog('info', 'All pagination requests completed, calling completion callback');
                            setTimeout(() => {
                                try {
                                    global.pagination.completionCallback();
                                } catch (err) {
                                    console.error(`DIRECT_DEBUG: Error in completion callback: ${err.message}`);
                                }
                            }, 1000);
                        }
                    }
                    
                    const shouldContinuePagination = 
                        global.pagination.pagesProcessed < global.pagination.maxPages && 
                        paginationInfo.next_page;
                        
                    if (shouldContinuePagination) {
                        if (!global.pagination.visitedUrls.has(paginationInfo.next_page)) {
                            sendLog('info', `Pagination: Queueing next page: ${paginationInfo.next_page} (${global.pagination.pagesProcessed}/${global.pagination.maxPages})`);
                            
                            global.pagination.visitedUrls.add(paginationInfo.next_page);
                            global.pagination.pendingRequests++;
                            
                            const paginationDelay = Math.floor(Math.random() * 5000) + 5000; // 5-10 seconds
                            
                            setTimeout(() => {
                                crawler.addRequests([paginationInfo.next_page]);
                                sendLog('info', `Pagination: Added next page to queue: ${paginationInfo.next_page}`);
                            }, paginationDelay);
                        }
                    }
                }

                // Extract job data from the page
                const pageData = await page.evaluate(() => {
                    function debugLog(message) {
                        console.log("[SEEK BROWSER] " + message);
                    }
                    
                    debugLog("Starting Seek job data extraction");
                    
                    const title = document.title;
                    debugLog(`Page title: ${title}`);
                    
                    // Find job cards
                    const jobCards = document.querySelectorAll('[data-automation="normalJob"], article[data-automation="normalJob"]');
                    debugLog(`Found ${jobCards.length} job cards`);
                    
                    if (jobCards.length === 0) {
                        debugLog("WARNING: No job cards found");
                        return { title, results: [] };
                    }
                    
                    const results = Array.from(jobCards).map((card, index) => {
                        try {
                            // Extract job title and link
                            const titleLink = card.querySelector('a[data-automation="jobTitle"]') ||
                                            card.querySelector('h3 a') ||
                                            card.querySelector('a[href*="/job/"]');
                            
                            const jobTitle = titleLink ? titleLink.textContent.trim() : '';
                            const jobUrl = titleLink ? titleLink.href : '';
                            
                            // Extract Seek job ID from URL
                            const seekJobIdMatch = jobUrl.match(/jobId=(\d+)/);
                            const seekJobId = seekJobIdMatch ? seekJobIdMatch[1] : '';
                            
                            // Extract company name
                            const companyElement = card.querySelector('[data-automation="jobCompany"]') ||
                                                 card.querySelector('a[data-automation="jobCompany"]') ||
                                                 card.querySelector('[data-automation="advertiser-name"]');
                            
                            const company = companyElement ? companyElement.textContent.trim() : '';
                            
                            // Extract location
                            const locationElement = card.querySelector('[data-automation="jobLocation"]') ||
                                                  card.querySelector('[data-automation="job-location"]');
                            
                            const location = locationElement ? locationElement.textContent.trim() : '';
                            
                            // Extract salary if available
                            const salaryElement = card.querySelector('[data-automation="jobSalary"]') ||
                                                card.querySelector('[data-automation="job-salary"]') ||
                                                card.querySelector('.salary');
                            
                            const salary = salaryElement ? salaryElement.textContent.trim() : '';
                            
                            // Extract job description/summary
                            const descriptionElement = card.querySelector('[data-automation="jobShortDescription"]') ||
                                                      card.querySelector('.job-summary') ||
                                                      card.querySelector('p');
                            
                            const description = descriptionElement ? descriptionElement.textContent.trim() : '';
                            
                            debugLog(`Job ${index + 1}: ${jobTitle} at ${company}`);
                            
                            return {
                                title: jobTitle,
                                employer: company,
                                location: location,
                                salary: salary || 'Not specified',
                                apply_link: jobUrl,
                                seek_job_id: seekJobId,
                                description: description,
                                raw_data: {
                                    url: jobUrl,
                                    extracted_at: Date.now()
                                }
                            };
                        } catch (error) {
                            debugLog(`Error extracting job ${index + 1}: ${error.message}`);
                            return null;
                        }
                    }).filter(job => job !== null && job.title && job.employer);
                    
                    debugLog(`Successfully extracted ${results.length} valid jobs`);
                    
                    return {
                        title,
                        results,
                        pagination: {
                            current_page: 1, // Will be updated from pagination info
                            total_pages: null
                        }
                    };
                });
                
                console.error("DIRECT_DEBUG: Seek job data extraction complete");
                console.error(`DIRECT_DEBUG: Extracted ${pageData.results.length} jobs`);
                
                sendLog('info', `Seek page data extraction complete, found ${pageData.results.length} jobs`);

                // Create structured data object
                const structuredData = {
                    metadata: {
                        url: request.url,
                        crawled_at: Date.now(),
                        total_results: pageData.results.length,
                        source: 'seek.com.au'
                    },
                    page_info: {
                        title: pageData.title,
                        current_page: paginationInfo.current_page,
                        total_pages: paginationInfo.total_pages
                    },
                    results: pageData.results
                };
                
                console.error(`DIRECT_DEBUG: Starting chunked data transfer with ${pageData.results.length} results`);
                
                try {
                    await sendPageResultsInChunks(structuredData);
                    console.error(`DIRECT_DEBUG: Chunked data transfer completed`);
                } catch (chunkError) {
                    console.error(`DIRECT_DEBUG: Error during chunked data transfer: ${chunkError.message}`);
                    sendLog('error', `Error sending results: ${chunkError.message}`);
                }
                
                sendLog('info', 'Seek page processing complete');

            } catch (error) {
                sendLog('error', `Error processing Seek page ${request.url}: ${error.message}`);
                sendLog('error', error.stack);
                
                try {
                    const screenshotBuffer = await page.screenshot({ fullPage: true });
                    sendLog('error', `Error screenshot captured for debugging`);
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

        failedRequestHandler: async ({ request, error }) => {
            sendLog('error', `Failed request for ${request.url}: ${error.message}`);
            sendMessage('error', {
                url: request.url,
                message: error.message,
                stack: error.stack
            });
        }
    });

    try {
        await crawler.run(urls);
        
        if (global.pagination.enabled && global.pagination.pendingRequests > 0) {
            sendLog('info', `Crawler run completed initial URLs, but ${global.pagination.pendingRequests} pagination requests still pending`);
            
            return new Promise((resolve) => {
                global.pagination.completionCallback = () => {
                    sendLog('info', 'All pagination completed, finalizing crawler run');
                    finalizeCrawlerRun().then(() => resolve({ success: true }));
                };
                
                setTimeout(() => {
                    if (global.pagination.pendingRequests > 0) {
                        sendLog('warning', `Pagination timeout: ${global.pagination.pendingRequests} requests never completed, proceeding with completion anyway`);
                        global.pagination.pendingRequests = 0;
                        finalizeCrawlerRun().then(() => resolve({ success: true }));
                    }
                }, 180000); // 3 minute timeout
            });
        }
        
        return await finalizeCrawlerRun();
    } catch (error) {
        sendLog('error', `Seek crawler failed: ${error.message}`);
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
    
    // Random scroll
    await page.evaluate(() => {
        window.scrollBy(0, Math.floor(Math.random() * 500) + 100);
    });
    
    await new Promise(r => setTimeout(r, Math.random() * 1000 + 500));
}

// Helper function to finalize the crawler run
async function finalizeCrawlerRun() {
    console.error(`DIRECT_DEBUG: finalizeCrawlerRun called, chunking_in_progress=${global.chunking_in_progress}`);
    sendLog('info', 'Finalizing Seek crawler run');
    
    if (global.chunking_in_progress) {
        sendLog('info', `Chunking still in progress (${global.chunks_sent}/${global.chunks_total} chunks sent)`);
        
        let waitTime = 0;
        const checkInterval = 1000;
        const maxWaitTime = 30000;
        
        while (global.chunking_in_progress && waitTime < maxWaitTime) {
            sendLog('info', `Waiting for chunking to complete (${global.chunks_sent}/${global.chunks_total} chunks sent)...`);
            await new Promise(resolve => setTimeout(resolve, checkInterval));
            waitTime += checkInterval;
        }
        
        if (global.chunking_in_progress) {
            sendLog('warning', `Timeout waiting for chunking to complete after ${waitTime}ms, proceeding anyway`);
        }
        
        await new Promise(resolve => setTimeout(resolve, 5000));
    }
    
    const paginationSummary = global.pagination.enabled ? {
        enabled: true,
        pages_processed: global.pagination.pagesProcessed,
        pages_discovered: global.pagination.totalPagesDiscovered,
        max_pages: global.pagination.maxPages,
        visited_urls: Array.from(global.pagination.visitedUrls),
        completed: true
    } : null;
    
    if (paginationSummary) {
        sendLog('info', `Pagination summary: Processed ${paginationSummary.pages_processed} pages, discovered ${paginationSummary.pages_discovered} pages (max: ${paginationSummary.max_pages})`);
    }
    
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