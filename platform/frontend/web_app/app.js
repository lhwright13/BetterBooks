// Route all requests through API Gateway for proper load balancing and auth
const apiBase = 'http://localhost:8002'; // API Gateway - routes to all services (updated to match current port forwarding)
const transcriptionBase = 'http://localhost:8002'; // API Gateway handles routing to transcription service

// Player elements
const audioPlayer = document.getElementById('audioPlayer');
const bookSelect = document.getElementById('bookSelect');
const chapterSelect = document.getElementById('chapterSelect');
const chapterNavigation = document.getElementById('chapterNavigation');
const playerStatus = document.getElementById('playbackStatus');
const configSelect = document.getElementById('configSelect');
const currentBookInfo = document.getElementById('currentBook');

// Current context tracking
let currentContext = {
  bookName: null,
  bookType: null, // 'single' or 'chapters'
  chapterName: null,
  hasContext: false,
  currentPosition: 0, // Current playback position in seconds
  lastContextUpdate: 0 // Last time we updated context
};

// Book management elements
const singleBookFile = document.getElementById('singleBookFile');
const uploadSingleBtn = document.getElementById('uploadSingle');
const bookNameInput = document.getElementById('bookName');
const chapterFiles = document.getElementById('chapterFiles');
const uploadChaptersBtn = document.getElementById('uploadChapters');
const booksListDiv = document.getElementById('booksList');
const refreshBooksBtn = document.getElementById('refreshLibrary');

async function loadConfigs() {
  if (!configSelect) return;
  try {
    // Clear existing options first
    configSelect.innerHTML = '';
    
    const res = await fetch(`${apiBase}/configs`);
    const data = await res.json();
    data.configs.forEach((name) => {
      const opt = document.createElement('option');
      opt.value = name;
      opt.textContent = name;
      configSelect.appendChild(opt);
    });
  } catch (err) {
    console.error('Failed to load configs', err);
    alert('Failed to load configs. Please check the console for details.');
  }
}

async function getDetailedContext() {
  console.log('Getting detailed context for:', {
    bookName: currentContext.bookName,
    chapterName: currentContext.chapterName,
    currentPosition: currentContext.currentPosition
  });
  
  try {
    // Add timeout for context extraction
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout
    
    const contextRes = await fetch(`${transcriptionBase}/context`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: controller.signal,
      body: JSON.stringify({
        book_name: currentContext.bookName,
        chapter_name: currentContext.chapterName,
        current_position: currentContext.currentPosition
      })
    });
    
    clearTimeout(timeoutId);
    
    console.log('Context response status:', contextRes.status);
    
    if (contextRes.ok) {
      const contextData = await contextRes.json();
      console.log('Context data received:', contextData.context_text ? 'Yes' : 'No', contextData.context_text?.length || 0, 'characters');
      return contextData.context_text || null;
    } else {
      console.error('Context request failed:', contextRes.status, contextRes.statusText);
    }
  } catch (err) {
    if (err.name === 'AbortError') {
      console.warn('Context extraction timed out, proceeding without detailed context');
    } else {
      console.error('Failed to get detailed context:', err);
    }
  }
  
  return null;
}

