const apiBase = 'http://localhost:8000';

const audioInput = document.getElementById('audioFile');
const audioPlayer = document.getElementById('audioPlayer');

audioInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (file) {
    audioPlayer.src = URL.createObjectURL(file);
  }
});

document.getElementById('sendText').addEventListener('click', async () => {
  const prompt = document.getElementById('prompt').value;
  const respDiv = document.getElementById('response');
  respDiv.textContent = 'Loading...';
  try {
    const res = await fetch(`${apiBase}/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt })
    });
    const data = await res.json();
    respDiv.textContent = data.text || JSON.stringify(data);
  } catch (err) {
    respDiv.textContent = 'Error: ' + err;
  }
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
      document.getElementById('prompt').value = transcript;
    };
    recognition.start();
  });
}
