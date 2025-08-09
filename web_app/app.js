// Temporarily connect directly to services while API Gateway is building
const apiBase = 'http://localhost:8002'; // LLM Gateway for configs and chat
const transcriptionBase = 'http://localhost:8003'; // Transcription service for chapter intelligence

// Player elements
const audioPlayer = document.getElementById('audioPlayer');
const bookSelect = document.getElementById('bookSelect');
const chapterSelect = document.getElementById('chapterSelect');
const chapterDropdown = document.getElementById('chapterDropdown');
const playerStatus = document.getElementById('playerStatus');
const configSelect = document.getElementById('configSelect');

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
const refreshBooksBtn = document.getElementById('refreshBooks');

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

document.getElementById('sendText').addEventListener('click', async () => {
  const prompt = document.getElementById('prompt').value;
  const config = document.getElementById('configSelect').value;
  // Text-only response (no voice)
  sendPrompt(prompt, config, false);
});

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
    booksListDiv.textContent = 'Loading...';
    
    // Load real books from transcription service
    const res = await fetch(`${transcriptionBase}/books/list`);
    const data = await res.json();
    
    // Update book list display
    let html = '';
    
    if (data.single_books.length > 0) {
      html += '<h4>📖 Single File Books</h4>';
      data.single_books.forEach(book => {
        const sizeMB = (book.size / (1024 * 1024)).toFixed(1);
        html += `
          <div class="book-item">
            <span>${book.name} (${sizeMB} MB)</span>
            <button onclick="deleteBook('${book.name}')">Delete</button>
          </div>
        `;
      });
    }
    
    if (data.chapter_books.length > 0) {
      html += '<h4>📚 Chapter Books</h4>';
      data.chapter_books.forEach(book => {
        html += `
          <div class="book-item">
            <span>${book.name} (${book.chapter_count} chapters)</span>
            <button onclick="deleteBook('${book.name}')">Delete</button>
            <details>
              <summary>Chapters</summary>
              <ul>
                ${book.chapters.map(ch => `<li>${ch}</li>`).join('')}
              </ul>
            </details>
          </div>
        `;
      });
    }
    
    if (data.single_books.length === 0 && data.chapter_books.length === 0) {
      html = '<p>No books uploaded yet. Upload some MP3 files to get started!</p>';
    }
    
    booksListDiv.innerHTML = html;
    
    // Update player book selection dropdown
    updateBookSelector(data);
  } catch (err) {
    booksListDiv.textContent = 'Failed to load books: ' + err.message;
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
    chapterSelect.style.display = 'none';
    // Load real audio file
    audioPlayer.src = `${transcriptionBase}/books/play/${bookData.filename}`;
    playerStatus.textContent = `Playing: ${bookData.name}`;
    
    // Set context for single book
    currentContext = {
      bookName: bookData.name,
      bookType: 'single',
      chapterName: null,
      hasContext: true
    };
  } else if (bookData.type === 'chapters') {
    // Chapter book - show chapter selector
    chapterSelect.style.display = 'block';
    
    // Populate chapter dropdown
    chapterDropdown.innerHTML = '<option value="">Choose a chapter...</option>';
    bookData.chapters.forEach(chapter => {
      const option = document.createElement('option');
      option.value = chapter;
      option.textContent = chapter.replace('.mp3', '');
      chapterDropdown.appendChild(option);
    });
    
    audioPlayer.src = '';
    playerStatus.textContent = `Book selected: ${bookData.name}. Choose a chapter to play.`;
    
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
  const selectedChapter = chapterDropdown.value;
  
  if (!selectedBook || !selectedChapter) {
    if (currentContext.bookType === 'chapters') {
      currentContext.hasContext = false;
      updateContextStatus();
    }
    return;
  }
  
  const bookData = JSON.parse(selectedBook);
  // Load real chapter audio file
  audioPlayer.src = `${transcriptionBase}/books/play/${bookData.name}/${selectedChapter}`;
  playerStatus.textContent = `Playing: ${bookData.name} - ${selectedChapter.replace('.mp3', '')}`;
  
  // Update context with chapter information
  currentContext.chapterName = selectedChapter;
  currentContext.hasContext = true;
  updateContextStatus();
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
uploadSingleBtn.addEventListener('click', uploadSingleBook);
uploadChaptersBtn.addEventListener('click', uploadChapterBook);
refreshBooksBtn.addEventListener('click', loadBooksList);
bookSelect.addEventListener('change', handleBookSelection);
chapterDropdown.addEventListener('change', handleChapterSelection);

// Load initial data
loadConfigs();
loadBooksList();

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
