class ContextManager:
    def __init__(self, window_size=2000):
        self.context = ""
        self.window_size = window_size

    def read_in_chunks(self, file_path, chunk_size=500):
        with open(file_path, 'r') as f:
            while chunk := f.read(chunk_size):
                self.context += chunk
                self.context = self.context[-self.window_size:]
                yield chunk

    def get_context(self):
        return self.context
