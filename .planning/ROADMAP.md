# Project Roadmap: True Me

## Phase 1: Foundation & Infrastructure
- [ ] Flutter workspace initialization & folder structure
- [ ] Theme system: Liquid Glass UI components (cards, buttons, appbar, specular gloss)
- [ ] GoRouter navigation map skeleton
- [ ] Firebase setup (Auth with Google & Email, Firestore user profile schemas)
- [ ] Supabase PostgreSQL setup with `pgvector` tables (`document_chunks`, `user_files`, `study_sessions`)

## Phase 2: Mother AI "Sage" & AI Routing
- [ ] Multi-provider AI Router (Gemini, Groq, Cloudflare, OpenRouter fallback)
- [ ] Sage Agent implementation with function calling tools
- [ ] SM-2 Spaced Repetition calculation engine in Dart
- [ ] Daily background job (WorkManager at 6:00 AM)
- [ ] FCM push notifications for morning motivation & study schedule
- [ ] Daily Study Plan UI screen

## Phase 3: Content Ingestion Engine
- [ ] User Cloud Storage integration (Google Drive file picker & upload)
- [ ] Document processing (PDF text extraction, 1000-token chunker)
- [ ] Vectorization pipeline (Gemini `text-embedding-004` to Supabase `pgvector`)
- [ ] On-device OCR (Google ML Kit for notes & handwriting)
- [ ] Audio recording & Groq Whisper Large v3 transcription
- [ ] Web URL and YouTube transcript fetchers + summarizer

## Phase 4: Core Study Tools
- [ ] Grounded RAG Chat with Notebook & Single Documents (Groq LLaMA 70B)
- [ ] Flashcard generator (Groq LLaMA 8B) & interactive flip player
- [ ] Adaptive Quiz generator (MCQ, True/False, Fill-in-the-blank)
- [ ] Rich Text Note Editor (`flutter_quill`)
- [ ] Interactive Mind Map generator (`graphview`)

## Phase 5: Voice Tutor & Explainer Video
- [ ] 30-minute interactive Voice Tutor loop (STT -> Groq -> TTS)
- [ ] Explainer video generator (Script generation -> timeline animation engine)
- [ ] Animation scene types (text typewriter, diagram painter, Lottie animations)
- [ ] Interactive media scrubber with playback speed controls

## Phase 6: Document Export & Progress Dashboard
- [ ] Document exporters (PDF with `pdf`/`printing`, PPTX, DOCX)
- [ ] Progress Dashboard (Study streaks, topic mastery curves, weak area indicators)
- [ ] Gamification & achievement badge unlock system

## Phase 7: Hardening, Polish & Launch
- [ ] Offline caching layer (Hive for flashcards & notes)
- [ ] AI error handling & quota failover testing
- [ ] Performance profiling & image caching
- [ ] Store deployment configuration (Android & iOS release bundles)