async function sendPrompt(prompt, config, enableVoiceResponse = false) {
  const respDiv = document.getElementById('response');
  
  // Check if we have context before sending
  if (!currentContext.hasContext) {
    respDiv.textContent = 'Error: Please select a book in the Audio Player section before asking questions. I need to know which book you\'re referring to!';
    respDiv.style.color = '#ff6b6b';
    return;
  }
  
  respDiv.textContent = 'Extracting audio context...';
  respDiv.style.color = '#e0e0e0';
  
  try {
    // Get detailed context from current position
    const detailedContext = await getDetailedContext();
    
    respDiv.textContent = 'Generating response...';
    
    // Create context-aware prompt
    let contextualPrompt = `Book: "${currentContext.bookName}"`;
    if (currentContext.bookType === 'chapters' && currentContext.chapterName) {
      contextualPrompt += `, Chapter: "${currentContext.chapterName}"`;
    }
    
    const minutes = Math.floor(currentContext.currentPosition / 60);
    const seconds = Math.floor(currentContext.currentPosition % 60);
    contextualPrompt += `\nCurrent position: ${minutes}:${seconds.toString().padStart(2, '0')}`;
    
    if (detailedContext) {
      contextualPrompt += `\n\nRecent audio transcript:\n${detailedContext}`;
    } else {
      contextualPrompt += `\n\nNote: Unable to extract recent audio transcript (processing may have timed out), but I can still help with general questions about this book.`;
    }
    
    contextualPrompt += `\n\nUser question: ${prompt}`;
    
    console.log('Final prompt being sent:', contextualPrompt);
    
    const res = await fetch(`${apiBase}/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        prompt: contextualPrompt, 
        config: config,
        max_tokens: 4000
      })
    });
    const data = await res.json();
    
    // Use typewriter effect for response display
    const responseText = data.text || JSON.stringify(data);
    respDiv.style.color = 'var(--stellar-white)';
    if (window.typewriterEffect) {
      window.typewriterEffect(respDiv, responseText, 30);
    } else {
      respDiv.textContent = responseText;
    }

    // Only use TTS if voice response is requested
    if (enableVoiceResponse && data.text) {
      respDiv.textContent = 'Converting to speech...';
      
      try {
        // Use Web Speech API for text-to-speech (built into browser)
        if ('speechSynthesis' in window) {
          const utterance = new SpeechSynthesisUtterance(data.text);
          utterance.rate = 0.9;
          utterance.pitch = 1;
          utterance.volume = 0.8;
          
          // Find a good voice
          const voices = speechSynthesis.getVoices();
          const preferredVoice = voices.find(voice => 
            voice.lang.startsWith('en') && voice.name.includes('Natural')
          ) || voices.find(voice => voice.lang.startsWith('en')) || voices[0];
          
          if (preferredVoice) {
            utterance.voice = preferredVoice;
          }
          
          utterance.onstart = () => {
            respDiv.textContent = responseText + '\n\n🔊 Playing audio response...';
            respDiv.style.color = 'var(--teal-blue)';
          };
          
          utterance.onend = () => {
            respDiv.textContent = responseText;
            respDiv.style.color = 'var(--stellar-white)';
          };
          
          utterance.onerror = (event) => {
            console.error('Speech synthesis error:', event);
            respDiv.textContent = responseText + '\n\n⚠️ Voice response failed, but text is available above.';
            respDiv.style.color = 'var(--golden-yellow)';
          };
          
          speechSynthesis.speak(utterance);
        } else {
          console.warn('Speech synthesis not supported');
          respDiv.textContent = responseText + '\n\n⚠️ Voice response not supported in this browser.';
          respDiv.style.color = 'var(--golden-yellow)';
        }
      } catch (ttsError) {
        console.error('TTS error:', ttsError);
        respDiv.textContent = responseText + '\n\n⚠️ Voice response failed, but text is available above.';
        respDiv.style.color = 'var(--golden-yellow)';
      }
    }
  } catch (err) {
    respDiv.textContent = 'Error: ' + err;
    respDiv.style.color = '#ff6b6b';
  }
}

// Chat functions for the new interface
function addMessageToChat(role, message) {
  const chatMessages = document.getElementById('chatMessages');
  if (!chatMessages) return;
  
  const messageDiv = document.createElement('div');
  messageDiv.className = `chat-message ${role}`;
  
  const avatarDiv = document.createElement('div');
  avatarDiv.className = 'message-avatar';
  avatarDiv.innerHTML = `<div class="avatar-icon">${role === 'user' ? '👤' : '🤖'}</div>`;
  
  const contentDiv = document.createElement('div');
  contentDiv.className = 'message-content';
  
  const bubbleDiv = document.createElement('div');
  bubbleDiv.className = `message-bubble ${role === 'user' ? 'user' : 'assistant'}`;
  bubbleDiv.innerHTML = `<p>${message}</p>`;
  
  contentDiv.appendChild(bubbleDiv);
  messageDiv.appendChild(avatarDiv);
  messageDiv.appendChild(contentDiv);
  
  chatMessages.appendChild(messageDiv);
  
  // Scroll to bottom
  chatMessages.scrollTop = chatMessages.scrollHeight;
}

async function sendChatMessage(prompt, config, enableVoiceResponse = false) {
  try {
    // Show loading message
    addMessageToChat('assistant', '🤔 Thinking...');
    
    // Check if we have context
    if (!currentContext.hasContext) {
      const lastMessage = document.querySelector('.chat-message:last-child .message-bubble');
      if (lastMessage) {
        lastMessage.innerHTML = '<p>⚠️ Please select a book first so I know which audiobook you\'re asking about!</p>';
      }
      return;
    }
    
    // Get detailed context if available
    let contextualPrompt = `Book: "${currentContext.bookName}"`;
    if (currentContext.bookType === 'chapters' && currentContext.chapterName) {
      contextualPrompt += `, Chapter: "${currentContext.chapterName}"`;
    }
    
    const minutes = Math.floor(currentContext.currentPosition / 60);
    const seconds = Math.floor(currentContext.currentPosition % 60);
    contextualPrompt += `\nCurrent position: ${minutes}:${seconds.toString().padStart(2, '0')}`;
    
    // Try to get detailed context
    const detailedContext = await getDetailedContext();
    if (detailedContext) {
      contextualPrompt += `\n\nRecent audio transcript:\n${detailedContext}`;
    }
    
    contextualPrompt += `\n\nUser question: ${prompt}`;
    
    // Send to API
    const response = await fetch(`${apiBase}/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        prompt: contextualPrompt,
        config: config,
        max_tokens: 2000
      })
    });
    
    let responseText;
    if (response.ok) {
      const data = await response.json();
      responseText = data.text || 'Sorry, I couldn\'t generate a response.';
    } else {
      // Fallback to demo mode response
      console.log('AI chat endpoint failed, using demo response');
      responseText = generateDemoResponse(prompt, currentContext);
    }
    
    // Update the last message with the actual response
    const lastMessage = document.querySelector('.chat-message:last-child .message-bubble');
    if (lastMessage) {
      lastMessage.innerHTML = `<p>${responseText}</p>`;
    }
    
    // Handle voice response if requested
    if (enableVoiceResponse) {
      speakText(responseText);
    }
    
  } catch (error) {
    console.error('Chat error:', error);
    const lastMessage = document.querySelector('.chat-message:last-child .message-bubble');
    if (lastMessage) {
      lastMessage.innerHTML = '<p>❌ Sorry, there was an error processing your request. Please try again.</p>';
    }
  }
}

