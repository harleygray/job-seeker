// PDF Download Crawler
// Specialized crawler for downloading PDFs, designed to bypass WAF restrictions

import { PlaywrightCrawler, FileDownload, log, LogLevel } from 'crawlee';
import { readFileSync, existsSync, writeFileSync } from 'fs';
import { dirname } from 'path';
import { execSync } from 'child_process';
import { pipeline } from 'stream';
import { createWriteStream } from 'fs';
import https from 'https';
import http from 'http';

// Set high level of logging to capture all details
log.setLevel(LogLevel.DEBUG);

// Communication functions
function sendMessage(type, data) {
    try {
        const message = {
            type,
            data
        };
        
        // Send the structured message to Elixir
        const jsonString = JSON.stringify(message);
        console.log(`ELIXIR_JSON_MESSAGE:${jsonString}`);
    } catch (error) {
        console.error(`Error sending message: ${error.message}`);
    }
}

// Critical messages sent with confirmation for reliability
async function sendCriticalMessage(type, data) {
    try {
        // Send main message
        sendMessage(type, data);
        
        // Send a backup confirmation message that's easier to detect
        console.log(`CRITICAL_MESSAGE_SENT: ${type}`);
        
        // Small delay to ensure messages are processed separately
        await new Promise(resolve => setTimeout(resolve, 200));
    } catch (error) {
        console.error(`Error sending critical message: ${error.message}`);
    }
}

// Logging utility
function sendLog(level, message) {
    console.log(`LOG: [${level.toUpperCase()}] ${message}`);
    
    // Also send structured log for more reliable parsing
    sendMessage('log', { level, message });
    
    // Also log using Crawlee's logger
    switch(level) {
        case 'debug':
            log.debug(message);
            break;
        case 'info':
            log.info(message);
            break;
        case 'warning':
            log.warning(message);
            break;
        case 'error':
            log.error(message);
            break;
        default:
            log.info(message);
    }
}

// Verify directory and file permissions
function verifyDirectory(dirPath) {
    try {
        // Using child_process to get detailed info about the directory
        const lsOutput = execSync(`ls -la ${dirPath}`).toString();
        sendLog('info', `Directory details: ${lsOutput.split('\n').slice(0, 3).join('\n')}`);
        return true;
    } catch (error) {
        sendLog('error', `Failed to verify directory ${dirPath}: ${error.message}`);
        return false;
    }
}

// Direct file download using Node.js native https/http
function downloadFileWithNative(url, outputPath) {
    return new Promise((resolve, reject) => {
        // Determine if http or https
        const client = url.startsWith('https') ? https : http;
        
        // Create request with browser-like headers
        const request = client.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/pdf,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9',
                'Referer': 'https://parlinfo.aph.gov.au/',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
                'Sec-Fetch-Dest': 'document',
                'Sec-Fetch-Mode': 'navigate',
                'Sec-Fetch-Site': 'same-origin',
                'Pragma': 'no-cache',
                'Cache-Control': 'no-cache'
            }
        }, (response) => {
            // Log response details
            sendLog('debug', `Response status: ${response.statusCode} ${response.statusMessage}`);
            sendLog('debug', `Response headers: ${JSON.stringify(response.headers)}`);
            
            // Handle redirects
            if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
                const redirectUrl = new URL(response.headers.location, url).toString();
                return downloadFileWithNative(redirectUrl, outputPath).then(resolve).catch(reject);
            }
            
            // Check for successful response
            if (response.statusCode !== 200) {
                const error = new Error(`Failed to download file: HTTP status ${response.statusCode} ${response.statusMessage}`);
                sendLog('error', error.message);
                return reject(error);
            }
            
            // Create write stream for output file
            const fileStream = createWriteStream(outputPath);
            
            // Log content type
            const contentType = response.headers['content-type'] || 'unknown';
            sendLog('info', `Content-Type: ${contentType}`);
            
            let downloadedBytes = 0;
            const totalBytes = parseInt(response.headers['content-length'] || '0', 10);
            
            // Set up pipeline
            pipeline(
                response,
                fileStream,
                (error) => {
                    if (error) {
                        sendLog('error', `Pipeline error: ${error.message}`);
                        reject(error);
                    }
                }
            );
            
            // Log progress
            response.on('data', (chunk) => {
                downloadedBytes += chunk.length;
                if (totalBytes > 0 && downloadedBytes % 100000 === 0) {
                    const percentage = Math.round((downloadedBytes / totalBytes) * 100);
                    sendLog('debug', `Downloaded ${downloadedBytes} bytes (${percentage}%)`);
                }
            });
            
            // Handle completion
            fileStream.on('finish', () => {
                fileStream.close();
                sendLog('info', `Download completed to ${outputPath} (${downloadedBytes} bytes)`);
                
                // Verify file was created
                if (existsSync(outputPath)) {
                    const stats = execSync(`ls -la ${outputPath}`).toString().trim();
                    sendLog('info', `File verified with stats: ${stats}`);
                    resolve(true);
                } else {
                    const error = new Error('File was not created after download completed');
                    sendLog('error', error.message);
                    reject(error);
                }
            });
            
            // Handle errors
            response.on('error', (error) => {
                sendLog('error', `Response error: ${error.message}`);
                fileStream.close();
                reject(error);
            });
            
            fileStream.on('error', (error) => {
                sendLog('error', `File write error: ${error.message}`);
                fileStream.close();
                reject(error);
            });
        });
        
        request.on('error', (error) => {
            sendLog('error', `Request error: ${error.message}`);
            reject(error);
        });
        
        // Set timeout
        request.setTimeout(60000, () => {
            request.destroy();
            reject(new Error('Request timed out after 60 seconds'));
        });
    });
}

