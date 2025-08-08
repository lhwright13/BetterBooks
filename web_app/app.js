const apiBase = 'http://localhost:8000';

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
    
    const contextRes = await fetch(`${apiBase}/context`, {
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

async function sendPrompt(prompt, config) {
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

    // Convert the response text to speech
    if (data.text) {
      const ttsRes = await fetch(`${apiBase}/tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          text: data.text,
          config: config  // Pass the same config used for LLM
        })
      });
      const ttsData = await ttsRes.json();
      if (ttsData.audio) {
        audioPlayer.src = 'data:audio/mpeg;base64,' + ttsData.audio;
        await audioPlayer.play();
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
  sendPrompt(prompt, config);
});

const voiceBtn = document.getElementById('startVoice');
if (voiceBtn) {
  voiceBtn.addEventListener('click', () => {
    if (!('webkitSpeechRecognition' in window)) {
      alert('Speech recognition not supported in this browser.');
      return;
    }
    const recognition = new webkitSpeechRecognition();
    recognition.lang = 'en-US';
    recognition.onresult = function(event) {
      const transcript = event.results[0][0].transcript;
      const promptInput = document.getElementById('prompt');
      promptInput.value = transcript;
      const config = document.getElementById('configSelect').value;
      sendPrompt(transcript, config);
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

  const formData = new FormData();
  formData.append('file', file);

  try {
    uploadSingleBtn.textContent = 'Uploading...';
    const res = await fetch(`${apiBase}/books/upload`, {
      method: 'POST',
      body: formData
    });
    const data = await res.json();
    
    if (res.ok) {
      alert(data.message);
      loadBooksList();
      singleBookFile.value = '';
    } else {
      alert('Error: ' + data.detail);
    }
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

  const formData = new FormData();
  for (let file of files) {
    formData.append('files', file);
  }

  try {
    uploadChaptersBtn.textContent = 'Uploading...';
    const res = await fetch(`${apiBase}/books/upload-chapters?book_name=${encodeURIComponent(bookName)}`, {
      method: 'POST',
      body: formData
    });
    const data = await res.json();
    
    if (res.ok) {
      alert(data.message);
      loadBooksList();
      bookNameInput.value = '';
      chapterFiles.value = '';
    } else {
      alert('Error: ' + data.detail);
    }
  } catch (err) {
    alert('Upload failed: ' + err.message);
  } finally {
    uploadChaptersBtn.textContent = 'Upload Chapters';
  }
}

async function loadBooksList() {
  try {
    booksListDiv.textContent = 'Loading...';
    const res = await fetch(`${apiBase}/books/list`);
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
    audioPlayer.src = `${apiBase}/books/play/${bookData.filename}`;
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
  audioPlayer.src = `${apiBase}/books/play/${bookData.name}/${selectedChapter}`;
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

  try {
    const res = await fetch(`${apiBase}/books/${encodeURIComponent(bookName)}`, {
      method: 'DELETE'
    });
    const data = await res.json();
    
    if (res.ok) {
      alert(data.message);
      loadBooksList();
    } else {
      alert('Error: ' + data.detail);
    }
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
