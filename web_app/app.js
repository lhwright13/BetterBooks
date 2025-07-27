const apiBase = 'http://localhost:8000';

const audioInput = document.getElementById('audioFile');
const audioPlayer = document.getElementById('audioPlayer');
const configSelect = document.getElementById('configSelect');

async function loadConfigs() {
  if (!configSelect) return;
  try {
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
  }
}

loadConfigs();
audioInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (file) {
    audioPlayer.src = URL.createObjectURL(file);
  }
});

async function sendPrompt(prompt, config) {
  const respDiv = document.getElementById('response');
  respDiv.textContent = 'Loading...';
  try {
    const res = await fetch(`${apiBase}/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, config })
    });
    const data = await res.json();
    respDiv.textContent = data.text || JSON.stringify(data);

    // Convert the response text to speech
    if (data.text) {
      const ttsRes = await fetch(`${apiBase}/tts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: data.text })
      });
      const ttsData = await ttsRes.json();
      if (ttsData.audio) {
        audioPlayer.src = 'data:audio/wav;base64,' + ttsData.audio;
        await audioPlayer.play();
      }
    }
  } catch (err) {
    respDiv.textContent = 'Error: ' + err;
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