// Main function to process input
async function processInput() {
    let config;
    
    try {
        // Read configuration from stdin
        const inputChunks = [];
        process.stdin.setEncoding('utf8');
        
        for await (const chunk of process.stdin) {
            inputChunks.push(chunk);
            // Break when we have a complete JSON object
            if (chunk.includes('}')) break;
        }
        
        const inputData = inputChunks.join('');
        sendLog('debug', `Received input data: ${inputData}`);
        
        try {
            config = JSON.parse(inputData);
        } catch (parseError) {
            sendLog('error', `Failed to parse JSON input: ${parseError.message}`);
            sendLog('error', `Input data was: ${inputData}`);
            throw parseError;
        }
        
        // Validate required configuration
        if (!config.urls || !Array.isArray(config.urls) || config.urls.length === 0) {
            throw new Error('Configuration must include at least one URL');
        }
        
        sendLog('info', `Received configuration with ${config.urls.length} URLs`);
        
        // Verify access to output directory first
        if (config.outputPath) {
            const outputDir = dirname(config.outputPath);
            sendLog('info', `Verifying output directory: ${outputDir}`);
            verifyDirectory(outputDir);
        }
        
        // First try downloading with native Node.js methods
        if (config.outputPath) {
            try {
                const success = await downloadFileWithNative(config.urls[0], config.outputPath);
                
                if (success) {
                    await sendCriticalMessage('page_complete', {
                        status: 'success',
                        completed: true,
                        file_verified: true,
                        method: 'native-http',
                        timestamp: new Date().toISOString()
                    });
                    return;
                }
            } catch (nativeError) {
                sendLog('warning', `Native download failed: ${nativeError.message}, trying Crawlee...`);
            }
        }
        
        // If native download failed, try with Crawlee
        try {
            // Run the PDF download crawler with the configuration
            await runPdfDownloader(config);
        } catch (crawleeError) {
            sendLog('error', `Crawlee download failed: ${crawleeError.message}`);
            throw crawleeError;
        }
        
    } catch (error) {
        sendLog('error', `Failed to process input: ${error.message}`);
        sendLog('error', `Stack trace: ${error.stack}`);
        await sendCriticalMessage('error', {
            error: error.message,
            stack: error.stack
        });
        process.exit(1);
    }
}