function speakText(text) {
  if ('speechSynthesis' in window) {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 0.9;
    utterance.pitch = 1;
    utterance.volume = 0.8;
    
    const voices = speechSynthesis.getVoices();
    const preferredVoice = voices.find(voice => 
      voice.lang.startsWith('en') && voice.name.includes('Natural')
    ) || voices.find(voice => voice.lang.startsWith('en')) || voices[0];
    
    if (preferredVoice) {
      utterance.voice = preferredVoice;
    }
    
    speechSynthesis.speak(utterance);
  }
}

function generateDemoResponse(prompt, context) {
  // Demo AI responses based on the question and context
  const lowerPrompt = prompt.toLowerCase();
  
  if (lowerPrompt.includes('hello') || lowerPrompt.includes('hi')) {
    return `Hello! I'm your AI reading companion. I can see you're ${context.hasContext ? `currently exploring "${context.bookName}"` : 'ready to start exploring a book'}. What would you like to discuss about your reading experience?`;
  }
  
  if (context.hasContext) {
    const bookResponses = {
      'The Great Gatsby': [
        'The Great Gatsby is a masterpiece of American literature that explores themes of the American Dream, social class, and moral decay in the Jazz Age.',
        'Gatsby\'s obsession with Daisy represents the broader American obsession with wealth and status. What specific aspect interests you?',
        'The green light at the end of Daisy\'s dock is one of the most famous symbols in literature, representing hope and longing.'
      ],
      'Pride and Prejudice': [
        'Pride and Prejudice brilliantly depicts the social restrictions and expectations of 19th century England.',
        'Elizabeth Bennet is considered one of literature\'s greatest heroines - independent, witty, and ahead of her time.',
        'The relationship between Elizabeth and Darcy shows how first impressions can be misleading.'
      ]
    };
    
    const responses = bookResponses[context.bookName] || [
      `That's an interesting question about "${context.bookName}". This classic work offers rich themes and complex characters to explore.`,
      `In "${context.bookName}", there are many layers of meaning to discover. What particular aspect caught your attention?`
    ];
    
    return responses[Math.floor(Math.random() * responses.length)];
  }
  
  return `I'd love to discuss literature with you! Please select a book from the library above so I can provide more specific insights about your reading. I'm here to help enhance your audiobook experience with analysis, discussion questions, and thematic insights.`;
}

function startVoiceInput() {
  if (!('webkitSpeechRecognition' in window)) {
    alert('Voice input is not supported in this browser. Please use Chrome or Edge.');
    return;
  }
  
  const recognition = new webkitSpeechRecognition();
  recognition.lang = 'en-US';
  recognition.continuous = false;
  recognition.interimResults = false;
  
  // Update button state
  if (voiceChatBtn) {
    voiceChatBtn.disabled = true;
    const originalText = voiceChatBtn.innerHTML;
    voiceChatBtn.innerHTML = '<span class="btn-icon">🎙️</span> Listening...';
    
    recognition.onresult = function(event) {
      const transcript = event.results[0][0].transcript;
      if (chatInput) {
        chatInput.value = transcript;
      }
      
      // Add user message
      addMessageToChat('user', transcript);
      
      // Send with voice response enabled
      const config = configSelect?.value || 'default';
      sendChatMessage(transcript, config, true);
    };
    
    recognition.onerror = function(event) {
      console.error('Speech recognition error:', event.error);
      alert('Voice recognition failed: ' + event.error);
    };
    
    recognition.onend = function() {
      voiceChatBtn.disabled = false;
      voiceChatBtn.innerHTML = originalText;
    };
    
    recognition.start();
  }
}

// Updated chat interface for new HTML structure
const sendMessageBtn = document.getElementById('sendMessage');
const chatInput = document.getElementById('chatInput');
const voiceChatBtn = document.getElementById('voiceChat');

if (sendMessageBtn && chatInput) {
  sendMessageBtn.addEventListener('click', async () => {
    const prompt = chatInput.value.trim();
    const config = configSelect?.value || 'default';
    
    if (!prompt) {
      alert('Please enter a message');
      return;
    }
    
    // Clear input
    chatInput.value = '';
    
    // Add user message to chat
    addMessageToChat('user', prompt);
    
    // Send to AI and display response
    await sendChatMessage(prompt, config, false);
  });

  // Enable sending with Enter key
  chatInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessageBtn.click();
    }
  });
}

if (voiceChatBtn) {
  voiceChatBtn.addEventListener('click', () => {
    startVoiceInput();
  });
}

const voiceBtn = document.getElementById('startVoice');
if (voiceBtn) {
  voiceBtn.addEventListener('click', () => {
    if (!('webkitSpeechRecognition' in window)) {
      alert('Speech recognition not supported in this browser.');
      return;
    }
    
    // Update button state to show it's listening
    const originalText = voiceBtn.querySelector('.button-text').textContent;
    voiceBtn.querySelector('.button-text').textContent = 'Listening...';
    voiceBtn.disabled = true;
    
    const recognition = new webkitSpeechRecognition();
    recognition.lang = 'en-US';
    recognition.continuous = false;
    recognition.interimResults = false;
    
    recognition.onstart = () => {
      console.log('Voice recognition started');
    };
    
    recognition.onresult = function(event) {
      const transcript = event.results[0][0].transcript;
      const promptInput = document.getElementById('prompt');
      promptInput.value = transcript;
      const config = document.getElementById('configSelect').value;
      
      console.log('Voice input received:', transcript);
      
      // Voice response enabled (will speak the response)
      sendPrompt(transcript, config, true);
    };
    
    recognition.onerror = function(event) {
      console.error('Speech recognition error:', event.error);
      alert('Speech recognition failed: ' + event.error);
    };
    
    recognition.onend = function() {
      // Reset button state
      voiceBtn.querySelector('.button-text').textContent = originalText;
      voiceBtn.disabled = false;
      console.log('Voice recognition ended');
    };
    
    recognition.start();
  });
}

