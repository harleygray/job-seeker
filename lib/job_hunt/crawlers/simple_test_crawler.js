// Simple test crawler to verify communication
console.error("TEST CRAWLER: Starting");

// Simple direct message sender that doesn't rely on any complex logic
function sendDirectMessage(type, data) {
    // Add timestamp
    data = data || {};
    data.timestamp = Date.now();
    
    // Log to stderr for guaranteed output
    console.error(`SENDING_MESSAGE: ${type}`);
    
    // Write to stdout for Elixir
    const message = JSON.stringify({ type, data });
    process.stdout.write(message + "\n");
    
    // Force flush
    if (process.stdout.flush) {
        process.stdout.flush();
    }
    
    // Debug confirmation
    console.error(`SENT_MESSAGE: ${type}`);
}

// Read stdin
const stdin = process.stdin;
let inputBuffer = '';

// Listen for data
stdin.on('data', (chunk) => {
    console.error(`TEST CRAWLER: Received chunk of ${chunk.length} bytes`);
    inputBuffer += chunk;
    
    // Try to parse JSON
    try {
        const config = JSON.parse(inputBuffer);
        console.error(`TEST CRAWLER: Parsed config: ${JSON.stringify(config)}`);
        
        // Send acknowledgment
        sendDirectMessage('log', { level: 'info', message: 'Configuration received' });
        
        // Send test results
        console.error('TEST CRAWLER: Sending test results');
        setTimeout(() => {
            // Create a date for testing
            const today = new Date();
            const formattedDate = `${today.getDate().toString().padStart(2, '0')}/${(today.getMonth() + 1).toString().padStart(2, '0')}/${today.getFullYear()}`;
            
            // Send test results with minimal data
            sendDirectMessage('page_results', {
                metadata: { test: true, url: "https://test.example.com" },
                page_info: { title: 'Test Page', current_page: 1, total_pages: 1 },
                results: [
                    { 
                        title: 'Test Result 1', 
                        committee_name: 'Test Committee', 
                        date: formattedDate,
                        date_held: formattedDate,
                        url: "https://test.example.com/result1"
                    },
                    { 
                        title: 'Test Result 2', 
                        committee_name: 'Test Committee', 
                        date: formattedDate,
                        date_held: formattedDate,
                        url: "https://test.example.com/result2"
                    }
                ]
            });
            
            // Send completion after 1 second
            setTimeout(() => {
                console.error('TEST CRAWLER: Sending completion');
                sendDirectMessage('complete', { status: 'success' });
                
                // Exit after 1 more second
                setTimeout(() => {
                    console.error('TEST CRAWLER: Exiting');
                    process.exit(0);
                }, 1000);
            }, 1000);
        }, 1000);
        
    } catch (e) {
        // Not complete JSON yet
        console.error(`TEST CRAWLER: Waiting for more data - ${e.message}`);
    }
});

// Keep alive
stdin.resume();
console.error("TEST CRAWLER: Ready for input"); 