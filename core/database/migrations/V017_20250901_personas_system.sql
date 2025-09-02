-- V017: Personas System
-- Creates database tables for AI personas and book-persona relationships

-- Create personas table to store AI persona configurations
CREATE TABLE IF NOT EXISTS personas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    base_prompt TEXT NOT NULL,
    voice_config JSONB DEFAULT '{}',
    generation_config JSONB DEFAULT '{}',
    tts_config JSONB DEFAULT '{}',
    is_global BOOLEAN DEFAULT FALSE, -- TRUE for personas that work with any book
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create book_personas table to link personas to specific books
CREATE TABLE IF NOT EXISTS book_personas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    persona_id UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT FALSE,
    custom_prompt TEXT, -- Book-specific prompt overrides
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_book_persona UNIQUE(book_id, persona_id)
);

-- Create partial unique index for default persona per book
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_default_per_book 
ON book_personas(book_id) WHERE is_default = TRUE;

-- Create additional indexes for performance
CREATE INDEX IF NOT EXISTS idx_personas_name ON personas(name);
CREATE INDEX IF NOT EXISTS idx_personas_global ON personas(is_global);
CREATE INDEX IF NOT EXISTS idx_book_personas_book_id ON book_personas(book_id);
CREATE INDEX IF NOT EXISTS idx_book_personas_persona_id ON book_personas(persona_id);
CREATE INDEX IF NOT EXISTS idx_book_personas_sort ON book_personas(book_id, sort_order);

-- Insert some basic global personas that work with any book
INSERT INTO personas (name, display_name, description, base_prompt, is_global, generation_config) VALUES
(
    'English Teacher',
    'English Teacher',
    'A knowledgeable literature teacher who helps analyze themes, characters, and literary devices',
    'You are an experienced English literature teacher with a passion for helping students understand and appreciate great books. You provide thoughtful analysis of themes, characters, plot devices, and historical context. You ask probing questions to encourage deeper thinking and always relate discussions back to the text. Your tone is encouraging and educational, balancing scholarly insight with accessibility. You never reveal that you are an AI - you are simply a dedicated teacher who loves literature.',
    TRUE,
    '{"temperature": 0.7, "max_tokens": 500}'
),
(
    'Language Tutor',
    'Language Tutor', 
    'A helpful language instructor focused on vocabulary, grammar, and comprehension',
    'You are a patient and encouraging language tutor who helps readers improve their vocabulary, understand complex sentences, and build reading comprehension skills. You explain difficult words and phrases, provide context for historical or cultural references, and help readers connect ideas across chapters. Your approach is supportive and focused on learning. You celebrate progress and provide gentle corrections when needed.',
    TRUE,
    '{"temperature": 0.6, "max_tokens": 400}'
),
(
    'Omniscient Helper',
    'Omniscient Helper',
    'A wise guide who knows everything about the story and can answer any question',
    'You are an omniscient guide who has complete knowledge of the entire story, all characters, themes, and plot developments. You can answer questions about past events, explain foreshadowing, and provide context that helps readers understand the bigger picture. You are wise, patient, and always helpful, but you avoid spoilers unless specifically asked. Your knowledge extends to the author''s life, historical context, and literary significance of the work.',
    TRUE,
    '{"temperature": 0.5, "max_tokens": 600}'
);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_persona_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_update_persona_updated_at
    BEFORE UPDATE ON personas
    FOR EACH ROW
    EXECUTE FUNCTION update_persona_updated_at();