// Book Management Functions
async function uploadSingleBook() {
  const file = singleBookFile.files[0];
  if (!file) {
    alert('Please select an MP3 file');
    return;
  }

  // Mock upload for testing - API Gateway not available yet
  try {
    uploadSingleBtn.textContent = 'Uploading...';
    
    // Simulate upload delay
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    alert('Upload feature not implemented yet - using mock data for testing');
    loadBooksList();
    singleBookFile.value = '';
  } catch (err) {
    alert('Upload failed: ' + err.message);
  } finally {
    uploadSingleBtn.textContent = 'Upload Single Book';
  }
}

async function uploadChapterBook() {
  const bookName = bookNameInput.value.trim();
  const files = chapterFiles.files;
  
  if (!bookName) {
    alert('Please enter a book name');
    return;
  }
  
  if (files.length === 0) {
    alert('Please select MP3 chapter files');
    return;
  }

  // Mock upload for testing - API Gateway not available yet
  try {
    uploadChaptersBtn.textContent = 'Uploading...';
    
    // Simulate upload delay
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    alert('Upload feature not implemented yet - using mock data for testing');
    loadBooksList();
    bookNameInput.value = '';
    chapterFiles.value = '';
  } catch (err) {
    alert('Upload failed: ' + err.message);
  } finally {
    uploadChaptersBtn.textContent = 'Upload Chapters';
  }
}

async function loadBooksList() {
  try {
    if (booksListDiv) {
      booksListDiv.textContent = 'Loading books from backend...';
    }
    
    // Load real books from API Gateway
    const res = await fetch(`${apiBase}/books/list`);
    
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }
    
    const data = await res.json();
    console.log('Books loaded from backend:', data);
    
    // Update stats display
    updateStatsDisplay(data);
    
    // Update book list display
    let html = '';
    
    if (data.single_books && data.single_books.length > 0) {
      html += '<h4>📖 Single File Books</h4>';
      data.single_books.forEach(book => {
        const sizeMB = book.size ? (book.size / (1024 * 1024)).toFixed(1) : 'N/A';
        html += `
          <div class="book-item">
            <span>${book.name} (${sizeMB} MB)</span>
            <button onclick="deleteBook('${book.name}')">Delete</button>
          </div>
        `;
      });
    }
    
    if (data.chapter_books && data.chapter_books.length > 0) {
      html += '<h4>📚 Chapter Books</h4>';
      data.chapter_books.forEach(book => {
        html += `
          <div class="book-item">
            <span>${book.name} (${book.chapter_count || book.chapters?.length || 0} chapters)</span>
            <button onclick="deleteBook('${book.name}')">Delete</button>
            <details>
              <summary>Chapters</summary>
              <ul>
                ${(book.chapters || []).map(ch => `<li>${ch}</li>`).join('')}
              </ul>
            </details>
          </div>
        `;
      });
    }
    
    if ((!data.single_books || data.single_books.length === 0) && 
        (!data.chapter_books || data.chapter_books.length === 0)) {
      html = '<p>📚 Demo library loaded! Select a book below to start listening.</p>';
    }
    
    if (booksListDiv) {
      booksListDiv.innerHTML = html;
    }
    
    // Update player book selection dropdown
    updateBookSelector(data);
  } catch (err) {
    console.error('Failed to load books:', err);
    
    if (booksListDiv) {
      booksListDiv.innerHTML = `
        <div style="color: #ff6b6b; text-align: center; padding: 20px;">
          <h4>❌ Failed to load books</h4>
          <p>Error: ${err.message}</p>
          <p>Please check that the backend is running and try again.</p>
          <button onclick="loadBooksList()" style="margin-top: 10px; padding: 8px 16px; background: #ff6b6b; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Retry
          </button>
        </div>
      `;
    }
  }
}

function createDemoBooksData() {
  return {
    single_books: [
      {
        name: "Pride and Prejudice",
        filename: "pride-and-prejudice.mp3",
        size: 50 * 1024 * 1024 // 50MB
      },
      {
        name: "A Study in Scarlet",
        filename: "study-in-scarlet.mp3", 
        size: 35 * 1024 * 1024 // 35MB
      }
    ],
    chapter_books: [
      {
        name: "The Great Gatsby",
        chapter_count: 9,
        chapters: [
          "Chapter 1.mp3",
          "Chapter 2.mp3", 
          "Chapter 3.mp3",
          "Chapter 4.mp3",
          "Chapter 5.mp3",
          "Chapter 6.mp3",
          "Chapter 7.mp3",
          "Chapter 8.mp3",
          "Chapter 9.mp3"
        ]
      },
      {
        name: "Alice's Adventures in Wonderland",
        chapter_count: 12,
        chapters: [
          "Chapter 1 - Down the Rabbit Hole.mp3",
          "Chapter 2 - The Pool of Tears.mp3",
          "Chapter 3 - A Caucus Race.mp3",
          "Chapter 4 - The Rabbit Sends in a Little Bill.mp3",
          "Chapter 5 - Advice from a Caterpillar.mp3",
          "Chapter 6 - Pig and Pepper.mp3",
          "Chapter 7 - A Mad Tea Party.mp3",
          "Chapter 8 - The Queen's Croquet Ground.mp3",
          "Chapter 9 - The Mock Turtle's Story.mp3",
          "Chapter 10 - The Lobster Quadrille.mp3",
          "Chapter 11 - Who Stole the Tarts.mp3",
          "Chapter 12 - Alice's Evidence.mp3"
        ]
      }
    ]
  };
}