// Main PDF download crawler function using FileDownload
async function runPdfDownloader(options) {
    const {
        urls,
        outputPath = null  // Path to save the PDF, provided by Elixir
    } = options;
    
    sendLog('info', `Starting PDF download crawler for URL: ${urls[0]}`);
    sendLog('info', `Output path: ${outputPath}`);
    
    // Track if file was successfully saved
    let pdfSavedSuccessfully = false;
    
    try {
        // Method 1: Try using FileDownload class first
        sendLog('info', 'Trying download with Crawlee FileDownload...');
        
        // Create a FileDownload instance for downloading the PDF
        const fileDownloader = new FileDownload({
            maxRequestRetries: 2,
            requestHandlerTimeoutSecs: 120,
            
            // Use the stream handler for larger files and better control
            async streamHandler({ stream, request, log, response }) {
                const url = new URL(request.url);
                
                // Log all response headers for debugging
                sendLog('debug', `Response headers: ${JSON.stringify(response.headers)}`);
                
                // Log details about the download
                sendLog('info', `Downloading ${url} with content-type: ${response.headers['content-type']}`);
                sendLog('info', `Content-length: ${response.headers['content-length'] || 'unknown'} bytes`);
                
                if (outputPath) {
                    return new Promise((resolve, reject) => {
                        const fileStream = createWriteStream(outputPath);
                        let downloadedBytes = 0;
                        
                        stream.on('data', (chunk) => {
                            downloadedBytes += chunk.length;
                            if (downloadedBytes % 100000 === 0) {
                                sendLog('debug', `Downloaded ${downloadedBytes} bytes`);
                            }
                        });
                        
                        stream.pipe(fileStream);
                        
                        fileStream.on('finish', () => {
                            sendLog('info', `File saved to ${outputPath} (${downloadedBytes} bytes)`);
                            
                            // Verify the file exists and has content
                            if (existsSync(outputPath)) {
                                const stats = execSync(`ls -la ${outputPath}`).toString().trim();
                                sendLog('info', `File verification: ${stats}`);
                                pdfSavedSuccessfully = true;
                                resolve();
                            } else {
                                const error = new Error(`File not found at ${outputPath} after download completed`);
                                sendLog('error', error.message);
                                reject(error);
                            }
                        });
                        
                        stream.on('error', (error) => {
                            sendLog('error', `Stream error: ${error.message}`);
                            reject(error);
                        });
                        
                        fileStream.on('error', (error) => {
                            sendLog('error', `File write error: ${error.message}`);
                            reject(error);
                        });
                    });
                } else {
                    sendLog('warning', 'No output path provided, skipping download');
                }
            },
            
            // Fallback to body handler if stream handler fails
            async requestHandler({ body, request, contentType }) {
                if (pdfSavedSuccessfully) return; // Skip if already downloaded
                
                const url = new URL(request.url);
                sendLog('info', `Received file ${url.pathname} with type ${contentType?.type || 'unknown'}`);
                
                // Save the file if we have an output path
                if (outputPath && body) {
                    // For binary data, we need to write the buffer directly
                    if (Buffer.isBuffer(body)) {
                        sendLog('info', `Writing ${body.length} bytes to ${outputPath}`);
                        writeFileSync(outputPath, body);
                    } else {
                        sendLog('error', `Unexpected body type: ${typeof body}`);
                        return;
                    }
                    
                    // Verify the file was created
                    if (existsSync(outputPath)) {
                        const stats = execSync(`ls -la ${outputPath}`).toString().trim();
                        sendLog('info', `File saved and verified: ${stats}`);
                        pdfSavedSuccessfully = true;
                    } else {
                        sendLog('error', `File not found at ${outputPath} after writing`);
                    }
                }
            },
            
            // Handle failed requests
            failedRequestHandler({ request, error }) {
                sendLog('error', `Failed to download ${request.url}: ${error.message}`);
                sendLog('error', `Error stack: ${error.stack}`);
            }
        });
        
        // Add the URL to the downloader
        await fileDownloader.addRequests(urls);
        
        // Run the downloader
        await fileDownloader.run();
        
        // Final check - was the file successfully saved?
        if (outputPath && existsSync(outputPath)) {
            const stats = execSync(`ls -la ${outputPath}`).toString().trim();
            sendLog('info', `Final verification - file exists with stats: ${stats}`);
            pdfSavedSuccessfully = true;
            
            // Send success message
            await sendCriticalMessage('page_complete', {
                status: 'success',
                completed: true,
                file_verified: true,
                method: 'crawlee-file-download',
                timestamp: new Date().toISOString()
            });
        } else {
            sendLog('error', 'FileDownload completed but file not found or empty');
            throw new Error('File not created after download completed');
        }
        
    } catch (error) {
        sendLog('error', `PDF download failed: ${error.message}`);
        sendLog('error', `Stack trace: ${error.stack}`);
        
        await sendCriticalMessage('error', {
            error: error.message,
            stack: error.stack,
            url: urls[0]
        });
        
        throw error;
    } finally {
        // Always try to send completion
        await sendCriticalMessage('complete', {
            status: pdfSavedSuccessfully ? 'success' : 'failed',
            timestamp: new Date().toISOString()
        });
    }
}

// Start processing input
processInput().catch(error => {
    console.error(`Fatal error: ${error.message}`);
    console.error(error.stack);
    process.exit(1);
});