function updateStatsDisplay(data) {
  const totalBooksEl = document.getElementById('totalBooks');
  const totalChaptersEl = document.getElementById('totalChapters');
  
  if (totalBooksEl) {
    const totalBooks = (data.single_books?.length || 0) + (data.chapter_books?.length || 0);
    totalBooksEl.textContent = totalBooks;
  }
  
  if (totalChaptersEl) {
    const totalChapters = (data.chapter_books || []).reduce((sum, book) => 
      sum + (book.chapter_count || book.chapters?.length || 0), 0
    );
    totalChaptersEl.textContent = totalChapters;
  }
}

function updateBookSelector(data) {
  // Clear existing options
  bookSelect.innerHTML = '<option value="">Choose a book...</option>';
  
  // Add single books
  data.single_books.forEach(book => {
    const option = document.createElement('option');
    option.value = JSON.stringify({type: 'single', name: book.name, filename: book.filename});
    option.textContent = book.name;
    bookSelect.appendChild(option);
  });
  
  // Add chapter books
  data.chapter_books.forEach(book => {
    const option = document.createElement('option');
    option.value = JSON.stringify({type: 'chapters', name: book.name, chapters: book.chapters});
    option.textContent = `${book.name} (${book.chapter_count} chapters)`;
    bookSelect.appendChild(option);
  });
}

function handleBookSelection() {
  const selectedValue = bookSelect.value;
  if (!selectedValue) {
    chapterSelect.style.display = 'none';
    audioPlayer.src = '';
    playerStatus.textContent = 'Select a book to start listening';
    // Clear context
    currentContext = { bookName: null, bookType: null, chapterName: null, hasContext: false };
    updateContextStatus();
    return;
  }
  
  const bookData = JSON.parse(selectedValue);
  
  if (bookData.type === 'single') {
    // Single file book
    if (chapterNavigation) {
      chapterNavigation.style.display = 'none';
    }
    // In demo mode, use placeholder audio URL
    audioPlayer.src = `${transcriptionBase}/books/play/${encodeURIComponent(bookData.filename)}`;
    
    if (playerStatus) {
      playerStatus.textContent = `Ready to play: ${bookData.name}`;
    }
    if (currentBookInfo) {
      currentBookInfo.textContent = bookData.name;
    }
    
    // Set context for single book
    currentContext = {
      bookName: bookData.name,
      bookType: 'single',
      chapterName: null,
      hasContext: true
    };
    
    // Show intelligence panel for single books too
    const intelligencePanel = document.getElementById('intelligencePanel');
    if (intelligencePanel) {
      intelligencePanel.style.display = 'block';
    }
  } else if (bookData.type === 'chapters') {
    // Chapter book - show chapter selector
    if (chapterNavigation) {
      chapterNavigation.style.display = 'block';
    }
    
    // Populate chapter dropdown
    if (chapterSelect) {
      chapterSelect.innerHTML = '<option value="">Choose a chapter...</option>';
      bookData.chapters.forEach(chapter => {
        const option = document.createElement('option');
        option.value = chapter;
        option.textContent = chapter.replace('.mp3', '');
        chapterSelect.appendChild(option);
      });
    }
    
    audioPlayer.src = '';
    if (playerStatus) {
      playerStatus.textContent = `Book selected: ${bookData.name}. Choose a chapter to play.`;
    }
    if (currentBookInfo) {
      currentBookInfo.textContent = `${bookData.name} - Select Chapter`;
    }
    
    // Set partial context (book selected, but no chapter yet)
    currentContext = {
      bookName: bookData.name,
      bookType: 'chapters',
      chapterName: null,
      hasContext: false // Not complete until chapter is selected
    };
  }
  
  updateContextStatus();
}

function handleChapterSelection() {
  const selectedBook = bookSelect.value;
  const selectedChapter = chapterSelect ? chapterSelect.value : null;
  
  if (!selectedBook || !selectedChapter) {
    if (currentContext.bookType === 'chapters') {
      currentContext.hasContext = false;
      updateContextStatus();
    }
    return;
  }
  
  const bookData = JSON.parse(selectedBook);
  // In demo mode, just use a placeholder audio URL
  audioPlayer.src = `${transcriptionBase}/books/play/${encodeURIComponent(bookData.name)}/${encodeURIComponent(selectedChapter)}`;
  
  if (playerStatus) {
    playerStatus.textContent = `Ready to play: ${bookData.name} - ${selectedChapter.replace('.mp3', '')}`;
  }
  if (currentBookInfo) {
    currentBookInfo.textContent = `${bookData.name} - ${selectedChapter.replace('.mp3', '')}`;
  }
  
  // Update context with chapter information
  currentContext.chapterName = selectedChapter;
  currentContext.hasContext = true;
  updateContextStatus();
  
  // Show intelligence panel now that we have a complete selection
  const intelligencePanel = document.getElementById('intelligencePanel');
  if (intelligencePanel) {
    intelligencePanel.style.display = 'block';
  }
}

function updateContextStatus() {
  const contextDiv = document.getElementById('contextStatus');
  if (!contextDiv) return;
  
  const statusIcon = contextDiv.querySelector('.status-icon');
  const statusText = contextDiv.querySelector('.status-text');
  
  if (currentContext.hasContext) {
    let contextText = `Mission: ${currentContext.bookName}`;
    if (currentContext.chapterName) {
      contextText += ` - ${currentContext.chapterName.replace('.mp3', '')}`;
    }
    statusIcon.textContent = '✓';
    statusText.textContent = contextText;
    contextDiv.style.background = 'linear-gradient(135deg, rgba(74, 155, 155, 0.15) 0%, rgba(230, 184, 71, 0.15) 100%)';
    contextDiv.style.borderColor = 'var(--teal-blue)';
  } else if (currentContext.bookName && currentContext.bookType === 'chapters') {
    statusIcon.textContent = '⚠';
    statusText.textContent = `${currentContext.bookName} - Chapter selection required`;
    contextDiv.style.background = 'linear-gradient(135deg, rgba(230, 184, 71, 0.15) 0%, rgba(204, 107, 90, 0.15) 100%)';
    contextDiv.style.borderColor = 'var(--golden-yellow)';
  } else {
    statusIcon.textContent = '⚡';
    statusText.textContent = 'Awaiting mission parameters...';
    contextDiv.style.background = 'linear-gradient(135deg, rgba(204, 107, 90, 0.1) 0%, rgba(230, 184, 71, 0.1) 100%)';
    contextDiv.style.borderColor = 'rgba(204, 107, 90, 0.2)';
  }
}

async function deleteBook(bookName) {
  if (!confirm(`Are you sure you want to delete "${bookName}"?`)) {
    return;
  }

  // Mock delete for testing - API Gateway not available yet
  try {
    alert('Delete feature not implemented yet - using mock data for testing');
    loadBooksList();
  } catch (err) {
    alert('Delete failed: ' + err.message);
  }
}

// Event Listeners
if (uploadSingleBtn) uploadSingleBtn.addEventListener('click', uploadSingleBook);
if (uploadChaptersBtn) uploadChaptersBtn.addEventListener('click', uploadChapterBook);
if (refreshBooksBtn) refreshBooksBtn.addEventListener('click', loadBooksList);
if (bookSelect) bookSelect.addEventListener('change', handleBookSelection);
if (chapterSelect) chapterSelect.addEventListener('change', handleChapterSelection);

// Test backend connectivity and update status
async function initializeApp() {
  try {
    // Test basic connectivity
    const healthResponse = await fetch(`${apiBase}/health`);
    const isHealthy = healthResponse.ok;
    
    // Test specific endpoints
    const configsResponse = await fetch(`${apiBase}/configs`);
    const booksResponse = await fetch(`${apiBase}/books/list`);
    
    const configsWorking = configsResponse.ok;
    const booksWorking = booksResponse.ok;
    
    // Update connection status
    updateConnectionStatus(isHealthy, configsWorking, booksWorking);
    
    // Load data
    await loadConfigs();
    await loadBooksList();
    
  } catch (error) {
    console.error('Failed to initialize app:', error);
    updateConnectionStatus(false, false, false);
    
    // Still try to load demo data
    const demoData = createDemoBooksData();
    updateStatsDisplay(demoData);
    updateBookSelector(demoData);
  }
}

function updateConnectionStatus(health, configs, books) {
  const statusIndicator = document.querySelector('.status-indicator');
  const statusText = document.querySelector('.status-text');
  
  if (!statusIndicator || !statusText) return;
  
  if (health && configs && books) {
    statusIndicator.className = 'status-indicator online';
    statusText.textContent = 'Connected';
  } else if (health && configs) {
    statusIndicator.className = 'status-indicator warning';
    statusText.textContent = 'Demo Mode';
  } else if (health) {
    statusIndicator.className = 'status-indicator warning';
    statusText.textContent = 'Limited';
  } else {
    statusIndicator.className = 'status-indicator offline';
    statusText.textContent = 'Offline';
  }
}

// Initialize app
initializeApp();

// Initialize context status
updateContextStatus();

// Chapter Intelligence Panel functionality
let currentChapters = [];
let selectedChapter = null;

// Tab switching functionality
document.addEventListener('DOMContentLoaded', function() {
  const tabButtons = document.querySelectorAll('.tab-button');
  const tabContents = document.querySelectorAll('.tab-content');
  
  tabButtons.forEach(button => {
    button.addEventListener('click', function() {
      const tabId = this.dataset.tab;
      
      // Remove active class from all buttons and contents
      tabButtons.forEach(btn => btn.classList.remove('active'));
      tabContents.forEach(content => content.classList.remove('active'));
      
      // Add active class to clicked button and corresponding content
      this.classList.add('active');
      document.getElementById(tabId + 'Tab').classList.add('active');
    });
  });

  // Show chapter panel when book is selected
  function showChapterPanel() {
    const chapterPanel = document.getElementById('chapterPanel');
    if (chapterPanel && currentContext.hasContext) {
      chapterPanel.style.display = 'block';
    }
  }

  // Override the existing handleBookSelection to show chapter panel
  const originalHandleBookSelection = window.handleBookSelection || handleBookSelection;
  window.handleBookSelection = function() {
    originalHandleBookSelection.call(this);
    if (currentContext.hasContext) {
      showChapterPanel();
    }
  };

  // Chapter Detection
  const detectChaptersBtn = document.getElementById('detectChapters');
  if (detectChaptersBtn) {
    detectChaptersBtn.addEventListener('click', async function() {
      if (!currentContext.hasContext) {
        alert('Please select a book first');
        return;
      }

      const originalText = this.querySelector('.button-text').textContent;
      this.querySelector('.button-text').textContent = 'Detecting...';
      this.disabled = true;

      try {
        const response = await fetch(`${transcriptionBase}/detect-chapters`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            book_name: currentContext.bookName,
            chapter_name: currentContext.chapterName
          })
        });

        const data = await response.json();
        
        if (response.ok) {
          currentChapters = data.chapters || [];
          displayChapters(currentChapters);
        } else {
          alert('Chapter detection failed: ' + (data.detail || 'Unknown error'));
        }
      } catch (error) {
        alert('Error detecting chapters: ' + error.message);
      } finally {
        this.querySelector('.button-text').textContent = originalText;
        this.disabled = false;
      }
    });
  }

  // Summary Generation
  const generateSummaryBtn = document.getElementById('generateSummary');
  if (generateSummaryBtn) {
    generateSummaryBtn.addEventListener('click', async function() {
      if (!selectedChapter) {
        alert('Please select a chapter first by detecting chapters');
        return;
      }

      const summaryStyle = document.getElementById('summaryStyle').value;
      const originalText = this.querySelector('.button-text').textContent;
      this.querySelector('.button-text').textContent = 'Generating...';
      this.disabled = true;

      try {
        const response = await fetch(`${transcriptionBase}/summarize-chapter`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            book_name: currentContext.bookName,
            chapter_id: selectedChapter.id,
            style: summaryStyle
          })
        });

        const data = await response.json();
        
        if (response.ok) {
          displaySummary(data.summary, summaryStyle);
        } else {
          alert('Summary generation failed: ' + (data.detail || 'Unknown error'));
        }
      } catch (error) {
        alert('Error generating summary: ' + error.message);
      } finally {
        this.querySelector('.button-text').textContent = originalText;
        this.disabled = false;
      }
    });
  }

  // Question Generation
  const generateQuestionsBtn = document.getElementById('generateQuestions');
  if (generateQuestionsBtn) {
    generateQuestionsBtn.addEventListener('click', async function() {
      if (!selectedChapter) {
        alert('Please select a chapter first by detecting chapters');
        return;
      }

      const difficulty = document.getElementById('questionDifficulty').value;
      const readingMode = document.getElementById('readingMode').value;
      const originalText = this.querySelector('.button-text').textContent;
      this.querySelector('.button-text').textContent = 'Generating...';
      this.disabled = true;

      try {
        const response = await fetch(`${transcriptionBase}/generate-questions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            book_name: currentContext.bookName,
            chapter_id: selectedChapter.id,
            difficulty: difficulty,
            reading_mode: readingMode,
            num_questions: 5
          })
        });

        const data = await response.json();
        
        if (response.ok) {
          displayQuestions(data.questions);
        } else {
          alert('Question generation failed: ' + (data.detail || 'Unknown error'));
        }
      } catch (error) {
        alert('Error generating questions: ' + error.message);
      } finally {
        this.querySelector('.button-text').textContent = originalText;
        this.disabled = false;
      }
    });
  }
});

// Audio position tracking
audioPlayer.addEventListener('timeupdate', function() {
  if (currentContext.hasContext) {
    currentContext.currentPosition = audioPlayer.currentTime;
    console.log('Audio position updated:', currentContext.currentPosition);
    
    // Update context status with current position
    const contextDiv = document.getElementById('contextStatus');
    const statusText = contextDiv?.querySelector('.status-text');
    if (statusText && currentContext.hasContext) {
      const minutes = Math.floor(currentContext.currentPosition / 60);
      const seconds = Math.floor(currentContext.currentPosition % 60);
      
      let contextText = `Mission: ${currentContext.bookName}`;
      if (currentContext.chapterName) {
        contextText += ` - ${currentContext.chapterName.replace('.mp3', '')}`;
      }
      contextText += ` [${minutes}:${seconds.toString().padStart(2, '0')}]`;
      
      statusText.textContent = contextText;
    }
    
    // Update audio visualizer
    updateAudioVisualizer();
  }
});

// Update position when user seeks
audioPlayer.addEventListener('seeked', function() {
  if (currentContext.hasContext) {
    currentContext.currentPosition = audioPlayer.currentTime;
    currentContext.lastContextUpdate = Date.now();
  }
});

// Audio Visualizer Function
function updateAudioVisualizer() {
  const vizBars = document.querySelectorAll('.viz-bar');
  if (vizBars.length === 0) return;
  
  // Generate random visualization data based on audio playing state
  if (!audioPlayer.paused && !audioPlayer.ended) {
    vizBars.forEach((bar, index) => {
      const baseHeight = [10, 20, 30, 20, 15][index];
      const randomMultiplier = 0.3 + Math.random() * 0.7;
      const newHeight = Math.floor(baseHeight * randomMultiplier);
      bar.style.height = `${newHeight}px`;
    });
  } else {
    // Reset to base heights when not playing
    vizBars.forEach((bar, index) => {
      const baseHeight = [10, 20, 30, 20, 15][index];
      bar.style.height = `${Math.floor(baseHeight * 0.3)}px`;
    });
  }
}

// Enhanced Button Interactions
document.addEventListener('DOMContentLoaded', function() {
  // Add space-themed loading states
  const buttons = document.querySelectorAll('.space-button');
  buttons.forEach(button => {
    button.addEventListener('click', function() {
      // Add a brief "transmission" effect
      const originalText = button.querySelector('.button-text').textContent;
      const buttonText = button.querySelector('.button-text');
      
      if (button.id === 'sendText' && originalText === 'Transmit') {
        buttonText.textContent = 'SENDING...';
        setTimeout(() => {
          buttonText.textContent = originalText;
        }, 2000);
      }
    });
  });
  
  // Enhanced select interactions
  const selects = document.querySelectorAll('.space-select');
  selects.forEach(select => {
    select.addEventListener('change', function() {
      // Add brief glow effect on selection
      const wrapper = select.closest('.select-wrapper');
      const glow = wrapper?.querySelector('.select-glow');
      if (glow) {
        glow.style.boxShadow = '0 0 20px rgba(230, 184, 71, 0.4)';
        setTimeout(() => {
          glow.style.boxShadow = '';
        }, 300);
      }
    });
  });
  
  // Terminal typing effect for responses
  window.typewriterEffect = function(element, text, speed = 50) {
    element.textContent = '';
    let i = 0;
    const timer = setInterval(() => {
      if (i < text.length) {
        element.textContent += text.charAt(i);
        i++;
      } else {
        clearInterval(timer);
      }
    }, speed);
  };
  
  // Start visualizer update loop
  setInterval(updateAudioVisualizer, 200);
});

// Display functions for Chapter Intelligence Panel
function displayChapters(chapters) {
  const chaptersList = document.getElementById('chaptersList');
  if (!chaptersList) return;

  if (!chapters || chapters.length === 0) {
    chaptersList.innerHTML = '<div class="no-chapters">No chapters detected. Try uploading a multi-chapter audiobook.</div>';
    return;
  }

  let html = '<div class="chapters-grid">';
  chapters.forEach((chapter, index) => {
    const duration = chapter.duration ? formatDuration(chapter.duration) : 'Unknown';
    const confidence = chapter.confidence ? Math.round(chapter.confidence * 100) : 0;
    
    html += `
      <div class="chapter-card ${selectedChapter?.id === chapter.id ? 'selected' : ''}" 
           onclick="selectChapter(${index})">
        <div class="chapter-header">
          <span class="chapter-number">${index + 1}</span>
          <span class="chapter-duration">${duration}</span>
        </div>
        <h4 class="chapter-title">${chapter.title || `Chapter ${index + 1}`}</h4>
        <p class="chapter-summary">${chapter.summary || 'AI-detected chapter boundary'}</p>
        <div class="chapter-meta">
          <span class="confidence-badge">Confidence: ${confidence}%</span>
        </div>
      </div>
    `;
  });
  html += '</div>';
  
  chaptersList.innerHTML = html;
}

function selectChapter(index) {
  selectedChapter = currentChapters[index];
  
  // Update visual selection
  const cards = document.querySelectorAll('.chapter-card');
  cards.forEach((card, i) => {
    if (i === index) {
      card.classList.add('selected');
    } else {
      card.classList.remove('selected');
    }
  });
}

function displaySummary(summary, style) {
  const summaryContent = document.getElementById('summaryContent');
  if (!summaryContent) return;

  let html = `
    <div class="summary-result">
      <div class="summary-header">
        <h4>Chapter Summary (${style.replace('_', ' ').toUpperCase()})</h4>
        <span class="summary-style-badge">${style}</span>
      </div>
      <div class="summary-text">
        ${summary.content || summary}
      </div>
  `;

  // Add additional metadata if available
  if (summary.themes && summary.themes.length > 0) {
    html += `
      <div class="summary-metadata">
        <h5>Key Themes:</h5>
        <div class="themes-tags">
          ${summary.themes.map(theme => `<span class="theme-tag">${theme}</span>`).join('')}
        </div>
      </div>
    `;
  }

  if (summary.characters && summary.characters.length > 0) {
    html += `
      <div class="summary-metadata">
        <h5>Characters Mentioned:</h5>
        <div class="characters-tags">
          ${summary.characters.map(char => `<span class="character-tag">${char}</span>`).join('')}
        </div>
      </div>
    `;
  }

  html += '</div>';
  summaryContent.innerHTML = html;
}

function displayQuestions(questions) {
  const questionsContent = document.getElementById('questionsContent');
  if (!questionsContent) return;

  if (!questions || questions.length === 0) {
    questionsContent.innerHTML = '<p class="no-questions">No questions generated. Try a different difficulty or reading mode.</p>';
    return;
  }

  let html = '<div class="questions-list">';
  
  questions.forEach((question, index) => {
    html += `
      <div class="question-item">
        <div class="question-header">
          <span class="question-number">Q${index + 1}</span>
          <span class="question-type-badge">${question.type || 'general'}</span>
        </div>
        <div class="question-text">${question.question}</div>
        
        ${question.options && question.options.length > 0 ? `
          <div class="question-options">
            ${question.options.map((option, optIndex) => 
              `<div class="option-item">
                <span class="option-letter">${String.fromCharCode(65 + optIndex)}</span>
                <span class="option-text">${option}</span>
              </div>`
            ).join('')}
          </div>
        ` : ''}
        
        ${question.suggested_answer ? `
          <details class="answer-details">
            <summary>Show Answer Guide</summary>
            <div class="answer-guide">${question.suggested_answer}</div>
          </details>
        ` : ''}
      </div>
    `;
  });
  
  html += '</div>';
  questionsContent.innerHTML = html;
}

function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  
  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  } else {
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  }
}
